use tokio;
use async_nats as nats;
use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};
use std::process::Command;
use std::fs;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use rayon::prelude::*;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct RealThreatEvent {
    timestamp: u64,
    source_ip: String,
    threat_type: String,
    payload: String,
    severity: u8,
    confidence: f32,
    source: String, // "network", "filesystem", "events", "processes"
    details: HashMap<String, String>,
}

pub struct RealThreatDetector {
    nats_client: Arc<nats::Client>,
    threat_patterns: Arc<Mutex<HashMap<String, Vec<Vec<u8>>>>>,
    running: Arc<Mutex<bool>>,
    reported_threats: Arc<Mutex<HashMap<String, u64>>>, // Track reported threats to prevent duplicates
}

impl RealThreatDetector {
    pub fn new(nats_client: nats::Client) -> Self {
        let mut patterns = HashMap::new();
        
        // Real threat patterns for actual detection
        patterns.insert("malware".to_string(), vec![
            b"malware".to_vec(),
            b"virus".to_vec(),
            b"trojan".to_vec(),
            b"backdoor".to_vec(),
            b"keylogger".to_vec(),
            b"ransomware".to_vec(),
        ]);
        
        patterns.insert("suspicious".to_string(), vec![
            b"suspicious".to_vec(),
            b"unknown".to_vec(),
            b"temp".to_vec(),
            b"tmp".to_vec(),
        ]);
        
        Self {
            nats_client: Arc::new(nats_client),
            threat_patterns: Arc::new(Mutex::new(patterns)),
            running: Arc::new(Mutex::new(true)),
            reported_threats: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub fn get_patterns(&self, threat_type: &str) -> Vec<Vec<u8>> {
        if let Ok(patterns) = self.threat_patterns.lock() {
            if let Some(threat_patterns) = patterns.get(threat_type) {
                threat_patterns.clone()
            } else {
                vec![]
            }
        } else {
            vec![]
        }
    }

    // Use rayon for parallel pattern matching
    pub fn detect_threat_parallel(&self, data: &[u8], threat_type: &str) -> bool {
        let patterns = self.get_patterns(threat_type);
        patterns.par_iter().any(|pattern| {
            data.windows(pattern.len()).any(|window| window.eq_ignore_ascii_case(pattern))
        })
    }

    // Check if threat has been recently reported to prevent duplicates
    fn is_threat_already_reported(&self, threat_key: &str) -> bool {
        if let Ok(reported) = self.reported_threats.lock() {
            if let Some(last_reported) = reported.get(threat_key) {
                let current_time = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
                // Only report same threat once per 60 seconds
                return current_time - last_reported < 60;
            }
        }
        false
    }

    // Mark threat as reported
    fn mark_threat_reported(&self, threat_key: &str) {
        if let Ok(mut reported) = self.reported_threats.lock() {
            let current_time = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
            reported.insert(threat_key.to_string(), current_time);
        }
    }

    pub async fn start_real_detection(&self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        println!("🚀 Starting REAL threat detection engines...");
        println!("🔍 REAL MODE: No simulation, actual system monitoring only");
        
        let nats_client = Arc::clone(&self.nats_client);
        let detector = Arc::new(self.clone());
        
        // Real Windows Event Log monitoring
        let event_monitor = {
            let detector = Arc::clone(&detector);
            let nats_client = Arc::clone(&nats_client);
            tokio::spawn(async move {
                detector.monitor_windows_events(nats_client).await
            })
        };
        
        // Real network traffic monitoring
        let network_monitor = {
            let detector = Arc::clone(&detector);
            let nats_client = Arc::clone(&nats_client);
            tokio::spawn(async move {
                detector.monitor_network_traffic(nats_client).await
            })
        };
        
        // Real file system monitoring
        let filesystem_monitor = {
            let detector = Arc::clone(&detector);
            let nats_client = Arc::clone(&nats_client);
            tokio::spawn(async move {
                detector.monitor_filesystem(nats_client).await
            })
        };
        
        // Real process monitoring
        let process_monitor = {
            let detector = Arc::clone(&detector);
            let nats_client = Arc::clone(&nats_client);
            tokio::spawn(async move {
                detector.monitor_processes(nats_client).await
            })
        };

        // Wait for all monitors
        tokio::try_join!(
            event_monitor,
            network_monitor,
            filesystem_monitor,
            process_monitor
        )?;

        Ok(())
    }

    async fn monitor_windows_events(&self, nats_client: Arc<nats::Client>) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        println!("🔍 Monitoring REAL Windows Security Events...");
        
        loop {
            // Real Windows Event Log query (PowerShell)
            let output = Command::new("powershell")
                .args(&[
                    "-Command",
                    "Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4625} -MaxEvents 10 | ConvertTo-Json"
                ])
                .output();

            if let Ok(output) = output {
                if let Ok(json_str) = String::from_utf8(output.stdout) {
                    // Parse real failed login events
                    if json_str.contains("4625") {
                        let threat_key = "windows_events:failed_login";
                        
                        // Check if we've already reported this threat recently
                        if !self.is_threat_already_reported(threat_key) {
                            let threat_event = RealThreatEvent {
                                timestamp: SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs(),
                                source_ip: "REAL_FAILED_LOGIN".to_string(),
                                threat_type: "failed_authentication".to_string(),
                                payload: json_str.clone(),
                                severity: 3,
                                confidence: 0.95,
                                source: "windows_events".to_string(),
                                details: {
                                    let mut map = HashMap::new();
                                    map.insert("event_id".to_string(), "4625".to_string());
                                    map.insert("event_type".to_string(), "failed_login".to_string());
                                    map
                                },
                            };

                            let serialized = serde_json::to_vec(&threat_event)?;
                            // Publish to both channels for backward compatibility
                            nats_client.publish("threats.detected", serialized.clone().into()).await?;
                            nats_client.publish("threats.real", serialized.into()).await?;
                            println!("🚨 REAL THREAT: Failed authentication detected!");
                            
                            // Mark this threat as reported
                            self.mark_threat_reported(threat_key);
                        }
                    }
                }
            }

            tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
        }
    }

    async fn monitor_network_traffic(&self, nats_client: Arc<nats::Client>) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        println!("🌐 Monitoring REAL Network Traffic...");
        
        loop {
            // Real network connection monitoring
            let output = Command::new("netstat")
                .args(&["-an"])
                .output();

            if let Ok(output) = output {
                if let Ok(netstat_output) = String::from_utf8(output.stdout) {
                    // Analyze real network connections for suspicious activity
                    for line in netstat_output.lines() {
                        if line.contains("ESTABLISHED") {
                            // Check for suspicious connections
                            if line.contains(":80") || line.contains(":443") {
                                // Real web traffic analysis
                                if self.detect_threat_parallel(line.as_bytes(), "malware") {
                                    let threat_key = format!("network:{}", line);
                                    
                                    // Check if we've already reported this threat recently
                                    if !self.is_threat_already_reported(&threat_key) {
                                        let threat_event = RealThreatEvent {
                                            timestamp: SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs(),
                                            source_ip: "REAL_NETWORK".to_string(),
                                            threat_type: "suspicious_connection".to_string(),
                                            payload: line.to_string(),
                                            severity: 4,
                                            confidence: 0.88,
                                            source: "network_traffic".to_string(),
                                            details: {
                                                let mut map = HashMap::new();
                                                map.insert("connection_type".to_string(), "web".to_string());
                                                map.insert("status".to_string(), "established".to_string());
                                                map
                                            },
                                        };

                                        let serialized = serde_json::to_vec(&threat_event)?;
                                        // Publish to both channels for backward compatibility
                                        nats_client.publish("threats.detected", serialized.clone().into()).await?;
                                        nats_client.publish("threats.real", serialized.into()).await?;
                                        println!("🚨 REAL THREAT: Suspicious network connection detected!");
                                        
                                        // Mark this threat as reported
                                        self.mark_threat_reported(&threat_key);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            tokio::time::sleep(tokio::time::Duration::from_secs(10)).await;
        }
    }

    async fn monitor_filesystem(&self, nats_client: Arc<nats::Client>) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        println!("📁 Monitoring REAL File System...");
        
        loop {
            // Real file system monitoring
            let temp_dir = std::env::temp_dir();
            if let Ok(entries) = fs::read_dir(temp_dir) {
                for entry in entries {
                    if let Ok(entry) = entry {
                        let path = entry.path();
                        if let Some(file_name) = path.file_name() {
                            let file_name_str = file_name.to_string_lossy();
                            
                            // Real malware file detection
                            if self.detect_threat_parallel(file_name_str.as_bytes(), "malware") {
                                let threat_key = format!("filesystem:{}", file_name_str);
                                
                                // Check if we've already reported this threat recently
                                if !self.is_threat_already_reported(&threat_key) {
                                    let threat_event = RealThreatEvent {
                                        timestamp: SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs(),
                                        source_ip: "REAL_FILESYSTEM".to_string(),
                                        threat_type: "suspicious_file".to_string(),
                                        payload: file_name_str.to_string(),
                                        severity: 4,
                                        confidence: 0.92,
                                        source: "filesystem".to_string(),
                                        details: {
                                            let mut map = HashMap::new();
                                            map.insert("file_path".to_string(), path.to_string_lossy().to_string());
                                            map.insert("file_size".to_string(), "unknown".to_string());
                                            map
                                        },
                                    };

                                                                    let serialized = serde_json::to_vec(&threat_event)?;
                                // Publish to both channels for backward compatibility
                                nats_client.publish("threats.detected", serialized.clone().into()).await?;
                                nats_client.publish("threats.real", serialized.into()).await?;
                                println!("🚨 REAL THREAT: Suspicious file detected: {}", file_name_str);
                                    
                                    // Mark this threat as reported
                                    self.mark_threat_reported(&threat_key);
                                }
                            }
                        }
                    }
                }
            }

            tokio::time::sleep(tokio::time::Duration::from_secs(15)).await;
        }
    }

    async fn monitor_processes(&self, nats_client: Arc<nats::Client>) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        println!("⚙️ Monitoring REAL Processes...");
        
        loop {
            // Real process monitoring
            let output = Command::new("tasklist")
                .args(&["/FO", "CSV"])
                .output();

            if let Ok(output) = output {
                if let Ok(process_list) = String::from_utf8(output.stdout) {
                    for line in process_list.lines() {
                        // Real suspicious process detection
                        if self.detect_threat_parallel(line.as_bytes(), "malware") {
                            let threat_key = format!("process:{}", line);
                            
                            // Check if we've already reported this threat recently
                            if !self.is_threat_already_reported(&threat_key) {
                                let threat_event = RealThreatEvent {
                                    timestamp: SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs(),
                                    source_ip: "REAL_PROCESS".to_string(),
                                    threat_type: "suspicious_process".to_string(),
                                    payload: line.to_string(),
                                    severity: 4,
                                    confidence: 0.90,
                                    source: "processes".to_string(),
                                    details: {
                                        let mut map = HashMap::new();
                                        map.insert("process_name".to_string(), line.to_string());
                                        map.insert("status".to_string(), "running".to_string());
                                        map
                                    },
                                };

                                let serialized = serde_json::to_vec(&threat_event)?;
                                // Publish to both channels for backward compatibility
                                nats_client.publish("threats.detected", serialized.clone().into()).await?;
                                nats_client.publish("threats.real", serialized.into()).await?;
                                println!("🚨 REAL THREAT: Suspicious process detected!");
                                
                                // Mark this threat as reported
                                self.mark_threat_reported(&threat_key);
                            }
                        }
                    }
                }
            }

            tokio::time::sleep(tokio::time::Duration::from_secs(20)).await;
        }
    }
}

impl Clone for RealThreatDetector {
    fn clone(&self) -> Self {
        Self {
            nats_client: Arc::clone(&self.nats_client),
            threat_patterns: Arc::clone(&self.threat_patterns),
            running: Arc::clone(&self.running),
            reported_threats: Arc::clone(&self.reported_threats),
        }
    }
} 