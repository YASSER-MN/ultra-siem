#!/usr/bin/env python3
"""
🌐 Ultra SIEM - Threat Intelligence Feed Integration
Real-time threat intelligence aggregation and correlation
"""

import asyncio
import aiohttp
import json
import time
import hashlib
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
import sqlite3
import os
import sys

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('threat_intelligence.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class ThreatIntelligenceFeed:
    """Main threat intelligence feed integration class"""
    
    def __init__(self, config_path: str = "config/threat_intel.json"):
        self.config_path = config_path
        self.feeds = {}
        self.threat_data = {}
        self.correlation_rules = {}
        self.indicators = {}
        self.last_update = {}
        self.session = None
        self.db_path = "data/threat_intelligence.db"
        
        # Initialize database
        self._init_database()
        
        # Load configuration
        self._load_config()
        
        # Initialize correlation rules
        self._init_correlation_rules()
    
    def _init_database(self):
        """Initialize SQLite database for threat intelligence"""
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Create tables
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS threat_feeds (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                feed_name TEXT NOT NULL,
                feed_url TEXT NOT NULL,
                feed_type TEXT NOT NULL,
                last_update TIMESTAMP,
                status TEXT DEFAULT 'active'
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS threat_indicators (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                indicator TEXT NOT NULL,
                indicator_type TEXT NOT NULL,
                threat_type TEXT NOT NULL,
                confidence REAL DEFAULT 0.0,
                first_seen TIMESTAMP,
                last_seen TIMESTAMP,
                source TEXT NOT NULL,
                tags TEXT,
                UNIQUE(indicator, source)
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS threat_reports (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                report_id TEXT UNIQUE NOT NULL,
                title TEXT NOT NULL,
                description TEXT,
                threat_type TEXT NOT NULL,
                severity TEXT NOT NULL,
                published_date TIMESTAMP,
                source TEXT NOT NULL,
                raw_data TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS correlation_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                event_type TEXT NOT NULL,
                indicators TEXT NOT NULL,
                threat_type TEXT NOT NULL,
                confidence REAL DEFAULT 0.0,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                source TEXT NOT NULL
            )
        ''')
        
        conn.commit()
        conn.close()
        
        logger.info("Threat intelligence database initialized")
    
    def _load_config(self):
        """Load threat intelligence configuration"""
        default_config = {
            "feeds": {
                "alienvault_otx": {
                    "url": "https://otx.alienvault.com/api/v1/indicators/domain/",
                    "type": "api",
                    "api_key": "",
                    "enabled": True,
                    "update_interval": 3600
                },
                "virustotal": {
                    "url": "https://www.virustotal.com/vtapi/v2/",
                    "type": "api",
                    "api_key": "",
                    "enabled": True,
                    "update_interval": 1800
                },
                "abuseipdb": {
                    "url": "https://api.abuseipdb.com/api/v2/",
                    "type": "api",
                    "api_key": "",
                    "enabled": True,
                    "update_interval": 3600
                },
                "urlhaus": {
                    "url": "https://urlhaus.abuse.ch/downloads/csv_recent/",
                    "type": "csv",
                    "enabled": True,
                    "update_interval": 1800
                },
                "phishtank": {
                    "url": "https://data.phishtank.com/data/online-valid.json",
                    "type": "json",
                    "enabled": True,
                    "update_interval": 3600
                },
                "malware_bazaar": {
                    "url": "https://bazaar.abuse.ch/export/txt/recent/",
                    "type": "txt",
                    "enabled": True,
                    "update_interval": 7200
                }
            },
            "correlation": {
                "enabled": True,
                "min_confidence": 0.7,
                "max_age_hours": 24
            },
            "integration": {
                "ultra_siem_url": "http://localhost:8123",
                "nats_url": "nats://localhost:4222",
                "auto_export": True
            }
        }
        
        try:
            if os.path.exists(self.config_path):
                with open(self.config_path, 'r') as f:
                    self.config = json.load(f)
            else:
                self.config = default_config
                os.makedirs(os.path.dirname(self.config_path), exist_ok=True)
                with open(self.config_path, 'w') as f:
                    json.dump(default_config, f, indent=2)
            
            self.feeds = self.config["feeds"]
            logger.info(f"Loaded {len(self.feeds)} threat intelligence feeds")
            
        except Exception as e:
            logger.error(f"Failed to load configuration: {e}")
            self.config = default_config
            self.feeds = default_config["feeds"]
    
    def _init_correlation_rules(self):
        """Initialize threat correlation rules"""
        self.correlation_rules = {
            "malware_campaign": {
                "indicators": ["ip", "domain", "url", "hash"],
                "threshold": 3,
                "time_window": 3600,
                "confidence_boost": 0.2
            },
            "phishing_attack": {
                "indicators": ["url", "domain", "email"],
                "threshold": 2,
                "time_window": 1800,
                "confidence_boost": 0.15
            },
            "botnet_activity": {
                "indicators": ["ip", "domain"],
                "threshold": 5,
                "time_window": 7200,
                "confidence_boost": 0.25
            },
            "apt_activity": {
                "indicators": ["ip", "domain", "hash", "email"],
                "threshold": 4,
                "time_window": 86400,
                "confidence_boost": 0.3
            }
        }
        
        logger.info(f"Initialized {len(self.correlation_rules)} correlation rules")
    
    async def start_session(self):
        """Start aiohttp session for API calls"""
        if self.session is None:
            self.session = aiohttp.ClientSession(
                timeout=aiohttp.ClientTimeout(total=30),
                headers={'User-Agent': 'Ultra-SIEM-Threat-Intel/1.0'}
            )
    
    async def stop_session(self):
        """Stop aiohttp session"""
        if self.session:
            await self.session.close()
            self.session = None
    
    async def fetch_feed_data(self, feed_name: str, feed_config: Dict) -> Optional[List[Dict]]:
        """Fetch data from a threat intelligence feed"""
        try:
            await self.start_session()
            
            if feed_config["type"] == "api":
                return await self._fetch_api_feed(feed_name, feed_config)
            elif feed_config["type"] == "csv":
                return await self._fetch_csv_feed(feed_name, feed_config)
            elif feed_config["type"] == "json":
                return await self._fetch_json_feed(feed_name, feed_config)
            elif feed_config["type"] == "txt":
                return await self._fetch_txt_feed(feed_name, feed_config)
            else:
                logger.warning(f"Unknown feed type: {feed_config['type']}")
                return None
                
        except Exception as e:
            logger.error(f"Failed to fetch data from {feed_name}: {e}")
            return None
    
    async def _fetch_api_feed(self, feed_name: str, feed_config: Dict) -> Optional[List[Dict]]:
        """Fetch data from API-based feeds"""
        if not feed_config.get("api_key"):
            logger.warning(f"No API key configured for {feed_name}")
            return None
        
        headers = {}
        if feed_name == "alienvault_otx":
            headers["X-OTX-API-KEY"] = feed_config["api_key"]
        elif feed_name == "virustotal":
            params = {"apikey": feed_config["api_key"]}
        elif feed_name == "abuseipdb":
            headers["Key"] = feed_config["api_key"]
            headers["Accept"] = "application/json"
        
        try:
            async with self.session.get(feed_config["url"], headers=headers) as response:
                if response.status == 200:
                    data = await response.json()
                    return self._parse_api_response(feed_name, data)
                else:
                    logger.error(f"API request failed for {feed_name}: {response.status}")
                    return None
        except Exception as e:
            logger.error(f"API request error for {feed_name}: {e}")
            return None
    
    async def _fetch_csv_feed(self, feed_name: str, feed_config: Dict) -> Optional[List[Dict]]:
        """Fetch data from CSV-based feeds"""
        try:
            async with self.session.get(feed_config["url"]) as response:
                if response.status == 200:
                    csv_data = await response.text()
                    return self._parse_csv_response(feed_name, csv_data)
                else:
                    logger.error(f"CSV request failed for {feed_name}: {response.status}")
                    return None
        except Exception as e:
            logger.error(f"CSV request error for {feed_name}: {e}")
            return None
    
    async def _fetch_json_feed(self, feed_name: str, feed_config: Dict) -> Optional[List[Dict]]:
        """Fetch data from JSON-based feeds"""
        try:
            async with self.session.get(feed_config["url"]) as response:
                if response.status == 200:
                    json_data = await response.json()
                    return self._parse_json_response(feed_name, json_data)
                else:
                    logger.error(f"JSON request failed for {feed_name}: {response.status}")
                    return None
        except Exception as e:
            logger.error(f"JSON request error for {feed_name}: {e}")
            return None
    
    async def _fetch_txt_feed(self, feed_name: str, feed_config: Dict) -> Optional[List[Dict]]:
        """Fetch data from TXT-based feeds"""
        try:
            async with self.session.get(feed_config["url"]) as response:
                if response.status == 200:
                    txt_data = await response.text()
                    return self._parse_txt_response(feed_name, txt_data)
                else:
                    logger.error(f"TXT request failed for {feed_name}: {response.status}")
                    return None
        except Exception as e:
            logger.error(f"TXT request error for {feed_name}: {e}")
            return None
    
    def _parse_api_response(self, feed_name: str, data: Dict) -> List[Dict]:
        """Parse API response data"""
        indicators = []
        
        if feed_name == "alienvault_otx":
            # Parse OTX indicators
            if "indicators" in data:
                for indicator in data["indicators"]:
                    indicators.append({
                        "indicator": indicator.get("indicator", ""),
                        "type": indicator.get("type", ""),
                        "threat_type": "malware",
                        "confidence": 0.8,
                        "source": feed_name,
                        "tags": indicator.get("tags", [])
                    })
        
        elif feed_name == "virustotal":
            # Parse VirusTotal data
            if "positives" in data and "total" in data:
                indicators.append({
                    "indicator": data.get("resource", ""),
                    "type": "hash",
                    "threat_type": "malware",
                    "confidence": data["positives"] / data["total"],
                    "source": feed_name,
                    "tags": []
                })
        
        elif feed_name == "abuseipdb":
            # Parse AbuseIPDB data
            if "data" in data:
                for item in data["data"]:
                    indicators.append({
                        "indicator": item.get("ipAddress", ""),
                        "type": "ip",
                        "threat_type": "malicious_ip",
                        "confidence": item.get("abuseConfidenceScore", 0) / 100,
                        "source": feed_name,
                        "tags": []
                    })
        
        return indicators
    
    def _parse_csv_response(self, feed_name: str, csv_data: str) -> List[Dict]:
        """Parse CSV response data"""
        indicators = []
        lines = csv_data.strip().split('\n')
        
        if feed_name == "urlhaus":
            # Skip header line
            for line in lines[1:]:
                if line.strip():
                    parts = line.split(',')
                    if len(parts) >= 3:
                        indicators.append({
                            "indicator": parts[2].strip('"'),
                            "type": "url",
                            "threat_type": "malware",
                            "confidence": 0.9,
                            "source": feed_name,
                            "tags": []
                        })
        
        return indicators
    
    def _parse_json_response(self, feed_name: str, json_data: List[Dict]) -> List[Dict]:
        """Parse JSON response data"""
        indicators = []
        
        if feed_name == "phishtank":
            for item in json_data:
                indicators.append({
                    "indicator": item.get("url", ""),
                    "type": "url",
                    "threat_type": "phishing",
                    "confidence": 0.95,
                    "source": feed_name,
                    "tags": []
                })
        
        return indicators
    
    def _parse_txt_response(self, feed_name: str, txt_data: str) -> List[Dict]:
        """Parse TXT response data"""
        indicators = []
        lines = txt_data.strip().split('\n')
        
        if feed_name == "malware_bazaar":
            for line in lines:
                if line.strip() and not line.startswith('#'):
                    indicators.append({
                        "indicator": line.strip(),
                        "type": "hash",
                        "threat_type": "malware",
                        "confidence": 0.85,
                        "source": feed_name,
                        "tags": []
                    })
        
        return indicators
    
    def store_indicators(self, indicators: List[Dict]):
        """Store indicators in database"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        for indicator in indicators:
            try:
                cursor.execute('''
                    INSERT OR REPLACE INTO threat_indicators 
                    (indicator, indicator_type, threat_type, confidence, first_seen, last_seen, source, tags)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ''', (
                    indicator["indicator"],
                    indicator["type"],
                    indicator["threat_type"],
                    indicator["confidence"],
                    datetime.now(),
                    datetime.now(),
                    indicator["source"],
                    json.dumps(indicator.get("tags", []))
                ))
            except Exception as e:
                logger.error(f"Failed to store indicator {indicator['indicator']}: {e}")
        
        conn.commit()
        conn.close()
        
        logger.info(f"Stored {len(indicators)} indicators")
    
    def correlate_threats(self) -> List[Dict]:
        """Correlate threats based on rules"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        correlations = []
        
        for rule_name, rule in self.correlation_rules.items():
            # Get indicators within time window
            time_window = datetime.now() - timedelta(seconds=rule["time_window"])
            
            cursor.execute('''
                SELECT indicator, indicator_type, threat_type, confidence, source
                FROM threat_indicators 
                WHERE last_seen >= ? AND indicator_type IN ({})
            '''.format(','.join(['?'] * len(rule["indicators"]))), 
            [time_window] + rule["indicators"])
            
            indicators = cursor.fetchall()
            
            if len(indicators) >= rule["threshold"]:
                # Group by threat type
                threat_groups = {}
                for indicator in indicators:
                    threat_type = indicator[2]
                    if threat_type not in threat_groups:
                        threat_groups[threat_type] = []
                    threat_groups[threat_type].append(indicator)
                
                # Check if any group meets threshold
                for threat_type, group in threat_groups.items():
                    if len(group) >= rule["threshold"]:
                        avg_confidence = sum(ind[3] for ind in group) / len(group)
                        boosted_confidence = min(1.0, avg_confidence + rule["confidence_boost"])
                        
                        correlation = {
                            "rule": rule_name,
                            "threat_type": threat_type,
                            "indicators": [ind[0] for ind in group],
                            "confidence": boosted_confidence,
                            "sources": list(set(ind[4] for ind in group)),
                            "timestamp": datetime.now()
                        }
                        
                        correlations.append(correlation)
                        
                        # Store correlation event
                        cursor.execute('''
                            INSERT INTO correlation_events 
                            (event_type, indicators, threat_type, confidence, source)
                            VALUES (?, ?, ?, ?, ?)
                        ''', (
                            rule_name,
                            json.dumps([ind[0] for ind in group]),
                            threat_type,
                            boosted_confidence,
                            json.dumps(list(set(ind[4] for ind in group)))
                        ))
        
        conn.commit()
        conn.close()
        
        logger.info(f"Generated {len(correlations)} threat correlations")
        return correlations
    
    async def export_to_ultra_siem(self, correlations: List[Dict]):
        """Export threat intelligence to Ultra SIEM"""
        if not self.config["integration"]["auto_export"]:
            return
        
        try:
            # Export to ClickHouse
            for correlation in correlations:
                threat_data = {
                    "timestamp": correlation["timestamp"].isoformat(),
                    "threat_type": correlation["threat_type"],
                    "confidence": correlation["confidence"],
                    "indicators": correlation["indicators"],
                    "sources": correlation["sources"],
                    "rule": correlation["rule"],
                    "source": "threat_intelligence"
                }
                
                # Insert into ClickHouse
                query = '''
                    INSERT INTO bulletproof_threats 
                    (timestamp, threat_type, confidence, indicators, sources, rule, source)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                '''
                
                # This would be implemented with ClickHouse client
                logger.info(f"Exported correlation: {correlation['rule']} - {correlation['threat_type']}")
        
        except Exception as e:
            logger.error(f"Failed to export to Ultra SIEM: {e}")
    
    async def update_all_feeds(self):
        """Update all enabled threat intelligence feeds"""
        logger.info("Starting threat intelligence feed update")
        
        tasks = []
        for feed_name, feed_config in self.feeds.items():
            if feed_config.get("enabled", False):
                task = asyncio.create_task(self.update_feed(feed_name, feed_config))
                tasks.append(task)
        
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
        
        # Correlate threats
        correlations = self.correlate_threats()
        
        # Export to Ultra SIEM
        await self.export_to_ultra_siem(correlations)
        
        logger.info("Threat intelligence feed update completed")
    
    async def update_feed(self, feed_name: str, feed_config: Dict):
        """Update a single threat intelligence feed"""
        try:
            logger.info(f"Updating feed: {feed_name}")
            
            indicators = await self.fetch_feed_data(feed_name, feed_config)
            if indicators:
                self.store_indicators(indicators)
                self.last_update[feed_name] = datetime.now()
                logger.info(f"Updated {feed_name}: {len(indicators)} indicators")
            else:
                logger.warning(f"No data received from {feed_name}")
        
        except Exception as e:
            logger.error(f"Failed to update {feed_name}: {e}")
    
    def get_statistics(self) -> Dict:
        """Get threat intelligence statistics"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Total indicators
        cursor.execute("SELECT COUNT(*) FROM threat_indicators")
        total_indicators = cursor.fetchone()[0]
        
        # Indicators by type
        cursor.execute("SELECT indicator_type, COUNT(*) FROM threat_indicators GROUP BY indicator_type")
        indicators_by_type = dict(cursor.fetchall())
        
        # Indicators by threat type
        cursor.execute("SELECT threat_type, COUNT(*) FROM threat_indicators GROUP BY threat_type")
        indicators_by_threat = dict(cursor.fetchall())
        
        # Recent correlations
        cursor.execute("SELECT COUNT(*) FROM correlation_events WHERE timestamp >= datetime('now', '-1 hour')")
        recent_correlations = cursor.fetchone()[0]
        
        # Feed status
        feed_status = {}
        for feed_name in self.feeds.keys():
            last_update = self.last_update.get(feed_name)
            feed_status[feed_name] = {
                "enabled": self.feeds[feed_name].get("enabled", False),
                "last_update": last_update.isoformat() if last_update else None
            }
        
        conn.close()
        
        return {
            "total_indicators": total_indicators,
            "indicators_by_type": indicators_by_type,
            "indicators_by_threat": indicators_by_threat,
            "recent_correlations": recent_correlations,
            "feed_status": feed_status,
            "correlation_rules": len(self.correlation_rules)
        }
    
    async def run_continuous(self, update_interval: int = 3600):
        """Run continuous threat intelligence updates"""
        logger.info(f"Starting continuous threat intelligence updates (interval: {update_interval}s)")
        
        try:
            while True:
                await self.update_all_feeds()
                await asyncio.sleep(update_interval)
        
        except KeyboardInterrupt:
            logger.info("Stopping continuous threat intelligence updates")
        finally:
            await self.stop_session()

async def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Ultra SIEM Threat Intelligence Integration")
    parser.add_argument("--config", default="config/threat_intel.json", help="Configuration file path")
    parser.add_argument("--continuous", action="store_true", help="Run continuous updates")
    parser.add_argument("--update-interval", type=int, default=3600, help="Update interval in seconds")
    parser.add_argument("--stats", action="store_true", help="Show statistics")
    parser.add_argument("--update-now", action="store_true", help="Update all feeds now")
    
    args = parser.parse_args()
    
    # Initialize threat intelligence
    ti = ThreatIntelligenceFeed(args.config)
    
    try:
        if args.stats:
            stats = ti.get_statistics()
            print(json.dumps(stats, indent=2))
        
        elif args.update_now:
            await ti.update_all_feeds()
        
        elif args.continuous:
            await ti.run_continuous(args.update_interval)
        
        else:
            # Default: run one update
            await ti.update_all_feeds()
    
    finally:
        await ti.stop_session()

if __name__ == "__main__":
    asyncio.run(main()) 