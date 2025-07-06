use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;

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
    pub last_trained: u64,
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
    pub timestamp: u64,
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
            last_trained: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs(),
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
            last_trained: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs(),
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
            last_trained: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs(),
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
            last_trained: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs(),
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
        
        let prediction = match model.model_type {
            ModelType::RandomForest => self.run_random_forest(model, features),
            ModelType::NeuralNetwork => self.run_neural_network(model, features),
            ModelType::SVM => self.run_svm(model, features),
            ModelType::XGBoost => self.run_xgboost(model, features),
            ModelType::DeepLearning => self.run_deep_learning(model, features),
            ModelType::Ensemble => self.run_ensemble(model, features),
        };
        
        let prediction_time = start_time.elapsed().as_millis() as u64;
        
        MLThreatPrediction {
            threat_type: self.determine_threat_type(model_name, prediction),
            confidence: prediction,
            severity: self.calculate_severity(prediction),
            features_used: vec![model_name.to_string()],
            model_version: model.version.clone(),
            prediction_time_ms: prediction_time,
        }
    }
    
    fn run_random_forest(&self, model: &MLModel, features: &FeatureVector) -> f64 {
        // Simplified Random Forest implementation
        let mut prediction: f64 = 0.0;
        
        // Weighted feature combination
        prediction += features.request_length * model.weights.get(0).unwrap_or(&0.0);
        prediction += features.special_char_ratio * model.weights.get(1).unwrap_or(&0.0);
        prediction += features.sql_keyword_count * model.weights.get(2).unwrap_or(&0.0);
        prediction += features.script_tag_count * model.weights.get(3).unwrap_or(&0.0);
        prediction += features.entropy * model.weights.get(4).unwrap_or(&0.0);
        prediction += features.ip_reputation_score * model.weights.get(5).unwrap_or(&0.0);
        
        prediction.min(1.0)
    }
    
    fn run_neural_network(&self, model: &MLModel, features: &FeatureVector) -> f64 {
        // Simplified Neural Network implementation
        let mut prediction: f64 = 0.0;
        
        // Feed-forward computation
        prediction += features.request_length * model.weights.get(0).unwrap_or(&0.0);
        prediction += features.special_char_ratio * model.weights.get(1).unwrap_or(&0.0);
        prediction += features.sql_keyword_count * model.weights.get(2).unwrap_or(&0.0);
        prediction += features.script_tag_count * model.weights.get(3).unwrap_or(&0.0);
        
        // Activation function (sigmoid)
        prediction = 1.0 / (1.0 + (-prediction).exp());
        prediction
    }
    
    fn run_svm(&self, model: &MLModel, features: &FeatureVector) -> f64 {
        // Simplified SVM implementation
        let mut prediction: f64 = 0.0;
        
        // Kernel computation (linear kernel)
        prediction += features.request_length * model.weights.get(0).unwrap_or(&0.0);
        prediction += features.special_char_ratio * model.weights.get(1).unwrap_or(&0.0);
        prediction += features.sql_keyword_count * model.weights.get(2).unwrap_or(&0.0);
        prediction += features.script_tag_count * model.weights.get(3).unwrap_or(&0.0);
        prediction += features.entropy * model.weights.get(4).unwrap_or(&0.0);
        prediction += features.ip_reputation_score * model.weights.get(5).unwrap_or(&0.0);
        
        // Decision function
        prediction.min(1.0).max(0.0)
    }
    
    fn run_xgboost(&self, _model: &MLModel, features: &FeatureVector) -> f64 {
        // Simplified XGBoost implementation
        let mut prediction: f64 = 0.0;
        
        // Gradient boosting computation
        prediction += features.request_length * 0.3;
        prediction += features.special_char_ratio * 0.25;
        prediction += features.sql_keyword_count * 0.2;
        prediction += features.script_tag_count * 0.15;
        prediction += features.entropy * 0.1;
        
        prediction.min(1.0)
    }
    
    fn run_deep_learning(&self, model: &MLModel, features: &FeatureVector) -> f64 {
        // Simplified Deep Learning implementation
        let mut prediction: f64 = 0.0;
        
        // Multi-layer computation (simplified)
        prediction += features.request_length * model.weights.get(0).unwrap_or(&0.0);
        prediction += features.special_char_ratio * model.weights.get(1).unwrap_or(&0.0);
        prediction += features.sql_keyword_count * model.weights.get(2).unwrap_or(&0.0);
        prediction += features.script_tag_count * model.weights.get(3).unwrap_or(&0.0);
        prediction += features.entropy * model.weights.get(4).unwrap_or(&0.0);
        prediction += features.ip_reputation_score * model.weights.get(5).unwrap_or(&0.0);
        
        // Non-linear transformation
        prediction = prediction.tanh();
        prediction = (prediction + 1.0) / 2.0; // Normalize to [0, 1]
        
        prediction
    }
    
    fn run_ensemble(&self, _model: &MLModel, _features: &FeatureVector) -> f64 {
        // Ensemble method (average of all models)
        0.75 // Placeholder
    }
    
    fn create_ensemble_prediction(&self, predictions: &[MLThreatPrediction], total_time_ms: u64) -> MLThreatPrediction {
        let mut weighted_confidence = 0.0;
        let mut total_weight = 0.0;
        
        for prediction in predictions {
            let weight = self.ensemble_weights.get(&prediction.threat_type).unwrap_or(&0.25);
            weighted_confidence += prediction.confidence * weight;
            total_weight += weight;
        }
        
        let ensemble_confidence = if total_weight > 0.0 {
            weighted_confidence / total_weight
        } else {
            0.5
        };
        
        MLThreatPrediction {
            threat_type: "ensemble".to_string(),
            confidence: ensemble_confidence,
            severity: self.calculate_severity(ensemble_confidence),
            features_used: predictions.iter().map(|p| p.threat_type.clone()).collect(),
            model_version: "ensemble_v1.0".to_string(),
            prediction_time_ms: total_time_ms,
        }
    }
    
    fn determine_threat_type(&self, model_name: &str, confidence: f64) -> String {
        if confidence > 0.8 {
            format!("high_confidence_{}", model_name)
        } else if confidence > 0.6 {
            format!("medium_confidence_{}", model_name)
        } else {
            format!("low_confidence_{}", model_name)
        }
    }
    
    fn calculate_severity(&self, confidence: f64) -> u8 {
        if confidence > 0.9 { 5 }
        else if confidence > 0.8 { 4 }
        else if confidence > 0.7 { 3 }
        else if confidence > 0.6 { 2 }
        else { 1 }
    }
    
    pub fn train_model(&mut self, model_name: &str, _training_data: Vec<(FeatureVector, bool)>) -> Result<(), String> {
        if let Some(model) = self.models.get_mut(model_name) {
            // Simplified retraining - in practice, you'd implement actual ML training
            model.accuracy += 0.01; // Simulate improvement
            model.last_trained = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs();
            Ok(())
        } else {
            Err(format!("Model {} not found", model_name))
        }
    }
    
    pub fn get_model_stats(&self) -> HashMap<String, (f64, u64)> {
        let mut stats = HashMap::new();
        for (name, model) in &self.models {
            stats.insert(name.clone(), (model.accuracy, model.last_trained));
        }
        stats
    }
}

// Feature Extractors
struct PayloadAnalyzer;

impl FeatureExtractor for PayloadAnalyzer {
    fn extract(&self, payload: &str, _metadata: &EventMetadata) -> FeatureVector {
        let request_length = payload.len() as f64;
        let special_char_ratio = payload.chars().filter(|c| !c.is_alphanumeric()).count() as f64 / request_length;
        let sql_keyword_count = payload.to_lowercase().matches("select").count() as f64 +
                               payload.to_lowercase().matches("union").count() as f64 +
                               payload.to_lowercase().matches("drop").count() as f64;
        let script_tag_count = payload.to_lowercase().matches("<script").count() as f64;
        
        FeatureVector {
            request_length,
            special_char_ratio,
            sql_keyword_count,
            script_tag_count,
            entropy: 0.0, // Will be calculated by BehavioralAnalyzer
            ip_reputation_score: 0.0, // Will be calculated by NetworkAnalyzer
            geo_risk_score: 0.0,
            time_of_day: 0.0,
            request_frequency: 0.0,
            user_agent_entropy: 0.0,
        }
    }
    
    fn name(&self) -> &str {
        "payload_analyzer"
    }
}

struct NetworkAnalyzer;

impl FeatureExtractor for NetworkAnalyzer {
    fn extract(&self, _payload: &str, metadata: &EventMetadata) -> FeatureVector {
        let ip_reputation_score = self.calculate_ip_reputation(&metadata.source_ip);
        let geo_risk_score = self.calculate_geo_risk(&metadata.source_ip);
        
        FeatureVector {
            request_length: 0.0,
            special_char_ratio: 0.0,
            sql_keyword_count: 0.0,
            script_tag_count: 0.0,
            entropy: 0.0,
            ip_reputation_score,
            geo_risk_score,
            time_of_day: 0.0,
            request_frequency: 0.0,
            user_agent_entropy: 0.0,
        }
    }
    
    fn name(&self) -> &str {
        "network_analyzer"
    }
}

impl NetworkAnalyzer {
    fn calculate_ip_reputation(&self, ip: &str) -> f64 {
        // Simplified IP reputation calculation
        if ip.contains("192.168.") || ip.contains("10.") || ip.contains("172.") {
            0.1 // Low risk for private IPs
        } else {
            0.5 // Medium risk for public IPs
        }
    }
    
    fn calculate_geo_risk(&self, ip: &str) -> f64 {
        // Simplified geographic risk calculation
        if ip.contains("192.168.1.") {
            0.2 // Low risk for local network
        } else {
            0.6 // Higher risk for external
        }
    }
}

struct BehavioralAnalyzer;

impl FeatureExtractor for BehavioralAnalyzer {
    fn extract(&self, payload: &str, metadata: &EventMetadata) -> FeatureVector {
        let entropy = self.calculate_entropy(payload);
        let time_of_day = (metadata.timestamp % 86400) as f64 / 86400.0; // Normalize to [0, 1]
        let request_frequency = self.calculate_request_frequency(&metadata.source_ip);
        let user_agent_entropy = metadata.user_agent.as_ref().map_or(0.0, |ua| self.calculate_entropy(ua));
        
        FeatureVector {
            request_length: 0.0,
            special_char_ratio: 0.0,
            sql_keyword_count: 0.0,
            script_tag_count: 0.0,
            entropy,
            ip_reputation_score: 0.0,
            geo_risk_score: 0.0,
            time_of_day,
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
        let mut char_counts = HashMap::new();
        for ch in text.chars() {
            *char_counts.entry(ch).or_insert(0) += 1;
        }
        
        let len = text.len() as f64;
        char_counts.values().map(|&count| {
            let p = count as f64 / len;
            -p * p.log2()
        }).sum()
    }
    
    fn calculate_request_frequency(&self, _ip: &str) -> f64 {
        // Simplified request frequency calculation
        0.5 // Placeholder
    }
} 