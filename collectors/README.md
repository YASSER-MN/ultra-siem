# Collectors

Scripts that read logs from a source and send them to the SIEM.

| File | Source |
|---|---|
| `syslog_collector.py` | Syslog messages |
| `firewall_collector.py` | Firewall logs |
| `windows_event_collector.ps1` | Windows event logs |
| `aws_cloudwatch_collector.py` | AWS CloudWatch logs |
| `azure_monitor_collector.py` | Azure Monitor logs |
| `gcp_logging_collector.py` | Google Cloud Logging |
| `custom_collector.py` | Template for a new source, configured with `custom_collector_config.yaml` |

The cloud collectors are prototypes. No performance figure has been measured for these scripts.
