use std::error::Error;
use std::fmt;
use std::time::{SystemTime, UNIX_EPOCH};

/// Custom error types for Ultra SIEM
#[derive(Debug)]
pub enum SIEMError {
    TimeError(String),
    NetworkError(String),
    DatabaseError(String),
    SerializationError(String),
    ConfigurationError(String),
    ResourceError(String),
    SecurityError(String),
    ValidationError(String),
    InternalError(String),
}

impl fmt::Display for SIEMError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            SIEMError::TimeError(msg) => write!(f, "Time error: {}", msg),
            SIEMError::NetworkError(msg) => write!(f, "Network error: {}", msg),
            SIEMError::DatabaseError(msg) => write!(f, "Database error: {}", msg),
            SIEMError::SerializationError(msg) => write!(f, "Serialization error: {}", msg),
            SIEMError::ConfigurationError(msg) => write!(f, "Configuration error: {}", msg),
            SIEMError::ResourceError(msg) => write!(f, "Resource error: {}", msg),
            SIEMError::SecurityError(msg) => write!(f, "Security error: {}", msg),
            SIEMError::ValidationError(msg) => write!(f, "Validation error: {}", msg),
            SIEMError::InternalError(msg) => write!(f, "Internal error: {}", msg),
        }
    }
}

impl Error for SIEMError {}

impl From<std::time::SystemTimeError> for SIEMError {
    fn from(err: std::time::SystemTimeError) -> Self {
        SIEMError::TimeError(format!("System time error: {}", err))
    }
}

impl From<serde_json::Error> for SIEMError {
    fn from(err: serde_json::Error) -> Self {
        SIEMError::SerializationError(format!("JSON serialization error: {}", err))
    }
}

impl From<std::io::Error> for SIEMError {
    fn from(err: std::io::Error) -> Self {
        SIEMError::ResourceError(format!("I/O error: {}", err))
    }
}

/// Safe time utilities
pub mod time {
    use super::*;

    /// Get current timestamp safely
    pub fn current_timestamp() -> Result<u64, SIEMError> {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .map_err(|e| SIEMError::TimeError(format!("Failed to get current time: {}", e)))
    }

    /// Get current timestamp in nanoseconds
    pub fn current_timestamp_nanos() -> Result<u64, SIEMError> {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_nanos() as u64)
            .map_err(|e| SIEMError::TimeError(format!("Failed to get current time: {}", e)))
    }

    /// Get elapsed time safely
    pub fn elapsed_since(start: SystemTime) -> Result<u64, SIEMError> {
        start
            .elapsed()
            .map(|d| d.as_secs())
            .map_err(|e| SIEMError::TimeError(format!("Failed to calculate elapsed time: {}", e)))
    }
}

/// Safe serialization utilities
pub mod serialization {
    use super::*;

    /// Safe JSON serialization
    pub fn to_json<T: serde::Serialize>(value: &T) -> Result<String, SIEMError> {
        serde_json::to_string(value).map_err(|e| SIEMError::SerializationError(format!("JSON serialization failed: {}", e)))
    }

    /// Safe JSON deserialization
    pub fn from_json<T: serde::de::DeserializeOwned>(json: &str) -> Result<T, SIEMError> {
        serde_json::from_str(json).map_err(|e| SIEMError::SerializationError(format!("JSON deserialization failed: {}", e)))
    }
}

/// Safe resource management
pub mod resources {
    use super::*;
    use std::sync::{Arc, RwLock};

    /// Safe lock acquisition with timeout
    pub fn try_lock<T>(lock: &Arc<RwLock<T>>, timeout_ms: u64) -> Result<std::sync::RwLockReadGuard<T>, SIEMError> {
        let start = SystemTime::now();
        let timeout_duration = std::time::Duration::from_millis(timeout_ms);
        
        loop {
            match lock.try_read() {
                Ok(guard) => return Ok(guard),
                Err(_) => {
                    if start.elapsed().unwrap_or_default() > timeout_duration {
                        return Err(SIEMError::ResourceError("Lock acquisition timeout".to_string()));
                    }
                    std::thread::sleep(std::time::Duration::from_millis(1));
                }
            }
        }
    }

    /// Safe write lock acquisition with timeout
    pub fn try_write_lock<T>(lock: &Arc<RwLock<T>>, timeout_ms: u64) -> Result<std::sync::RwLockWriteGuard<T>, SIEMError> {
        let start = SystemTime::now();
        let timeout_duration = std::time::Duration::from_millis(timeout_ms);
        
        loop {
            match lock.try_write() {
                Ok(guard) => return Ok(guard),
                Err(_) => {
                    if start.elapsed().unwrap_or_default() > timeout_duration {
                        return Err(SIEMError::ResourceError("Write lock acquisition timeout".to_string()));
                    }
                    std::thread::sleep(std::time::Duration::from_millis(1));
                }
            }
        }
    }
}

/// Validation utilities
pub mod validation {
    use super::*;

    /// Validate IP address format
    pub fn validate_ip(ip: &str) -> Result<(), SIEMError> {
        if ip.parse::<std::net::IpAddr>().is_ok() {
            Ok(())
        } else {
            Err(SIEMError::ValidationError(format!("Invalid IP address: {}", ip)))
        }
    }

    /// Validate port number
    pub fn validate_port(port: u16) -> Result<(), SIEMError> {
        if port > 0 && port <= 65535 {
            Ok(())
        } else {
            Err(SIEMError::ValidationError(format!("Invalid port number: {}", port)))
        }
    }

    /// Validate confidence score
    pub fn validate_confidence(confidence: f32) -> Result<(), SIEMError> {
        if confidence >= 0.0 && confidence <= 1.0 {
            Ok(())
        } else {
            Err(SIEMError::ValidationError(format!("Invalid confidence score: {}", confidence)))
        }
    }
}

/// Result type alias for SIEM operations
pub type SIEMResult<T> = Result<T, SIEMError>;

/// Macro for safe unwrapping with context
#[macro_export]
macro_rules! safe_unwrap {
    ($expr:expr, $context:expr) => {
        match $expr {
            Ok(value) => value,
            Err(e) => {
                log::error!("{}: {:?}", $context, e);
                return Err(SIEMError::InternalError(format!("{}: {:?}", $context, e)));
            }
        }
    };
}

/// Macro for safe unwrapping with default value
#[macro_export]
macro_rules! safe_unwrap_or {
    ($expr:expr, $default:expr, $context:expr) => {
        match $expr {
            Ok(value) => value,
            Err(e) => {
                log::warn!("{}: {:?}, using default", $context, e);
                $default
            }
        }
    };
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_current_timestamp() {
        let timestamp = time::current_timestamp().unwrap();
        assert!(timestamp > 0);
    }

    #[test]
    fn test_validation() {
        assert!(validation::validate_ip("192.168.1.1").is_ok());
        assert!(validation::validate_ip("invalid").is_err());
        
        assert!(validation::validate_port(8080).is_ok());
        assert!(validation::validate_port(0).is_err());
        
        assert!(validation::validate_confidence(0.5).is_ok());
        assert!(validation::validate_confidence(1.5).is_err());
    }

    #[test]
    fn test_serialization() {
        let data = serde_json::json!({"test": "value"});
        let json = serialization::to_json(&data).unwrap();
        let parsed: serde_json::Value = serialization::from_json(&json).unwrap();
        assert_eq!(data, parsed);
    }
} 