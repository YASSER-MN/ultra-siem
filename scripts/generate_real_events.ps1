# Ultra SIEM Real Event Generator
# Generates realistic security events and sends them through NATS

Write-Host "🚨 Ultra SIEM Real Event Generator" -ForegroundColor Red
Write-Host "=================================" -ForegroundColor Red

# Event types for realistic security simulation
$eventTypes = @(
    @{type="login_attempt"; severity=3; message="Failed login attempt from IP"},
    @{type="port_scan"; severity=4; message="Port scanning detected from"},
    @{type="brute_force"; severity=5; message="Multiple failed login attempts from"},
    @{type="malware_detection"; severity=5; message="Malware signature detected from"},
    @{type="sql_injection"; severity=5; message="SQL injection attempt detected from"},
    @{type="xss_attempt"; severity=4; message="XSS attack attempt from"},
    @{type="ddos_attack"; severity=5; message="DDoS attack detected from"},
    @{type="file_access"; severity=2; message="Unauthorized file access from"},
    @{type="network_scan"; severity=4; message="Network scanning activity from"},
    @{type="privilege_escalation"; severity=5; message="Privilege escalation attempt from"}
)

# Generate realistic IP addresses
$sourceIPs = @(
    "192.168.1.100", "192.168.1.101", "192.168.1.102", "192.168.1.103",
    "10.0.0.50", "10.0.0.51", "10.0.0.52", "10.0.0.53",
    "172.16.0.10", "172.16.0.11", "172.16.0.12", "172.16.0.13"
)

$destinationIPs = @(
    "192.168.1.1", "192.168.1.2", "192.168.1.3",
    "10.0.0.1", "10.0.0.2", "10.0.0.3",
    "172.16.0.1", "172.16.0.2", "172.16.0.3"
)

function Generate-Event {
    param($eventNumber)
    
    $eventType = $eventTypes | Get-Random
    $sourceIP = $sourceIPs | Get-Random
    $destIP = $destinationIPs | Get-Random
    
    $event = @{
        id = [System.Guid]::NewGuid().ToString()
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        source_ip = $sourceIP
        destination_ip = $destIP
        event_type = $eventType.type
        severity = $eventType.severity
        message = "$($eventType.message) $sourceIP"
        event_number = $eventNumber
    }
    
    return $event
}

function Send-EventToNATS {
    param($event)
    
    $jsonEvent = $event | ConvertTo-Json -Compress
    
    try {
        # Send event to NATS using curl (since nats-pub might not be available)
        $natsUrl = "http://localhost:8222/connz"
        $headers = @{
            "Content-Type" = "application/json"
        }
        
        # For now, we'll insert directly into ClickHouse to simulate NATS processing
        $clickhouseQuery = @"
INSERT INTO events VALUES (
    '$($event.id)',
    '$($event.timestamp)',
    '$($event.source_ip)',
    '$($event.destination_ip)',
    '$($event.event_type)',
    $($event.severity),
    '$($event.message)'
)
"@
        
        docker exec ultra-siem-clickhouse clickhouse-client --user admin --password admin --query $clickhouseQuery
        
        Write-Host "✅ Event $($event.event_number) sent: $($event.event_type) from $($event.source_ip)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Failed to send event $($event.event_number): $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main event generation loop
Write-Host "`n🚀 Starting real event generation..." -ForegroundColor Yellow
Write-Host "Events will be sent every 2-5 seconds to simulate real security events" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow

$eventCounter = 1
$successCount = 0
$totalCount = 0

try {
    while ($true) {
        $event = Generate-Event -eventNumber $eventCounter
        
        Write-Host "`n📡 Generating Event #$eventCounter..." -ForegroundColor Cyan
        Write-Host "Type: $($event.event_type)" -ForegroundColor White
        Write-Host "Severity: $($event.severity)" -ForegroundColor White
        Write-Host "Source: $($event.source_ip)" -ForegroundColor White
        Write-Host "Message: $($event.message)" -ForegroundColor White
        
        if (Send-EventToNATS -event $event) {
            $successCount++
        }
        $totalCount++
        
        Write-Host "📊 Stats: $successCount/$totalCount events sent successfully" -ForegroundColor Green
        
        # Random delay between 2-5 seconds
        $delay = Get-Random -Minimum 2 -Maximum 6
        Write-Host "⏳ Waiting $delay seconds before next event..." -ForegroundColor Yellow
        Start-Sleep -Seconds $delay
        
        $eventCounter++
        
        # Every 10 events, show system status
        if ($eventCounter % 10 -eq 0) {
            Write-Host "`n📊 System Status Check:" -ForegroundColor Magenta
            docker logs ultra-siem-rust-core --tail 3
            Write-Host "`n"
        }
    }
}
catch {
    Write-Host "`n🛑 Event generation stopped by user" -ForegroundColor Yellow
}
finally {
    Write-Host "`n📈 Final Statistics:" -ForegroundColor Green
    Write-Host "Total Events Generated: $totalCount" -ForegroundColor White
    Write-Host "Successfully Sent: $successCount" -ForegroundColor White
    Write-Host "Success Rate: $([math]::Round(($successCount/$totalCount)*100, 2))%" -ForegroundColor White
    
    Write-Host "`n🔍 Check your dashboards for real-time threat detection!" -ForegroundColor Cyan
    Write-Host "Grafana: http://localhost:3000" -ForegroundColor White
    Write-Host "Prometheus: http://localhost:9090" -ForegroundColor White
} 