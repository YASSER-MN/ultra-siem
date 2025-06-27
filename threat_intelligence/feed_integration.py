#!/usr/bin/env python3
"""
Ultra SIEM Threat Intelligence Feed Integration
Real-time IoC ingestion, processing, and distribution
"""

import asyncio
import aiohttp
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any
import pandas as pd
import clickhouse_connect
from cryptography.fernet import Fernet
import hashlib
import yara

class ThreatIntelligenceFeed:
    def __init__(self, config_path: str = "config/threat_intel.json"):
        self.config = self._load_config(config_path)
        self.client = clickhouse_connect.get_client(
            host=self.config['clickhouse']['host'],
            port=self.config['clickhouse']['port'],
            username=self.config['clickhouse']['username'],
            password=self.config['clickhouse']['password']
        )
        self.cipher = Fernet(self.config['encryption_key'].encode())
        self.yara_rules = None
        self._setup_logging()
        
    def _load_config(self, config_path: str) -> Dict:
        """Load configuration from file"""
        default_config = {
            "feeds": [
                {
                    "name": "emergingthreats",
                    "url": "https://rules.emergingthreats.net/open/suricata/rules/",
                    "type": "suricata",
                    "update_interval": 3600
                },
                {
                    "name": "alienvault",
                    "url": "https://reputation.alienvault.com/reputation.data",
                    "type": "reputation",
                    "update_interval": 1800
                },
                {
                    "name": "malwaredomains",
                    "url": "http://mirror1.malwaredomains.com/files/justdomains",
                    "type": "domain",
                    "update_interval": 7200
                }
            ],
            "clickhouse": {
                "host": "localhost",
                "port": 9000,
                "username": "default",
                "password": ""
            },
            "encryption_key": Fernet.generate_key().decode(),
            "max_iocs_per_batch": 10000,
            "threat_expiry_days": 30
        }
        
        try:
            with open(config_path, 'r') as f:
                config = json.load(f)
            return {**default_config, **config}
        except FileNotFoundError:
            logging.warning(f"Config file {config_path} not found, using defaults")
            with open(config_path, 'w') as f:
                json.dump(default_config, f, indent=2)
            return default_config
    
    def _setup_logging(self):
        """Setup structured logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('logs/threat_intel.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    async def refresh_all_feeds(self) -> Dict[str, Any]:
        """Refresh all configured threat intelligence feeds"""
        self.logger.info("🔄 Starting threat intelligence feed refresh")
        
        results = {
            "timestamp": datetime.now().isoformat(),
            "feeds_processed": 0,
            "total_iocs": 0,
            "new_iocs": 0,
            "updated_iocs": 0,
            "expired_iocs": 0,
            "errors": []
        }
        
        # Process feeds concurrently
        tasks = []
        for feed in self.config['feeds']:
            task = self._process_feed(feed)
            tasks.append(task)
        
        feed_results = await asyncio.gather(*tasks, return_exceptions=True)
        
        for i, result in enumerate(feed_results):
            if isinstance(result, Exception):
                error_msg = f"Feed {self.config['feeds'][i]['name']} failed: {str(result)}"
                self.logger.error(error_msg)
                results["errors"].append(error_msg)
            else:
                results["feeds_processed"] += 1
                results["total_iocs"] += result["iocs_processed"]
                results["new_iocs"] += result["new_iocs"]
                results["updated_iocs"] += result["updated_iocs"]
        
        # Clean up expired IoCs
        expired_count = await self._cleanup_expired_iocs()
        results["expired_iocs"] = expired_count
        
        # Update detection engine
        await self._update_detection_engine()
        
        self.logger.info(f"✅ Feed refresh completed: {results['feeds_processed']} feeds, {results['total_iocs']} total IoCs")
        return results
    
    async def _process_feed(self, feed_config: Dict) -> Dict[str, Any]:
        """Process a single threat intelligence feed"""
        self.logger.info(f"📥 Processing feed: {feed_config['name']}")
        
        result = {
            "feed_name": feed_config['name'],
            "iocs_processed": 0,
            "new_iocs": 0,
            "updated_iocs": 0
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(feed_config['url']) as response:
                    if response.status != 200:
                        raise Exception(f"HTTP {response.status}: {await response.text()}")
                    
                    content = await response.text()
                    
                    # Parse based on feed type
                    iocs = self._parse_feed_content(content, feed_config)
                    
                    # Batch insert to ClickHouse
                    batch_result = await self._batch_insert_iocs(iocs, feed_config['name'])
                    result.update(batch_result)
                    
        except Exception as e:
            self.logger.error(f"❌ Failed to process feed {feed_config['name']}: {str(e)}")
            raise
        
        return result
    
    def _parse_feed_content(self, content: str, feed_config: Dict) -> List[Dict]:
        """Parse feed content based on type"""
        iocs = []
        feed_type = feed_config['type']
        
        if feed_type == "suricata":
            iocs = self._parse_suricata_rules(content)
        elif feed_type == "reputation":
            iocs = self._parse_reputation_data(content)
        elif feed_type == "domain":
            iocs = self._parse_domain_list(content)
        elif feed_type == "stix":
            iocs = self._parse_stix_bundle(content)
        
        # Enrich with metadata
        for ioc in iocs:
            ioc.update({
                "source": feed_config['name'],
                "first_seen": datetime.now(),
                "last_updated": datetime.now(),
                "expires_at": datetime.now() + timedelta(days=self.config['threat_expiry_days']),
                "confidence": self._calculate_confidence(ioc, feed_config),
                "encrypted": False
            })
        
        return iocs
    
    def _parse_suricata_rules(self, content: str) -> List[Dict]:
        """Parse Suricata rule format"""
        iocs = []
        
        for line in content.split('\n'):
            if line.startswith('alert') or line.startswith('drop'):
                # Extract IoCs from Suricata rule
                if 'content:' in line:
                    # Extract content patterns
                    import re
                    patterns = re.findall(r'content:"([^"]+)"', line)
                    
                    for pattern in patterns:
                        iocs.append({
                            "indicator_type": "pattern",
                            "value": pattern,
                            "pattern_type": "suricata_content",
                            "severity": self._extract_severity_from_rule(line),
                            "description": self._extract_description_from_rule(line)
                        })
        
        return iocs
    
    def _parse_reputation_data(self, content: str) -> List[Dict]:
        """Parse reputation data (IP addresses with scores)"""
        iocs = []
        
        for line in content.split('\n'):
            if line.strip() and not line.startswith('#'):
                parts = line.strip().split('#')
                if len(parts) >= 2:
                    ip = parts[0].strip()
                    reputation_data = parts[1].strip()
                    
                    iocs.append({
                        "indicator_type": "ipv4",
                        "value": ip,
                        "pattern_type": "exact_match",
                        "severity": self._parse_reputation_score(reputation_data),
                        "description": f"Malicious IP from reputation feed: {reputation_data}"
                    })
        
        return iocs
    
    def _parse_domain_list(self, content: str) -> List[Dict]:
        """Parse simple domain list"""
        iocs = []
        
        for line in content.split('\n'):
            domain = line.strip()
            if domain and not domain.startswith('#') and '.' in domain:
                iocs.append({
                    "indicator_type": "domain",
                    "value": domain.lower(),
                    "pattern_type": "exact_match",
                    "severity": 3,  # Medium severity for domain blocks
                    "description": f"Malicious domain: {domain}"
                })
        
        return iocs
    
    async def _batch_insert_iocs(self, iocs: List[Dict], source: str) -> Dict[str, int]:
        """Batch insert IoCs to ClickHouse with deduplication"""
        if not iocs:
            return {"iocs_processed": 0, "new_iocs": 0, "updated_iocs": 0}
        
        result = {"iocs_processed": len(iocs), "new_iocs": 0, "updated_iocs": 0}
        
        # Create DataFrame for batch processing
        df = pd.DataFrame(iocs)
        
        # Add hash for deduplication
        df['ioc_hash'] = df.apply(lambda row: hashlib.sha256(
            f"{row['indicator_type']}:{row['value']}".encode()
        ).hexdigest(), axis=1)
        
        # Check for existing IoCs
        existing_hashes = set()
        if len(df) > 0:
            hash_list = "','".join(df['ioc_hash'].tolist())
            existing_query = f"SELECT ioc_hash FROM threat_intel WHERE ioc_hash IN ('{hash_list}')"
            existing_results = self.client.query(existing_query)
            existing_hashes = {row[0] for row in existing_results.result_rows}
        
        # Separate new and updated IoCs
        new_iocs = df[~df['ioc_hash'].isin(existing_hashes)]
        updated_iocs = df[df['ioc_hash'].isin(existing_hashes)]
        
        # Insert new IoCs
        if len(new_iocs) > 0:
            self.client.insert('threat_intel', new_iocs.to_dict('records'))
            result["new_iocs"] = len(new_iocs)
        
        # Update existing IoCs
        if len(updated_iocs) > 0:
            for _, ioc in updated_iocs.iterrows():
                update_query = f"""
                ALTER TABLE threat_intel UPDATE 
                    last_updated = '{ioc['last_updated']}',
                    expires_at = '{ioc['expires_at']}',
                    confidence = {ioc['confidence']}
                WHERE ioc_hash = '{ioc['ioc_hash']}'
                """
                self.client.command(update_query)
            result["updated_iocs"] = len(updated_iocs)
        
        self.logger.info(f"📊 {source}: {result['new_iocs']} new, {result['updated_iocs']} updated IoCs")
        return result
    
    async def _cleanup_expired_iocs(self) -> int:
        """Remove expired IoCs from the database"""
        self.logger.info("🧹 Cleaning up expired IoCs")
        
        cleanup_query = f"""
        DELETE FROM threat_intel 
        WHERE expires_at < '{datetime.now()}'
        """
        
        result = self.client.command(cleanup_query)
        expired_count = result.summary.get('written_rows', 0)
        
        self.logger.info(f"🗑️ Removed {expired_count} expired IoCs")
        return expired_count
    
    async def _update_detection_engine(self):
        """Update detection rules based on new IoCs"""
        self.logger.info("⚙️ Updating detection engine rules")
        
        try:
            # Generate YARA rules from IoCs
            yara_rules = await self._generate_yara_rules()
            
            # Update detection engine
            if yara_rules:
                with open("config/threat_detection.yar", "w") as f:
                    f.write(yara_rules)
                
                # Compile rules for validation
                self.yara_rules = yara.compile(source=yara_rules)
                self.logger.info(f"✅ Updated {len(self.yara_rules)} YARA rules")
            
            # Update network detection patterns
            await self._update_network_patterns()
            
        except Exception as e:
            self.logger.error(f"❌ Failed to update detection engine: {str(e)}")
    
    async def _generate_yara_rules(self) -> str:
        """Generate YARA rules from threat IoCs"""
        query = """
        SELECT indicator_type, value, description, severity
        FROM threat_intel 
        WHERE indicator_type IN ('pattern', 'hash') 
        AND expires_at > now()
        ORDER BY severity DESC
        LIMIT 1000
        """
        
        results = self.client.query(query)
        
        yara_rules = []
        rule_id = 1
        
        for row in results.result_rows:
            indicator_type, value, description, severity = row
            
            if indicator_type == "pattern":
                rule = f"""
rule ThreatIntel_Pattern_{rule_id} {{
    meta:
        description = "{description}"
        severity = {severity}
        source = "Ultra SIEM Threat Intel"
        
    strings:
        $pattern = "{value}"
        
    condition:
        $pattern
}}
"""
                yara_rules.append(rule)
                rule_id += 1
            
            elif indicator_type == "hash":
                rule = f"""
rule ThreatIntel_Hash_{rule_id} {{
    meta:
        description = "{description}"
        severity = {severity}
        source = "Ultra SIEM Threat Intel"
        
    condition:
        hash.sha256(0, filesize) == "{value}"
}}
"""
                yara_rules.append(rule)
                rule_id += 1
        
        return "\n".join(yara_rules)
    
    async def _update_network_patterns(self):
        """Update network-based detection patterns"""
        # Get malicious IPs and domains
        network_query = """
        SELECT indicator_type, value, severity
        FROM threat_intel 
        WHERE indicator_type IN ('ipv4', 'ipv6', 'domain', 'url')
        AND expires_at > now()
        ORDER BY severity DESC
        """
        
        results = self.client.query(network_query)
        
        network_patterns = {
            "malicious_ips": [],
            "malicious_domains": [],
            "malicious_urls": []
        }
        
        for row in results.result_rows:
            indicator_type, value, severity = row
            
            if indicator_type in ['ipv4', 'ipv6']:
                network_patterns["malicious_ips"].append({
                    "ip": value,
                    "severity": severity
                })
            elif indicator_type == 'domain':
                network_patterns["malicious_domains"].append({
                    "domain": value,
                    "severity": severity
                })
            elif indicator_type == 'url':
                network_patterns["malicious_urls"].append({
                    "url": value,
                    "severity": severity
                })
        
        # Save patterns for Vector to use
        with open("config/network_threat_patterns.json", "w") as f:
            json.dump(network_patterns, f, indent=2)
        
        self.logger.info(f"🌐 Updated network patterns: {len(network_patterns['malicious_ips'])} IPs, {len(network_patterns['malicious_domains'])} domains")
    
    def _calculate_confidence(self, ioc: Dict, feed_config: Dict) -> float:
        """Calculate confidence score for IoC"""
        base_confidence = 0.7
        
        # Adjust based on source reputation
        source_multipliers = {
            "emergingthreats": 0.9,
            "alienvault": 0.85,
            "malwaredomains": 0.8
        }
        
        source_multiplier = source_multipliers.get(feed_config['name'], 0.7)
        
        # Adjust based on severity
        severity_multiplier = {
            1: 0.6,  # Low
            2: 0.7,  # Medium-Low
            3: 0.8,  # Medium
            4: 0.9,  # High
            5: 1.0   # Critical
        }.get(ioc.get('severity', 3), 0.8)
        
        return min(1.0, base_confidence * source_multiplier * severity_multiplier)
    
    def _extract_severity_from_rule(self, rule: str) -> int:
        """Extract severity from Suricata rule"""
        if "priority:1" in rule:
            return 5
        elif "priority:2" in rule:
            return 4
        elif "priority:3" in rule:
            return 3
        else:
            return 2
    
    def _extract_description_from_rule(self, rule: str) -> str:
        """Extract description from Suricata rule"""
        import re
        match = re.search(r'msg:"([^"]+)"', rule)
        return match.group(1) if match else "Threat detected"
    
    def _parse_reputation_score(self, reputation_data: str) -> int:
        """Parse reputation score from feed data"""
        # Extract numeric score if present
        import re
        score_match = re.search(r'(\d+)', reputation_data)
        if score_match:
            score = int(score_match.group(1))
            # Convert to 1-5 scale
            if score >= 80:
                return 5
            elif score >= 60:
                return 4
            elif score >= 40:
                return 3
            elif score >= 20:
                return 2
            else:
                return 1
        return 3  # Default medium severity

# CLI interface
async def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="Ultra SIEM Threat Intelligence Feed Manager")
    parser.add_argument("--config", default="config/threat_intel.json", help="Config file path")
    parser.add_argument("--refresh", action="store_true", help="Refresh all feeds")
    parser.add_argument("--daemon", action="store_true", help="Run as daemon")
    parser.add_argument("--interval", type=int, default=3600, help="Refresh interval in seconds")
    
    args = parser.parse_args()
    
    feed_manager = ThreatIntelligenceFeed(args.config)
    
    if args.refresh:
        results = await feed_manager.refresh_all_feeds()
        print(json.dumps(results, indent=2))
    elif args.daemon:
        while True:
            try:
                await feed_manager.refresh_all_feeds()
                await asyncio.sleep(args.interval)
            except KeyboardInterrupt:
                break
            except Exception as e:
                logging.error(f"Daemon error: {e}")
                await asyncio.sleep(60)  # Wait before retry
    else:
        parser.print_help()

if __name__ == "__main__":
    asyncio.run(main()) 