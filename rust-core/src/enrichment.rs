use std::net::IpAddr;
use std::collections::HashMap;
use serde::{Deserialize, Serialize};
use tokio::time::{Duration, interval};
use std::sync::{Arc, RwLock};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GeoData {
    pub country: String,
    pub asn: u32,
    pub is_tor: bool,
    pub city: String,
    pub latitude: f64,
    pub longitude: f64,
    pub isp: String,
    pub organization: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThreatIntelData {
    pub reputation_score: f32,
    pub threat_categories: Vec<String>,
    pub malware_families: Vec<String>,
    pub first_seen: String,
    pub last_seen: String,
    pub confidence: f32,
}

#[derive(Debug, Clone)]
pub struct ThreatEvent {
    pub timestamp: u64,
    pub source_ip: String,
    pub threat_type: String,
    pub payload: String,
    pub severity: u8,
    pub confidence: f32,
    pub geo_data: Option<GeoData>,
    pub threat_intel: Option<ThreatIntelData>,
    pub ml_score: f32,
    pub user_agent: String,
    pub request_uri: String,
    pub session_id: String,
    pub process_info: ProcessInfo,
    pub network_info: NetworkInfo,
}

#[derive(Debug, Clone, Default)]
pub struct ProcessInfo {
    pub name: String,
    pub pid: u32,
    pub parent_name: String,
    pub command_line: String,
    pub file_hash: String,
    pub digital_signature: String,
}

#[derive(Debug, Clone, Default)]
pub struct NetworkInfo {
    pub src_port: u16,
    pub dst_port: u16,
    pub protocol: String,
    pub bytes_transferred: u64,
    pub connection_duration: u32,
}

pub struct ThreatEnrichment {
    tor_exits: Arc<RwLock<HashMap<String, bool>>>,
    threat_intel_cache: Arc<RwLock<HashMap<String, ThreatIntelData>>>,
    malware_signatures: Arc<RwLock<HashMap<String, String>>>,
}

impl ThreatEnrichment {
    pub async fn new() -> Result<Self, Box<dyn std::error::Error + Send + Sync>> {
        let enrichment = ThreatEnrichment {
            tor_exits: Arc::new(RwLock::new(HashMap::new())),
            threat_intel_cache: Arc::new(RwLock::new(HashMap::new())),
            malware_signatures: Arc::new(RwLock::new(HashMap::new())),
        };

        // Start background tasks
        enrichment.start_tor_list_updater().await;
        enrichment.start_threat_intel_updater().await;
        enrichment.load_malware_signatures().await;

        Ok(enrichment)
    }



    async fn start_tor_list_updater(&self) {
        let tor_exits = Arc::clone(&self.tor_exits);
        tokio::spawn(async move {
            let mut interval = interval(Duration::from_secs(3600)); // Update hourly
            loop {
                interval.tick().await;
                if let Ok(tor_list) = Self::fetch_tor_exit_list().await {
                    let mut exits = tor_exits.write().unwrap();
                    exits.clear();
                    for ip in tor_list {
                        exits.insert(ip, true);
                    }
                    println!("✅ Updated Tor exit list with {} nodes", exits.len());
                }
            }
        });
    }

    async fn start_threat_intel_updater(&self) {
        let cache = Arc::clone(&self.threat_intel_cache);
        tokio::spawn(async move {
            let mut interval = interval(Duration::from_secs(1800)); // Update every 30 minutes
            loop {
                interval.tick().await;
                if let Ok(intel_data) = Self::fetch_threat_intelligence().await {
                    let mut intel_cache = cache.write().unwrap();
                    for (ip, data) in intel_data {
                        intel_cache.insert(ip, data);
                    }
                    println!("✅ Updated threat intelligence cache");
                }
            }
        });
    }

    async fn load_malware_signatures(&self) {
        // Load YARA rules and malware signatures
        let signatures = vec![
            ("WannaCry".to_string(), "ransomware".to_string()),
            ("Mirai".to_string(), "botnet".to_string()),
            ("Zeus".to_string(), "banking_trojan".to_string()),
            ("Emotet".to_string(), "trojan_downloader".to_string()),
            ("TrickBot".to_string(), "banking_trojan".to_string()),
        ];

        let mut sigs = self.malware_signatures.write().unwrap();
        for (family, category) in signatures {
            sigs.insert(family, category);
        }
    }

    async fn fetch_tor_exit_list() -> Result<Vec<String>, Box<dyn std::error::Error + Send + Sync>> {
        // Simplified Tor exit list fetching
        let sample_exits = vec![
            "185.220.100.240".to_string(),
            "185.220.100.241".to_string(),
            "185.220.100.242".to_string(),
        ];
        Ok(sample_exits)
    }

    async fn fetch_threat_intelligence() -> Result<HashMap<String, ThreatIntelData>, Box<dyn std::error::Error + Send + Sync>> {
        // Integrate with threat intelligence feeds
        let mut intel_data = HashMap::new();
        
        // Example integration with VirusTotal, AbuseIPDB, etc.
        // This would be replaced with actual API calls
        let sample_data = vec![
            ("192.168.1.100", ThreatIntelData {
                reputation_score: 0.8,
                threat_categories: vec!["malware".to_string(), "botnet".to_string()],
                malware_families: vec!["Mirai".to_string()],
                first_seen: "2024-01-01T00:00:00Z".to_string(),
                last_seen: "2024-01-15T12:00:00Z".to_string(),
                confidence: 0.95,
            }),
        ];

        for (ip, data) in sample_data {
            intel_data.insert(ip.to_string(), data);
        }

        Ok(intel_data)
    }

    pub fn enrich_event(&self, event: &mut ThreatEvent) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        // GeoIP enrichment
        if let Ok(ip) = event.source_ip.parse::<IpAddr>() {
            event.geo_data = self.get_geo_data(&ip);
        }

        // Threat intelligence enrichment
        if let Some(intel) = self.get_threat_intel(&event.source_ip) {
            event.threat_intel = Some(intel);
        }

        // ML scoring
        event.ml_score = self.calculate_ml_score(event);

        // GDPR compliance check
        self.apply_gdpr_compliance(event);

        Ok(())
    }

    fn get_geo_data(&self, ip: &IpAddr) -> Option<GeoData> {
        // Simplified GeoIP lookup
        match ip {
            IpAddr::V4(ipv4) => {
                let octets = ipv4.octets();
                if octets[0] == 192 && octets[1] == 168 {
                    Some(GeoData {
                        country: "US".to_string(),
                        asn: 0,
                        is_tor: false,
                        city: "Local".to_string(),
                        latitude: 0.0,
                        longitude: 0.0,
                        isp: "Local Network".to_string(),
                        organization: "Private".to_string(),
                    })
                } else {
                    Some(GeoData {
                        country: "Unknown".to_string(),
                        asn: 0,
                        is_tor: false,
                        city: "Unknown".to_string(),
                        latitude: 0.0,
                        longitude: 0.0,
                        isp: "Unknown".to_string(),
                        organization: "Unknown".to_string(),
                    })
                }
            }
            _ => None,
        }
    }

    fn get_threat_intel(&self, ip: &str) -> Option<ThreatIntelData> {
        self.threat_intel_cache
            .read()
            .unwrap()
            .get(ip)
            .cloned()
    }

    fn calculate_ml_score(&self, event: &ThreatEvent) -> f32 {
        let mut score = 0.0;

        // Base confidence score
        score += event.confidence * 0.3;

        // Geolocation risk
        if let Some(ref geo) = event.geo_data {
            if geo.is_tor {
                score += 0.3;
            }
            // High-risk countries
            if ["CN", "RU", "KP", "IR"].contains(&geo.country.as_str()) {
                score += 0.2;
            }
        }

        // Threat intelligence risk
        if let Some(ref intel) = event.threat_intel {
            score += intel.reputation_score * 0.2;
        }

        // Payload analysis
        let payload_lower = event.payload.to_lowercase();
        if payload_lower.contains("<script>") || payload_lower.contains("javascript:") {
            score += 0.4;
        }
        if payload_lower.contains("union select") || payload_lower.contains("drop table") {
            score += 0.5;
        }

        // Normalize to 0-1 range
        score.min(1.0)
    }

    fn apply_gdpr_compliance(&self, event: &mut ThreatEvent) {
        // Check if IP is from EU
        if let Some(ref geo) = event.geo_data {
            let eu_countries = [
                "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR",
                "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL",
                "PL", "PT", "RO", "SK", "SI", "ES", "SE"
            ];
            
            if eu_countries.contains(&geo.country.as_str()) {
                // Apply GDPR data minimization
                event.source_ip = self.pseudonymize_ip(&event.source_ip);
                event.session_id = "REDACTED_GDPR".to_string();
                
                // Set retention policy
                // This would be handled in the database layer
            }
        }
    }

    fn pseudonymize_ip(&self, ip: &str) -> String {
        // Simple IP pseudonymization - replace last octet with 0
        if let Ok(parsed_ip) = ip.parse::<IpAddr>() {
            match parsed_ip {
                IpAddr::V4(ipv4) => {
                    let octets = ipv4.octets();
                    format!("{}.{}.{}.0", octets[0], octets[1], octets[2])
                }
                IpAddr::V6(_) => {
                    // For IPv6, zero out the last 64 bits
                    "REDACTED_IPv6".to_string()
                }
            }
        } else {
            "REDACTED_IP".to_string()
        }
    }

    pub fn generate_compliance_audit(&self, event: &ThreatEvent) -> ComplianceAudit {
        ComplianceAudit {
            event_time: std::time::SystemTime::now(),
            regulation: "GDPR".to_string(),
            event_type: "data_processing".to_string(),
            user_id: "SYSTEM".to_string(),
            resource_type: "threat_event".to_string(),
            resource_id: format!("event_{}", event.timestamp),
            action_description: format!("Processed threat event: {}", event.threat_type),
            legal_basis: "legitimate_interest".to_string(),
            encryption_applied: true,
            anonymization_applied: event.source_ip.contains("REDACTED"),
            audit_trail: format!("Event processed with enrichment at {}", 
                std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs()),
        }
    }
}

#[derive(Debug, Serialize)]
pub struct ComplianceAudit {
    pub event_time: std::time::SystemTime,
    pub regulation: String,
    pub event_type: String,
    pub user_id: String,
    pub resource_type: String,
    pub resource_id: String,
    pub action_description: String,
    pub legal_basis: String,
    pub encryption_applied: bool,
    pub anonymization_applied: bool,
    pub audit_trail: String,
} 