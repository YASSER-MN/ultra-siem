#!/usr/bin/env python3
"""
🛡️ Ultra SIEM - AWS CloudWatch Collector
Professional AWS log ingestion for Ultra SIEM
Supports CloudWatch Logs, CloudTrail, VPC Flow Logs, and other AWS services
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
import boto3
from botocore.exceptions import ClientError, NoCredentialsError

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
        self.log_source = "aws_cloudwatch"
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

class AWSCloudWatchCollector:
    """AWS CloudWatch log collector for Ultra SIEM"""
    
    def __init__(self, 
                 aws_access_key_id: str = None,
                 aws_secret_access_key: str = None,
                 aws_region: str = "us-east-1",
                 nats_url: str = None,
                 http_url: str = None):
        
        self.aws_region = aws_region
        self.nats_url = nats_url
        self.http_url = http_url
        self.nats_client = None
        self.logger = logging.getLogger(__name__)
        
        # Initialize AWS clients
        try:
            if aws_access_key_id and aws_secret_access_key:
                self.cloudwatch = boto3.client(
                    'cloudwatch-logs',
                    aws_access_key_id=aws_access_key_id,
                    aws_secret_access_key=aws_secret_access_key,
                    region_name=aws_region
                )
                self.cloudtrail = boto3.client(
                    'cloudtrail',
                    aws_access_key_id=aws_access_key_id,
                    aws_secret_access_key=aws_secret_access_key,
                    region_name=aws_region
                )
                self.ec2 = boto3.client(
                    'ec2',
                    aws_access_key_id=aws_access_key_id,
                    aws_secret_access_key=aws_secret_access_key,
                    region_name=aws_region
                )
            else:
                # Use default credentials
                self.cloudwatch = boto3.client('cloudwatch-logs', region_name=aws_region)
                self.cloudtrail = boto3.client('cloudtrail', region_name=aws_region)
                self.ec2 = boto3.client('ec2', region_name=aws_region)
                
            self.logger.info(f"✅ AWS clients initialized for region: {aws_region}")
        except NoCredentialsError:
            self.logger.error("❌ AWS credentials not found")
            raise
        except Exception as e:
            self.logger.error(f"❌ Failed to initialize AWS clients: {e}")
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
    
    def parse_cloudwatch_log(self, log_event: Dict[str, Any], log_group: str) -> Optional[UltraSIEMEvent]:
        """Parse CloudWatch log event"""
        
        event = UltraSIEMEvent()
        event.raw_message = json.dumps(log_event)
        event.log_source = f"aws_cloudwatch_{log_group.replace('/', '_')}"
        event.hostname = log_event.get('awsRegion', self.aws_region)
        
        # Extract timestamp
        if 'timestamp' in log_event:
            event.timestamp = int(log_event['timestamp'] / 1000)
        
        # Parse based on log group
        if 'CloudTrail' in log_group:
            return self._parse_cloudtrail_event(log_event, event)
        elif 'VPCFlowLogs' in log_group:
            return self._parse_vpc_flow_log(log_event, event)
        elif 'RDS' in log_group:
            return self._parse_rds_log(log_event, event)
        elif 'Lambda' in log_group:
            return self._parse_lambda_log(log_event, event)
        else:
            return self._parse_generic_log(log_event, event)
    
    def _parse_cloudtrail_event(self, log_event: Dict[str, Any], event: UltraSIEMEvent) -> UltraSIEMEvent:
        """Parse CloudTrail event"""
        
        event.event_category = "cloudtrail"
        event.user = log_event.get('userIdentity', {}).get('userName', 'unknown')
        
        # Extract source IP
        if 'sourceIPAddress' in log_event:
            event.source_ip = log_event['sourceIPAddress']
        
        # Determine event type and severity
        event_name = log_event.get('eventName', '')
        event_type = log_event.get('eventType', '')
        
        # Security-sensitive events
        security_events = {
            'CreateUser': ('user_creation', 4),
            'DeleteUser': ('user_deletion', 5),
            'CreateAccessKey': ('access_key_creation', 4),
            'DeleteAccessKey': ('access_key_deletion', 4),
            'AttachUserPolicy': ('policy_attachment', 4),
            'DetachUserPolicy': ('policy_detachment', 4),
            'CreateRole': ('role_creation', 4),
            'DeleteRole': ('role_deletion', 5),
            'CreateSecurityGroup': ('security_group_creation', 3),
            'DeleteSecurityGroup': ('security_group_deletion', 4),
            'AuthorizeSecurityGroupIngress': ('security_group_rule_add', 4),
            'RevokeSecurityGroupIngress': ('security_group_rule_remove', 3),
            'CreateBucket': ('s3_bucket_creation', 3),
            'DeleteBucket': ('s3_bucket_deletion', 4),
            'PutBucketPolicy': ('s3_policy_change', 4),
            'StartInstances': ('ec2_instance_start', 3),
            'StopInstances': ('ec2_instance_stop', 3),
            'TerminateInstances': ('ec2_instance_termination', 4),
        }
        
        if event_name in security_events:
            event.event_type, event.severity = security_events[event_name]
        else:
            event.event_type = "aws_api_call"
            event.severity = 2
        
        event.message = f"AWS API Call: {event_name} by {event.user} from {event.source_ip}"
        event.metadata = {
            'aws_event_name': event_name,
            'aws_event_type': event_type,
            'aws_request_id': log_event.get('requestID', ''),
            'aws_user_agent': log_event.get('userAgent', ''),
            'aws_error_code': log_event.get('errorCode', ''),
        }
        
        return event
    
    def _parse_vpc_flow_log(self, log_event: Dict[str, Any], event: UltraSIEMEvent) -> UltraSIEMEvent:
        """Parse VPC Flow Log"""
        
        event.event_category = "vpc_flow"
        
        # VPC Flow Log format: version account-id interface-id srcaddr dstaddr srcport dstport protocol packets bytes start end action log-status
        if isinstance(log_event.get('message'), str):
            parts = log_event['message'].split()
            if len(parts) >= 13:
                event.source_ip = parts[3]
                event.destination_ip = parts[4]
                src_port = parts[5]
                dst_port = parts[6]
                protocol = parts[7]
                action = parts[12]
                
                # Determine severity based on action and ports
                if action == 'REJECT':
                    event.severity = 4
                    event.event_type = "vpc_flow_reject"
                elif action == 'ACCEPT' and dst_port in ['22', '3389', '1433', '3306']:
                    event.severity = 3
                    event.event_type = "vpc_flow_admin_access"
                else:
                    event.severity = 2
                    event.event_type = "vpc_flow_accept"
                
                event.message = f"VPC Flow: {action} {protocol} {event.source_ip}:{src_port} -> {event.destination_ip}:{dst_port}"
                event.metadata = {
                    'vpc_protocol': protocol,
                    'vpc_src_port': src_port,
                    'vpc_dst_port': dst_port,
                    'vpc_action': action,
                    'vpc_packets': parts[8] if len(parts) > 8 else '0',
                    'vpc_bytes': parts[9] if len(parts) > 9 else '0',
                }
        
        return event
    
    def _parse_rds_log(self, log_event: Dict[str, Any], event: UltraSIEMEvent) -> UltraSIEMEvent:
        """Parse RDS log"""
        
        event.event_category = "rds"
        event.event_type = "rds_log"
        event.severity = 2
        
        # Extract database connection info
        message = log_event.get('message', '')
        event.message = f"RDS Log: {message[:100]}"
        
        # Look for security events
        if any(pattern in message.lower() for pattern in ['error', 'failed', 'denied', 'unauthorized']):
            event.severity = 4
            event.event_type = "rds_security_event"
        
        event.metadata = {
            'rds_instance': log_event.get('logStream', ''),
            'rds_message': message,
        }
        
        return event
    
    def _parse_lambda_log(self, log_event: Dict[str, Any], event: UltraSIEMEvent) -> UltraSIEMEvent:
        """Parse Lambda log"""
        
        event.event_category = "lambda"
        event.event_type = "lambda_log"
        event.severity = 2
        
        message = log_event.get('message', '')
        event.message = f"Lambda Log: {message[:100]}"
        
        # Look for errors
        if 'error' in message.lower() or 'exception' in message.lower():
            event.severity = 3
            event.event_type = "lambda_error"
        
        event.metadata = {
            'lambda_function': log_event.get('logStream', ''),
            'lambda_message': message,
        }
        
        return event
    
    def _parse_generic_log(self, log_event: Dict[str, Any], event: UltraSIEMEvent) -> UltraSIEMEvent:
        """Parse generic CloudWatch log"""
        
        event.event_type = "cloudwatch_log"
        event.severity = 2
        event.message = str(log_event.get('message', 'CloudWatch log event'))
        
        return event
    
    async def collect_cloudwatch_logs(self, log_group_name: str, start_time: int = None, end_time: int = None):
        """Collect logs from CloudWatch Log Group"""
        
        if not start_time:
            start_time = int((datetime.now() - timedelta(minutes=5)).timestamp() * 1000)
        if not end_time:
            end_time = int(datetime.now().timestamp() * 1000)
        
        try:
            # Get log streams
            streams_response = self.cloudwatch.describe_log_streams(
                logGroupName=log_group_name,
                orderBy='LastEventTime',
                descending=True,
                maxItems=10
            )
            
            for stream in streams_response.get('logStreams', []):
                stream_name = stream['logStreamName']
                
                # Get log events
                events_response = self.cloudwatch.get_log_events(
                    logGroupName=log_group_name,
                    logStreamName=stream_name,
                    startTime=start_time,
                    endTime=end_time,
                    startFromHead=False
                )
                
                for log_event in events_response.get('events', []):
                    parsed_event = self.parse_cloudwatch_log(log_event, log_group_name)
                    if parsed_event:
                        # Send to NATS or HTTP
                        if self.nats_client:
                            await self.send_to_nats(parsed_event)
                        else:
                            self.send_via_http(parsed_event)
                        
                        self.logger.debug(f"📤 Sent CloudWatch event: {parsed_event.event_type}")
            
            self.logger.info(f"✅ Collected logs from {log_group_name}")
            
        except ClientError as e:
            self.logger.error(f"❌ AWS API error: {e}")
        except Exception as e:
            self.logger.error(f"❌ Failed to collect CloudWatch logs: {e}")
    
    async def collect_cloudtrail_events(self, start_time: datetime = None, end_time: datetime = None):
        """Collect CloudTrail events"""
        
        if not start_time:
            start_time = datetime.now() - timedelta(hours=1)
        if not end_time:
            end_time = datetime.now()
        
        try:
            response = self.cloudtrail.lookup_events(
                StartTime=start_time,
                EndTime=end_time,
                MaxResults=50
            )
            
            for trail_event in response.get('Events', []):
                # Convert CloudTrail event to CloudWatch format
                log_event = {
                    'timestamp': int(trail_event['EventTime'].timestamp() * 1000),
                    'awsRegion': trail_event.get('AwsRegion', self.aws_region),
                    'eventName': trail_event.get('EventName', ''),
                    'eventType': trail_event.get('EventType', ''),
                    'userIdentity': trail_event.get('UserIdentity', {}),
                    'sourceIPAddress': trail_event.get('SourceIPAddress', ''),
                    'userAgent': trail_event.get('UserAgent', ''),
                    'requestID': trail_event.get('EventId', ''),
                    'errorCode': trail_event.get('ErrorCode', ''),
                }
                
                parsed_event = self.parse_cloudwatch_log(log_event, 'CloudTrail')
                if parsed_event:
                    if self.nats_client:
                        await self.send_to_nats(parsed_event)
                    else:
                        self.send_via_http(parsed_event)
            
            self.logger.info(f"✅ Collected {len(response.get('Events', []))} CloudTrail events")
            
        except ClientError as e:
            self.logger.error(f"❌ AWS API error: {e}")
        except Exception as e:
            self.logger.error(f"❌ Failed to collect CloudTrail events: {e}")
    
    async def start_collection(self, log_groups: List[str] = None, collection_interval: int = 60):
        """Start continuous log collection"""
        
        if not log_groups:
            # Default log groups to monitor
            log_groups = [
                '/aws/cloudtrail',
                '/aws/vpc/flowlogs',
                '/aws/rds/instance',
                '/aws/lambda',
            ]
        
        # Connect to NATS
        if self.nats_url:
            await self.connect_nats()
        
        self.logger.info(f"🚀 Starting AWS CloudWatch collection for {len(log_groups)} log groups")
        
        while True:
            try:
                # Collect from each log group
                for log_group in log_groups:
                    await self.collect_cloudwatch_logs(log_group)
                
                # Collect CloudTrail events
                await self.collect_cloudtrail_events()
                
                # Wait for next collection cycle
                await asyncio.sleep(collection_interval)
                
            except KeyboardInterrupt:
                self.logger.info("🛑 AWS CloudWatch collection stopped")
                break
            except Exception as e:
                self.logger.error(f"❌ Collection error: {e}")
                await asyncio.sleep(10)  # Wait before retry

async def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='AWS CloudWatch Collector for Ultra SIEM')
    parser.add_argument('--aws-access-key', help='AWS Access Key ID')
    parser.add_argument('--aws-secret-key', help='AWS Secret Access Key')
    parser.add_argument('--aws-region', default='us-east-1', help='AWS Region')
    parser.add_argument('--nats-url', help='NATS server URL')
    parser.add_argument('--http-url', help='HTTP fallback URL')
    parser.add_argument('--log-groups', nargs='+', help='CloudWatch Log Groups to monitor')
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
    collector = AWSCloudWatchCollector(
        aws_access_key_id=args.aws_access_key,
        aws_secret_access_key=args.aws_secret_key,
        aws_region=args.aws_region,
        nats_url=args.nats_url,
        http_url=args.http_url
    )
    
    # Start collection
    await collector.start_collection(
        log_groups=args.log_groups,
        collection_interval=args.interval
    )

if __name__ == "__main__":
    asyncio.run(main()) 