#!/usr/bin/env python3
"""
🛡️ Ultra SIEM - Google Cloud Platform Logging Collector
Professional GCP log ingestion for Ultra SIEM
Supports Cloud Logging, Cloud Audit Logs, and other GCP services
"""

import json
import time
import uuid
import re
import logging
import argparse
import asyncio
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List
from google.cloud import logging_v2
from google.cloud.logging_v2 import LoggingServiceV2Client
from google.cloud.logging_v2.types import ListLogEntriesRequest
from google.auth import default
from google.auth.exceptions import DefaultCredentialsError

# Try to import required libraries
try:
    import nats
    NATS_AVAILABLE = True
except ImportError:
    NATS_AVAILABLE = False

try:
    import requests
    REQUESTS_AVAILABLE = True
except ImportError:
    REQUESTS_AVAILABLE = False

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
        self.log_source = "gcp_logging"
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

class GCPLoggingCollector:
    """Google Cloud Platform logging collector for Ultra SIEM"""
    
    def __init__(self, 
                 project_id: str = None,
                 credentials_path: str = None,
                 nats_url: str = None,
                 http_url: str = None):
        
        self.project_id = project_id
        self.credentials_path = credentials_path
        self.nats_url = nats_url
        self.http_url = http_url
        self.nats_client = None
        self.logger = logging.getLogger(__name__)
        
        # Initialize GCP clients
        try:
            if credentials_path:
                # Use service account key file
                import os
                os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = credentials_path
            
            # Initialize logging client
            self.logging_client = LoggingServiceV2Client()
            
            # Get default project if not specified
            if not project_id:
                _, project_id = default()
                self.project_id = project_id
            
            self.logger.info(f"✅ GCP Logging client initialized for project: {self.project_id}")
            
        except DefaultCredentialsError:
            self.logger.error("❌ GCP credentials not found")
            raise
        except Exception as e:
            self.logger.error(f"❌ Failed to initialize GCP client: {e}")
            raise
    
    async def connect_nats(self):
        """Connect to NATS server"""
        if not NATS_AVAILABLE:
            self.logger.warning("NATS client not available")
            return False
            
        try:
            self.nats_client = await nats.connect(self.nats_url)
            self.logger.info(f"✅ Connected to NATS at {self.nats_url}")
            return True
        except Exception as e:
            self.logger.error(f"❌ Failed to connect to NATS: {e}")
            return False
    
    async def send_to_nats(self, event: UltraSIEMEvent):
        """Send event to NATS"""
        if not self.nats_client:
            return False
            
        try:
            event_data = json.dumps(event.to_dict())
            await self.nats_client.publish("ultra_siem.events", event_data.encode())
            return True
        except Exception as e:
            self.logger.error(f"❌ Failed to send to NATS: {e}")
            return False
    
    def send_via_http(self, event: UltraSIEMEvent):
        """Send event via HTTP fallback"""
        if not self.http_url or not REQUESTS_AVAILABLE:
            return False
            
        try:
            response = requests.post(
                self.http_url,
                json=event.to_dict(),
                headers={'Content-Type': 'application/json'},
                timeout=5
            )
            return response.status_code == 200
        except Exception as e:
            self.logger.error(f"❌ HTTP fallback failed: {e}")
            return False
    
    def parse_gcp_log(self, log_entry: Dict[str, Any], log_type: str) -> Optional[UltraSIEMEvent]:
        """Parse GCP log entry"""
        
        event = UltraSIEMEvent()
        event.raw_message = json.dumps(log_entry)
        event.log_source = f"gcp_{log_type}"
        
        # Extract timestamp
        if 'timestamp' in log_entry:
            try:
                # GCP timestamps are in RFC3339 format
                timestamp_str = log_entry['timestamp']
                if 'T' in timestamp_str and 'Z' in timestamp_str:
                    event.timestamp = int(datetime.fromisoformat(timestamp_str.replace('Z', '+00:00')).timestamp())
            except:
                pass
        
        # Parse based on log type
        if log_type == 'audit':
            return self._parse_audit_log(log_entry, event)
        elif log_type == 'vpc_flow':
            return self._parse_vpc_flow_log(log_entry, event)
        elif log_type == 'compute':
            return self._parse_compute_log(log_entry, event)
        elif log_type == 'storage':
            return self._parse_storage_log(log_entry, event)
        elif log_type == 'iam':
            return self._parse_iam_log(log_entry, event)
        else:
            return self._parse_generic_log(log_entry, event)
    
    def _parse_audit_log(self, log_entry: Dict[str, Any], event: UltraSIEMEvent) -> UltraSIEMEvent:
        """Parse GCP Audit log"""
        
        event.event_category = "gcp_audit"
        
        # Extract authentication info
        auth_info = log_entry.get('authenticationInfo', {})
        event.user = auth_info.get('principalEmail', 'unknown')
        
        # Extract source IP
        if 'callerIp' in auth_info:
            event.source_ip = auth_info['callerIp']
        
        # Extract request info
        request = log_entry.get('request', {})
        method = request.get('method', '')
        resource = request.get('resource', '')
        
        # Determine event type and severity
        service_name = log_entry.get('serviceName', '')
        method_name = log_entry.get('methodName', '')
        
        # Security-sensitive operations
        security_operations = {
            'SetIamPolicy': ('iam_policy_change', 5),
            'CreateServiceAccount': ('service_account_creation', 4),
            'DeleteServiceAccount': ('service_account_deletion', 5),
            'CreateKey': ('service_account_key_creation', 4),
            'DeleteKey': ('service_account_key_deletion', 4),
            'CreateBucket': ('storage_bucket_creation', 3),
            'DeleteBucket': ('storage_bucket_deletion', 4),
            'SetBucketIamPolicy': ('storage_policy_change', 4),
            'CreateInstance': ('compute_instance_creation', 3),
            'DeleteInstance': ('compute_instance_deletion', 4),
            'CreateNetwork': ('network_creation', 3),
            'DeleteNetwork': ('network_deletion', 4),
            'CreateSubnetwork': ('subnet_creation', 3),
            'DeleteSubnetwork': ('subnet_deletion', 4),
        }
        
        if method_name in security_operations:
            event.event_type, event.severity = security_operations[method_name]
        else:
            event.event_type = "gcp_api_call"
            event.severity = 2
        
        event.message = f"GCP Audit: {method_name} by {event.user} from {event.source_ip}"
        event.metadata = {
            'gcp_service': service_name,
            'gcp_method': method_name,
            'gcp_resource': resource,
            'gcp_request_method': method,
            'gcp_response': log_entry.get('response', {}),
        }
        
        return event
    
    def _parse_vpc_flow_log(self, log_entry: Dict[str, Any], event: UltraSIEMEvent) -> UltraSIEMEvent:
        """Parse GCP VPC Flow log"""
        
        event.event_category = "gcp_vpc_flow"
        
        # VPC Flow Log format: timestamp,src_ip,dst_ip,src_port,dst_port,protocol,action,bytes_sent,packets_sent
        if 'jsonPayload' in log_entry:
            payload = log_entry['jsonPayload']
            event.source_ip = payload.get('src_ip', '')
            event.destination_ip = payload.get('dst_ip', '')
            src_port = payload.get('src_port', '')
            dst_port = payload.get('dst_port', '')
            protocol = payload.get('protocol', '')
            action = payload.get('action', '')
            
            # Determine severity based on action and ports
            if action == 'DENY':
                event.severity = 4
                event.event_type = "vpc_flow_deny"
            elif action == 'ACCEPT' and dst_port in ['22', '3389', '1433', '3306']:
                event.severity = 3
                event.event_type = "vpc_flow_admin_access"
            else:
                event.severity = 2
                event.event_type = "vpc_flow_accept"
            
            event.message = f"GCP VPC Flow: {action} {protocol} {event.source_ip}:{src_port} -> {event.destination_ip}:{dst_port}"
            event.metadata = {
                'gcp_protocol': protocol,
                'gcp_src_port': src_port,
                'gcp_dst_port': dst_port,
                'gcp_action': action,
                'gcp_bytes_sent': payload.get('bytes_sent', '0'),
                'gcp_packets_sent': payload.get('packets_sent', '0'),
            }
        
        return event
    
    def _parse_compute_log(self, log_entry: Dict[str, Any], event: UltraSIEMEvent) -> UltraSIEMEvent:
        """Parse GCP Compute Engine log"""
        
        event.event_category = "gcp_compute"
        event.event_type = "compute_log"
        event.severity = 2
        
        # Extract instance information
        resource_labels = log_entry.get('resource', {}).get('labels', {})
        instance_name = resource_labels.get('instance_name', '')
        zone = resource_labels.get('zone', '')
        
        # Extract message
        text_payload = log_entry.get('textPayload', '')
        event.message = f"GCP Compute: {text_payload[:100]}"
        
        # Look for security events
        if any(pattern in text_payload.lower() for pattern in ['error', 'failed', 'denied', 'unauthorized']):
            event.severity = 4
            event.event_type = "compute_security_event"
        
        event.metadata = {
            'gcp_instance_name': instance_name,
            'gcp_zone': zone,
            'gcp_text_payload': text_payload,
        }
        
        return event
    
    def _parse_storage_log(self, log_entry: Dict[str, Any], event: UltraSIEMEvent) -> UltraSIEMEvent:
        """Parse GCP Cloud Storage log"""
        
        event.event_category = "gcp_storage"
        event.event_type = "storage_log"
        event.severity = 2
        
        # Extract storage information
        resource_labels = log_entry.get('resource', {}).get('labels', {})
        bucket_name = resource_labels.get('bucket_name', '')
        
        # Extract request info
        request = log_entry.get('httpRequest', {})
        method = request.get('requestMethod', '')
        url = request.get('requestUrl', '')
        
        event.message = f"GCP Storage: {method} {url}"
        
        # Look for security events
        if method in ['DELETE', 'PUT']:
            event.severity = 3
            event.event_type = "storage_modification"
        
        event.metadata = {
            'gcp_bucket_name': bucket_name,
            'gcp_request_method': method,
            'gcp_request_url': url,
            'gcp_status': request.get('status', ''),
        }
        
        return event
    
    def _parse_iam_log(self, log_entry: Dict[str, Any], event: UltraSIEMEvent) -> UltraSIEMEvent:
        """Parse GCP IAM log"""
        
        event.event_category = "gcp_iam"
        event.event_type = "iam_log"
        event.severity = 3
        
        # Extract IAM information
        auth_info = log_entry.get('authenticationInfo', {})
        event.user = auth_info.get('principalEmail', 'unknown')
        
        # Extract request info
        request = log_entry.get('request', {})
        method = request.get('method', '')
        
        event.message = f"GCP IAM: {method} by {event.user}"
        
        # Security-sensitive IAM operations
        if method in ['SetIamPolicy', 'CreateServiceAccount', 'DeleteServiceAccount']:
            event.severity = 4
            event.event_type = "iam_security_event"
        
        event.metadata = {
            'gcp_iam_method': method,
            'gcp_iam_resource': request.get('resource', ''),
        }
        
        return event
    
    def _parse_generic_log(self, log_entry: Dict[str, Any], event: UltraSIEMEvent) -> UltraSIEMEvent:
        """Parse generic GCP log"""
        
        event.event_type = "gcp_log"
        event.severity = 2
        event.message = str(log_entry.get('textPayload', 'GCP log event'))
        
        return event
    
    async def collect_gcp_logs(self, log_names: List[str] = None, start_time: datetime = None, end_time: datetime = None):
        """Collect logs from GCP Cloud Logging"""
        
        if not start_time:
            start_time = datetime.now() - timedelta(minutes=5)
        if not end_time:
            end_time = datetime.now()
        
        if not log_names:
            # Default log names to monitor
            log_names = [
                f"projects/{self.project_id}/logs/cloudaudit.googleapis.com%2Factivity",
                f"projects/{self.project_id}/logs/cloudaudit.googleapis.com%2Fdata_access",
                f"projects/{self.project_id}/logs/cloudaudit.googleapis.com%2Fpolicy",
                f"projects/{self.project_id}/logs/compute.googleapis.com%2Fvpc_flows",
                f"projects/{self.project_id}/logs/compute.googleapis.com%2Ffirewall",
                f"projects/{self.project_id}/logs/storage.googleapis.com%2Frequest_log",
            ]
        
        try:
            for log_name in log_names:
                # Create request
                request = ListLogEntriesRequest(
                    resource_names=[f"projects/{self.project_id}"],
                    filter_=f'logName="{log_name}" AND timestamp>="{start_time.isoformat()}" AND timestamp<="{end_time.isoformat()}"',
                    order_by="timestamp desc",
                    page_size=100
                )
                
                # Get log entries
                page_result = self.logging_client.list_log_entries(request=request)
                
                for log_entry in page_result:
                    # Convert protobuf to dict
                    log_dict = {
                        'timestamp': log_entry.timestamp.ToDatetime().isoformat(),
                        'severity': log_entry.severity.name,
                        'textPayload': log_entry.text_payload,
                        'jsonPayload': json.loads(log_entry.json_payload) if log_entry.json_payload else {},
                        'resource': {
                            'type': log_entry.resource.type,
                            'labels': dict(log_entry.resource.labels)
                        },
                        'logName': log_entry.log_name,
                        'insertId': log_entry.insert_id,
                    }
                    
                    # Add HTTP request info if available
                    if log_entry.http_request:
                        log_dict['httpRequest'] = {
                            'requestMethod': log_entry.http_request.request_method,
                            'requestUrl': log_entry.http_request.request_url,
                            'status': log_entry.http_request.status,
                        }
                    
                    # Add authentication info if available
                    if log_entry.authentication_info:
                        log_dict['authenticationInfo'] = {
                            'principalEmail': log_entry.authentication_info.principal_email,
                            'callerIp': log_entry.authentication_info.caller_ip,
                        }
                    
                    # Determine log type
                    log_type = 'generic'
                    if 'cloudaudit.googleapis.com' in log_name:
                        log_type = 'audit'
                    elif 'vpc_flows' in log_name:
                        log_type = 'vpc_flow'
                    elif 'compute.googleapis.com' in log_name:
                        log_type = 'compute'
                    elif 'storage.googleapis.com' in log_name:
                        log_type = 'storage'
                    elif 'iam.googleapis.com' in log_name:
                        log_type = 'iam'
                    
                    # Parse and send event
                    parsed_event = self.parse_gcp_log(log_dict, log_type)
                    if parsed_event:
                        if self.nats_client:
                            await self.send_to_nats(parsed_event)
                        else:
                            self.send_via_http(parsed_event)
                        
                        self.logger.debug(f"📤 Sent GCP log event: {parsed_event.event_type}")
            
            self.logger.info(f"✅ Collected GCP logs from {len(log_names)} log sources")
            
        except Exception as e:
            self.logger.error(f"❌ Failed to collect GCP logs: {e}")
    
    async def start_collection(self, collection_interval: int = 60):
        """Start continuous log collection"""
        
        # Connect to NATS
        if self.nats_url:
            await self.connect_nats()
        
        self.logger.info(f"🚀 Starting GCP Logging collection for project: {self.project_id}")
        
        while True:
            try:
                # Collect GCP logs
                await self.collect_gcp_logs()
                
                # Wait for next collection cycle
                await asyncio.sleep(collection_interval)
                
            except KeyboardInterrupt:
                self.logger.info("🛑 GCP Logging collection stopped")
                break
            except Exception as e:
                self.logger.error(f"❌ Collection error: {e}")
                await asyncio.sleep(10)  # Wait before retry

async def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='GCP Logging Collector for Ultra SIEM')
    parser.add_argument('--project-id', help='GCP Project ID')
    parser.add_argument('--credentials-path', help='Path to GCP service account key file')
    parser.add_argument('--nats-url', help='NATS server URL')
    parser.add_argument('--http-url', help='HTTP fallback URL')
    parser.add_argument('--log-names', nargs='+', help='GCP Log names to monitor')
    parser.add_argument('--interval', type=int, default=60, help='Collection interval in seconds')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose logging')
    
    args = parser.parse_args()
    
    # Setup logging
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # Create collector
    collector = GCPLoggingCollector(
        project_id=args.project_id,
        credentials_path=args.credentials_path,
        nats_url=args.nats_url,
        http_url=args.http_url
    )
    
    # Start collection
    await collector.start_collection(collection_interval=args.interval)

if __name__ == "__main__":
    asyncio.run(main()) 