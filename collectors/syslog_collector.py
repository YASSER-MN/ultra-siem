#!/usr/bin/env python3
"""
🛡️ Ultra SIEM - Syslog Collector
Professional syslog ingestion for Ultra SIEM
Collects syslog messages from Linux systems and network devices
"""

import socket
import json
import time
import threading
import logging
import re
import uuid
from datetime import datetime
from typing import Dict, Any, Optional
import argparse
import sys
import os

# Try to import NATS client
try:
    import nats
    import asyncio
    NATS_AVAILABLE = True
except ImportError:
    NATS_AVAILABLE = False
    print("Warning: NATS client not available. Using HTTP fallback.")

# Try to import HTTP client
try:
    import requests
    REQUESTS_AVAILABLE = True
except ImportError:
    REQUESTS_AVAILABLE = False
    print("Warning: Requests library not available.")

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
        self.log_source = "syslog"
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

class SyslogParser:
    """Parse syslog messages and convert to Ultra SIEM events"""
    
    # Syslog regex patterns
    SYSLOG_PATTERNS = [
        # RFC3164 format
        r'<(\d+)>(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})\s+(\S+)\s+(.+)',
        # RFC5424 format
        r'<(\d+)>(\d)\s+(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[+-]\d{2}:\d{2}|Z)?)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+)',
        # Simple format
        r'<(\d+)>(.+)'
    ]
    
    # Common security event patterns
    SECURITY_PATTERNS = {
        'ssh_failed_login': [
            r'Failed password for (\S+) from (\S+)',
            r'Invalid user (\S+) from (\S+)',
            r'Authentication failure for (\S+) from (\S+)'
        ],
        'ssh_successful_login': [
            r'Accepted password for (\S+) from (\S+)',
            r'Accepted publickey for (\S+) from (\S+)'
        ],
        'sudo_usage': [
            r'(\S+) : TTY=(\S+) ; PWD=(\S+) ; USER=(\S+) ; COMMAND=(\S+)',
            r'(\S+) : (\S+) ; TTY=(\S+) ; PWD=(\S+) ; USER=(\S+) ; COMMAND=(.+)'
        ],
        'user_creation': [
            r'new user: name=(\S+)',
            r'useradd\[(\d+)\]: new user: name=(\S+)'
        ],
        'user_deletion': [
            r'delete user: name=(\S+)',
            r'userdel\[(\d+)\]: delete user: name=(\S+)'
        ],
        'password_change': [
            r'password for (\S+) changed by (\S+)',
            r'passwd\[(\d+)\]: password for (\S+) changed by (\S+)'
        ],
        'service_start': [
            r'Started (\S+)',
            r'(\S+) started'
        ],
        'service_stop': [
            r'Stopped (\S+)',
            r'(\S+) stopped'
        ],
        'kernel_alert': [
            r'kernel: (.+)',
            r'Kernel: (.+)'
        ],
        'disk_full': [
            r'No space left on device',
            r'Disk full'
        ],
        'network_interface': [
            r'Network interface (\S+) is up',
            r'Network interface (\S+) is down'
        ]
    }
    
    def __init__(self):
        self.compiled_patterns = {}
        for event_type, patterns in self.SECURITY_PATTERNS.items():
            self.compiled_patterns[event_type] = [re.compile(p, re.IGNORECASE) for p in patterns]
    
    def parse_syslog_message(self, message: str, source_ip: str = "") -> Optional[UltraSIEMEvent]:
        """Parse syslog message and convert to Ultra SIEM event"""
        
        event = UltraSIEMEvent()
        event.raw_message = message
        event.source_ip = source_ip
        
        # Try to parse syslog format
        parsed = self._parse_syslog_format(message)
        if parsed:
            priority, timestamp, hostname, process, content = parsed
            event.hostname = hostname
            event.process = process
            event.metadata['priority'] = priority
            event.metadata['timestamp'] = timestamp
        else:
            # Fallback parsing
            event.hostname = "unknown"
            event.process = "unknown"
            content = message
        
        # Analyze content for security events
        security_info = self._analyze_security_content(content)
        if security_info:
            event.event_type = security_info['type']
            event.severity = security_info['severity']
            event.message = security_info['message']
            event.user = security_info.get('user', '')
            event.metadata.update(security_info.get('metadata', {}))
        else:
            # Default event
            event.event_type = "syslog_message"
            event.severity = self._get_severity_from_priority(parsed[0] if parsed else 6)
            event.message = content[:200]  # Truncate long messages
        
        return event
    
    def _parse_syslog_format(self, message: str) -> Optional[tuple]:
        """Parse syslog message format"""
        
        for pattern in self.SYSLOG_PATTERNS:
            match = re.match(pattern, message)
            if match:
                groups = match.groups()
                
                if len(groups) >= 4:
                    # RFC3164 or RFC5424 format
                    priority = int(groups[0])
                    timestamp = groups[1]
                    hostname = groups[2]
                    
                    if len(groups) >= 5:
                        # RFC5424 format
                        process = groups[4]
                        content = groups[-1]
                    else:
                        # RFC3164 format
                        content = groups[3]
                        # Extract process from content
                        process_match = re.match(r'(\S+):\s*(.+)', content)
                        if process_match:
                            process = process_match.group(1)
                            content = process_match.group(2)
                        else:
                            process = "unknown"
                    
                    return priority, timestamp, hostname, process, content
        
        return None
    
    def _analyze_security_content(self, content: str) -> Optional[Dict[str, Any]]:
        """Analyze content for security-related events"""
        
        for event_type, patterns in self.compiled_patterns.items():
            for pattern in patterns:
                match = pattern.search(content)
                if match:
                    return self._create_security_event(event_type, match, content)
        
        return None
    
    def _create_security_event(self, event_type: str, match, content: str) -> Dict[str, Any]:
        """Create security event from pattern match"""
        
        groups = match.groups()
        
        if event_type == 'ssh_failed_login':
            return {
                'type': 'ssh_failed_login',
                'severity': 4,
                'message': f"SSH failed login attempt for user '{groups[0]}' from {groups[1]}",
                'user': groups[0],
                'metadata': {'source_ip': groups[1], 'protocol': 'ssh'}
            }
        
        elif event_type == 'ssh_successful_login':
            return {
                'type': 'ssh_successful_login',
                'severity': 2,
                'message': f"SSH successful login for user '{groups[0]}' from {groups[1]}",
                'user': groups[0],
                'metadata': {'source_ip': groups[1], 'protocol': 'ssh'}
            }
        
        elif event_type == 'sudo_usage':
            return {
                'type': 'sudo_usage',
                'severity': 3,
                'message': f"Sudo command executed by '{groups[0]}': {groups[-1]}",
                'user': groups[0],
                'metadata': {'command': groups[-1], 'tty': groups[1] if len(groups) > 1 else ''}
            }
        
        elif event_type == 'user_creation':
            username = groups[-1] if len(groups) > 1 else groups[0]
            return {
                'type': 'user_creation',
                'severity': 4,
                'message': f"New user created: {username}",
                'user': username,
                'metadata': {'action': 'user_creation'}
            }
        
        elif event_type == 'user_deletion':
            username = groups[-1] if len(groups) > 1 else groups[0]
            return {
                'type': 'user_deletion',
                'severity': 4,
                'message': f"User deleted: {username}",
                'user': username,
                'metadata': {'action': 'user_deletion'}
            }
        
        elif event_type == 'password_change':
            return {
                'type': 'password_change',
                'severity': 3,
                'message': f"Password changed for user '{groups[0]}' by {groups[1]}",
                'user': groups[0],
                'metadata': {'changed_by': groups[1]}
            }
        
        elif event_type == 'service_start':
            service = groups[0]
            return {
                'type': 'service_start',
                'severity': 2,
                'message': f"Service started: {service}",
                'metadata': {'service': service, 'action': 'start'}
            }
        
        elif event_type == 'service_stop':
            service = groups[0]
            return {
                'type': 'service_stop',
                'severity': 3,
                'message': f"Service stopped: {service}",
                'metadata': {'service': service, 'action': 'stop'}
            }
        
        elif event_type == 'kernel_alert':
            return {
                'type': 'kernel_alert',
                'severity': 4,
                'message': f"Kernel alert: {groups[0]}",
                'metadata': {'kernel_message': groups[0]}
            }
        
        elif event_type == 'disk_full':
            return {
                'type': 'disk_full',
                'severity': 5,
                'message': "Disk space full - critical system issue",
                'metadata': {'issue': 'disk_full'}
            }
        
        elif event_type == 'network_interface':
            interface = groups[0]
            status = "up" if "up" in content.lower() else "down"
            return {
                'type': 'network_interface_change',
                'severity': 3,
                'message': f"Network interface {interface} is {status}",
                'metadata': {'interface': interface, 'status': status}
            }
        
        return None
    
    def _get_severity_from_priority(self, priority: int) -> int:
        """Convert syslog priority to Ultra SIEM severity"""
        facility = priority >> 3
        level = priority & 0x07
        
        # Map syslog levels to Ultra SIEM severity
        severity_map = {
            0: 5,  # Emergency
            1: 5,  # Alert
            2: 5,  # Critical
            3: 4,  # Error
            4: 3,  # Warning
            5: 2,  # Notice
            6: 1,  # Info
            7: 1   # Debug
        }
        
        return severity_map.get(level, 2)

class SyslogCollector:
    """Syslog collector server"""
    
    def __init__(self, host: str = '0.0.0.0', port: int = 514, nats_url: str = None, http_url: str = None):
        self.host = host
        self.port = port
        self.nats_url = nats_url
        self.http_url = http_url
        self.parser = SyslogParser()
        self.running = False
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
    
    async def handle_syslog_message(self, message: str, client_address: tuple):
        """Handle incoming syslog message"""
        try:
            # Parse syslog message
            event = self.parser.parse_syslog_message(message, client_address[0])
            if not event:
                return
            
            # Send to NATS first, fallback to HTTP
            sent = await self.send_to_nats(event)
            if not sent:
                sent = self.send_via_http(event)
            
            if sent:
                self.logger.info(f"Processed syslog event: {event.event_type} from {client_address[0]}")
            else:
                self.logger.warning(f"Failed to send event: {event.event_type}")
                
        except Exception as e:
            self.logger.error(f"Error processing syslog message: {e}")
    
    async def start_udp_server(self):
        """Start UDP syslog server"""
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind((self.host, self.port))
        
        self.logger.info(f"Starting UDP syslog server on {self.host}:{self.port}")
        
        while self.running:
            try:
                data, addr = sock.recvfrom(4096)
                message = data.decode('utf-8', errors='ignore').strip()
                
                if message:
                    await self.handle_syslog_message(message, addr)
                    
            except Exception as e:
                self.logger.error(f"UDP server error: {e}")
        
        sock.close()
    
    async def start_tcp_server(self):
        """Start TCP syslog server"""
        server = await asyncio.start_server(
            self.handle_tcp_client,
            self.host,
            self.port
        )
        
        self.logger.info(f"Starting TCP syslog server on {self.host}:{self.port}")
        
        async with server:
            await server.serve_forever()
    
    async def handle_tcp_client(self, reader, writer):
        """Handle TCP client connection"""
        addr = writer.get_extra_info('peername')
        
        try:
            while self.running:
                data = await reader.read(4096)
                if not data:
                    break
                
                message = data.decode('utf-8', errors='ignore').strip()
                if message:
                    await self.handle_syslog_message(message, addr)
                    
        except Exception as e:
            self.logger.error(f"TCP client error: {e}")
        finally:
            writer.close()
            await writer.wait_closed()
    
    async def start(self):
        """Start the syslog collector"""
        self.running = True
        
        # Connect to NATS
        await self.connect_nats()
        
        # Start both UDP and TCP servers
        udp_task = asyncio.create_task(self.start_udp_server())
        tcp_task = asyncio.create_task(self.start_tcp_server())
        
        try:
            await asyncio.gather(udp_task, tcp_task)
        except KeyboardInterrupt:
            self.logger.info("Shutting down syslog collector...")
        finally:
            self.running = False
            if self.nats_client:
                await self.nats_client.close()

def main():
    parser = argparse.ArgumentParser(description='Ultra SIEM Syslog Collector')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--port', type=int, default=514, help='Port to listen on')
    parser.add_argument('--nats-url', help='NATS server URL')
    parser.add_argument('--http-url', default='http://localhost:8080/events', help='HTTP fallback URL')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose logging')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Create and start collector
    collector = SyslogCollector(
        host=args.host,
        port=args.port,
        nats_url=args.nats_url,
        http_url=args.http_url
    )
    
    try:
        asyncio.run(collector.start())
    except KeyboardInterrupt:
        print("\nShutting down...")

if __name__ == '__main__':
    main() 