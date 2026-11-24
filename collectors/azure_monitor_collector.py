#!/usr/bin/env python3
"""
🛡️ Ultra SIEM - Azure Monitor Collector
Professional Azure log ingestion for Ultra SIEM
Supports Azure Monitor, Azure AD, Security Center, and other Azure services
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
import requests
from azure.identity import DefaultAzureCredential, ClientSecretCredential
from azure.mgmt.monitor import MonitorManagementClient
from azure.mgmt.security import SecurityCenter
from azure.graphrbac import GraphRbacManagementClient

# Try to import required libraries
try:
    import nats
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
        self.log_source = "azure_monitor"
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

class AzureMonitorCollector:
    """Azure Monitor log collector for Ultra SIEM"""
    
    def __init__(self, 
                 tenant_id: str = None,
                 client_id: str = None,
                 client_secret: str = None,
                 subscription_id: str = None,
                 nats_url: str = None,
                 http_url: str = None):
        
        self.tenant_id = tenant_id
        self.client_id = client_id
        self.client_secret = client_secret
        self.subscription_id = subscription_id
        self.nats_url = nats_url
        self.http_url = http_url
        self.nats_client = None
        self.logger = logging.getLogger(__name__)
        
        # Initialize Azure clients
        try:
            if tenant_id and client_id and client_secret:
                # Use service principal authentication
                self.credential = ClientSecretCredential(
                    tenant_id=tenant_id,
                    client_id=client_id,
                    client_secret=client_secret
                )
            else:
                # Use default credential (managed identity or Azure CLI)
                self.credential = DefaultAzureCredential()
            
            # Initialize Azure clients
            self.monitor_client = MonitorManagementClient(
                credential=self.credential,
                subscription_id=subscription_id
            )
            
            self.security_client = SecurityCenter(
                credential=self.credential,
                subscription_id=subscription_id
            )
            
            if tenant_id:
                self.graph_client = GraphRbacManagementClient(
                    credential=self.credential,
                    tenant_id=tenant_id
                )
            
            self.logger.info("✅ Azure clients initialized successfully")
            
        except Exception as e:
            self.logger.error(f"❌ Failed to initialize Azure clients: {e}")
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
        if not self.http_url:
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
    
    def parse_azure_log(self, log_entry: Dict[str, Any], log_type: str) -> Optional[UltraSIEMEvent]:
        """Parse Azure log entry"""
        
        event = UltraSIEMEvent()
        event.raw_message = json.dumps(log_entry)
        event.log_source = f"azure_{log_type}"
        
        # Extract timestamp
        if 'time' in log_entry:
            try:
                event.timestamp = int(datetime.fromisoformat(log_entry['time'].replace('Z', '+00:00')).timestamp())
            except:
                pass
        
        # Parse based on log type
        if log_type == 'audit':
            return self._parse_audit_log(log_entry, event)
        elif log_type == 'signin':
            return self._parse_signin_log(log_entry, event)
        elif log_type == 'security':
            return self._parse_security_log(log_entry, event)
        elif log_type == 'activity':
            return self._parse_activity_log(log_entry, event)
        else:
            return self._parse_generic_log(log_entry, event)
    
    def _parse_audit_log(self, log_entry: Dict[str, Any], event: UltraSIEMEvent) -> UltraSIEMEvent:
        """Parse Azure AD audit log"""
        
        event.event_category = "azure_ad_audit"
        event.user = log_entry.get('initiatedBy', {}).get('user', {}).get('userPrincipalName', 'unknown')
        
        # Extract IP address
        if 'ipAddress' in log_entry:
            event.source_ip = log_entry['ipAddress']
        
        # Determine event type and severity
        category = log_entry.get('category', '')
        activity = log_entry.get('activityDisplayName', '')
        
        # Security-sensitive events
        security_events = {
            'UserManagement': ('user_management', 4),
            'GroupManagement': ('group_management', 4),
            'ApplicationManagement': ('application_management', 4),
            'RoleManagement': ('role_management', 5),
            'DirectoryManagement': ('directory_management', 4),
            'PolicyManagement': ('policy_management', 4),
            'DeviceManagement': ('device_management', 3),
            'AdministrativeUnit': ('administrative_unit', 4),
        }
        
        if category in security_events:
            event.event_type, event.severity = security_events[category]
        else:
            event.event_type = "azure_ad_event"
            event.severity = 2
        
        event.message = f"Azure AD Audit: {activity} by {event.user}"
        event.metadata = {
            'azure_category': category,
            'azure_activity': activity,
            'azure_result': log_entry.get('result', ''),
            'azure_target_resources': log_entry.get('targetResources', []),
        }
        
        return event
    
    def _parse_signin_log(self, log_entry: Dict[str, Any], event: UltraSIEMEvent) -> UltraSIEMEvent:
        """Parse Azure AD sign-in log"""
        
        event.event_category = "azure_ad_signin"
        event.user = log_entry.get('userPrincipalName', 'unknown')
        
        # Extract IP address
        if 'ipAddress' in log_entry:
            event.source_ip = log_entry['ipAddress']
        
        # Determine event type and severity
        result = log_entry.get('resultType', '')
        risk_level = log_entry.get('riskLevel', 'none')
        
        if result == 'success':
            if risk_level in ['high', 'medium']:
                event.event_type = "risky_signin"
                event.severity = 4
            else:
                event.event_type = "successful_signin"
                event.severity = 2
        else:
            event.event_type = "failed_signin"
            event.severity = 3
        
        event.message = f"Azure AD Sign-in: {result} for {event.user} from {event.source_ip}"
        event.metadata = {
            'azure_result': result,
            'azure_risk_level': risk_level,
            'azure_app_display_name': log_entry.get('appDisplayName', ''),
            'azure_client_app_used': log_entry.get('clientAppUsed', ''),
            'azure_device_detail': log_entry.get('deviceDetail', {}),
            'azure_location': log_entry.get('location', {}),
        }
        
        return event
    
    def _parse_security_log(self, log_entry: Dict[str, Any], event: UltraSIEMEvent) -> UltraSIEMEvent:
        """Parse Azure Security Center log"""
        
        event.event_category = "azure_security"
        event.event_type = "security_alert"
        event.severity = 4
        
        # Extract alert information
        alert_name = log_entry.get('alertName', '')
        severity = log_entry.get('severity', 'medium')
        
        # Map severity
        severity_map = {
            'high': 5,
            'medium': 4,
            'low': 3,
            'informational': 2
        }
        event.severity = severity_map.get(severity.lower(), 3)
        
        event.message = f"Azure Security Alert: {alert_name} (Severity: {severity})"
        event.metadata = {
            'azure_alert_name': alert_name,
            'azure_severity': severity,
            'azure_category': log_entry.get('category', ''),
            'azure_subcategory': log_entry.get('subcategory', ''),
            'azure_resource_group': log_entry.get('resourceGroup', ''),
            'azure_resource_type': log_entry.get('resourceType', ''),
        }
        
        return event
    
    def _parse_activity_log(self, log_entry: Dict[str, Any], event: UltraSIEMEvent) -> UltraSIEMEvent:
        """Parse Azure Activity log"""
        
        event.event_category = "azure_activity"
        
        # Extract caller information
        caller = log_entry.get('caller', 'unknown')
        event.user = caller
        
        # Extract IP address
        if 'claims' in log_entry and 'ipaddr' in log_entry['claims']:
            event.source_ip = log_entry['claims']['ipaddr']
        
        # Determine event type and severity
        operation_name = log_entry.get('operationName', '')
        status = log_entry.get('status', '')
        
        # Security-sensitive operations
        security_operations = {
            'Microsoft.Authorization/policyAssignments/write': ('policy_assignment', 4),
            'Microsoft.Authorization/policyDefinitions/write': ('policy_definition', 4),
            'Microsoft.Authorization/roleAssignments/write': ('role_assignment', 5),
            'Microsoft.Authorization/roleDefinitions/write': ('role_definition', 5),
            'Microsoft.KeyVault/vaults/write': ('keyvault_creation', 4),
            'Microsoft.KeyVault/vaults/accessPolicies/write': ('keyvault_policy', 4),
            'Microsoft.Storage/storageAccounts/write': ('storage_creation', 3),
            'Microsoft.Network/virtualNetworks/write': ('vnet_creation', 3),
            'Microsoft.Compute/virtualMachines/write': ('vm_creation', 3),
        }
        
        if operation_name in security_operations:
            event.event_type, event.severity = security_operations[operation_name]
        else:
            event.event_type = "azure_operation"
            event.severity = 2
        
        event.message = f"Azure Activity: {operation_name} by {caller} - {status}"
        event.metadata = {
            'azure_operation': operation_name,
            'azure_status': status,
            'azure_resource_group': log_entry.get('resourceGroup', ''),
            'azure_resource_type': log_entry.get('resourceType', ''),
            'azure_subscription_id': log_entry.get('subscriptionId', ''),
        }
        
        return event
    
    def _parse_generic_log(self, log_entry: Dict[str, Any], event: UltraSIEMEvent) -> UltraSIEMEvent:
        """Parse generic Azure log"""
        
        event.event_type = "azure_log"
        event.severity = 2
        event.message = str(log_entry.get('message', 'Azure log event'))
        
        return event
    
    async def collect_azure_ad_logs(self, start_time: datetime = None, end_time: datetime = None):
        """Collect Azure AD logs"""
        
        if not start_time:
            start_time = datetime.now() - timedelta(hours=1)
        if not end_time:
            end_time = datetime.now()
        
        try:
            # Collect audit logs
            audit_logs = self.graph_client.audit_logs.list(
                filter=f"eventDateTime ge {start_time.isoformat()} and eventDateTime le {end_time.isoformat()}"
            )
            
            for log_entry in audit_logs:
                parsed_event = self.parse_azure_log(log_entry.as_dict(), 'audit')
                if parsed_event:
                    if self.nats_client:
                        await self.send_to_nats(parsed_event)
                    else:
                        self.send_via_http(parsed_event)
            
            # Collect sign-in logs
            signin_logs = self.graph_client.sign_in_reports.list(
                filter=f"signInDateTime ge {start_time.isoformat()} and signInDateTime le {end_time.isoformat()}"
            )
            
            for log_entry in signin_logs:
                parsed_event = self.parse_azure_log(log_entry.as_dict(), 'signin')
                if parsed_event:
                    if self.nats_client:
                        await self.send_to_nats(parsed_event)
                    else:
                        self.send_via_http(parsed_event)
            
            self.logger.info("✅ Collected Azure AD logs")
            
        except Exception as e:
            self.logger.error(f"❌ Failed to collect Azure AD logs: {e}")
    
    async def collect_security_alerts(self):
        """Collect Azure Security Center alerts"""
        
        try:
            alerts = self.security_client.alerts.list()
            
            for alert in alerts:
                alert_dict = alert.as_dict()
                parsed_event = self.parse_azure_log(alert_dict, 'security')
                if parsed_event:
                    if self.nats_client:
                        await self.send_to_nats(parsed_event)
                    else:
                        self.send_via_http(parsed_event)
            
            self.logger.info("✅ Collected Azure Security Center alerts")
            
        except Exception as e:
            self.logger.error(f"❌ Failed to collect security alerts: {e}")
    
    async def collect_activity_logs(self, start_time: datetime = None, end_time: datetime = None):
        """Collect Azure Activity logs"""
        
        if not start_time:
            start_time = datetime.now() - timedelta(hours=1)
        if not end_time:
            end_time = datetime.now()
        
        try:
            # Get activity logs
            activity_logs = self.monitor_client.activity_logs.list(
                filter=f"eventTimestamp ge '{start_time.isoformat()}' and eventTimestamp le '{end_time.isoformat()}'"
            )
            
            for log_entry in activity_logs:
                parsed_event = self.parse_azure_log(log_entry.as_dict(), 'activity')
                if parsed_event:
                    if self.nats_client:
                        await self.send_to_nats(parsed_event)
                    else:
                        self.send_via_http(parsed_event)
            
            self.logger.info("✅ Collected Azure Activity logs")
            
        except Exception as e:
            self.logger.error(f"❌ Failed to collect activity logs: {e}")
    
    async def start_collection(self, collection_interval: int = 60):
        """Start continuous log collection"""
        
        # Connect to NATS
        if self.nats_url:
            await self.connect_nats()
        
        self.logger.info("🚀 Starting Azure Monitor collection")
        
        while True:
            try:
                # Collect Azure AD logs
                await self.collect_azure_ad_logs()
                
                # Collect security alerts
                await self.collect_security_alerts()
                
                # Collect activity logs
                await self.collect_activity_logs()
                
                # Wait for next collection cycle
                await asyncio.sleep(collection_interval)
                
            except KeyboardInterrupt:
                self.logger.info("🛑 Azure Monitor collection stopped")
                break
            except Exception as e:
                self.logger.error(f"❌ Collection error: {e}")
                await asyncio.sleep(10)  # Wait before retry

async def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='Azure Monitor Collector for Ultra SIEM')
    parser.add_argument('--tenant-id', help='Azure Tenant ID')
    parser.add_argument('--client-id', help='Azure Client ID')
    parser.add_argument('--client-secret', help='Azure Client Secret')
    parser.add_argument('--subscription-id', help='Azure Subscription ID')
    parser.add_argument('--nats-url', help='NATS server URL')
    parser.add_argument('--http-url', help='HTTP fallback URL')
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
    collector = AzureMonitorCollector(
        tenant_id=args.tenant_id,
        client_id=args.client_id,
        client_secret=args.client_secret,
        subscription_id=args.subscription_id,
        nats_url=args.nats_url,
        http_url=args.http_url
    )
    
    # Start collection
    await collector.start_collection(collection_interval=args.interval)

if __name__ == "__main__":
    asyncio.run(main()) 