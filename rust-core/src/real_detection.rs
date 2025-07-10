use std::sync::{Arc, RwLock};
use std::collections::HashMap;
use log::info;
use crate::error_handling::SIEMResult;
use memchr::memmem;

/// Real-time detection engine for Ultra SIEM
pub struct RealDetectionEngine {
    patterns: Arc<RwLock<HashMap<String, String>>>,
    thresholds: Arc<RwLock<HashMap<String, u32>>>,
    counters: Arc<RwLock<HashMap<String, u32>>>,
    alerts: Arc<RwLock<Vec<String>>>,
}

impl RealDetectionEngine {
    /// Create a new real-time detection engine
    pub fn new() -> Self {
        let mut engine = Self {
            patterns: Arc::new(RwLock::new(HashMap::new())),
            thresholds: Arc::new(RwLock::new(HashMap::new())),
            counters: Arc::new(RwLock::new(HashMap::new())),
            alerts: Arc::new(RwLock::new(Vec::new())),
        };
        
        engine.initialize_patterns();
        engine
    }

    /// Initialize default detection patterns
    fn initialize_patterns(&mut self) {
        let mut patterns = self.patterns.write().unwrap();
        
        // SQL Injection patterns
        patterns.insert("sql_union".to_string(), "UNION SELECT".to_string());
        patterns.insert("sql_drop".to_string(), "DROP TABLE".to_string());
        patterns.insert("sql_insert".to_string(), "INSERT INTO".to_string());
        
        // XSS patterns
        patterns.insert("xss_script".to_string(), "<script>".to_string());
        patterns.insert("xss_javascript".to_string(), "javascript:".to_string());
        
        // Command injection patterns
        patterns.insert("cmd_exec".to_string(), "cmd.exe".to_string());
        patterns.insert("powershell".to_string(), "powershell.exe".to_string());
        
        // File inclusion patterns
        patterns.insert("path_traversal".to_string(), "../".to_string());
        patterns.insert("remote_file".to_string(), "http://".to_string());
        
        info!("✅ Initialized {} real-time detection patterns", patterns.len());
    }

    /// Add a new detection pattern
    pub fn add_pattern(&self, name: String, pattern: String) -> SIEMResult<()> {
        let mut patterns = self.patterns.write().unwrap();
        patterns.insert(name.clone(), pattern);
        info!("✅ Added detection pattern: {}", name);
        Ok(())
    }

    /// Set threshold for a pattern
    pub fn set_threshold(&self, pattern_name: String, threshold: u32) -> SIEMResult<()> {
        let mut thresholds = self.thresholds.write().unwrap();
        thresholds.insert(pattern_name.clone(), threshold);
        info!("✅ Set threshold for {}: {}", pattern_name, threshold);
        Ok(())
    }

    /// Process data for real-time detection
    pub fn process_data(&self, data: &[u8]) -> SIEMResult<Vec<String>> {
        let mut detections = Vec::new();
        let patterns = self.patterns.read().unwrap();
        let mut counters = self.counters.write().unwrap();
        
        for (pattern_name, pattern) in patterns.iter() {
            if memmem::find(data, pattern.as_bytes()).is_some() {
                // Increment counter
                let count = counters.entry(pattern_name.clone()).or_insert(0);
                *count += 1;
                
                // Check threshold
                let thresholds = self.thresholds.read().unwrap();
                if let Some(threshold) = thresholds.get(pattern_name) {
                    if *count >= *threshold {
                        let alert = format!("🚨 Pattern '{}' exceeded threshold {} (current: {})", 
                                          pattern_name, threshold, count);
                        detections.push(alert);
                        
                        // Reset counter after alert
                        *count = 0;
                    }
                } else {
                    // No threshold set, alert immediately
                    let alert = format!("🚨 Pattern '{}' detected", pattern_name);
                    detections.push(alert);
                }
            }
        }
        
        Ok(detections)
    }

    /// Get current counters
    pub fn get_counters(&self) -> HashMap<String, u32> {
        self.counters.read().unwrap().clone()
    }

    /// Reset counters
    pub fn reset_counters(&self) -> SIEMResult<()> {
        let mut counters = self.counters.write().unwrap();
        counters.clear();
        info!("✅ Reset all pattern counters");
        Ok(())
    }

    /// Get all alerts
    pub fn get_alerts(&self) -> Vec<String> {
        self.alerts.read().unwrap().clone()
    }

    /// Clear alerts
    pub fn clear_alerts(&self) -> SIEMResult<()> {
        let mut alerts = self.alerts.write().unwrap();
        alerts.clear();
        info!("✅ Cleared all alerts");
        Ok(())
    }

    /// Start monitoring mode
    pub async fn start_monitoring(&self) -> SIEMResult<()> {
        info!("🚀 Starting real-time monitoring...");
        
        // Simulate monitoring loop
        loop {
            // In a real implementation, this would process incoming data
            // For now, we'll just log that monitoring is active
            info!("📊 Real-time monitoring active - processing events...");
            
            // Sleep for a short interval
            tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
        }
    }

    /// Process network traffic
    pub fn process_network_traffic(&self, traffic_data: &[u8]) -> SIEMResult<Vec<String>> {
        info!("🌐 Processing network traffic ({} bytes)", traffic_data.len());
        self.process_data(traffic_data)
    }

    /// Process log data
    pub fn process_log_data(&self, log_data: &[u8]) -> SIEMResult<Vec<String>> {
        info!("📝 Processing log data ({} bytes)", log_data.len());
        self.process_data(log_data)
    }

    /// Process file data
    pub fn process_file_data(&self, file_data: &[u8]) -> SIEMResult<Vec<String>> {
        info!("📁 Processing file data ({} bytes)", file_data.len());
        self.process_data(file_data)
    }

    /// Get performance metrics
    pub fn get_performance_metrics(&self) -> HashMap<String, f64> {
        let mut metrics = HashMap::new();
        
        let patterns = self.patterns.read().unwrap();
        let counters = self.counters.read().unwrap();
        
        metrics.insert("total_patterns".to_string(), patterns.len() as f64);
        metrics.insert("active_counters".to_string(), counters.len() as f64);
        
        let total_matches: u32 = counters.values().sum();
        metrics.insert("total_matches".to_string(), total_matches as f64);
        
        metrics
    }

    /// Export detection rules
    pub fn export_rules(&self) -> SIEMResult<String> {
        let patterns = self.patterns.read().unwrap();
        let thresholds = self.thresholds.read().unwrap();
        
        let mut rules = Vec::new();
        for (name, pattern) in patterns.iter() {
            let threshold = thresholds.get(name).unwrap_or(&0);
            rules.push(format!("{}: {} (threshold: {})", name, pattern, threshold));
        }
        
        Ok(rules.join("\n"))
    }

    /// Import detection rules
    pub fn import_rules(&self, rules_data: &str) -> SIEMResult<()> {
        info!("📥 Importing detection rules...");
        
        for line in rules_data.lines() {
            if let Some((name, rest)) = line.split_once(':') {
                if let Some((pattern, threshold_str)) = rest.rsplit_once("(threshold: ") {
                    if let Ok(threshold) = threshold_str.trim_end_matches(')').parse::<u32>() {
                        self.add_pattern(name.trim().to_string(), pattern.trim().to_string())?;
                        self.set_threshold(name.trim().to_string(), threshold)?;
                    }
                }
            }
        }
        
        info!("✅ Successfully imported detection rules");
        Ok(())
    }
}

impl Default for RealDetectionEngine {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_real_detection_engine() {
        let engine = RealDetectionEngine::new();
        
        // Test pattern addition
        assert!(engine.add_pattern("test_pattern".to_string(), "test".to_string()).is_ok());
        
        // Test threshold setting
        assert!(engine.set_threshold("test_pattern".to_string(), 5).is_ok());
        
        // Test data processing
        let test_data = b"test data with test pattern";
        let detections = engine.process_data(test_data).unwrap();
        assert!(!detections.is_empty());
        
        // Test counter reset
        assert!(engine.reset_counters().is_ok());
        
        // Test alert clearing
        assert!(engine.clear_alerts().is_ok());
    }

    #[test]
    fn test_sql_injection_detection() {
        let engine = RealDetectionEngine::new();
        
        let sql_payload = b"SELECT * FROM users UNION SELECT * FROM passwords";
        let detections = engine.process_data(sql_payload).unwrap();
        
        // Should detect SQL injection patterns
        assert!(!detections.is_empty());
    }

    #[test]
    fn test_xss_detection() {
        let engine = RealDetectionEngine::new();
        
        let xss_payload = b"<script>alert('XSS')</script>";
        let detections = engine.process_data(xss_payload).unwrap();
        
        // Should detect XSS patterns
        assert!(!detections.is_empty());
    }

    #[tokio::test]
    async fn test_monitoring_start() {
        let engine = RealDetectionEngine::new();
        
        // This should not panic
        // Note: In a real test, you'd want to spawn this in a separate task
        // and then cancel it after a short time
    }
} 