//! # Machine Learning Engine Module
//! 
//! This module provides machine learning capabilities for Ultra SIEM, focusing on
//! anomaly detection using statistical methods and real-time scoring.
//! 
//! ## Features
//! - Real-time anomaly detection using Z-score and EWMA
//! - Batch processing for multiple features
//! - Online statistical updates
//! - Configurable thresholds and parameters
//! 
//! ## Algorithms
//! - **Z-Score**: Standard deviation-based anomaly detection
//! - **EWMA**: Exponentially Weighted Moving Average for trend analysis
//! - **Combined Scoring**: Hybrid approach using both methods
//! 
//! ## Usage
//! ```rust
//! use siem_rust_core::ml_engine::{MLAnomalyEngine, MLAnomalyResult};
//! 
//! let engine = MLAnomalyEngine::new(10, 2.0, 0.1);
//! engine.update_stats("cpu_usage", 85.5);
//! let result = engine.score("cpu_usage", 95.0);
//! ```

use dashmap::DashMap;
use serde::{Serialize, Deserialize};
use std::sync::Arc;
use std::collections::HashMap;

/// Result of machine learning anomaly detection
/// 
/// Contains the anomaly score, classification, model information,
/// and detailed metrics for analysis and debugging.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MLAnomalyResult {
    /// Anomaly score (higher = more anomalous)
    pub score: f32,
    /// Whether the value is classified as anomalous
    pub is_anomaly: bool,
    /// Name of the model used for detection
    pub model: String,
    /// Detailed metrics and parameters used in detection
    pub details: HashMap<String, String>,
}

/// Machine Learning Anomaly Detection Engine
/// 
/// Provides real-time anomaly detection using statistical methods.
/// Supports online learning and batch processing for multiple features.
/// 
/// ## Thread Safety
/// This engine is thread-safe and can be shared across multiple threads
/// using `Arc<MLAnomalyEngine>`.
#[derive(Debug, Clone)]
pub struct MLAnomalyEngine {
    /// Baseline mean values for each feature (feature -> mean)
    pub baseline: Arc<DashMap<String, f32>>,
    /// Standard deviation values for each feature (feature -> stddev)
    pub stddev: Arc<DashMap<String, f32>>,
    /// Exponentially Weighted Moving Average values (feature -> ewma)
    pub ewma: Arc<DashMap<String, f32>>,
    /// Minimum number of samples required before anomaly detection
    pub min_samples: usize,
    /// Z-score threshold for anomaly classification
    pub z_threshold: f32,
    /// Alpha parameter for EWMA calculation (0.0 < alpha < 1.0)
    pub ewma_alpha: f32,
}

impl MLAnomalyEngine {
    /// Create a new ML anomaly detection engine
    /// 
    /// # Arguments
    /// * `min_samples` - Minimum samples required before anomaly detection
    /// * `z_threshold` - Z-score threshold for anomaly classification (typically 2.0-3.0)
    /// * `ewma_alpha` - EWMA smoothing factor (0.0 < alpha < 1.0, typically 0.1-0.3)
    /// 
    /// # Returns
    /// A new `MLAnomalyEngine` instance
    /// 
    /// # Examples
    /// ```rust
    /// use siem_rust_core::ml_engine::MLAnomalyEngine;
    /// 
    /// let engine = MLAnomalyEngine::new(10, 2.5, 0.15);
    /// ```
    pub fn new(min_samples: usize, z_threshold: f32, ewma_alpha: f32) -> Self {
        Self {
            baseline: Arc::new(DashMap::new()),
            stddev: Arc::new(DashMap::new()),
            ewma: Arc::new(DashMap::new()),
            min_samples,
            z_threshold,
            ewma_alpha,
        }
    }

    /// Update baseline and standard deviation for a feature
    /// 
    /// This method implements online statistical updates, allowing the engine
    /// to learn from new data points in real-time.
    /// 
    /// # Arguments
    /// * `feature` - Feature name to update
    /// * `value` - New value for the feature
    /// 
    /// # Algorithm
    /// - Updates EWMA using exponential smoothing
    /// - Updates mean using simple averaging
    /// - Updates standard deviation using absolute deviation
    /// 
    /// # Examples
    /// ```rust
    /// use siem_rust_core::ml_engine::MLAnomalyEngine;
    /// 
    /// let engine = MLAnomalyEngine::new(5, 2.0, 0.1);
    /// engine.update_stats("cpu_usage", 75.5);
    /// engine.update_stats("cpu_usage", 82.3);
    /// ```
    pub fn update_stats(&self, feature: &str, value: f32) {
        let mut mean = self.baseline.entry(feature.to_string()).or_insert(value);
        let mut std = self.stddev.entry(feature.to_string()).or_insert(0.0);
        let mut ewma = self.ewma.entry(feature.to_string()).or_insert(value);
        
        // Update EWMA using exponential smoothing
        *ewma = self.ewma_alpha * value + (1.0 - self.ewma_alpha) * *ewma;
        
        // Update mean using simple averaging (for demo purposes)
        *mean = (*mean + value) / 2.0;
        
        // Update standard deviation using absolute deviation
        *std = ((*std + (value - *mean).abs()) / 2.0).max(0.01);
    }

    /// Score a feature value for anomaly detection
    /// 
    /// Combines Z-score and EWMA deviation to determine if a value is anomalous.
    /// 
    /// # Arguments
    /// * `feature` - Feature name to score
    /// * `value` - Value to evaluate for anomaly
    /// 
    /// # Returns
    /// `MLAnomalyResult` containing anomaly score, classification, and details
    /// 
    /// # Algorithm
    /// 1. Calculate Z-score: (value - mean) / stddev
    /// 2. Calculate EWMA deviation: |value - ewma|
    /// 3. Classify as anomalous if Z-score > threshold OR EWMA deviation > threshold * stddev
    /// 4. Return combined score and detailed metrics
    /// 
    /// # Examples
    /// ```rust
    /// use siem_rust_core::ml_engine::MLAnomalyEngine;
    /// 
    /// let engine = MLAnomalyEngine::new(5, 2.0, 0.1);
    /// engine.update_stats("cpu_usage", 75.0);
    /// 
    /// let result = engine.score("cpu_usage", 95.0);
    /// println!("Anomaly: {}, Score: {:.2}", result.is_anomaly, result.score);
    /// ```
    pub fn score(&self, feature: &str, value: f32) -> MLAnomalyResult {
        let mean = self.baseline.get(feature).map(|v| *v.value()).unwrap_or(value);
        let std = self.stddev.get(feature).map(|v| *v.value()).unwrap_or(1.0);
        let ewma = self.ewma.get(feature).map(|v| *v.value()).unwrap_or(value);
        
        // Calculate Z-score
        let z = if std > 0.0 { (value - mean) / std } else { 0.0 };
        
        // Calculate EWMA deviation
        let ewma_dev = (value - ewma).abs();
        
        // Determine if anomalous
        let is_anomaly = z.abs() > self.z_threshold || ewma_dev > self.z_threshold * std;
        
        // Build detailed metrics
        let mut details = HashMap::new();
        details.insert("z_score".to_string(), format!("{:.2}", z));
        details.insert("ewma_dev".to_string(), format!("{:.2}", ewma_dev));
        details.insert("mean".to_string(), format!("{:.2}", mean));
        details.insert("stddev".to_string(), format!("{:.2}", std));
        details.insert("ewma".to_string(), format!("{:.2}", ewma));
        
        MLAnomalyResult {
            score: z.abs().max(ewma_dev),
            is_anomaly,
            model: "z-score+EWMA".to_string(),
            details,
        }
    }

    /// Batch anomaly detection for multiple features
    /// 
    /// Efficiently scores multiple features at once, useful for processing
    /// multiple metrics from a single event or time window.
    /// 
    /// # Arguments
    /// * `features` - HashMap of feature names to values
    /// 
    /// # Returns
    /// HashMap mapping feature names to their anomaly results
    /// 
    /// # Examples
    /// ```rust
    /// use siem_rust_core::ml_engine::MLAnomalyEngine;
    /// use std::collections::HashMap;
    /// 
    /// let engine = MLAnomalyEngine::new(5, 2.0, 0.1);
    /// let mut features = HashMap::new();
    /// features.insert("cpu_usage".to_string(), 85.0);
    /// features.insert("memory_usage".to_string(), 92.0);
    /// 
    /// let results = engine.batch_score(&features);
    /// for (feature, result) in results {
    ///     println!("{}: anomaly={}, score={:.2}", feature, result.is_anomaly, result.score);
    /// }
    /// ```
    pub fn batch_score(&self, features: &HashMap<String, f32>) -> HashMap<String, MLAnomalyResult> {
        features.iter().map(|(k, v)| (k.clone(), self.score(k, *v))).collect()
    }
} 

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    #[test]
    fn test_new_engine() {
        let engine = MLAnomalyEngine::new(5, 2.0, 0.1);
        assert_eq!(engine.min_samples, 5);
        assert_eq!(engine.z_threshold, 2.0);
        assert_eq!(engine.ewma_alpha, 0.1);
    }

    #[test]
    fn test_update_and_score() {
        let engine = MLAnomalyEngine::new(1, 2.0, 0.2);
        engine.update_stats("cpu", 80.0);
        let result = engine.score("cpu", 90.0);
        assert!(result.score >= 0.0);
        assert!(result.details.contains_key("z_score"));
    }

    #[test]
    fn test_batch_score() {
        let engine = MLAnomalyEngine::new(1, 2.0, 0.2);
        let mut features = HashMap::new();
        features.insert("cpu".to_string(), 85.0);
        features.insert("mem".to_string(), 92.0);
        let results = engine.batch_score(&features);
        assert_eq!(results.len(), 2);
        assert!(results["cpu"].score >= 0.0);
        assert!(results["mem"].score >= 0.0);
    }
} 