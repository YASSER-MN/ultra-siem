//! # Error Handling Module
//! 
//! This module provides comprehensive error handling for the Ultra SIEM system.
//! It defines custom error types, result aliases, and utility functions for
//! consistent error management across all components.
//! 
//! ## Features
//! - Custom `SIEMError` enum with all possible error types
//! - Type alias `SIEMResult<T>` for consistent error handling
//! - Time utility functions with error handling
//! - Automatic conversion from common error types
//! 
//! ## Usage
//! ```rust
//! use siem_rust_core::error_handling::{SIEMResult, SIEMError};
//! 
//! fn process_data() -> SIEMResult<String> {
//!     // Your processing logic here
//!     Ok("processed data".to_string())
//! }
//! ```

use std::time::SystemTimeError;
use serde_json;
use std::io;
use async_nats::SubscribeError;
use async_nats::PublishError;

/// Comprehensive error types for Ultra SIEM operations
/// 
/// This enum covers all possible error scenarios that can occur
/// during SIEM operations, including system errors, network issues,
/// configuration problems, and application-specific errors.
#[derive(Debug, thiserror::Error)]
pub enum SIEMError {
    /// System time related errors (e.g., clock issues)
    #[error("System time error: {0}")]
    SystemTime(#[from] SystemTimeError),
    
    /// JSON serialization/deserialization errors
    #[error("JSON serialization error: {0}")]
    Json(#[from] serde_json::Error),
    
    /// Input/Output errors (file operations, network I/O)
    #[error("IO error: {0}")]
    Io(#[from] io::Error),
    
    /// NATS messaging subscription errors
    #[error("NATS subscription error: {0}")]
    NatsSubscribe(#[from] SubscribeError),
    
    /// NATS messaging publish errors
    #[error("NATS publish error: {0}")]
    NatsPublish(#[from] PublishError),
    
    /// Configuration-related errors (invalid settings, missing config)
    #[error("Configuration error: {0}")]
    Config(String),
    
    /// Database operation errors (ClickHouse, etc.)
    #[error("Database error: {0}")]
    Database(String),
    
    /// Authentication and authorization errors
    #[error("Authentication error: {0}")]
    Auth(String),
    
    /// Data validation errors (invalid input, format issues)
    #[error("Validation error: {0}")]
    Validation(String),
    
    /// Threat detection specific errors
    #[error("Threat detection error: {0}")]
    ThreatDetection(String),
    
    /// Event correlation errors
    #[error("Correlation error: {0}")]
    Correlation(String),
    
    /// Performance-related errors (timeouts, resource limits)
    #[error("Performance error: {0}")]
    Performance(String),
    
    /// Unknown or unclassified errors
    #[error("Unknown error: {0}")]
    Unknown(String),
    
    /// Generic error wrapper for other error types
    #[error("Other error: {0}")]
    Other(String),
}

/// Type alias for SIEM operations that can fail
/// 
/// This provides a consistent way to handle errors across all
/// SIEM components. All public functions should use this type
/// for their return values.
pub type SIEMResult<T> = Result<T, SIEMError>;

impl From<String> for SIEMError {
    /// Convert a String to SIEMError::Other
    fn from(e: String) -> Self {
        SIEMError::Other(e)
    }
}

impl From<reqwest::Error> for SIEMError {
    /// Convert a reqwest HTTP error to SIEMError::Other
    fn from(e: reqwest::Error) -> Self {
        SIEMError::Other(e.to_string())
    }
}

/// Time utility functions with error handling
pub mod time {
    use super::*;
    
    /// Get current Unix timestamp in seconds
    /// 
    /// Returns the number of seconds since Unix epoch (January 1, 1970).
    /// This function handles system time errors gracefully.
    /// 
    /// # Returns
    /// - `SIEMResult<u64>`: Current timestamp in seconds, or error
    /// 
    /// # Examples
    /// ```rust
    /// use siem_rust_core::error_handling::time;
    /// 
    /// match time::current_timestamp() {
    ///     Ok(timestamp) => println!("Current time: {}", timestamp),
    ///     Err(e) => eprintln!("Time error: {}", e),
    /// }
    /// ```
    pub fn current_timestamp() -> SIEMResult<u64> {
        Ok(std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_err(SIEMError::SystemTime)?
            .as_secs())
    }
    
    /// Get current Unix timestamp in milliseconds
    /// 
    /// Returns the number of milliseconds since Unix epoch (January 1, 1970).
    /// This provides higher precision than `current_timestamp()`.
    /// 
    /// # Returns
    /// - `SIEMResult<u128>`: Current timestamp in milliseconds, or error
    /// 
    /// # Examples
    /// ```rust
    /// use siem_rust_core::error_handling::time;
    /// 
    /// match time::current_timestamp_millis() {
    ///     Ok(timestamp) => println!("Current time (ms): {}", timestamp),
    ///     Err(e) => eprintln!("Time error: {}", e),
    /// }
    /// ```
    pub fn current_timestamp_millis() -> SIEMResult<u128> {
        Ok(std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_err(SIEMError::SystemTime)?
            .as_millis())
    }
} 

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_from_string() {
        let err: SIEMError = String::from("custom error").into();
        match err {
            SIEMError::Other(msg) => assert_eq!(msg, "custom error"),
            _ => panic!("Expected SIEMError::Other"),
        }
    }

    #[test]
    fn test_time_utilities() {
        let ts = time::current_timestamp();
        assert!(ts.is_ok());
        let ts_ms = time::current_timestamp_millis();
        assert!(ts_ms.is_ok());
    }

    #[test]
    fn test_error_display() {
        let err = SIEMError::Config("bad config".to_string());
        let msg = format!("{}", err);
        assert!(msg.contains("bad config"));
    }
} 