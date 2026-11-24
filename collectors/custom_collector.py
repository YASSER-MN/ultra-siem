#!/usr/bin/env python3
"""
🛡️ Ultra SIEM - Custom Application Log Collector
Professional custom log ingestion for Ultra SIEM
Supports JSON, XML, CSV, and custom log formats with advanced parsing
"""

import json
import time
import uuid
import re
import logging
import argparse
import asyncio
import csv
import xml.etree.ElementTree as ET
from datetime import datetime
from typing import Dict, Any, Optional, List, Callable
from pathlib import Path
import yaml
import jsonschema
from dataclasses import dataclass, asdict

# Try to import required libraries
try:
    import requests
    REQUESTS_AVAILABLE = True
except ImportError:
    REQUESTS_AVAILABLE = False

try:
    import nats
    NATS_AVAILABLE = True
except ImportError:
    NATS_AVAILABLE = False

@dataclass
class UltraSIEMEvent:
    """Ultra SIEM event schema with comprehensive field support"""
    
    id: str = None
    timestamp: int = None
    source_ip: str = ""
    destination_ip: str = ""
    source_port: int = 0
    destination_port: int = 0
    protocol: str = ""
    event_type: str = ""
    severity: int = 2
    message: str = ""
    raw_message: str = ""
    log_source: str = "custom_collector"
    user: str = ""
    hostname: str = ""
    process: str = ""
    process_id: int = 0
    event_id: str = ""
    event_category: str = ""
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.id is None:
            self.id = str(uuid.uuid4())
        if self.timestamp is None:
            self.timestamp = int(time.time())
        if self.metadata is None:
            self.metadata = {}
    
    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

class LogParser:
    """Advanced log parser with multiple format support"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.logger = logging.getLogger(__name__)
        self.custom_transforms = {}
        self._load_custom_transforms()
    
    def _load_custom_transforms(self):
        """Load custom transformation functions"""
        if 'custom_transforms' in self.config:
            for name, transform_config in self.config['custom_transforms'].items():
                if 'function' in transform_config:
                    try:
                        # Create function from string (for simple transformations)
                        func_str = transform_config['function']
                        self.custom_transforms[name] = eval(f"lambda x: {func_str}")
                    except Exception as e:
                        self.logger.warning(f"Failed to load custom transform {name}: {e}")
    
    def parse_json(self, line: str) -> Optional[Dict[str, Any]]:
        """Parse JSON log line"""
        try:
            data = json.loads(line.strip())
            return data
        except json.JSONDecodeError:
            return None
    
    def parse_xml(self, line: str) -> Optional[Dict[str, Any]]:
        """Parse XML log line"""
        try:
            root = ET.fromstring(line.strip())
            return self._xml_to_dict(root)
        except ET.ParseError:
            return None
    
    def _xml_to_dict(self, element) -> Dict[str, Any]:
        """Convert XML element to dictionary"""
        result = {}
        for child in element:
            if len(child) == 0:
                result[child.tag] = child.text
            else:
                result[child.tag] = self._xml_to_dict(child)
        return result
    
    def parse_csv(self, line: str) -> Optional[Dict[str, Any]]:
        """Parse CSV log line"""
        try:
            reader = csv.DictReader([line.strip()])
            return next(reader)
        except Exception:
            return None
    
    def parse_regex(self, line: str, pattern: str, field_mapping: Dict[str, str]) -> Optional[Dict[str, Any]]:
        """Parse log line using regex pattern"""
        try:
            match = re.match(pattern, line.strip())
            if match:
                result = {}
                for field_name, group_name in field_mapping.items():
                    result[field_name] = match.group(group_name)
                return result
            return None
        except Exception:
            return None
    
    def parse_log_line(self, line: str) -> Optional[UltraSIEMEvent]:
        """Parse a single log line using configured format"""
        
        # Determine format and parse
        parsed_data = None
        format_config = self.config.get('format', 'json')
        
        if format_config == 'json':
            parsed_data = self.parse_json(line)
        elif format_config == 'xml':
            parsed_data = self.parse_xml(line)
        elif format_config == 'csv':
            parsed_data = self.parse_csv(line)
        elif format_config == 'regex':
            pattern = self.config.get('regex_pattern', '')
            field_mapping = self.config.get('field_mapping', {})
            parsed_data = self.parse_regex(line, pattern, field_mapping)
        else:
            # Try auto-detection
            parsed_data = self.parse_json(line) or self.parse_xml(line) or self.parse_csv(line)
        
        if not parsed_data:
            return None
        
        # Create Ultra SIEM event
        event = UltraSIEMEvent()
        event.raw_message = line
        
        # Apply field mapping
        field_mapping = self.config.get('field_mapping', {})
        for ultra_field, source_field in field_mapping.items():
            if source_field in parsed_data:
                setattr(event, ultra_field, parsed_data[source_field])
        
        # Apply custom transformations
        for transform_name, transform_func in self.custom_transforms.items():
            try:
                transform_func(event)
            except Exception as e:
                self.logger.warning(f"Transform {transform_name} failed: {e}")
        
        # Apply default values
        defaults = self.config.get('defaults', {})
        for field, value in defaults.items():
            if not getattr(event, field, None):
                setattr(event, field, value)
        
        return event

class CustomCollector:
    """Custom log collector with enterprise-grade features"""
    
    def __init__(self, config_path: str):
        self.config = self._load_config(config_path)
        self.parser = LogParser(self.config)
        self.logger = self._setup_logging()
        self.nats_client = None
        self.http_client = None
        self.stats = {
            'events_processed': 0,
            'events_sent': 0,
            'errors': 0,
            'start_time': time.time()
        }
    
    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """Load configuration from YAML file"""
        try:
            with open(config_path, 'r') as f:
                config = yaml.safe_load(f)
            
            # Validate configuration
            self._validate_config(config)
            return config
        except Exception as e:
            raise Exception(f"Failed to load configuration: {e}")
    
    def _validate_config(self, config: Dict[str, Any]):
        """Validate configuration schema"""
        required_fields = ['format', 'source']
        for field in required_fields:
            if field not in config:
                raise ValueError(f"Missing required field: {field}")
        
        # Validate format-specific requirements
        if config['format'] == 'regex':
            if 'regex_pattern' not in config:
                raise ValueError("regex_pattern required for regex format")
            if 'field_mapping' not in config:
                raise ValueError("field_mapping required for regex format")
    
    def _setup_logging(self) -> logging.Logger:
        """Setup logging configuration"""
        log_config = self.config.get('logging', {})
        log_level = getattr(logging, log_config.get('level', 'INFO').upper())
        
        logger = logging.getLogger(__name__)
        logger.setLevel(log_level)
        
        if not logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(
                log_config.get('format', '%(asctime)s - %(name)s - %(levelname)s - %(message)s')
            )
            handler.setFormatter(formatter)
            logger.addHandler(handler)
        
        return logger
    
    async def _setup_nats(self):
        """Setup NATS connection"""
        if not NATS_AVAILABLE:
            self.logger.warning("NATS not available, using HTTP fallback")
            return
        
        try:
            nats_config = self.config.get('nats', {})
            self.nats_client = await nats.connect(
                nats_config.get('url', 'nats://localhost:4222'),
                name=nats_config.get('client_name', 'custom-collector'),
                reconnect_time_wait=nats_config.get('reconnect_time_wait', 1),
                max_reconnect_attempts=nats_config.get('max_reconnect_attempts', 10)
            )
            self.logger.info("Connected to NATS")
        except Exception as e:
            self.logger.error(f"Failed to connect to NATS: {e}")
            self.nats_client = None
    
    def _setup_http(self):
        """Setup HTTP client for fallback"""
        if not REQUESTS_AVAILABLE:
            self.logger.warning("Requests not available, HTTP fallback disabled")
            return
        
        http_config = self.config.get('http', {})
        self.http_client = requests.Session()
        self.http_client.headers.update({
            'Content-Type': 'application/json',
            'User-Agent': 'UltraSIEM-CustomCollector/1.0'
        })
        
        if 'auth_token' in http_config:
            self.http_client.headers['Authorization'] = f"Bearer {http_config['auth_token']}"
    
    async def send_event(self, event: UltraSIEMEvent):
        """Send event via NATS or HTTP"""
        event_dict = event.to_dict()
        
        # Try NATS first
        if self.nats_client:
            try:
                topic = self.config.get('nats', {}).get('topic', 'ultra_siem.events')
                await self.nats_client.publish(topic, json.dumps(event_dict).encode())
                self.stats['events_sent'] += 1
                return
            except Exception as e:
                self.logger.warning(f"NATS send failed: {e}")
        
        # Fallback to HTTP
        if self.http_client:
            try:
                url = self.config.get('http', {}).get('url', 'http://localhost:8080/events')
                response = self.http_client.post(url, json=event_dict, timeout=5)
                response.raise_for_status()
                self.stats['events_sent'] += 1
            except Exception as e:
                self.logger.error(f"HTTP send failed: {e}")
                self.stats['errors'] += 1
    
    async def process_file(self, file_path: str):
        """Process a single log file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                for line_num, line in enumerate(f, 1):
                    try:
                        # Parse log line
                        event = self.parser.parse_log_line(line)
                        if event:
                            await self.send_event(event)
                            self.stats['events_processed'] += 1
                        else:
                            self.logger.debug(f"Failed to parse line {line_num}")
                    except Exception as e:
                        self.logger.error(f"Error processing line {line_num}: {e}")
                        self.stats['errors'] += 1
                        
                        # Apply error handling
                        error_config = self.config.get('error_handling', {})
                        if error_config.get('stop_on_error', False):
                            break
        except Exception as e:
            self.logger.error(f"Error processing file {file_path}: {e}")
    
    async def monitor_directory(self, directory: str):
        """Monitor directory for new log files"""
        import watchdog.observers
        import watchdog.events
        
        class LogFileHandler(watchdog.events.FileSystemEventHandler):
            def __init__(self, collector):
                self.collector = collector
            
            def on_created(self, event):
                if not event.is_directory and event.src_path.endswith('.log'):
                    asyncio.create_task(self.collector.process_file(event.src_path))
            
            def on_modified(self, event):
                if not event.is_directory and event.src_path.endswith('.log'):
                    asyncio.create_task(self.collector.process_file(event.src_path))
        
        observer = watchdog.observers.Observer()
        observer.schedule(LogFileHandler(self), directory, recursive=True)
        observer.start()
        
        try:
            while True:
                await asyncio.sleep(1)
        except KeyboardInterrupt:
            observer.stop()
        observer.join()
    
    async def start(self):
        """Start the custom collector"""
        self.logger.info("Starting Ultra SIEM Custom Collector")
        
        # Setup connections
        await self._setup_nats()
        self._setup_http()
        
        # Get source configuration
        source_config = self.config['source']
        source_type = source_config['type']
        
        if source_type == 'file':
            file_path = source_config['path']
            await self.process_file(file_path)
        elif source_type == 'directory':
            directory = source_config['path']
            await self.monitor_directory(directory)
        elif source_type == 'http':
            # HTTP endpoint monitoring
            url = source_config['url']
            interval = source_config.get('interval', 60)
            while True:
                try:
                    response = requests.get(url, timeout=10)
                    if response.status_code == 200:
                        for line in response.text.split('\n'):
                            if line.strip():
                                event = self.parser.parse_log_line(line)
                                if event:
                                    await self.send_event(event)
                                    self.stats['events_processed'] += 1
                except Exception as e:
                    self.logger.error(f"HTTP monitoring error: {e}")
                await asyncio.sleep(interval)
        else:
            raise ValueError(f"Unsupported source type: {source_type}")

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='Ultra SIEM Custom Collector')
    parser.add_argument('--config', required=True, help='Configuration file path')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose logging')
    
    args = parser.parse_args()
    
    try:
        collector = CustomCollector(args.config)
        if args.verbose:
            collector.logger.setLevel(logging.DEBUG)
        
        asyncio.run(collector.start())
    except KeyboardInterrupt:
        print("\nShutting down...")
    except Exception as e:
        print(f"Error: {e}")
        exit(1)

if __name__ == '__main__':
    main() 