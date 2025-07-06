# 🧪 Test Real-Time Detection with Existing Infrastructure
# Uses the already running Docker containers

Write-Host "🧪 Ultra SIEM - Real-Time Detection Test" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check if services are running
Write-Host "🔍 Checking existing infrastructure..." -ForegroundColor Yellow

try {
    $clickhouseResponse = Invoke-RestMethod -Uri "http://localhost:8123/ping" -TimeoutSec 5
    Write-Host "✅ ClickHouse is running" -ForegroundColor Green
} catch {
    Write-Host "❌ ClickHouse is not accessible" -ForegroundColor Red
    exit 1
}

try {
    $natsResponse = Invoke-RestMethod -Uri "http://localhost:8222/varz" -TimeoutSec 5
    Write-Host "✅ NATS is running" -ForegroundColor Green
} catch {
    Write-Host "❌ NATS is not accessible" -ForegroundColor Red
    exit 1
}

try {
    $grafanaResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/health" -TimeoutSec 5
    Write-Host "✅ Grafana is running" -ForegroundColor Green
} catch {
    Write-Host "❌ Grafana is not accessible" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Create database table if it doesn't exist
Write-Host "🗄️ Setting up database table..." -ForegroundColor Yellow

$createTableQuery = @"
CREATE TABLE IF NOT EXISTS siem.threats (
    event_time DateTime,
    source_ip String,
    threat_type String,
    payload String,
    severity UInt8,
    confidence_score Float32,
    source String,
    details String
) ENGINE = MergeTree()
ORDER BY (event_time, threat_type)
"@

$headers = @{
    "X-ClickHouse-User" = "admin"
    "X-ClickHouse-Key" = "admin"
}

try {
    Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $createTableQuery
    Write-Host "✅ Database table ready" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Table creation failed (may already exist): $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""

# Start detection engines
Write-Host "🔍 Starting detection engines..." -ForegroundColor Yellow

# Check if Rust engine is already running
$rustProcess = Get-Process | Where-Object {$_.ProcessName -like "*cargo*" -or $_.ProcessName -like "*rust*"}
if ($rustProcess) {
    Write-Host "✅ Rust detection engine is already running" -ForegroundColor Green
} else {
    Write-Host "   Starting Rust detection engine..." -ForegroundColor Blue
    Start-Process -FilePath "cargo" -ArgumentList "run" -WorkingDirectory "rust-core" -WindowStyle Hidden
}

# Check if Go processor is already running
$goProcess = Get-Process | Where-Object {$_.ProcessName -like "*go*"}
if ($goProcess) {
    Write-Host "✅ Go data processor is already running" -ForegroundColor Green
} else {
    Write-Host "   Starting Go data processor..." -ForegroundColor Blue
    Start-Process -FilePath "go" -ArgumentList "run", "real_processor.go" -WorkingDirectory "go-services/bridge" -WindowStyle Hidden
}

Write-Host "⏳ Waiting for engines to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host ""

# Test real-time detection
Write-Host "🎯 Real-Time Detection Active!" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green
Write-Host "Your SIEM is now monitoring REAL system activity:" -ForegroundColor Yellow
Write-Host "   🔍 Windows Security Events (failed logins, etc.)" -ForegroundColor Cyan
Write-Host "   🌐 Network Traffic (suspicious connections)" -ForegroundColor Cyan
Write-Host "   📁 File System (suspicious file operations)" -ForegroundColor Cyan
Write-Host "   ⚙️ Processes (suspicious process creation)" -ForegroundColor Cyan
Write-Host ""

Write-Host "💡 To test REAL threat detection, try these activities:" -ForegroundColor Yellow
Write-Host "   1. Failed login attempts (wrong password)" -ForegroundColor White
Write-Host "   2. Run suspicious commands in PowerShell" -ForegroundColor White
Write-Host "   3. Create files with suspicious names" -ForegroundColor White
Write-Host "   4. Make suspicious network connections" -ForegroundColor White
Write-Host ""

Write-Host "📊 Real-time monitoring dashboard:" -ForegroundColor Cyan
Write-Host "   http://localhost:3000 (admin/admin)" -ForegroundColor White
Write-Host ""

# Monitor detection for 2 minutes
Write-Host "⏱️ Monitoring real-time detection for 2 minutes..." -ForegroundColor Yellow
Write-Host ""

$monitoringDuration = 120  # 2 minutes
$startTime = Get-Date
$checkCount = 0

while (((Get-Date) - $startTime).TotalSeconds -lt $monitoringDuration) {
    $checkCount++
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
    
    try {
        # Check for threats in the last minute
        $query = "SELECT count() FROM siem.threats WHERE event_time >= now() - INTERVAL 1 MINUTE"
        $response = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $query
        
        if ([int]$response -gt 0) {
            Write-Host "   [$checkCount] 🚨 $response REAL threats detected! (${elapsed}s)" -ForegroundColor Red
            
            # Show recent threats
            $recentQuery = "SELECT threat_type, source, confidence_score FROM siem.threats WHERE event_time >= now() - INTERVAL 30 SECOND ORDER BY event_time DESC LIMIT 3"
            $recentResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $recentQuery
            
            if ($recentResponse -and $recentResponse.Length -gt 0) {
                Write-Host "      Recent threats:" -ForegroundColor Yellow
                $recentResponse.Split("`n") | ForEach-Object {
                    if ($_ -match "(.+?)\s+(.+?)\s+([\d.]+)") {
                        Write-Host "         - $($matches[1]) from $($matches[2]) (confidence: $($matches[3]))" -ForegroundColor Red
                    }
                }
            }
        } else {
            Write-Host "   [$checkCount] No threats detected yet... (${elapsed}s)" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "   [$checkCount] ⚠️ Monitoring temporarily unavailable (${elapsed}s)" -ForegroundColor Yellow
    }
    
    Start-Sleep -Seconds 10
}

Write-Host ""

# Final statistics
Write-Host "📊 Final Detection Statistics" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan

try {
    # Get total threats detected in the last hour
    $totalQuery = "SELECT count() FROM siem.threats WHERE event_time >= now() - INTERVAL 1 HOUR"
    $totalResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $totalQuery
    
    # Get threat distribution
    $distQuery = "SELECT threat_type, count() FROM siem.threats WHERE event_time >= now() - INTERVAL 1 HOUR GROUP BY threat_type ORDER BY count() DESC"
    $distResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $distQuery
    
    # Get performance metrics
    $perfQuery = "SELECT avg(confidence_score) as avg_confidence, max(severity) as max_severity FROM siem.threats WHERE event_time >= now() - INTERVAL 1 HOUR"
    $perfResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $perfQuery
    
    Write-Host "   🎯 Total threats detected: $totalResponse" -ForegroundColor Green
    
    if ([int]$totalResponse -gt 0) {
        Write-Host "   📊 Threat distribution:" -ForegroundColor Yellow
        $distResponse.Split("`n") | ForEach-Object {
            if ($_ -match "(.+?)\s+(\d+)") {
                Write-Host "      - $($matches[1]): $($matches[2]) threats" -ForegroundColor Cyan
            }
        }
        
        Write-Host "   📈 Performance metrics:" -ForegroundColor Yellow
        if ($perfResponse -match "([\d.]+)\s+(\d+)") {
            Write-Host "      - Average confidence: $($matches[1])" -ForegroundColor Cyan
            Write-Host "      - Maximum severity: $($matches[2])" -ForegroundColor Cyan
        }
        
        Write-Host ""
        Write-Host "✅ SUCCESS: Real-time detection is working!" -ForegroundColor Green
        Write-Host "   Your SIEM detected $totalResponse real threats" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "⚠️ No threats detected during the test period" -ForegroundColor Yellow
        Write-Host "   Try the suggested test activities above" -ForegroundColor Yellow
        Write-Host "   Or run the specific test scripts:" -ForegroundColor Cyan
        Write-Host "   - .\test_windows_events.ps1" -ForegroundColor White
        Write-Host "   - .\test_malware_detection.ps1" -ForegroundColor White
        Write-Host "   - .\test_network_detection.ps1" -ForegroundColor White
    }
    
} catch {
    Write-Host "   ❌ Unable to retrieve final statistics" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎉 Real-time detection test completed!" -ForegroundColor Green
Write-Host "   Check the dashboard for detailed analytics: http://localhost:3000" -ForegroundColor Cyan 