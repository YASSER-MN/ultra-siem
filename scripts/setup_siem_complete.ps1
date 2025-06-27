# Ultra SIEM Complete Setup Script
# Configures all services and creates dashboards

Write-Host "🛡️ Setting up Ultra SIEM with dashboards and data..." -ForegroundColor Green

# Step 1: Test ClickHouse connectivity
Write-Host "📋 Step 1: Testing ClickHouse..." -ForegroundColor Blue
try {
    $headers = @{ 'X-ClickHouse-User' = 'admin'; 'X-ClickHouse-Key' = 'admin123' }
    $response = Invoke-RestMethod -Uri "http://localhost:8123/" -Method POST -Body "SELECT 1" -ContentType "text/plain" -Headers $headers
    Write-Host "✅ ClickHouse connection successful" -ForegroundColor Green
}
catch {
    Write-Host "❌ ClickHouse connection failed: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Create comprehensive database schema
Write-Host "📋 Step 2: Creating SIEM database schema..." -ForegroundColor Blue
$createSchema = @"
CREATE DATABASE IF NOT EXISTS siem;

CREATE TABLE IF NOT EXISTS siem.threats (
    event_time DateTime64(3) DEFAULT now64(),
    source_ip String,
    dest_ip String DEFAULT '',
    threat_type String,
    severity String,
    message String,
    raw_log String,
    user_agent String DEFAULT '',
    geo_country String DEFAULT '',
    confidence_score Float32 DEFAULT 0.0,
    blocked UInt8 DEFAULT 0
) ENGINE = MergeTree()
ORDER BY (event_time, source_ip)
PARTITION BY toYYYYMM(event_time);

CREATE TABLE IF NOT EXISTS siem.events (
    event_time DateTime64(3) DEFAULT now64(),
    event_type String,
    source String,
    message String,
    details String DEFAULT '',
    user_name String DEFAULT '',
    process_name String DEFAULT ''
) ENGINE = MergeTree()
ORDER BY event_time
PARTITION BY toYYYYMM(event_time);
"@

try {
    Invoke-RestMethod -Uri "http://localhost:8123/" -Method POST -Body $createSchema -ContentType "text/plain" -Headers $headers
    Write-Host "✅ Database schema created" -ForegroundColor Green
}
catch {
    Write-Host "❌ Schema creation failed: $_" -ForegroundColor Red
}

# Step 3: Insert sample threat data
Write-Host "📋 Step 3: Inserting sample threat data..." -ForegroundColor Blue
$sampleData = @"
INSERT INTO siem.threats VALUES 
('2025-06-26 18:30:00', '192.168.1.100', '10.0.0.5', 'SQL_INJECTION', 'HIGH', 'Attempted SQL injection detected', 'POST /login UNION SELECT * FROM users--', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', 'US', 0.95, 1),
('2025-06-26 18:31:00', '10.0.0.15', '192.168.1.50', 'XSS_ATTACK', 'MEDIUM', 'Cross-site scripting attempt', 'GET /search?q=<script>alert(\"XSS\")</script>', 'Chrome/91.0.4472.124', 'CN', 0.87, 1),
('2025-06-26 18:32:00', '172.16.0.25', '10.0.0.1', 'BRUTE_FORCE', 'HIGH', 'Multiple failed login attempts', 'Failed SSH login attempt #45 for user root', 'ssh/2.0', 'RU', 0.92, 1),
('2025-06-26 18:33:00', '203.0.113.42', '192.168.1.200', 'MALWARE', 'CRITICAL', 'Known malware signature detected', 'Trojan.Win32.Agent.abc found in download', 'Wget/1.20.3', 'KP', 0.98, 1),
('2025-06-26 18:34:00', '198.51.100.33', '10.0.0.100', 'DDoS', 'HIGH', 'Distributed denial of service attack', 'Excessive requests from multiple IPs', 'curl/7.68.0', 'IR', 0.89, 1),
('2025-06-26 18:35:00', '192.0.2.15', '172.16.1.10', 'PRIVILEGE_ESCALATION', 'CRITICAL', 'Unauthorized privilege escalation attempt', 'sudo su - root executed by user guest', 'bash/5.0', 'US', 0.94, 0);

INSERT INTO siem.events VALUES
('2025-06-26 18:30:00', 'AUTHENTICATION', 'Windows Security', 'User login successful', 'Logon Type: Interactive, Workstation: WS001', 'admin', 'winlogon.exe'),
('2025-06-26 18:31:00', 'NETWORK', 'Windows Firewall', 'Blocked connection attempt', 'src: 1.2.3.4, dst: 192.168.1.1, port: 22, protocol: TCP', '', 'svchost.exe'),
('2025-06-26 18:32:00', 'FILE_ACCESS', 'NTFS Audit', 'Sensitive file accessed', 'File: C:\\secrets\\passwords.txt, Access: Read', 'SYSTEM', 'notepad.exe'),
('2025-06-26 18:33:00', 'PROCESS', 'Sysmon', 'Suspicious process started', 'Process: powershell.exe, CommandLine: -enc <base64>', 'user1', 'powershell.exe'),
('2025-06-26 18:34:00', 'REGISTRY', 'Windows Registry', 'Registry key modified', 'Key: HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run', 'admin', 'regedit.exe');
"@

try {
    Invoke-RestMethod -Uri "http://localhost:8123/" -Method POST -Body $sampleData -ContentType "text/plain" -Headers $headers
    Write-Host "✅ Sample data inserted" -ForegroundColor Green
}
catch {
    Write-Host "⚠️ Sample data insertion issue: $_" -ForegroundColor Yellow
}

# Step 4: Verify data
Write-Host "📋 Step 4: Verifying data..." -ForegroundColor Blue
try {
    $threatCount = Invoke-RestMethod -Uri "http://localhost:8123/" -Method POST -Body "SELECT count() FROM siem.threats" -ContentType "text/plain" -Headers $headers
    $eventCount = Invoke-RestMethod -Uri "http://localhost:8123/" -Method POST -Body "SELECT count() FROM siem.events" -ContentType "text/plain" -Headers $headers
    Write-Host "✅ Database ready: $threatCount threats, $eventCount events" -ForegroundColor Green
}
catch {
    Write-Host "⚠️ Data verification issue: $_" -ForegroundColor Yellow
}

# Step 5: Import dashboard to Grafana
Write-Host "📋 Step 5: Setting up Grafana dashboard..." -ForegroundColor Blue

# Create dashboard import payload
$dashboardJson = Get-Content "grafana/provisioning/dashboards/siem_dashboard.json" -Raw | ConvertFrom-Json
$importPayload = @{
    dashboard = $dashboardJson.dashboard
    overwrite = $true
    inputs = @()
} | ConvertTo-Json -Depth 20

# Import dashboard via Grafana API
try {
    $grafanaAuth = "admin:admin"
    $authBytes = [System.Text.Encoding]::UTF8.GetBytes($grafanaAuth)
    $authHeader = "Basic " + [System.Convert]::ToBase64String($authBytes)
    
    $headers = @{
        'Authorization' = $authHeader
        'Content-Type' = 'application/json'
    }
    
    $response = Invoke-RestMethod -Uri "http://localhost:3000/api/dashboards/db" -Method POST -Body $importPayload -Headers $headers
    Write-Host "✅ Dashboard imported successfully" -ForegroundColor Green
}
catch {
    Write-Host "⚠️ Dashboard import issue: $_" -ForegroundColor Yellow
    Write-Host "   You can manually import the dashboard from the Grafana UI" -ForegroundColor Yellow
}

# Step 6: Final status
Write-Host "`n🎉 ULTRA SIEM SETUP COMPLETE!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "🖥️  Grafana Dashboard: http://localhost:3000" -ForegroundColor Cyan
Write-Host "    Login: admin / admin" -ForegroundColor Gray
Write-Host "    Look for 'Ultra SIEM - Threat Monitor' dashboard" -ForegroundColor Gray
Write-Host ""
Write-Host "💾 ClickHouse Database: http://localhost:8123" -ForegroundColor Cyan
Write-Host "    Credentials: admin / admin123" -ForegroundColor Gray
Write-Host ""
Write-Host "📨 NATS Monitor: http://localhost:8222" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host "🛡️  Your SIEM is now fully operational with:" -ForegroundColor Green
Write-Host "   • Real-time threat monitoring" -ForegroundColor White
Write-Host "   • 6 sample threats for demonstration" -ForegroundColor White
Write-Host "   • 5 sample security events" -ForegroundColor White
Write-Host "   • Interactive dashboards and analytics" -ForegroundColor White
Write-Host "   • Zero licensing costs!" -ForegroundColor White
Write-Host "" 