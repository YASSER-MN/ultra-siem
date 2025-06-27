use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use tokio;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MLThreatPrediction {
    pub threat_type: String,
    pub confidence: f64,
    pub severity: u8,
    pub features_used: Vec<String>,
    pub model_version: String,
    pub prediction_time_ms: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FeatureVector {
    pub request_length: f64,
    pub special_char_ratio: f64,
    pub sql_keyword_count: f64,
    pub script_tag_count: f64,
    pub entropy: f64,
    pub ip_reputation_score: f64,
    pub geo_risk_score: f64,
    pub time_of_day: f64,
    pub request_frequency: f64,
    pub user_agent_entropy: f64,
}

#[derive(Debug)]
pub struct MLEngine {
    models: HashMap<String, MLModel>,
    feature_extractors: Vec<Box<dyn FeatureExtractor>>,
    ensemble_weights: HashMap<String, f64>,
}

#[derive(Debug, Clone)]
pub struct MLModel {
    pub name: String,
    pub version: String,
    pub model_type: ModelType,
    pub accuracy: f64,
    pub last_trained: chrono::DateTime<chrono::Utc>,
    pub weights: Vec<f64>,
    pub thresholds: HashMap<String, f64>,
}

#[derive(Debug, Clone)]
pub enum ModelType {
    RandomForest,
    NeuralNetwork,
    SVM,
    XGBoost,
    DeepLearning,
    Ensemble,
}

pub trait FeatureExtractor: Send + Sync {
    fn extract(&self, payload: &str, metadata: &EventMetadata) -> FeatureVector;
    fn name(&self) -> &str;
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EventMetadata {
    pub source_ip: String,
    pub user_agent: Option<String>,
    pub timestamp: chrono::DateTime<chrono::Utc>,
    pub request_method: Option<String>,
    pub url_path: Option<String>,
    pub headers: HashMap<String, String>,
}

impl MLEngine {
    pub fn new() -> Self {
        let mut engine = MLEngine {
            models: HashMap::new(),
            feature_extractors: Vec::new(),
            ensemble_weights: HashMap::new(),
        };
        
        engine.initialize_models();
        engine.initialize_feature_extractors();
        engine
    }
    
    fn initialize_models(&mut self) {
        // SQL Injection Detection Model
        let sql_injection_model = MLModel {
            name: "sql_injection_detector".to_string(),
            version: "2.1.0".to_string(),
            model_type: ModelType::RandomForest,
            accuracy: 0.987,
            last_trained: chrono::Utc::now(),
            weights: vec![
                0.25, 0.18, 0.31, 0.12, 0.08, 0.06  // Feature weights
            ],
            thresholds: {
                let mut map = HashMap::new();
                map.insert("high_confidence".to_string(), 0.85);
                map.insert("medium_confidence".to_string(), 0.65);
                map.insert("low_confidence".to_string(), 0.45);
                map
            },
        };
        
        // XSS Detection Model
        let xss_model = MLModel {
            name: "xss_detector".to_string(),
            version: "1.8.2".to_string(),
            model_type: ModelType::NeuralNetwork,
            accuracy: 0.954,
            last_trained: chrono::Utc::now(),
            weights: vec![
                0.22, 0.28, 0.15, 0.35  // Neural network weights (simplified)
            ],
            thresholds: {
                let mut map = HashMap::new();
                map.insert("high_confidence".to_string(), 0.80);
                map.insert("medium_confidence".to_string(), 0.60);
                map.insert("low_confidence".to_string(), 0.40);
                map
            },
        };
        
        // Anomaly Detection Model
        let anomaly_model = MLModel {
            name: "behavioral_anomaly".to_string(),
            version: "3.0.1".to_string(),
            model_type: ModelType::SVM,
            accuracy: 0.923,
            last_trained: chrono::Utc::now(),
            weights: vec![
                0.15, 0.20, 0.18, 0.12, 0.25, 0.10
            ],
            thresholds: {
                let mut map = HashMap::new();
                map.insert("high_anomaly".to_string(), 0.75);
                map.insert("medium_anomaly".to_string(), 0.55);
                map.insert("low_anomaly".to_string(), 0.35);
                map
            },
        };
        
        // Advanced Threat Detection (Deep Learning)
        let advanced_model = MLModel {
            name: "advanced_threat_detection".to_string(),
            version: "1.0.0-beta".to_string(),
            model_type: ModelType::DeepLearning,
            accuracy: 0.991,
            last_trained: chrono::Utc::now(),
            weights: vec![
                0.18, 0.22, 0.16, 0.28, 0.08, 0.08
            ],
            thresholds: {
                let mut map = HashMap::new();
                map.insert("apt_detected".to_string(), 0.90);
                map.insert("suspicious_activity".to_string(), 0.70);
                map.insert("baseline_deviation".to_string(), 0.50);
                map
            },
        };
        
        self.models.insert("sql_injection".to_string(), sql_injection_model);
        self.models.insert("xss".to_string(), xss_model);
        self.models.insert("anomaly".to_string(), anomaly_model);
        self.models.insert("advanced_threats".to_string(), advanced_model);
        
        // Set ensemble weights
        self.ensemble_weights.insert("sql_injection".to_string(), 0.30);
        self.ensemble_weights.insert("xss".to_string(), 0.25);
        self.ensemble_weights.insert("anomaly".to_string(), 0.20);
        self.ensemble_weights.insert("advanced_threats".to_string(), 0.25);
    }
    
    fn initialize_feature_extractors(&mut self) {
        self.feature_extractors.push(Box::new(PayloadAnalyzer));
        self.feature_extractors.push(Box::new(NetworkAnalyzer));
        self.feature_extractors.push(Box::new(BehavioralAnalyzer));
    }
    
    pub async fn predict_threat(&self, payload: &str, metadata: &EventMetadata) -> Vec<MLThreatPrediction> {
        let start_time = std::time::Instant::now();
        let mut predictions = Vec::new();
        
        // Extract features
        let features = self.extract_features(payload, metadata);
        
        // Run each model
        for (model_name, model) in &self.models {
            let prediction = self.run_model(model, &features, model_name).await;
            predictions.push(prediction);
        }
        
        // Add ensemble prediction
        let ensemble_prediction = self.create_ensemble_prediction(&predictions, start_time.elapsed().as_millis() as u64);
        predictions.push(ensemble_prediction);
        
        predictions
    }
    
    fn extract_features(&self, payload: &str, metadata: &EventMetadata) -> FeatureVector {
        let mut combined_features = FeatureVector {
            request_length: 0.0,
            special_char_ratio: 0.0,
            sql_keyword_count: 0.0,
            script_tag_count: 0.0,
            entropy: 0.0,
            ip_reputation_score: 0.0,
            geo_risk_score: 0.0,
            time_of_day: 0.0,
            request_frequency: 0.0,
            user_agent_entropy: 0.0,
        };
        
        // Run all feature extractors
        for extractor in &self.feature_extractors {
            let features = extractor.extract(payload, metadata);
            // Combine features (simplified - in practice, you'd have more sophisticated combination)
            combined_features.request_length = features.request_length;
            combined_features.special_char_ratio = features.special_char_ratio;
            combined_features.sql_keyword_count = features.sql_keyword_count;
            combined_features.script_tag_count = features.script_tag_count;
            combined_features.entropy = features.entropy;
            combined_features.ip_reputation_score = features.ip_reputation_score;
            combined_features.geo_risk_score = features.geo_risk_score;
            combined_features.time_of_day = features.time_of_day;
            combined_features.request_frequency = features.request_frequency;
            combined_features.user_agent_entropy = features.user_agent_entropy;
        }
        
        combined_features
    }
    
    async fn run_model(&self, model: &MLModel, features: &FeatureVector, model_name: &str) -> MLThreatPrediction {
        let start_time = std::time::Instant::now();
        
        // Simulate ML model inference (in practice, this would call actual ML libraries)
        let confidence = match model.model_type {
            ModelType::RandomForest => self.run_random_forest(model, features),
            ModelType::NeuralNetwork => self.run_neural_network(model, features),
            ModelType::SVM => self.run_svm(model, features),
            ModelType::XGBoost => self.run_xgboost(model, features),
            ModelType::DeepLearning => self.run_deep_learning(model, features),
            ModelType::Ensemble => self.run_ensemble(model, features),
        };
        
        let threat_type = self.determine_threat_type(model_name, confidence);
        let severity = self.calculate_severity(confidence);
        
        MLThreatPrediction {
            threat_type,
            confidence,
            severity,
            features_used: vec![
                "request_length".to_string(),
                "special_char_ratio".to_string(),
                "sql_keyword_count".to_string(),
                "script_tag_count".to_string(),
                "entropy".to_string(),
            ],
            model_version: model.version.clone(),
            prediction_time_ms: start_time.elapsed().as_millis() as u64,
        }
    }
    
    fn run_random_forest(&self, model: &MLModel, features: &FeatureVector) -> f64 {
        // Simplified Random Forest implementation
        let feature_values = vec![
            features.request_length,
            features.special_char_ratio,
            features.sql_keyword_count,
            features.script_tag_count,
            features.entropy,
            features.ip_reputation_score,
        ];
        
        let mut weighted_sum = 0.0;
        for (i, &weight) in model.weights.iter().enumerate() {
            if i < feature_values.len() {
                weighted_sum += weight * feature_values[i];
            }
        }
        
        // Apply sigmoid activation
        1.0 / (1.0 + (-weighted_sum).exp())
    }
    
    fn run_neural_network(&self, model: &MLModel, features: &FeatureVector) -> f64 {
        // Simplified Neural Network implementation
        let input = vec![
            features.script_tag_count,
            features.special_char_ratio,
            features.entropy,
            features.user_agent_entropy,
        ];
        
        let mut output = 0.0;
        for (i, &weight) in model.weights.iter().enumerate() {
            if i < input.len() {
                output += weight * input[i].tanh(); // Tanh activation
            }
        }
        
        output.max(0.0).min(1.0) // Clamp to [0, 1]
    }
    
    fn run_svm(&self, model: &MLModel, features: &FeatureVector) -> f64 {
        // Simplified SVM implementation
        let feature_vector = vec![
            features.request_frequency,
            features.time_of_day,
            features.geo_risk_score,
            features.ip_reputation_score,
            features.entropy,
            features.special_char_ratio,
        ];
        
        let mut decision_value = 0.0;
        for (i, &weight) in model.weights.iter().enumerate() {
            if i < feature_vector.len() {
                decision_value += weight * feature_vector[i];
            }
        }
        
        // Convert SVM decision value to probability
        1.0 / (1.0 + (-decision_value).exp())
    }
    
    fn run_xgboost(&self, _model: &MLModel, features: &FeatureVector) -> f64 {
        // Simplified XGBoost-like gradient boosting
        let mut prediction = 0.0;
        
        // Tree 1: Focus on SQL patterns
        if features.sql_keyword_count > 2.0 {
            prediction += 0.3;
        }
        
        // Tree 2: Focus on script patterns
        if features.script_tag_count > 0.0 {
            prediction += 0.25;
        }
        
        // Tree 3: Focus on entropy
        if features.entropy > 4.5 {
            prediction += 0.2;
        }
        
        // Tree 4: Combined features
        if features.special_char_ratio > 0.1 && features.request_length > 100.0 {
            prediction += 0.25;
        }
        
        prediction.min(1.0)
    }
    
    fn run_deep_learning(&self, model: &MLModel, features: &FeatureVector) -> f64 {
        // Simplified deep learning model (multi-layer)
        let layer1_input = vec![
            features.request_length / 1000.0, // Normalize
            features.special_char_ratio,
            features.entropy / 8.0, // Normalize entropy
        ];
        
        // Layer 1: Hidden layer with ReLU activation
        let mut layer1_output = Vec::new();
        for (i, &input) in layer1_input.iter().enumerate() {
            let weight = model.weights.get(i).unwrap_or(&0.5);
            layer1_output.push((input * weight).max(0.0)); // ReLU
        }
        
        // Layer 2: Output layer with sigmoid
        let mut final_output = 0.0;
        for (i, &output) in layer1_output.iter().enumerate() {
            let weight = model.weights.get(i + 3).unwrap_or(&0.3);
            final_output += output * weight;
        }
        
        1.0 / (1.0 + (-final_output).exp()) // Sigmoid
    }
    
    fn run_ensemble(&self, _model: &MLModel, _features: &FeatureVector) -> f64 {
        // Ensemble prediction is handled separately
        0.0
    }
    
    fn create_ensemble_prediction(&self, predictions: &[MLThreatPrediction], total_time_ms: u64) -> MLThreatPrediction {
        let mut weighted_confidence = 0.0;
        let mut max_severity = 0;
        
        for prediction in predictions {
            if let Some(&weight) = self.ensemble_weights.get(&prediction.threat_type) {
                weighted_confidence += prediction.confidence * weight;
                max_severity = max_severity.max(prediction.severity);
            }
        }
        
        MLThreatPrediction {
            threat_type: "ensemble_prediction".to_string(),
            confidence: weighted_confidence,
            severity: max_severity,
            features_used: vec![
                "multi_model_ensemble".to_string(),
                "weighted_voting".to_string(),
                "confidence_aggregation".to_string(),
            ],
            model_version: "ensemble_v2.0".to_string(),
            prediction_time_ms: total_time_ms,
        }
    }
    
    fn determine_threat_type(&self, model_name: &str, confidence: f64) -> String {
        match model_name {
            "sql_injection" if confidence > 0.7 => "SQL Injection".to_string(),
            "xss" if confidence > 0.6 => "Cross-Site Scripting".to_string(),
            "anomaly" if confidence > 0.8 => "Behavioral Anomaly".to_string(),
            "advanced_threats" if confidence > 0.85 => "Advanced Persistent Threat".to_string(),
            _ => "Low Risk".to_string(),
        }
    }
    
    fn calculate_severity(&self, confidence: f64) -> u8 {
        match confidence {
            c if c >= 0.9 => 5, // Critical
            c if c >= 0.7 => 4, // High
            c if c >= 0.5 => 3, // Medium
            c if c >= 0.3 => 2, // Low
            _ => 1,             // Very Low
        }
    }
    
    pub async fn retrain_model(&mut self, model_name: &str, training_data: Vec<(FeatureVector, bool)>) -> Result<(), String> {
        if let Some(model) = self.models.get_mut(model_name) {
            // Simulate model retraining
            println!("🤖 Retraining model: {} with {} samples", model_name, training_data.len());
            
            // Update last trained timestamp
            model.last_trained = chrono::Utc::now();
            
            // Simulate accuracy improvement
            model.accuracy = (model.accuracy + 0.001).min(0.999);
            
            println!("✅ Model {} retrained. New accuracy: {:.3}", model_name, model.accuracy);
            Ok(())
        } else {
            Err(format!("Model {} not found", model_name))
        }
    }
    
    pub fn get_model_stats(&self) -> HashMap<String, (f64, chrono::DateTime<chrono::Utc>)> {
        self.models.iter()
            .map(|(name, model)| (name.clone(), (model.accuracy, model.last_trained)))
            .collect()
    }
}

// Feature Extractors
struct PayloadAnalyzer;

impl FeatureExtractor for PayloadAnalyzer {
    fn extract(&self, payload: &str, _metadata: &EventMetadata) -> FeatureVector {
        let length = payload.len() as f64;
        let special_chars = payload.chars().filter(|c| "!@#$%^&*()[]{}|\\:;\"'<>?".contains(*c)).count() as f64;
        let special_char_ratio = special_chars / length.max(1.0);
        
        let sql_keywords = ["SELECT", "INSERT", "UPDATE", "DELETE", "DROP", "UNION", "OR", "AND"];
        let sql_count = sql_keywords.iter()
            .map(|&keyword| payload.to_uppercase().matches(keyword).count())
            .sum::<usize>() as f64;
        
        let script_count = payload.matches("<script").count() as f64;
        
        // Calculate Shannon entropy
        let mut char_freq = std::collections::HashMap::new();
        for c in payload.chars() {
            *char_freq.entry(c).or_insert(0) += 1;
        }
        let entropy = char_freq.values()
            .map(|&freq| {
                let p = freq as f64 / length;
                -p * p.log2()
            })
            .sum::<f64>();
        
        FeatureVector {
            request_length: length,
            special_char_ratio,
            sql_keyword_count: sql_count,
            script_tag_count: script_count,
            entropy,
            ip_reputation_score: 0.5, // Placeholder
            geo_risk_score: 0.3,      // Placeholder
            time_of_day: 0.0,         // Placeholder
            request_frequency: 0.0,    // Placeholder
            user_agent_entropy: 0.0,   // Placeholder
        }
    }
    
    fn name(&self) -> &str {
        "payload_analyzer"
    }
}

struct NetworkAnalyzer;

impl FeatureExtractor for NetworkAnalyzer {
    fn extract(&self, _payload: &str, metadata: &EventMetadata) -> FeatureVector {
        // Simulate IP reputation lookup
        let ip_reputation = self.calculate_ip_reputation(&metadata.source_ip);
        
        // Simulate geo risk calculation
        let geo_risk = self.calculate_geo_risk(&metadata.source_ip);
        
        FeatureVector {
            request_length: 0.0,
            special_char_ratio: 0.0,
            sql_keyword_count: 0.0,
            script_tag_count: 0.0,
            entropy: 0.0,
            ip_reputation_score: ip_reputation,
            geo_risk_score: geo_risk,
            time_of_day: metadata.timestamp.hour() as f64 / 24.0,
            request_frequency: 0.0, // Would be calculated from historical data
            user_agent_entropy: 0.0,
        }
    }
    
    fn name(&self) -> &str {
        "network_analyzer"
    }
}

impl NetworkAnalyzer {
    fn calculate_ip_reputation(&self, ip: &str) -> f64 {
        // Simulate IP reputation scoring
        match ip {
            ip if ip.starts_with("192.168.") => 0.9, // Local network - high trust
            ip if ip.starts_with("10.") => 0.9,      // Private network
            ip if ip.starts_with("203.0.113.") => 0.1, // TEST-NET-3 (suspicious for demo)
            _ => 0.6, // Default reputation
        }
    }
    
    fn calculate_geo_risk(&self, ip: &str) -> f64 {
        // Simulate geolocation risk scoring
        match ip {
            ip if ip.starts_with("192.168.") => 0.1, // Local - low risk
            ip if ip.starts_with("203.0.113.") => 0.8, // High risk for demo
            _ => 0.4, // Medium risk
        }
    }
}

struct BehavioralAnalyzer;

impl FeatureExtractor for BehavioralAnalyzer {
    fn extract(&self, payload: &str, metadata: &EventMetadata) -> FeatureVector {
        let user_agent_entropy = if let Some(ua) = &metadata.user_agent {
            self.calculate_entropy(ua)
        } else {
            0.0
        };
        
        // Simulate request frequency analysis
        let request_frequency = self.calculate_request_frequency(&metadata.source_ip);
        
        FeatureVector {
            request_length: payload.len() as f64,
            special_char_ratio: 0.0,
            sql_keyword_count: 0.0,
            script_tag_count: 0.0,
            entropy: 0.0,
            ip_reputation_score: 0.0,
            geo_risk_score: 0.0,
            time_of_day: 0.0,
            request_frequency,
            user_agent_entropy,
        }
    }
    
    fn name(&self) -> &str {
        "behavioral_analyzer"
    }
}

impl BehavioralAnalyzer {
    fn calculate_entropy(&self, text: &str) -> f64 {
        let mut char_freq = std::collections::HashMap::new();
        for c in text.chars() {
            *char_freq.entry(c).or_insert(0) += 1;
        }
        
        let length = text.len() as f64;
        char_freq.values()
            .map(|&freq| {
                let p = freq as f64 / length;
                -p * p.log2()
            })
            .sum::<f64>()
    }
    
    fn calculate_request_frequency(&self, _ip: &str) -> f64 {
        // Simulate request frequency calculation
        // In practice, this would query historical data
        0.5 // Placeholder
    }
} 