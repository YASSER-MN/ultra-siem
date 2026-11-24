use std::collections::{HashMap, HashSet};
use std::sync::{Arc, RwLock};
use std::time::SystemTime;
use std::fmt;
use serde::{Deserialize, Serialize};
use log::{info, error, debug};
use crate::error_handling::{SIEMResult, time};
use futures_util::StreamExt;
use async_nats::Client;
use uuid::Uuid;
use chrono::{DateTime, Utc};
use regex::Regex;

/// Threat severity levels
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum ThreatSeverity {
    Low,
    Medium,
    High,
    Critical,
}

impl fmt::Display for ThreatSeverity {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ThreatSeverity::Low => write!(f, "Low"),
            ThreatSeverity::Medium => write!(f, "Medium"),
            ThreatSeverity::High => write!(f, "High"),
            ThreatSeverity::Critical => write!(f, "Critical"),
        }
    }
}

/// Threat categories
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum ThreatCategory {
    Malware,
    Network,
    Authentication,
    Compliance,
    SQLInjection,
    XSS,
    BruteForce,
    InsiderThreat,
    APT,
    DDoS,
    DataExfiltration,
    PrivilegeEscalation,
    LateralMovement,
    Persistence,
    Evasion,
    Other,
}

impl fmt::Display for ThreatCategory {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ThreatCategory::Malware => write!(f, "Malware"),
            ThreatCategory::Network => write!(f, "Network"),
            ThreatCategory::Authentication => write!(f, "Authentication"),
            ThreatCategory::Compliance => write!(f, "Compliance"),
            ThreatCategory::SQLInjection => write!(f, "SQLInjection"),
            ThreatCategory::XSS => write!(f, "XSS"),
            ThreatCategory::BruteForce => write!(f, "BruteForce"),
            ThreatCategory::InsiderThreat => write!(f, "InsiderThreat"),
            ThreatCategory::APT => write!(f, "APT"),
            ThreatCategory::DDoS => write!(f, "DDoS"),
            ThreatCategory::DataExfiltration => write!(f, "DataExfiltration"),
            ThreatCategory::PrivilegeEscalation => write!(f, "PrivilegeEscalation"),
            ThreatCategory::LateralMovement => write!(f, "LateralMovement"),
            ThreatCategory::Persistence => write!(f, "Persistence"),
            ThreatCategory::Evasion => write!(f, "Evasion"),
            ThreatCategory::Other => write!(f, "Other"),
        }
    }
}

/// IOC (Indicator of Compromise) structure
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct IOC {
    pub id: String,
    pub value: String,
    pub ioc_type: String,
    pub confidence: f32,
    pub source: String,
    pub first_seen: u64,
    pub last_seen: u64,
    pub tags: Vec<String>,
}

/// Signature pattern for threat detection
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SignaturePattern {
    pub id: String,
    pub name: String,
    pub pattern: String,
    pub category: ThreatCategory,
    pub severity: ThreatSeverity,
    pub description: String,
    pub enabled: bool,
    pub confidence: f32,
}

/// Behavioral context for anomaly detection
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BehavioralContext {
    pub user_id: String,
    pub source_ip: String,
    pub destination_ip: String,
    pub action: String,
    pub timestamp: u64,
    pub frequency: u32,
    pub baseline_deviation: f32,
    pub risk_score: f32,
}

/// Anomaly detection model
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnomalyModel {
    pub id: String,
    pub name: String,
    pub baseline_data: Vec<f32>,
    pub threshold: f32,
    pub sensitivity: f32,
    pub enabled: bool,
}

/// Correlation rule for threat correlation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CorrelationRule {
    pub id: String,
    pub name: String,
    pub description: String,
    pub conditions: Vec<String>,
    pub time_window: u64,
    pub severity: ThreatSeverity,
    pub enabled: bool,
}

/// Threat event structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThreatEvent {
    pub id: String,
    pub timestamp: u64,
    pub severity: ThreatSeverity,
    pub category: ThreatCategory,
    pub source_ip: String,
    pub destination_ip: String,
    pub user_id: String,
    pub description: String,
    pub confidence: f32,
    pub iocs: Vec<String>,
    pub signatures: Vec<String>,
    pub correlation_id: Option<String>,
    pub details: HashMap<String, String>,
    pub status: String,
    pub false_positive: bool,
}

/// Detection statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DetectionStats {
    pub total_threats: u64,
    pub threats_by_severity: HashMap<ThreatSeverity, u64>,
    pub threats_by_category: HashMap<ThreatCategory, u64>,
    pub false_positives: u64,
    pub detection_rate: f32,
    pub average_response_time: f64,
    pub last_updated: u64,
}

/// Ultra SIEM Threat Detection Engine
pub struct ThreatDetectionEngine {
    nats_client: Client,
    iocs: Arc<RwLock<HashMap<String, IOC>>>,
    signatures: Arc<RwLock<HashMap<String, SignaturePattern>>>,
    anomaly_models: Arc<RwLock<HashMap<String, AnomalyModel>>>,
    correlation_rules: Arc<RwLock<HashMap<String, CorrelationRule>>>,
    behavioral_contexts: Arc<RwLock<HashMap<String, BehavioralContext>>>,
    false_positive_history: Arc<RwLock<HashMap<String, u64>>>,
    stats: Arc<RwLock<DetectionStats>>,
    whitelist: Arc<RwLock<HashSet<String>>>,
    performance_metrics: Arc<RwLock<HashMap<String, f64>>>,
}

impl ThreatDetectionEngine {
    /// Create a new threat detection engine
    pub fn new(nats_client: Client) -> Self {
        Self {
            nats_client,
            iocs: Arc::new(RwLock::new(HashMap::new())),
            signatures: Arc::new(RwLock::new(HashMap::new())),
            anomaly_models: Arc::new(RwLock::new(HashMap::new())),
            correlation_rules: Arc::new(RwLock::new(HashMap::new())),
            behavioral_contexts: Arc::new(RwLock::new(HashMap::new())),
            false_positive_history: Arc::new(RwLock::new(HashMap::new())),
            stats: Arc::new(RwLock::new(DetectionStats {
                total_threats: 0,
                threats_by_severity: HashMap::new(),
                threats_by_category: HashMap::new(),
                false_positives: 0,
                detection_rate: 0.0,
                average_response_time: 0.0,
                last_updated: time::current_timestamp().unwrap_or(0),
            })),
            whitelist: Arc::new(RwLock::new(HashSet::new())),
            performance_metrics: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Start the threat detection engine
    pub async fn start(&self) -> SIEMResult<()> {
        info!("🚀 Starting Ultra SIEM Threat Detection Engine...");
        
        // Initialize default signatures and IOCs
        self.initialize_default_patterns()?;
        
        // Start event processing
        self.process_events().await?;
        
        info!("✅ Threat Detection Engine started successfully!");
        Ok(())
    }

    /// Initialize default threat patterns
    fn initialize_default_patterns(&self) -> SIEMResult<()> {
        info!("📋 Initializing default threat patterns...");
        
        // Add default signatures
        let default_signatures = vec![
            SignaturePattern {
                id: "sql_injection_1".to_string(),
                name: "SQL Injection Pattern".to_string(),
                pattern: r"(?i)(union|select|insert|update|delete|drop|create|alter).*from".to_string(),
                category: ThreatCategory::SQLInjection,
                severity: ThreatSeverity::High,
                confidence: 0.85,
                description: "Detects common SQL injection patterns".to_string(),
                enabled: true,
            },
            SignaturePattern {
                id: "xss_1".to_string(),
                name: "XSS Pattern".to_string(),
                pattern: r"(?i)<script.*?>.*?</script>|<.*?javascript:.*?>".to_string(),
                category: ThreatCategory::XSS,
                severity: ThreatSeverity::High,
                confidence: 0.90,
                description: "Detects XSS attack patterns".to_string(),
                enabled: true,
            },
            SignaturePattern {
                id: "brute_force_1".to_string(),
                name: "Brute Force Pattern".to_string(),
                pattern: r"(?i)(failed login|authentication failure|invalid credentials)".to_string(),
                category: ThreatCategory::BruteForce,
                severity: ThreatSeverity::Medium,
                confidence: 0.75,
                description: "Detects brute force attack patterns".to_string(),
                enabled: true,
            },
        ];

        for signature in default_signatures {
            self.add_signature(signature)?;
        }

        // Add default IOCs
        let default_iocs = vec![
            IOC {
                id: "malware_hash_1".to_string(),
                value: "a1b2c3d4e5f6789012345678901234567890abcd".to_string(),
                ioc_type: "hash".to_string(),
                confidence: 0.95,
                source: "threat_intel".to_string(),
                first_seen: time::current_timestamp()?,
                last_seen: time::current_timestamp()?,
                tags: vec!["malware".to_string(), "ransomware".to_string()],
            },
        ];

        for ioc in default_iocs {
            self.add_ioc(ioc)?;
        }

        info!("✅ Default patterns initialized successfully!");
        Ok(())
    }

    /// Process events from NATS
    async fn process_events(&self) -> SIEMResult<()> {
        info!("📡 Subscribing to Ultra SIEM events...");
        
        let mut sub = self.nats_client.subscribe("ultra_siem.events").await?;
        
        info!("🔄 Starting event processing loop...");
        
        while let Some(msg) = sub.next().await {
            let start_time = std::time::Instant::now();
            
            match self.process_single_event(&msg).await {
                Ok(_) => {
                    let duration = start_time.elapsed();
                    self.update_performance_metric("event_processing_time", duration.as_millis() as f64);
                }
                Err(e) => {
                    error!("❌ Error processing event: {}", e);
                }
            }
        }
        
        Ok(())
    }

    /// Process a single event
    async fn process_single_event(&self, msg: &async_nats::Message) -> SIEMResult<()> {
        let event_data = String::from_utf8_lossy(&msg.payload);
        debug!("📨 Processing event: {}", event_data);
        
        // Parse event data (simplified for demo)
        let event: serde_json::Value = serde_json::from_str(&event_data)?;
        
        // Perform threat detection
        let threats = self.detect_threats(&event).await?;
        
        // Process detected threats
        for threat in threats {
            self.handle_threat(threat).await?;
        }
        
        Ok(())
    }

    /// Detect threats in an event
    async fn detect_threats(&self, event: &serde_json::Value) -> SIEMResult<Vec<ThreatEvent>> {
        let mut threats = Vec::new();
        let timestamp = time::current_timestamp()?;
        
        // Signature-based detection
        let signature_threats = self.signature_detection(event, timestamp).await?;
        threats.extend(signature_threats);
        
        // IOC-based detection
        let ioc_threats = self.ioc_detection(event, timestamp).await?;
        threats.extend(ioc_threats);
        
        // Behavioral anomaly detection
        let anomaly_threats = self.anomaly_detection(event, timestamp).await?;
        threats.extend(anomaly_threats);
        
        // Correlation-based detection
        let correlation_threats = self.correlation_detection(&threats, timestamp).await?;
        threats.extend(correlation_threats);
        
        Ok(threats)
    }

    /// Signature-based threat detection
    async fn signature_detection(&self, event: &serde_json::Value, timestamp: u64) -> SIEMResult<Vec<ThreatEvent>> {
        let mut threats = Vec::new();
        let signatures = self.signatures.read().unwrap();
        
        let event_str = event.to_string();
        
        for signature in signatures.values() {
            if !signature.enabled {
                continue;
            }
            
            // Simple pattern matching (in production, use regex)
            if event_str.to_lowercase().contains(&signature.pattern.to_lowercase()) {
                let threat = ThreatEvent {
                    id: Uuid::new_v4().to_string(),
                    timestamp,
                    severity: signature.severity.clone(),
                    category: signature.category.clone(),
                    source_ip: event["source_ip"].as_str().unwrap_or("unknown").to_string(),
                    destination_ip: event["destination_ip"].as_str().unwrap_or("unknown").to_string(),
                    user_id: event["user_id"].as_str().unwrap_or("unknown").to_string(),
                    description: signature.description.clone(),
                    confidence: signature.confidence,
                    iocs: Vec::new(),
                    signatures: vec![signature.id.clone()],
                    correlation_id: None,
                    details: HashMap::new(),
                    status: "detected".to_string(),
                    false_positive: false,
                };
                
                threats.push(threat);
            }
        }
        
        Ok(threats)
    }

    /// IOC-based threat detection
    async fn ioc_detection(&self, event: &serde_json::Value, timestamp: u64) -> SIEMResult<Vec<ThreatEvent>> {
        let mut threats = Vec::new();
        let iocs = self.iocs.read().unwrap();
        
        let event_str = event.to_string();
        
        for ioc in iocs.values() {
            if event_str.contains(&ioc.value) {
                let threat = ThreatEvent {
                    id: Uuid::new_v4().to_string(),
                    timestamp,
                    severity: ThreatSeverity::High,
                    category: ThreatCategory::Malware,
                    source_ip: event["source_ip"].as_str().unwrap_or("unknown").to_string(),
                    destination_ip: event["destination_ip"].as_str().unwrap_or("unknown").to_string(),
                    user_id: event["user_id"].as_str().unwrap_or("unknown").to_string(),
                    description: format!("IOC detected: {}", ioc.value),
                    confidence: ioc.confidence,
                    iocs: vec![ioc.id.clone()],
                    signatures: Vec::new(),
                    correlation_id: None,
                    details: HashMap::new(),
                    status: "detected".to_string(),
                    false_positive: false,
                };
                
                threats.push(threat);
            }
        }
        
        Ok(threats)
    }

    /// Anomaly detection
    async fn anomaly_detection(&self, event: &serde_json::Value, timestamp: u64) -> SIEMResult<Vec<ThreatEvent>> {
        let mut threats = Vec::new();
        
        // Simple anomaly detection based on frequency
        let user_id = event["user_id"].as_str().unwrap_or("unknown");
        let action = event["action"].as_str().unwrap_or("unknown");
        
        let context_key = format!("{}:{}", user_id, action);
        let mut contexts = self.behavioral_contexts.write().unwrap();
        
        let context = contexts.entry(context_key.clone()).or_insert(BehavioralContext {
            user_id: user_id.to_string(),
            source_ip: event["source_ip"].as_str().unwrap_or("unknown").to_string(),
            destination_ip: event["destination_ip"].as_str().unwrap_or("unknown").to_string(),
            action: action.to_string(),
            timestamp,
            frequency: 0,
            baseline_deviation: 0.0,
            risk_score: 0.0,
        });
        
        context.frequency += 1;
        context.timestamp = timestamp;
        
        // Detect anomalies (frequency > 10 in 1 minute)
        if context.frequency > 10 {
            let threat = ThreatEvent {
                id: Uuid::new_v4().to_string(),
                timestamp,
                severity: ThreatSeverity::Medium,
                category: ThreatCategory::Other,
                source_ip: context.source_ip.clone(),
                destination_ip: context.destination_ip.clone(),
                user_id: context.user_id.clone(),
                description: format!("Anomalous behavior detected: {} actions in 1 minute", context.frequency),
                confidence: 0.7,
                iocs: Vec::new(),
                signatures: Vec::new(),
                correlation_id: None,
                details: HashMap::new(),
                status: "detected".to_string(),
                false_positive: false,
            };
            
            threats.push(threat);
        }
        
        Ok(threats)
    }

    /// Correlation-based threat detection
    async fn correlation_detection(&self, threats: &[ThreatEvent], timestamp: u64) -> SIEMResult<Vec<ThreatEvent>> {
        let mut correlated_threats = Vec::new();
        let correlation_rules = self.correlation_rules.read().unwrap();
        
        for rule in correlation_rules.values() {
            if !rule.enabled {
                continue;
            }
            
            // Simple correlation logic (in production, use more sophisticated correlation)
            let related_threats: Vec<&ThreatEvent> = threats
                .iter()
                .filter(|t| t.timestamp >= timestamp - rule.time_window)
                .collect();
            
            if related_threats.len() >= 2 {
                let threat = ThreatEvent {
                    id: Uuid::new_v4().to_string(),
                    timestamp,
                    severity: rule.severity.clone(),
                    category: ThreatCategory::Other,
                    source_ip: related_threats[0].source_ip.clone(),
                    destination_ip: related_threats[0].destination_ip.clone(),
                    user_id: related_threats[0].user_id.clone(),
                    description: rule.description.clone(),
                    confidence: 0.8,
                    iocs: Vec::new(),
                    signatures: Vec::new(),
                    correlation_id: Some(rule.id.clone()),
                    details: {
                        let mut details = HashMap::new();
                        details.insert("correlation_rule".to_string(), rule.name.clone());
                        details.insert("description".to_string(), rule.description.clone());
                        details.insert("related_threats".to_string(), related_threats.len().to_string());
                        details
                    },
                    status: "correlated".to_string(),
                    false_positive: false,
                };
                
                correlated_threats.push(threat);
            }
        }
        
        Ok(correlated_threats)
    }

    /// Handle detected threats
    async fn handle_threat(&self, threat: ThreatEvent) -> SIEMResult<()> {
        // Check whitelist
        let whitelist = self.whitelist.read().unwrap();
        if whitelist.contains(&threat.source_ip) || whitelist.contains(&threat.user_id) {
            debug!("🔄 Threat whitelisted: {}", threat.id);
            return Ok(());
        }
        
        // Check false positive history
        let false_positives = self.false_positive_history.read().unwrap();
        if false_positives.contains_key(&threat.id) {
            debug!("🔄 Threat marked as false positive: {}", threat.id);
            return Ok(());
        }
        
        // Update statistics
        self.update_threat_stats(&threat)?;
        
        // Publish threat to NATS
        self.publish_threat(&threat).await?;
        
        info!("🚨 Threat detected: {} - {} (Confidence: {:.2})", 
              threat.severity, threat.description, threat.confidence);
        
        Ok(())
    }

    /// Publish threat to NATS
    async fn publish_threat(&self, threat: &ThreatEvent) -> SIEMResult<()> {
        let serialized = serde_json::to_string(threat)?;
        self.nats_client.publish("ultra_siem.threats", serialized.into()).await?;
        Ok(())
    }

    /// Update threat statistics
    fn update_threat_stats(&self, threat: &ThreatEvent) -> SIEMResult<()> {
        let mut stats = self.stats.write().unwrap();
        
        stats.total_threats += 1;
        *stats.threats_by_severity.entry(threat.severity.clone()).or_insert(0) += 1;
        *stats.threats_by_category.entry(threat.category.clone()).or_insert(0) += 1;
        stats.last_updated = time::current_timestamp()?;
        
        Ok(())
    }

    /// Update performance metrics
    fn update_performance_metric(&self, metric: &str, value: f64) {
        let mut metrics = self.performance_metrics.write().unwrap();
        metrics.insert(metric.to_string(), value);
    }

    /// Add IOC to the detection engine
    pub fn add_ioc(&self, ioc: IOC) -> SIEMResult<()> {
        let mut iocs = self.iocs.write().unwrap();
        let ioc_value = ioc.value.clone();
        iocs.insert(ioc.id.clone(), ioc);
        info!("✅ Added IOC: {}", ioc_value);
        Ok(())
    }

    /// Add signature pattern to the detection engine
    pub fn add_signature(&self, signature: SignaturePattern) -> SIEMResult<()> {
        let mut signatures = self.signatures.write().unwrap();
        let signature_name = signature.name.clone();
        signatures.insert(signature.id.clone(), signature);
        info!("✅ Added signature: {}", signature_name);
        Ok(())
    }

    /// Mark threat as false positive
    pub fn mark_false_positive(&self, threat_id: String) -> SIEMResult<()> {
        let mut false_positives = self.false_positive_history.write().unwrap();
        let threat_id_clone = threat_id.clone();
        false_positives.insert(threat_id, time::current_timestamp()?);
        self.update_false_positive_stats();
        info!("✅ Marked threat as false positive: {}", threat_id_clone);
        Ok(())
    }

    /// Update false positive statistics
    fn update_false_positive_stats(&self) {
        let mut stats = self.stats.write().unwrap();
        let false_positives = self.false_positive_history.read().unwrap();
        stats.false_positives = false_positives.len() as u64;
        
        if stats.total_threats > 0 {
            stats.detection_rate = 1.0 - (stats.false_positives as f32 / stats.total_threats as f32);
        }
    }

    /// Get detection statistics
    pub fn get_stats(&self) -> DetectionStats {
        self.stats.read().unwrap().clone()
    }

    /// Add to whitelist
    pub fn add_to_whitelist(&self, item: String) -> SIEMResult<()> {
        let mut whitelist = self.whitelist.write().unwrap();
        whitelist.insert(item.clone());
        info!("✅ Added to whitelist: {}", item);
        Ok(())
    }

    /// Remove from whitelist
    pub fn remove_from_whitelist(&self, item: &str) -> SIEMResult<()> {
        let mut whitelist = self.whitelist.write().unwrap();
        whitelist.remove(item);
        info!("✅ Removed from whitelist: {}", item);
        Ok(())
    }

    /// Get performance metrics
    pub fn get_performance_metrics(&self) -> HashMap<String, f64> {
        self.performance_metrics.read().unwrap().clone()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use async_nats::connect;

    #[tokio::test]
    async fn test_threat_detection_engine() {
        let nats_client = connect("nats://localhost:4222").await.unwrap();
        let engine = ThreatDetectionEngine::new(nats_client);
        
        // Test IOC addition
        let ioc = IOC {
            id: "test_ioc".to_string(),
            value: "test_value".to_string(),
            ioc_type: "hash".to_string(),
            confidence: 0.9,
            source: "test".to_string(),
            first_seen: time::current_timestamp().unwrap(),
            last_seen: time::current_timestamp().unwrap(),
            tags: vec!["test".to_string()],
        };
        
        assert!(engine.add_ioc(ioc).is_ok());
        
        // Test signature addition
        let signature = SignaturePattern {
            id: "test_sig".to_string(),
            name: "Test Signature".to_string(),
            pattern: "test".to_string(),
            category: ThreatCategory::Other,
            severity: ThreatSeverity::Low,
            confidence: 0.8,
            description: "Test signature".to_string(),
            enabled: true,
        };
        
        assert!(engine.add_signature(signature).is_ok());
        
        // Test whitelist operations
        assert!(engine.add_to_whitelist("test_ip".to_string()).is_ok());
        assert!(engine.remove_from_whitelist("test_ip").is_ok());
    }
} 