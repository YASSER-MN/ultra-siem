use std::collections::{HashMap, HashSet};
use std::sync::{Arc, RwLock};
use std::time::{SystemTime, UNIX_EPOCH, Duration};
use serde::{Deserialize, Serialize};
use log::{info, warn, error};
use tokio::sync::{mpsc};
use uuid::Uuid;
use reqwest::Client;
use chrono::{DateTime, Utc};

use crate::error_handling::SIEMResult;
use crate::advanced_threat_detection::AdvancedThreatResult;

/// Incident severity levels
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum IncidentSeverity {
    Low,
    Medium,
    High,
    Critical,
    Emergency,
}

impl std::fmt::Display for IncidentSeverity {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            IncidentSeverity::Low => write!(f, "Low"),
            IncidentSeverity::Medium => write!(f, "Medium"),
            IncidentSeverity::High => write!(f, "High"),
            IncidentSeverity::Critical => write!(f, "Critical"),
            IncidentSeverity::Emergency => write!(f, "Emergency"),
        }
    }
}

/// Incident status
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum IncidentStatus {
    Open,
    Investigating,
    Containing,
    Resolved,
    Closed,
    FalsePositive,
}

/// Response action types
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ResponseAction {
    BlockIP { ip: String, duration_seconds: u64 },
    DisableAccount { user_id: String, reason: String },
    QuarantineFile { file_path: String, hash: String },
    KillProcess { process_id: u32, reason: String },
    RestartService { service_name: String },
    SendEmail { to: Vec<String>, subject: String, body: String },
    WebhookNotification { url: String, payload: serde_json::Value },
    GrafanaAlert { dashboard_id: String, panel_id: String },
    CustomScript { script_path: String, args: Vec<String> },
    LogOnly { message: String },
}

/// Response action result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResponseActionResult {
    pub action_id: String,
    pub action_type: ResponseAction,
    pub success: bool,
    pub error_message: Option<String>,
    pub execution_time_ms: u64,
    pub timestamp: u64,
    pub metadata: HashMap<String, String>,
}

/// Incident structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Incident {
    pub id: String,
    pub timestamp: u64,
    pub severity: IncidentSeverity,
    pub status: IncidentStatus,
    pub title: String,
    pub description: String,
    pub source_ip: String,
    pub destination_ip: String,
    pub user_id: String,
    pub threat_id: String,
    pub threat_result: AdvancedThreatResult,
    pub response_actions: Vec<ResponseActionResult>,
    pub assigned_to: Option<String>,
    pub notes: Vec<String>,
    pub tags: HashSet<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub resolved_at: Option<DateTime<Utc>>,
    pub false_positive: bool,
    pub escalation_level: u8,
    pub sla_deadline: Option<DateTime<Utc>>,
}

/// Alert configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AlertConfig {
    pub email_enabled: bool,
    pub email_smtp_server: String,
    pub email_smtp_port: u16,
    pub email_username: String,
    pub email_password: String,
    pub email_from: String,
    pub email_to: Vec<String>,
    pub webhook_enabled: bool,
    pub webhook_urls: Vec<String>,
    pub grafana_enabled: bool,
    pub grafana_url: String,
    pub grafana_api_key: String,
    pub slack_enabled: bool,
    pub slack_webhook_url: String,
    pub teams_enabled: bool,
    pub teams_webhook_url: String,
    pub pagerduty_enabled: bool,
    pub pagerduty_api_key: String,
    pub pagerduty_service_id: String,
}

/// Response rule configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResponseRule {
    pub id: String,
    pub name: String,
    pub description: String,
    pub enabled: bool,
    pub conditions: Vec<ResponseCondition>,
    pub actions: Vec<ResponseAction>,
    pub priority: u8,
    pub cooldown_seconds: u64,
    pub last_triggered: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResponseCondition {
    pub field: String,
    pub operator: String,
    pub value: String,
    pub case_sensitive: bool,
}

/// SOAR integration configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SOARConfig {
    pub enabled: bool,
    pub platform: String, // "splunk_phantom", "demisto", "swimlane", "custom"
    pub api_url: String,
    pub api_key: String,
    pub timeout_seconds: u64,
    pub retry_attempts: u32,
    pub custom_headers: HashMap<String, String>,
}

/// Incident Response Engine
#[derive(Debug)]
pub struct IncidentResponseEngine {
    config: AlertConfig,
    soar_config: SOARConfig,
    response_rules: Arc<RwLock<HashMap<String, ResponseRule>>>,
    incidents: Arc<RwLock<HashMap<String, Incident>>>,
    blocked_ips: Arc<RwLock<HashMap<String, u64>>>,
    disabled_accounts: Arc<RwLock<HashMap<String, u64>>>,
    http_client: Client,
    alert_tx: mpsc::Sender<AlertMessage>,
    alert_rx: mpsc::Receiver<AlertMessage>,
    response_tx: mpsc::Sender<ResponseMessage>,
    response_rx: mpsc::Receiver<ResponseMessage>,
    performance_metrics: Arc<RwLock<HashMap<String, f64>>>,
    incident_counter: Arc<RwLock<u64>>,
}

/// Alert message for internal communication
#[derive(Debug)]
pub struct AlertMessage {
    pub id: Uuid,
    pub severity: IncidentSeverity,
    pub message: String,
    pub timestamp: DateTime<Utc>,
}

#[derive(Debug)]
pub enum AlertChannel {
    Email,
    Webhook,
    Grafana,
    Slack,
    Teams,
    PagerDuty,
    Custom { url: String },
}

/// Response message for internal communication
#[derive(Debug)]
pub struct ResponseMessage {
    pub incident_id: String,
    pub action: ResponseAction,
}

impl IncidentResponseEngine {
    /// Create a new incident response engine
    pub fn new(config: AlertConfig, soar_config: SOARConfig) -> Self {
        let (alert_tx, alert_rx) = mpsc::channel(1000);
        let (response_tx, response_rx) = mpsc::channel(1000);
        
        let http_client = Client::builder()
            .timeout(Duration::from_secs(30))
            .build()
            .unwrap_or_else(|_| Client::new());
        
        Self {
            config,
            soar_config,
            response_rules: Arc::new(RwLock::new(HashMap::new())),
            incidents: Arc::new(RwLock::new(HashMap::new())),
            blocked_ips: Arc::new(RwLock::new(HashMap::new())),
            disabled_accounts: Arc::new(RwLock::new(HashMap::new())),
            http_client,
            alert_tx,
            alert_rx,
            response_tx,
            response_rx,
            performance_metrics: Arc::new(RwLock::new(HashMap::new())),
            incident_counter: Arc::new(RwLock::new(0)),
        }
    }

    /// Start the incident response engine
    pub async fn start(&mut self) -> SIEMResult<()> {
        info!("🚀 Starting Ultra SIEM Incident Response Engine...");
        
        // Initialize default response rules
        self.initialize_default_rules()?;
        
        // Start alert processing
        let mut alert_rx = std::mem::replace(&mut self.alert_rx, tokio::sync::mpsc::channel(1000).1);
        tokio::spawn(async move {
            Self::process_alerts(&mut alert_rx).await;
        });
        
        // Start response processing
        let mut response_rx = std::mem::replace(&mut self.response_rx, tokio::sync::mpsc::channel(1000).1);
        tokio::spawn(async move {
            Self::process_responses(&mut response_rx).await;
        });
        
        info!("✅ Incident Response Engine started successfully!");
        Ok(())
    }

    /// Process a threat and create incident response
    pub async fn process_threat(&self, threat: AdvancedThreatResult) -> SIEMResult<Incident> {
        let start_time = std::time::Instant::now();
        
        // Create incident from threat
        let incident = self.create_incident_from_threat(threat).await?;
        
        // Evaluate response rules
        let actions = self.evaluate_response_rules(&incident).await?;
        
        // Execute response actions
        let action_results = self.execute_response_actions(&incident, actions).await?;
        
        // Update incident with action results
        let mut updated_incident = incident.clone();
        updated_incident.response_actions = action_results;
        
        // Store incident
        {
            let mut incidents = self.incidents.write().unwrap();
            incidents.insert(incident.id.clone(), updated_incident.clone());
        }
        
        // Send alerts
        self.send_alerts(&updated_incident).await?;
        
        // Record performance metrics
        let processing_time = start_time.elapsed().as_millis() as f64;
        self.record_metric("incident_processing_time_ms", processing_time);
        
        info!("🚨 Incident {} created and processed in {:.2}ms", incident.id, processing_time);
        
        Ok(updated_incident)
    }

    /// Create incident from threat result
    async fn create_incident_from_threat(&self, threat: AdvancedThreatResult) -> SIEMResult<Incident> {
        let incident_id = Uuid::new_v4().to_string();
        let timestamp = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
        let now = Utc::now();
        
        // Determine incident severity
        let severity = match threat.severity {
            crate::threat_detection::ThreatSeverity::Low => IncidentSeverity::Low,
            crate::threat_detection::ThreatSeverity::Medium => IncidentSeverity::Medium,
            crate::threat_detection::ThreatSeverity::High => IncidentSeverity::High,
            crate::threat_detection::ThreatSeverity::Critical => IncidentSeverity::Critical,
        };
        
        // Calculate escalation level
        let escalation_level = match severity {
            IncidentSeverity::Low => 1,
            IncidentSeverity::Medium => 2,
            IncidentSeverity::High => 3,
            IncidentSeverity::Critical => 4,
            IncidentSeverity::Emergency => 5,
        };
        
        // Calculate SLA deadline
        let sla_deadline = match severity {
            IncidentSeverity::Low => Some(now + chrono::Duration::hours(24)),
            IncidentSeverity::Medium => Some(now + chrono::Duration::hours(8)),
            IncidentSeverity::High => Some(now + chrono::Duration::hours(2)),
            IncidentSeverity::Critical => Some(now + chrono::Duration::minutes(30)),
            IncidentSeverity::Emergency => Some(now + chrono::Duration::minutes(15)),
        };
        
        // Increment incident counter
        {
            let mut counter = self.incident_counter.write().unwrap();
            *counter += 1;
        }
        
        Ok(Incident {
            id: incident_id,
            timestamp,
            severity,
            status: IncidentStatus::Open,
            title: format!("{} - {}", threat.category, threat.description),
            description: threat.description.clone(),
            source_ip: threat.source_ip.clone(),
            destination_ip: threat.destination_ip.clone(),
            user_id: threat.user_id.clone(),
            threat_id: threat.threat_id.clone(),
            threat_result: threat,
            response_actions: Vec::new(),
            assigned_to: None,
            notes: Vec::new(),
            tags: HashSet::new(),
            created_at: now,
            updated_at: now,
            resolved_at: None,
            false_positive: false,
            escalation_level,
            sla_deadline,
        })
    }

    /// Evaluate response rules for an incident
    async fn evaluate_response_rules(&self, incident: &Incident) -> SIEMResult<Vec<ResponseAction>> {
        let mut actions = Vec::new();
        let rules = self.response_rules.read().unwrap();
        
        for rule in rules.values() {
            if !rule.enabled {
                continue;
            }
            
            // Check cooldown
            if let Some(last_triggered) = rule.last_triggered {
                let time_since = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs() - last_triggered;
                if time_since < rule.cooldown_seconds {
                    continue;
                }
            }
            
            // Check conditions
            if self.evaluate_rule_conditions(rule, incident) {
                actions.extend(rule.actions.clone());
            }
        }
        
        Ok(actions)
    }

    /// Evaluate rule conditions
    fn evaluate_rule_conditions(&self, rule: &ResponseRule, incident: &Incident) -> bool {
        for condition in &rule.conditions {
            let field_value = match condition.field.as_str() {
                "severity" => incident.severity.to_string(),
                "source_ip" => incident.source_ip.clone(),
                "user_id" => incident.user_id.clone(),
                "category" => incident.threat_result.category.to_string(),
                "confidence" => incident.threat_result.confidence.to_string(),
                _ => continue,
            };
            
            let condition_value = if condition.case_sensitive {
                condition.value.clone()
            } else {
                condition.value.to_lowercase()
            };
            
            let field_value = if condition.case_sensitive {
                field_value
            } else {
                field_value.to_lowercase()
            };
            
            let matches = match condition.operator.as_str() {
                "equals" => field_value == condition_value,
                "contains" => field_value.contains(&condition_value),
                "starts_with" => field_value.starts_with(&condition_value),
                "ends_with" => field_value.ends_with(&condition_value),
                "greater_than" => {
                    if let (Ok(field_num), Ok(condition_num)) = (field_value.parse::<f64>(), condition_value.parse::<f64>()) {
                        field_num > condition_num
                    } else {
                        false
                    }
                }
                "less_than" => {
                    if let (Ok(field_num), Ok(condition_num)) = (field_value.parse::<f64>(), condition_value.parse::<f64>()) {
                        field_num < condition_num
                    } else {
                        false
                    }
                }
                _ => false,
            };
            
            if !matches {
                return false;
            }
        }
        
        true
    }

    /// Execute response actions
    async fn execute_response_actions(&self, incident: &Incident, actions: Vec<ResponseAction>) -> SIEMResult<Vec<ResponseActionResult>> {
        let mut results = Vec::new();
        
        for action in actions {
            let start_time = std::time::Instant::now();
            let action_id = Uuid::new_v4().to_string();
            
            let result = match &action {
                ResponseAction::BlockIP { ip, duration_seconds } => {
                    self.block_ip(ip, *duration_seconds).await
                }
                ResponseAction::DisableAccount { user_id, reason } => {
                    self.disable_account(user_id, reason).await
                }
                ResponseAction::QuarantineFile { file_path, hash } => {
                    self.quarantine_file(file_path, hash).await
                }
                ResponseAction::KillProcess { process_id, reason } => {
                    self.kill_process(*process_id, reason).await
                }
                ResponseAction::RestartService { service_name } => {
                    self.restart_service(service_name).await
                }
                ResponseAction::SendEmail { to, subject, body } => {
                    self.send_email(to, subject, body).await
                }
                ResponseAction::WebhookNotification { url, payload } => {
                    self.send_webhook(url, payload).await
                }
                ResponseAction::GrafanaAlert { dashboard_id, panel_id } => {
                    self.send_grafana_alert(dashboard_id, panel_id, incident).await
                }
                ResponseAction::CustomScript { script_path, args } => {
                    self.execute_custom_script(script_path, args).await
                }
                ResponseAction::LogOnly { message } => {
                    self.log_only(message).await
                }
            };
            
            let execution_time = start_time.elapsed().as_millis() as u64;
            
            let action_result = ResponseActionResult {
                action_id,
                action_type: action,
                success: result.is_ok(),
                error_message: result.err().map(|e| e.to_string()),
                execution_time_ms: execution_time,
                timestamp: SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs(),
                metadata: HashMap::new(),
            };
            
            results.push(action_result);
        }
        
        Ok(results)
    }

    /// Block IP address
    async fn block_ip(&self, ip: &str, duration_seconds: u64) -> SIEMResult<()> {
        let expiry_time = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs() + duration_seconds;
        
        {
            let mut blocked_ips = self.blocked_ips.write().unwrap();
            blocked_ips.insert(ip.to_string(), expiry_time);
        }
        
        // Execute actual blocking (platform-specific)
        if cfg!(target_os = "windows") {
            self.block_ip_windows(ip).await?;
        } else {
            self.block_ip_linux(ip).await?;
        }
        
        info!("🚫 Blocked IP {} for {} seconds", ip, duration_seconds);
        Ok(())
    }

    /// Block IP on Windows
    async fn block_ip_windows(&self, ip: &str) -> SIEMResult<()> {
        // Use Windows Firewall or netsh
        let output = tokio::process::Command::new("netsh")
            .args(&["advfirewall", "firewall", "add", "rule", 
                   &format!("name=UltraSIEM-Block-{}", ip),
                   "dir=in", "action=block", &format!("remoteip={}", ip)])
            .output()
            .await?;
        
        if !output.status.success() {
            return Err(format!("Failed to block IP {}: {}", ip, String::from_utf8_lossy(&output.stderr)).into());
        }
        
        Ok(())
    }

    /// Block IP on Linux
    async fn block_ip_linux(&self, ip: &str) -> SIEMResult<()> {
        // Use iptables
        let output = tokio::process::Command::new("iptables")
            .args(&["-A", "INPUT", "-s", ip, "-j", "DROP"])
            .output()
            .await?;
        
        if !output.status.success() {
            return Err(format!("Failed to block IP {}: {}", ip, String::from_utf8_lossy(&output.stderr)).into());
        }
        
        Ok(())
    }

    /// Disable user account
    async fn disable_account(&self, user_id: &str, reason: &str) -> SIEMResult<()> {
        let expiry_time = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs() + 3600; // 1 hour
        
        {
            let mut disabled_accounts = self.disabled_accounts.write().unwrap();
            disabled_accounts.insert(user_id.to_string(), expiry_time);
        }
        
        // Execute actual account disable (platform-specific)
        if cfg!(target_os = "windows") {
            self.disable_account_windows(user_id).await?;
        } else {
            self.disable_account_linux(user_id).await?;
        }
        
        info!("🔒 Disabled account {}: {}", user_id, reason);
        Ok(())
    }

    /// Disable account on Windows
    async fn disable_account_windows(&self, user_id: &str) -> SIEMResult<()> {
        let output = tokio::process::Command::new("net")
            .args(&["user", user_id, "/active:no"])
            .output()
            .await?;
        
        if !output.status.success() {
            return Err(format!("Failed to disable account {}: {}", user_id, String::from_utf8_lossy(&output.stderr)).into());
        }
        
        Ok(())
    }

    /// Disable account on Linux
    async fn disable_account_linux(&self, user_id: &str) -> SIEMResult<()> {
        let output = tokio::process::Command::new("usermod")
            .args(&["-L", user_id])
            .output()
            .await?;
        
        if !output.status.success() {
            return Err(format!("Failed to disable account {}: {}", user_id, String::from_utf8_lossy(&output.stderr)).into());
        }
        
        Ok(())
    }

    /// Quarantine file
    async fn quarantine_file(&self, file_path: &str, hash: &str) -> SIEMResult<()> {
        // Create quarantine directory
        let quarantine_dir = "/tmp/ultra_siem_quarantine";
        tokio::fs::create_dir_all(quarantine_dir).await?;
        
        // Move file to quarantine
        let quarantine_path = format!("{}/{}", quarantine_dir, hash);
        tokio::fs::rename(file_path, &quarantine_path).await?;
        
        info!("📁 Quarantined file {} to {}", file_path, quarantine_path);
        Ok(())
    }

    /// Kill process
    async fn kill_process(&self, process_id: u32, reason: &str) -> SIEMResult<()> {
        let output = tokio::process::Command::new("kill")
            .args(&["-9", &process_id.to_string()])
            .output()
            .await?;
        
        if !output.status.success() {
            return Err(format!("Failed to kill process {}: {}", process_id, String::from_utf8_lossy(&output.stderr)).into());
        }
        
        info!("💀 Killed process {}: {}", process_id, reason);
        Ok(())
    }

    /// Restart service
    async fn restart_service(&self, service_name: &str) -> SIEMResult<()> {
        let output = tokio::process::Command::new("systemctl")
            .args(&["restart", service_name])
            .output()
            .await?;
        
        if !output.status.success() {
            return Err(format!("Failed to restart service {}: {}", service_name, String::from_utf8_lossy(&output.stderr)).into());
        }
        
        info!("🔄 Restarted service {}", service_name);
        Ok(())
    }

    /// Send email alert
    async fn send_email(&self, to: &[String], subject: &str, body: &str) -> SIEMResult<()> {
        if !self.config.email_enabled {
            return Ok(());
        }
        
        // In a real implementation, you would use a proper email library
        // For now, we'll simulate email sending
        info!("📧 Email alert sent to {:?}: {}", to, subject);
        info!("Email body: {}", body);
        
        Ok(())
    }

    /// Send webhook notification
    async fn send_webhook(&self, url: &str, payload: &serde_json::Value) -> SIEMResult<()> {
        let response = self.http_client
            .post(url)
            .json(payload)
            .send()
            .await?;
        
        if !response.status().is_success() {
            return Err(format!("Webhook failed with status: {}", response.status()).into());
        }
        
        info!("🔗 Webhook sent to {}", url);
        Ok(())
    }

    /// Send Grafana alert
    async fn send_grafana_alert(&self, dashboard_id: &str, panel_id: &str, incident: &Incident) -> SIEMResult<()> {
        if !self.config.grafana_enabled {
            return Ok(());
        }
        
        let alert_payload = serde_json::json!({
            "dashboardId": dashboard_id,
            "panelId": panel_id,
            "title": incident.title,
            "message": incident.description,
            "severity": incident.severity.to_string(),
            "timestamp": incident.timestamp,
            "source_ip": incident.source_ip,
            "user_id": incident.user_id,
        });
        
        let url = format!("{}/api/alerts", self.config.grafana_url);
        let response = self.http_client
            .post(&url)
            .header("Authorization", format!("Bearer {}", self.config.grafana_api_key))
            .json(&alert_payload)
            .send()
            .await?;
        
        if !response.status().is_success() {
            return Err(format!("Grafana alert failed with status: {}", response.status()).into());
        }
        
        info!("📊 Grafana alert sent for incident {}", incident.id);
        Ok(())
    }

    /// Execute custom script
    async fn execute_custom_script(&self, script_path: &str, args: &[String]) -> SIEMResult<()> {
        let output = tokio::process::Command::new(script_path)
            .args(args)
            .output()
            .await?;
        
        if !output.status.success() {
            return Err(format!("Custom script failed: {}", String::from_utf8_lossy(&output.stderr)).into());
        }
        
        info!("📜 Custom script executed: {} {:?}", script_path, args);
        Ok(())
    }

    /// Log only action
    async fn log_only(&self, message: &str) -> SIEMResult<()> {
        info!("📝 Log only action: {}", message);
        Ok(())
    }

    /// Send alerts for incident
    async fn send_alerts(&self, incident: &Incident) -> SIEMResult<()> {
        let alert_message = AlertMessage {
            id: Uuid::new_v4(),
            severity: incident.severity.clone(),
            message: incident.description.clone(),
            timestamp: Utc::now(),
        };
        
        let _ = self.alert_tx.send(alert_message).await;
        
        Ok(())
    }

    /// Process alerts (background task)
    async fn process_alerts(alert_rx: &mut mpsc::Receiver<AlertMessage>) {
        info!("🚨 Alert processor started");
        
        while let Some(alert) = alert_rx.recv().await {
            // Process alert through all configured channels
            Self::send_alert_to_channels(&alert).await;
        }
    }

    /// Process responses (background task)
    async fn process_responses(response_rx: &mut mpsc::Receiver<ResponseMessage>) {
        info!("🔄 Response processor started");
        
        while let Some(response) = response_rx.recv().await {
            // Process response actions
            Self::execute_response_action(&response).await;
        }
    }

    /// Send alert to all configured channels
    async fn send_alert_to_channels(alert: &AlertMessage) {
        // Email alerts
        if Self::should_send_email_alert(alert) {
            if let Err(e) = Self::send_email_alert(alert).await {
                error!("Failed to send email alert: {}", e);
            }
        }

        // Webhook notifications
        if Self::should_send_webhook_alert(alert) {
            if let Err(e) = Self::send_webhook_alert(alert).await {
                error!("Failed to send webhook alert: {}", e);
            }
        }

        // Slack notifications
        if Self::should_send_slack_alert(alert) {
            if let Err(e) = Self::send_slack_alert(alert).await {
                error!("Failed to send Slack alert: {}", e);
            }
        }

        // Teams notifications
        if Self::should_send_teams_alert(alert) {
            if let Err(e) = Self::send_teams_alert(alert).await {
                error!("Failed to send Teams alert: {}", e);
            }
        }

        // PagerDuty notifications
        if Self::should_send_pagerduty_alert(alert) {
            if let Err(e) = Self::send_pagerduty_alert(alert).await {
                error!("Failed to send PagerDuty alert: {}", e);
            }
        }
    }

    /// Execute response action
    async fn execute_response_action(response: &ResponseMessage) {
        match &response.action {
            ResponseAction::BlockIP { ip, duration_seconds } => {
                if let Err(e) = Self::block_ip_async(ip, *duration_seconds).await {
                    error!("Failed to block IP {}: {}", ip, e);
                }
            }
            ResponseAction::DisableAccount { user_id, reason } => {
                if let Err(e) = Self::disable_account_async(user_id, reason).await {
                    error!("Failed to disable account {}: {}", user_id, e);
                }
            }
            ResponseAction::QuarantineFile { file_path, hash } => {
                if let Err(e) = Self::quarantine_file_async(file_path, hash).await {
                    error!("Failed to quarantine file {}: {}", file_path, e);
                }
            }
            ResponseAction::KillProcess { process_id, reason } => {
                if let Err(e) = Self::kill_process_async(*process_id, reason).await {
                    error!("Failed to kill process {}: {}", process_id, e);
                }
            }
            ResponseAction::RestartService { service_name } => {
                if let Err(e) = Self::restart_service_async(service_name).await {
                    error!("Failed to restart service {}: {}", service_name, e);
                }
            }
            ResponseAction::CustomScript { script_path, args } => {
                if let Err(e) = Self::execute_custom_script_async(script_path, args).await {
                    error!("Failed to execute custom script {}: {}", script_path, e);
                }
            }
            _ => {
                warn!("Unsupported response action: {:?}", response.action);
            }
        }
    }

    // Async wrapper methods for response actions
    async fn block_ip_async(ip: &str, duration_seconds: u64) -> SIEMResult<()> {
        // Implementation would use the existing block_ip method
        info!("🛡️ Blocking IP {} for {} seconds", ip, duration_seconds);
        Ok(())
    }

    async fn disable_account_async(user_id: &str, reason: &str) -> SIEMResult<()> {
        info!("🔒 Disabling account {}: {}", user_id, reason);
        Ok(())
    }

    async fn quarantine_file_async(file_path: &str, hash: &str) -> SIEMResult<()> {
        info!("📁 Quarantining file {} (hash: {})", file_path, hash);
        Ok(())
    }

    async fn kill_process_async(process_id: u32, reason: &str) -> SIEMResult<()> {
        info!("💀 Killing process {}: {}", process_id, reason);
        Ok(())
    }

    async fn restart_service_async(service_name: &str) -> SIEMResult<()> {
        info!("🔄 Restarting service: {}", service_name);
        Ok(())
    }

    async fn execute_custom_script_async(script_path: &str, args: &[String]) -> SIEMResult<()> {
        info!("📜 Executing custom script: {} {:?}", script_path, args);
        Ok(())
    }

    // Alert channel decision methods
    fn should_send_email_alert(alert: &AlertMessage) -> bool {
        alert.severity >= IncidentSeverity::Medium
    }

    fn should_send_webhook_alert(alert: &AlertMessage) -> bool {
        alert.severity >= IncidentSeverity::High
    }

    fn should_send_slack_alert(alert: &AlertMessage) -> bool {
        alert.severity >= IncidentSeverity::Medium
    }

    fn should_send_teams_alert(alert: &AlertMessage) -> bool {
        alert.severity >= IncidentSeverity::High
    }

    fn should_send_pagerduty_alert(alert: &AlertMessage) -> bool {
        alert.severity >= IncidentSeverity::Critical
    }

    // Alert sending methods
    async fn send_email_alert(alert: &AlertMessage) -> SIEMResult<()> {
        info!("📧 Sending email alert: {}", alert.message);
        // Email implementation would go here
        Ok(())
    }

    async fn send_webhook_alert(alert: &AlertMessage) -> SIEMResult<()> {
        info!("🌐 Sending webhook alert: {}", alert.message);
        // Webhook implementation would go here
        Ok(())
    }

    async fn send_slack_alert(alert: &AlertMessage) -> SIEMResult<()> {
        info!("💬 Sending Slack alert: {}", alert.message);
        // Slack implementation would go here
        Ok(())
    }

    async fn send_teams_alert(alert: &AlertMessage) -> SIEMResult<()> {
        info!("💼 Sending Teams alert: {}", alert.message);
        // Teams implementation would go here
        Ok(())
    }

    async fn send_pagerduty_alert(alert: &AlertMessage) -> SIEMResult<()> {
        info!("🚨 Sending PagerDuty alert: {}", alert.message);
        // PagerDuty implementation would go here
        Ok(())
    }

    /// Initialize default response rules
    fn initialize_default_rules(&self) -> SIEMResult<()> {
        let mut rules = self.response_rules.write().unwrap();
        // Add a default rule if none exist
        if rules.is_empty() {
            rules.insert(
                "default_high_severity_log".to_string(),
                ResponseRule {
                    id: "default_high_severity_log".to_string(),
                    name: "Log High Severity Incidents".to_string(),
                    description: "Log all high severity incidents for audit.".to_string(),
                    enabled: true,
                    conditions: vec![ResponseCondition {
                        field: "severity".to_string(),
                        operator: "equals".to_string(),
                        value: "High".to_string(),
                        case_sensitive: false,
                    }],
                    actions: vec![ResponseAction::LogOnly { message: "High severity incident logged".to_string() }],
                    priority: 1,
                    cooldown_seconds: 0,
                    last_triggered: None,
                },
            );
        }
        Ok(())
    }

    /// Record performance metric
    fn record_metric(&self, metric: &str, value: f64) {
        let mut metrics = self.performance_metrics.write().unwrap();
        metrics.insert(metric.to_string(), value);
    }

    /// Get performance metrics
    pub fn get_performance_metrics(&self) -> HashMap<String, f64> {
        self.performance_metrics.read().unwrap().clone()
    }

    /// Get incident statistics
    pub fn get_incident_stats(&self) -> HashMap<String, u64> {
        let incidents = self.incidents.read().unwrap();
        let total_incidents = incidents.len() as u64;
        let mut stats = HashMap::new();
        stats.insert("total_incidents".to_string(), total_incidents);
        stats
    }

    /// Store an incident in the engine's internal storage
    pub fn store_incident(&self, incident: Incident) {
        self.incidents.write().unwrap().insert(incident.id.clone(), incident);
    }

    /// Clean up expired blocks and disabled accounts
    pub async fn cleanup_expired_items(&self) -> SIEMResult<()> {
        let current_time = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
        
        // Clean up expired IP blocks
        {
            let mut blocked_ips = self.blocked_ips.write().unwrap();
            blocked_ips.retain(|_, expiry_time| *expiry_time > current_time);
        }
        
        // Clean up expired account disables
        {
            let mut disabled_accounts = self.disabled_accounts.write().unwrap();
            disabled_accounts.retain(|_, expiry_time| *expiry_time > current_time);
        }
        
        info!("🧹 Cleaned up expired blocks and disabled accounts");
        Ok(())
    }

    /// Execute SOAR playbook
    pub async fn execute_soar_playbook(&self, playbook_name: &str, incident: &Incident) -> SIEMResult<()> {
        if !self.soar_config.enabled {
            return Err("SOAR integration not enabled".to_string().into());
        }

        let playbook_payload = serde_json::json!({
            "playbook": playbook_name,
            "incident": {
                "id": incident.id,
                "severity": incident.severity,
                "source_ip": incident.source_ip,
                "description": incident.description,
                "timestamp": incident.timestamp,
            }
        });

        let response = self.http_client
            .post(&format!("{}/playbooks/execute", self.soar_config.api_url))
            .header("Authorization", format!("Bearer {}", self.soar_config.api_key))
            .json(&playbook_payload)
            .timeout(Duration::from_secs(self.soar_config.timeout_seconds))
            .send()
            .await?;

        if !response.status().is_success() {
            return Err(format!("SOAR playbook execution failed: {}", response.status()).into());
        }

        info!("🎭 SOAR playbook '{}' executed successfully for incident {}", playbook_name, incident.id);
        Ok(())
    }

    /// Update incident status
    pub async fn update_incident_status(&self, incident_id: &str, status: IncidentStatus) -> SIEMResult<()> {
        let mut incidents = self.incidents.write().unwrap();
        
        if let Some(incident) = incidents.get_mut(incident_id) {
            let status_clone = status.clone();
            incident.status = status;
            incident.updated_at = Utc::now();
            
            if status_clone == IncidentStatus::Resolved {
                incident.resolved_at = Some(Utc::now());
            }
            
            info!("📝 Updated incident {} status to {:?}", incident_id, status_clone);
            Ok(())
        } else {
            Err(format!("Incident {} not found", incident_id).into())
        }
    }

    /// Add note to incident
    pub async fn add_incident_note(&self, incident_id: &str, note: String) -> SIEMResult<()> {
        let mut incidents = self.incidents.write().unwrap();
        
        if let Some(incident) = incidents.get_mut(incident_id) {
            incident.notes.push(note.clone());
            incident.updated_at = Utc::now();
            
            info!("📝 Added note to incident {}: {}", incident_id, note);
            Ok(())
        } else {
            Err(format!("Incident {} not found", incident_id).into())
        }
    }

    /// Assign incident to user
    pub async fn assign_incident(&self, incident_id: &str, assigned_to: String) -> SIEMResult<()> {
        let mut incidents = self.incidents.write().unwrap();
        
        if let Some(incident) = incidents.get_mut(incident_id) {
            incident.assigned_to = Some(assigned_to.clone());
            incident.updated_at = Utc::now();
            
            info!("👤 Assigned incident {} to {}", incident_id, assigned_to);
            Ok(())
        } else {
            Err(format!("Incident {} not found", incident_id).into())
        }
    }

    /// Mark incident as false positive
    pub async fn mark_false_positive(&self, incident_id: &str, reason: String) -> SIEMResult<()> {
        let mut incidents = self.incidents.write().unwrap();
        
        if let Some(incident) = incidents.get_mut(incident_id) {
            incident.false_positive = true;
            incident.status = IncidentStatus::FalsePositive;
            incident.notes.push(format!("Marked as false positive: {}", reason));
            incident.updated_at = Utc::now();
            
            info!("❌ Marked incident {} as false positive: {}", incident_id, reason);
            Ok(())
        } else {
            Err(format!("Incident {} not found", incident_id).into())
        }
    }

    /// Get incident by ID
    pub fn get_incident(&self, incident_id: &str) -> Option<Incident> {
        self.incidents.read().unwrap().get(incident_id).cloned()
    }

    /// Get all incidents
    pub fn get_all_incidents(&self) -> Vec<Incident> {
        self.incidents.read().unwrap().values().cloned().collect()
    }

    /// Get incidents by status
    pub fn get_incidents_by_status(&self, status: IncidentStatus) -> Vec<Incident> {
        self.incidents.read().unwrap()
            .values()
            .filter(|incident| incident.status == status)
            .cloned()
            .collect()
    }

    /// Get incidents by severity
    pub fn get_incidents_by_severity(&self, severity: IncidentSeverity) -> Vec<Incident> {
        self.incidents.read().unwrap()
            .values()
            .filter(|incident| incident.severity == severity)
            .cloned()
            .collect()
    }

    /// Search incidents
    pub fn search_incidents(&self, query: &str) -> Vec<Incident> {
        let query_lower = query.to_lowercase();
        self.incidents.read().unwrap()
            .values()
            .filter(|incident| {
                incident.title.to_lowercase().contains(&query_lower) ||
                incident.description.to_lowercase().contains(&query_lower) ||
                incident.source_ip.contains(&query) ||
                incident.user_id.to_lowercase().contains(&query_lower)
            })
            .cloned()
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::advanced_threat_detection::AdvancedThreatResult;
    use crate::threat_detection::{ThreatSeverity, ThreatCategory};

    #[tokio::test]
    async fn test_incident_response_engine() {
        let config = AlertConfig {
            email_enabled: false,
            email_smtp_server: "".to_string(),
            email_smtp_port: 587,
            email_username: "".to_string(),
            email_password: "".to_string(),
            email_from: "".to_string(),
            email_to: vec![],
            webhook_enabled: false,
            webhook_urls: vec![],
            grafana_enabled: false,
            grafana_url: "".to_string(),
            grafana_api_key: "".to_string(),
            slack_enabled: false,
            slack_webhook_url: "".to_string(),
            teams_enabled: false,
            teams_webhook_url: "".to_string(),
            pagerduty_enabled: false,
            pagerduty_api_key: "".to_string(),
            pagerduty_service_id: "".to_string(),
        };
        
        let soar_config = SOARConfig {
            enabled: false,
            platform: "".to_string(),
            api_url: "".to_string(),
            api_key: "".to_string(),
            timeout_seconds: 30,
            retry_attempts: 3,
            custom_headers: HashMap::new(),
        };
        
        let mut engine = IncidentResponseEngine::new(config, soar_config);
        engine.start().await.unwrap();
        
        let threat = AdvancedThreatResult {
            threat_id: "test_threat".to_string(),
            timestamp: 1640995200,
            severity: ThreatSeverity::Critical,
            category: ThreatCategory::BruteForce,
            confidence: 0.9,
            detection_method: "signature".to_string(),
            source_ip: "192.168.1.100".to_string(),
            destination_ip: "10.0.0.1".to_string(),
            user_id: "test_user".to_string(),
            description: "Test threat".to_string(),
            iocs: vec![],
            signatures: vec![],
            behavioral_context: None,
            correlation_events: vec![],
            false_positive_probability: 0.1,
            gpu_processing_time_ms: 1.0,
            details: HashMap::new(),
        };
        
        let incident = engine.process_threat(threat).await.unwrap();
        assert_eq!(incident.severity, IncidentSeverity::Critical);
        assert_eq!(incident.status, IncidentStatus::Open);
    }

    #[test]
    fn test_response_rule_evaluation() {
        let config = AlertConfig {
            email_enabled: false,
            email_smtp_server: "".to_string(),
            email_smtp_port: 587,
            email_username: "".to_string(),
            email_password: "".to_string(),
            email_from: "".to_string(),
            email_to: vec![],
            webhook_enabled: false,
            webhook_urls: vec![],
            grafana_enabled: false,
            grafana_url: "".to_string(),
            grafana_api_key: "".to_string(),
            slack_enabled: false,
            slack_webhook_url: "".to_string(),
            teams_enabled: false,
            teams_webhook_url: "".to_string(),
            pagerduty_enabled: false,
            pagerduty_api_key: "".to_string(),
            pagerduty_service_id: "".to_string(),
        };
        
        let soar_config = SOARConfig {
            enabled: false,
            platform: "".to_string(),
            api_url: "".to_string(),
            api_key: "".to_string(),
            timeout_seconds: 30,
            retry_attempts: 3,
            custom_headers: HashMap::new(),
        };
        
        let engine = IncidentResponseEngine::new(config, soar_config);
        // Insert a default rule for the test
        engine.response_rules.write().unwrap().insert(
            "test_critical_severity_log".to_string(),
            ResponseRule {
                id: "test_critical_severity_log".to_string(),
                name: "Log Critical Severity Incidents".to_string(),
                description: "Log all critical severity incidents for audit.".to_string(),
                enabled: true,
                conditions: vec![ResponseCondition {
                    field: "severity".to_string(),
                    operator: "equals".to_string(),
                    value: "Critical".to_string(),
                    case_sensitive: false,
                }],
                actions: vec![ResponseAction::LogOnly { message: "Critical severity incident logged".to_string() }],
                priority: 1,
                cooldown_seconds: 0,
                last_triggered: None,
            },
        );
        
        let threat = AdvancedThreatResult {
            threat_id: "test_threat".to_string(),
            timestamp: 1640995200,
            severity: ThreatSeverity::Critical,
            category: ThreatCategory::BruteForce,
            confidence: 0.9,
            detection_method: "signature".to_string(),
            source_ip: "192.168.1.100".to_string(),
            destination_ip: "10.0.0.1".to_string(),
            user_id: "test_user".to_string(),
            description: "Test threat".to_string(),
            iocs: vec![],
            signatures: vec![],
            behavioral_context: None,
            correlation_events: vec![],
            false_positive_probability: 0.1,
            gpu_processing_time_ms: 1.0,
            details: HashMap::new(),
        };
        
        let incident = tokio::runtime::Runtime::new().unwrap().block_on(async {
            engine.create_incident_from_threat(threat).await.unwrap()
        });
        
        let actions = tokio::runtime::Runtime::new().unwrap().block_on(async {
            engine.evaluate_response_rules(&incident).await.unwrap()
        });
        
        assert!(!actions.is_empty());
    }
} 