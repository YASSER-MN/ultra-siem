#!/usr/bin/env python3
"""
🛡️ Ultra SIEM - Firewall/IDS/IPS Log Collector
Professional security device log ingestion for Ultra SIEM
Supports pfSense, Cisco, Suricata, and other security devices
"""

import json
import time
import uuid
import re
import logging
import argparse
from datetime import datetime
from typing import Dict, Any, Optional
from pathlib import Path

# Try to import required libraries
try:
    import requests
    REQUESTS_AVAILABLE = True
except ImportError:
    REQUESTS_AVAILABLE = False

try:
    import nats
    import asyncio
    NATS_AVAILABLE = True
except ImportError:
    NATS_AVAILABLE = False

class UltraSIEMEvent:
    """Ultra SIEM event schema"""
    
    def __init__(self):
        self.id = str(uuid.uuid4())
        self.timestamp = int(time.time())
        self.source_ip = ""
        self.destination_ip = ""
        self.event_type = ""
        self.severity = 2
        self.message = ""
        self.raw_message = ""
        self.log_source = "firewall"
        self.user = ""
        self.hostname = ""
        self.process = ""
        self.event_id = ""
        self.event_category = ""
        self.metadata = {}
    
    def to_dict(self) -> Dict[str, Any]:
        return {
            'id': self.id,
            'timestamp': self.timestamp,
            'source_ip': self.source_ip,
            'destination_ip': self.destination_ip,
            'event_type': self.event_type,
            'severity': self.severity,
            'message': self.message,
            'raw_message': self.raw_message,
            'log_source': self.log_source,
            'user': self.user,
            'hostname': self.hostname,
            'process': self.process,
            'event_id': self.event_id,
            'event_category': self.event_category,
            'metadata': self.metadata
        }

class FirewallLogParser:
    """Parse firewall and security device logs"""
    
    # pfSense log patterns
    PFSENSE_PATTERNS = {
        'block': re.compile(r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}) .* rule (\d+) .* block .* (\S+) -> (\S+)'),
        'pass': re.compile(r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}) .* rule (\d+) .* pass .* (\S+) -> (\S+)'),
        'nat': re.compile(r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}) .* NAT .* (\S+) -> (\S+)'),
    }
    
    # Cisco ASA patterns
    CISCO_PATTERNS = {
        'deny': re.compile(r'(\d{3}) (\d{3}) (\d{2}:\d{2}:\d{2}) (\w{3}) (\d{2}) (\d{4}) .* Deny .* (\S+) -> (\S+)'),
        'permit': re.compile(r'(\d{3}) (\d{3}) (\d{2}:\d{2}:\d{2}) (\w{3}) (\d{2}) (\d{4}) .* Permit .* (\S+) -> (\S+)'),
        'threat': re.compile(r'(\d{3}) (\d{3}) (\d{2}:\d{2}:\d{2}) (\w{3}) (\d{2}) (\d{4}) .* Threat .* (\S+)'),
    }
    
    # Suricata patterns
    SURICATA_PATTERNS = {
        'alert': re.compile(r'(\d{2}/\d{2}/\d{4}-\d{2}:\d{2}:\d{2}\.\d+) .* \[(\S+)\] (\S+) (\S+) -> (\S+)'),
        'drop': re.compile(r'(\d{2}/\d{2}/\d{4}-\d{2}:\d{2}:\d{2}\.\d+) .* DROP .* (\S+) -> (\S+)'),
    }
    
    def __init__(self, device_type: str = "pfsense"):
        self.device_type = device_type
        self.logger = logging.getLogger(__name__)
    
    def parse_log_line(self, line: str) -> Optional[UltraSIEMEvent]:
        """Parse a single log line"""
        
        event = UltraSIEMEvent()
        event.raw_message = line
        event.log_source = f"{self.device_type}_firewall"
        
        if self.device_type == "pfsense":
            return self._parse_pfsense(line, event)
        elif self.device_type == "cisco":
            return self._parse_cisco(line, event)
        elif self.device_type == "suricata":
            return self._parse_suricata(line, event)
        else:
            return self._parse_generic(line, event)
    
    def _parse_pfsense(self, line: str, event: UltraSIEMEvent) -> Optional[UltraSIEMEvent]:
        """Parse pfSense log line"""
        
        # Check for block events
        match = self.PFSENSE_PATTERNS['block'].search(line)
        if match:
            timestamp, rule_id, src_ip, dst_ip = match.groups()
            event.timestamp = int(datetime.fromisoformat(timestamp).timestamp())
            event.source_ip = src_ip
            event.destination_ip = dst_ip
            event.event_type = "firewall_block"
            event.severity = 4
            event.message = f"pfSense blocked traffic from {src_ip} to {dst_ip} (Rule {rule_id})"
            event.metadata = {
                'rule_id': rule_id,
                'device': 'pfsense',
                'action': 'block'
            }
            return event
        
        # Check for pass events
        match = self.PFSENSE_PATTERNS['pass'].search(line)
        if match:
            timestamp, rule_id, src_ip, dst_ip = match.groups()
            event.timestamp = int(datetime.fromisoformat(timestamp).timestamp())
            event.source_ip = src_ip
            event.destination_ip = dst_ip
            event.event_type = "firewall_pass"
            event.severity = 2
            event.message = f"pfSense allowed traffic from {src_ip} to {dst_ip} (Rule {rule_id})"
            event.metadata = {
                'rule_id': rule_id,
                'device': 'pfsense',
                'action': 'pass'
            }
            return event
        
        return None
    
    def _parse_cisco(self, line: str, event: UltraSIEMEvent) -> Optional[UltraSIEMEvent]:
        """Parse Cisco ASA log line"""
        
        # Check for deny events
        match = self.CISCO_PATTERNS['deny'].search(line)
        if match:
            month, day, time, month_name, day_num, year, src_ip, dst_ip = match.groups()
            timestamp_str = f"{year}-{month}-{day_num} {time}"
            event.timestamp = int(datetime.strptime(timestamp_str, "%Y-%m-%d %H:%M:%S").timestamp())
            event.source_ip = src_ip
            event.destination_ip = dst_ip
            event.event_type = "firewall_deny"
            event.severity = 4
            event.message = f"Cisco ASA denied traffic from {src_ip} to {dst_ip}"
            event.metadata = {
                'device': 'cisco_asa',
                'action': 'deny'
            }
            return event
        
        # Check for threat events
        match = self.CISCO_PATTERNS['threat'].search(line)
        if match:
            month, day, time, month_name, day_num, year, threat_ip = match.groups()
            timestamp_str = f"{year}-{month}-{day_num} {time}"
            event.timestamp = int(datetime.strptime(timestamp_str, "%Y-%m-%d %H:%M:%S").timestamp())
            event.source_ip = threat_ip
            event.event_type = "threat_detected"
            event.severity = 5
            event.message = f"Cisco ASA detected threat from {threat_ip}"
            event.metadata = {
                'device': 'cisco_asa',
                'action': 'threat'
            }
            return event
        
        return None
    
    def _parse_suricata(self, line: str, event: UltraSIEMEvent) -> Optional[UltraSIEMEvent]:
        """Parse Suricata log line"""
        
        # Check for alert events
        match = self.SURICATA_PATTERNS['alert'].search(line)
        if match:
            timestamp, signature, src_ip, dst_ip = match.groups()
            event.timestamp = int(datetime.strptime(timestamp, "%m/%d/%Y-%H:%M:%S.%f").timestamp())
            event.source_ip = src_ip
            event.destination_ip = dst_ip
            event.event_type = "ids_alert"
            event.severity = 5
            event.message = f"Suricata alert: {signature} from {src_ip} to {dst_ip}"
            event.metadata = {
                'signature': signature,
                'device': 'suricata',
                'action': 'alert'
            }
            return event
        
        return None
    
    def _parse_generic(self, line: str, event: UltraSIEMEvent) -> Optional[UltraSIEMEvent]:
        """Parse generic firewall log line"""
        
        # Try to extract IP addresses
        ip_pattern = re.compile(r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b')
        ips = ip_pattern.findall(line)
        
        if len(ips) >= 2:
            event.source_ip = ips[0]
            event.destination_ip = ips[1]
        elif len(ips) == 1:
            event.source_ip = ips[0]
        
        # Determine event type based on keywords
        line_lower = line.lower()
        if any(word in line_lower for word in ['block', 'deny', 'drop']):
            event.event_type = "firewall_block"
            event.severity = 4
        elif any(word in line_lower for word in ['allow', 'pass', 'permit']):
            event.event_type = "firewall_pass"
            event.severity = 2
        elif any(word in line_lower for word in ['alert', 'threat', 'attack']):
            event.event_type = "security_alert"
            event.severity = 5
        else:
            event.event_type = "firewall_event"
            event.severity = 3
        
        event.message = line[:200]  # Truncate long messages
        event.metadata = {
            'device': self.device_type,
            'raw_line': line
        }
        
        return event

class FirewallCollector:
    """Firewall log collector"""
    
    def __init__(self, device_type: str = "pfsense", nats_url: str = None, http_url: str = None):
        self.device_type = device_type
        self.nats_url = nats_url
        self.http_url = http_url
        self.parser = FirewallLogParser(device_type)
        self.nats_client = None
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
    
    async def connect_nats(self):
        """Connect to NATS server"""
        if not NATS_AVAILABLE or not self.nats_url:
            return
        
        try:
            self.nats_client = await nats.connect(self.nats_url)
            self.logger.info(f"Connected to NATS at {self.nats_url}")
        except Exception as e:
            self.logger.error(f"Failed to connect to NATS: {e}")
            self.nats_client = None
    
    async def send_to_nats(self, event: UltraSIEMEvent):
        """Send event to NATS"""
        if not self.nats_client:
            return False
        
        try:
            event_data = json.dumps(event.to_dict())
            await self.nats_client.publish("ultra_siem.events", event_data.encode())
            return True
        except Exception as e:
            self.logger.error(f"Failed to send to NATS: {e}")
            return False
    
    def send_via_http(self, event: UltraSIEMEvent):
        """Send event via HTTP (fallback)"""
        if not REQUESTS_AVAILABLE or not self.http_url:
            return False
        
        try:
            headers = {'Content-Type': 'application/json'}
            response = requests.post(
                self.http_url,
                json=event.to_dict(),
                headers=headers,
                timeout=5
            )
            return response.status_code == 200
        except Exception as e:
            self.logger.error(f"HTTP fallback failed: {e}")
            return False
    
    async def process_log_file(self, log_file: str):
        """Process firewall log file"""
        try:
            with open(log_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    
                    # Parse log line
                    event = self.parser.parse_log_line(line)
                    if not event:
                        continue
                    
                    # Send to NATS first, fallback to HTTP
                    sent = await self.send_to_nats(event)
                    if not sent:
                        sent = self.send_via_http(event)
                    
                    if sent:
                        self.logger.info(f"Processed {self.device_type} event: {event.event_type}")
                    else:
                        self.logger.warning(f"Failed to send event: {event.event_type}")
                        
        except Exception as e:
            self.logger.error(f"Error processing log file {log_file}: {e}")
    
    async def start(self, log_file: str, watch_interval: int = 5):
        """Start the firewall collector"""
        self.logger.info(f"Starting {self.device_type} firewall collector")
        
        # Connect to NATS
        await self.connect_nats()
        
        # Process existing log file
        await self.process_log_file(log_file)
        
        # Watch for new entries
        last_position = 0
        while True:
            try:
                with open(log_file, 'r') as f:
                    f.seek(last_position)
                    new_lines = f.readlines()
                    last_position = f.tell()
                    
                    for line in new_lines:
                        line = line.strip()
                        if not line:
                            continue
                        
                        event = self.parser.parse_log_line(line)
                        if not event:
                            continue
                        
                        sent = await self.send_to_nats(event)
                        if not sent:
                            sent = self.send_via_http(event)
                        
                        if sent:
                            self.logger.info(f"Processed new {self.device_type} event: {event.event_type}")
                
                await asyncio.sleep(watch_interval)
                
            except Exception as e:
                self.logger.error(f"Error in watch loop: {e}")
                await asyncio.sleep(10)

def main():
    parser = argparse.ArgumentParser(description='Ultra SIEM Firewall Log Collector')
    parser.add_argument('--device-type', choices=['pfsense', 'cisco', 'suricata', 'generic'], 
                       default='pfsense', help='Type of firewall device')
    parser.add_argument('--log-file', required=True, help='Path to firewall log file')
    parser.add_argument('--nats-url', help='NATS server URL')
    parser.add_argument('--http-url', default='http://localhost:8080/events', help='HTTP fallback URL')
    parser.add_argument('--watch-interval', type=int, default=5, help='Watch interval in seconds')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose logging')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Create and start collector
    collector = FirewallCollector(
        device_type=args.device_type,
        nats_url=args.nats_url,
        http_url=args.http_url
    )
    
    try:
        asyncio.run(collector.start(args.log_file, args.watch_interval))
    except KeyboardInterrupt:
        print("\nShutting down...")

if __name__ == '__main__':
    main() 