use std::sync::Arc;
use tokio::sync::RwLock;
use log::{info, warn, error};
use serde::{Deserialize, Serialize};
use thiserror::Error;
use std::collections::HashMap;
use std::time::{Duration, Instant};

#[cfg(all(feature = "cuda", not(windows)))]
use cuda::runtime::*;
#[cfg(all(feature = "nvml", not(windows)))]
use nvml::*;
#[cfg(all(feature = "gpu-allocator", not(windows)))]
use gpu_allocator::*;

#[derive(Debug, Error)]
pub enum GpuError {
    #[error("CUDA not available")]
    CudaNotAvailable,
    #[error("NVML not available")]
    NvmlNotAvailable,
    #[error("GPU memory allocation failed")]
    MemoryAllocationFailed,
    #[error("GPU operation failed: {0}")]
    OperationFailed(String),
    #[error("ML inference not available on this platform")]
    MlNotAvailable,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GPUPerformanceProfile {
    pub gpu_utilization: f32,
    pub memory_usage: f32,
    pub temperature: f32,
    pub power_usage: f32,
    pub fan_speed: f32,
    pub clock_speed: f32,
    pub memory_clock: f32,
    pub processing_time_ms: f32,
    pub events_processed: u64,
    pub throughput_events_per_sec: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GPUDevice {
    pub id: u32,
    pub name: String,
    pub memory_total: u64,
    pub memory_free: u64,
    pub compute_capability: String,
    pub driver_version: String,
    pub is_available: bool,
}

pub struct UniversalNvidiaGPUEngine {
    devices: Vec<GPUDevice>,
    selected_device: Option<u32>,
    performance_profile: Arc<RwLock<GPUPerformanceProfile>>,
    is_initialized: bool,
}

impl UniversalNvidiaGPUEngine {
    pub fn new() -> Self {
        Self {
            devices: Vec::new(),
            selected_device: None,
            performance_profile: Arc::new(RwLock::new(GPUPerformanceProfile {
                gpu_utilization: 0.0,
                memory_usage: 0.0,
                temperature: 0.0,
                power_usage: 0.0,
                fan_speed: 0.0,
                clock_speed: 0.0,
                memory_clock: 0.0,
                processing_time_ms: 0.0,
                events_processed: 0,
                throughput_events_per_sec: 0.0,
            })),
            is_initialized: false,
        }
    }

    pub fn initialize(&mut self) -> Result<(), GpuError> {
        if self.is_initialized {
            return Ok(());
        }

        // Initialize NVML
        self.initialize_nvml()?;

        // Detect available GPUs
        self.devices = self.detect_gpus();

        if self.devices.is_empty() {
            return Err(GpuError::CudaNotAvailable);
        }

        // Select the best GPU
        self.select_best_gpu()?;

        self.is_initialized = true;
        Ok(())
    }

    fn initialize_nvml(&self) -> Result<(), GpuError> {
        #[cfg(all(feature = "nvml", not(windows)))]
        {
            nvml::init().map_err(|_| GpuError::NvmlNotAvailable)?;
        }
        #[cfg(any(windows, not(feature = "nvml")))]
        {
            // NVML not available on Windows or without feature
            return Err(GpuError::NvmlNotAvailable);
        }
        Ok(())
    }

    pub fn process_events_gpu(&self, events: &Vec<Vec<u8>>) -> Vec<u8> {
        if !self.is_initialized || self.selected_device.is_none() {
            return self.process_events_cpu(events);
        }

        self.process_events_gpu_impl(events)
    }

    fn process_events_cpu(&self, events: &Vec<Vec<u8>>) -> Vec<u8> {
        // CPU fallback implementation
        events.iter().flat_map(|event| event.clone()).collect()
    }

    fn process_events_gpu_impl(&self, events: &Vec<Vec<u8>>) -> Vec<u8> {
        // GPU implementation would go here
        // For now, return CPU fallback
        self.process_events_cpu(events)
    }

    pub fn get_gpu_stats(&self) -> GPUPerformanceProfile {
        self.performance_profile.blocking_read().clone()
    }

    pub fn detect_gpus(&self) -> Vec<GPUDevice> {
        let mut devices = Vec::new();
        
        #[cfg(all(feature = "nvml", not(windows)))]
        {
            if let Ok(nvml) = nvml::init() {
                if let Ok(device_count) = nvml.device_count() {
                    for i in 0..device_count {
                        if let Ok(device) = nvml.device_by_index(i) {
                            if let Ok(name) = device.name() {
                                let memory_info = device.memory_info().unwrap_or_default();
                                let compute_mode = device.compute_mode().unwrap_or_default();
                                
                                devices.push(GPUDevice {
                                    id: i,
                                    name: name,
                                    memory_total: memory_info.total,
                                    memory_free: memory_info.free,
                                    compute_capability: format!("{:?}", compute_mode),
                                    driver_version: "Unknown".to_string(),
                                    is_available: true,
                                });
                            }
                        }
                    }
                }
            }
        }
        
        devices
    }

    pub fn select_best_gpu(&mut self) -> Result<u32, GpuError> {
        if self.devices.is_empty() {
            return Err(GpuError::CudaNotAvailable);
        }

        // Select the first available GPU
        self.selected_device = Some(self.devices[0].id);
        Ok(self.devices[0].id)
    }

    pub fn get_active_gpu(&self) -> Option<GPUDevice> {
        if let Some(device_id) = self.selected_device {
            self.devices.iter().find(|d| d.id == device_id).cloned()
        } else {
            None
        }
    }
}

#[cfg(windows)]
pub enum TemperatureSensor {
    Gpu,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GpuInfo {
    pub name: String,
    pub memory_total: u64,
    pub memory_free: u64,
    pub compute_capability: String,
    pub driver_version: String,
    pub temperature: u32,
    pub utilization: u32,
    pub power_usage: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GpuMetrics {
    pub timestamp: u64,
    pub gpu_id: u32,
    pub memory_used: u64,
    pub memory_free: u64,
    pub utilization: u32,
    pub temperature: u32,
    pub power_usage: u32,
    pub throughput: f64,
}

pub struct GpuEngine {
    gpus: Vec<GpuInfo>,
    metrics_history: Arc<RwLock<Vec<GpuMetrics>>>,
    is_available: bool,
}

impl GpuEngine {
    pub fn new() -> Result<Self, GpuError> {
        let mut gpus = Vec::new();
        let mut is_available = false;

        #[cfg(all(feature = "nvml", not(windows)))]
        {
            match nvml::init() {
                Ok(nvml) => {
                    match nvml.device_count() {
                        Ok(count) => {
                            info!("Found {} NVIDIA GPUs", count);
                            is_available = true;

                            for i in 0..count {
                                if let Ok(device) = nvml.device_by_index(i) {
                                    if let Ok(name) = device.name() {
                                        if let Ok(memory) = device.memory_info() {
                                            if let Ok(compute_cap) = device.compute_mode() {
                                                if let Ok(driver) = nvml.driver_version() {
                                                    let gpu_info = GpuInfo {
                                                        name: name.clone(),
                                                        memory_total: memory.total,
                                                        memory_free: memory.free,
                                                        compute_capability: format!("{:?}", compute_cap),
                                                        driver_version: driver,
                                                        temperature: device.temperature(TemperatureSensor::Gpu).unwrap_or(0),
                                                        utilization: device.utilization_rates().unwrap_or_default().gpu,
                                                        power_usage: device.power_usage().unwrap_or(0),
                                                    };
                                                    gpus.push(gpu_info);
                                                    info!("GPU {}: {} ({} MB)", i, name, memory.total / 1024 / 1024);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Err(e) => {
                            warn!("Failed to get GPU count: {}", e);
                        }
                    }
                }
                Err(e) => {
                    warn!("NVML initialization failed: {}", e);
                }
            }
        }

        #[cfg(not(feature = "nvml"))]
        {
            warn!("NVML feature not enabled - GPU acceleration not available");
        }

        Ok(GpuEngine {
            gpus,
            metrics_history: Arc::new(RwLock::new(Vec::new())),
            is_available,
        })
    }

    pub fn is_available(&self) -> bool {
        self.is_available
    }

    pub fn get_gpu_count(&self) -> usize {
        self.gpus.len()
    }

    pub fn get_gpu_info(&self, gpu_id: usize) -> Option<&GpuInfo> {
        self.gpus.get(gpu_id)
    }

    pub async fn get_metrics(&self, gpu_id: usize) -> Option<GpuMetrics> {
        if gpu_id >= self.gpus.len() {
            return None;
        }

        #[cfg(all(feature = "nvml", not(windows)))]
        {
            if let Ok(nvml) = nvml::init() {
                if let Ok(device) = nvml.device_by_index(gpu_id as u32) {
                    let timestamp = std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .unwrap_or_default()
                        .as_secs();

                    let memory_info = device.memory_info().unwrap_or_default();
                    let utilization = device.utilization_rates().unwrap_or_default();
                    let temperature = device.temperature(TemperatureSensor::Gpu).unwrap_or(0);
                    let power_usage = device.power_usage().unwrap_or(0);

                    let metrics = GpuMetrics {
                        timestamp,
                        gpu_id: gpu_id as u32,
                        memory_used: memory_info.total - memory_info.free,
                        memory_free: memory_info.free,
                        utilization: utilization.gpu,
                        temperature,
                        power_usage,
                        throughput: 0.0, // Will be calculated based on operations
                    };

                    // Store in history
                    let mut history = self.metrics_history.write().await;
                    history.push(metrics.clone());
                    
                    // Keep only last 1000 metrics
                    if history.len() > 1000 {
                        history.remove(0);
                    }

                    return Some(metrics);
                }
            }
        }

        None
    }

    pub async fn process_events_gpu(&self, events: &[Vec<u8>]) -> Result<Vec<Vec<u8>>, GpuError> {
        if !self.is_available {
            return Err(GpuError::CudaNotAvailable);
        }

        if events.is_empty() {
            return Ok(Vec::new());
        }

        // For now, return CPU fallback
        // In a real implementation, this would use CUDA kernels
        warn!("GPU processing not fully implemented, using CPU fallback");
        Ok(events.to_vec())
    }

    pub async fn ml_inference(&self, input: &[f32]) -> Result<Vec<f32>, GpuError> {
        // ML inference is not available on Windows due to dependency issues
        // Return CPU fallback
        warn!("ML inference not available on this platform, using CPU fallback");
        
        // Simple CPU-based inference simulation
        let mut output = Vec::with_capacity(input.len());
        for &value in input {
            // Simple transformation as fallback
            output.push(value * 2.0 + 1.0);
        }
        
        Ok(output)
    }

    pub async fn get_performance_stats(&self) -> HashMap<String, f64> {
        let mut stats = HashMap::new();
        
        if !self.is_available {
            stats.insert("gpu_available".to_string(), 0.0);
            return stats;
        }

        stats.insert("gpu_available".to_string(), 1.0);
        stats.insert("gpu_count".to_string(), self.gpus.len() as f64);

        // Calculate average metrics
        let history = self.metrics_history.read().await;
        if !history.is_empty() {
            let recent_metrics: Vec<_> = history.iter()
                .filter(|m| m.timestamp > std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_secs() - 300) // Last 5 minutes
                .collect();

            if !recent_metrics.is_empty() {
                let avg_utilization: f64 = recent_metrics.iter()
                    .map(|m| m.utilization as f64)
                    .sum::<f64>() / recent_metrics.len() as f64;
                
                let avg_temperature: f64 = recent_metrics.iter()
                    .map(|m| m.temperature as f64)
                    .sum::<f64>() / recent_metrics.len() as f64;

                stats.insert("avg_gpu_utilization".to_string(), avg_utilization);
                stats.insert("avg_gpu_temperature".to_string(), avg_temperature);
            }
        }

        stats
    }

    pub fn get_gpu_memory_info(&self, gpu_id: usize) -> Option<(u64, u64)> {
        if gpu_id >= self.gpus.len() {
            return None;
        }

        let gpu = &self.gpus[gpu_id];
        Some((gpu.memory_total, gpu.memory_free))
    }

    pub async fn cleanup(&self) {
        info!("Cleaning up GPU engine resources");
        // Cleanup would go here in a real implementation
    }

    pub fn get_gpu_utilization(&self) -> f32 {
        #[cfg(all(feature = "nvml", not(windows)))]
        {
            if let Ok(nvml) = nvml::init() {
                if let Ok(device_count) = nvml.device_count() {
                    if device_count > 0 {
                        if let Ok(device) = nvml.device_by_index(0) {
                            if let Ok(utilization) = device.utilization_rates() {
                                return utilization.gpu as f32;
                            }
                        }
                    }
                }
            }
        }
        #[cfg(any(windows, not(feature = "nvml")))]
        {
            // NVML not available, use CPU fallback
            0.0
        }
    }
}

impl Default for GpuEngine {
    fn default() -> Self {
        GpuEngine::new().unwrap_or_else(|_| GpuEngine {
            gpus: Vec::new(),
            metrics_history: Arc::new(RwLock::new(Vec::new())),
            is_available: false,
        })
    }
}

// CPU fallback implementations
pub struct CpuFallback;

impl CpuFallback {
    pub async fn process_events_cpu(events: &[Vec<u8>]) -> Vec<Vec<u8>> {
        // Simple CPU-based event processing
        events.iter().map(|event| {
            // Add processing timestamp
            let mut processed = event.clone();
            let timestamp = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs();
            
            // In a real implementation, this would do actual processing
            processed.extend_from_slice(&timestamp.to_le_bytes());
            processed
        }).collect()
    }

    pub async fn ml_inference_cpu(input: &[f32]) -> Vec<f32> {
        // Simple CPU-based ML inference simulation
        input.iter().map(|&x| {
            // Simple neural network simulation
            x * 2.0 + 1.0
        }).collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_gpu_engine_creation() {
        let engine = GpuEngine::new();
        assert!(engine.is_ok() || !engine.unwrap().is_available());
    }

    #[tokio::test]
    async fn test_cpu_fallback() {
        let test_data = vec![1.0, 2.0, 3.0];
        let result = CpuFallback::ml_inference_cpu(&test_data).await;
        assert_eq!(result.len(), test_data.len());
    }

    #[tokio::test]
    async fn test_event_processing_fallback() {
        let test_events = vec![vec![1, 2, 3], vec![4, 5, 6]];
        let result = CpuFallback::process_events_cpu(&test_events).await;
        assert_eq!(result.len(), test_events.len());
    }
} 