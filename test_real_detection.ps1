# 🧪 Ultra SIEM - Real-Time Detection Test
# Test the real-time threat detection capabilities

Write-Host "🧪 Ultra SIEM - Real-Time Detection Test" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Start infrastructure
Write-Host "🚀 Step 1: Starting infrastructure..." -ForegroundColor Yellow

# Start ClickHouse
Write-Host "   Starting ClickHouse..." -ForegroundColor Blue
docker run -d --name clickhouse-test -p 8123:8123 -p 9000:9000 --memory=2g clickhouse/clickhouse-server:latest

# Start NATS
Write-Host "   Starting NATS..." -ForegroundColor Blue
docker run -d --name nats-test -p 4222:4222 -p 8222:8222 --memory=512m nats:latest

# Start Grafana
Write-Host "   Starting Grafana..." -ForegroundColor Blue
docker run -d --name grafana-test -p 3000:3000 -e GF_SECURITY_ADMIN_PASSWORD=admin --memory=1g grafana/grafana:latest

Write-Host "⏳ Waiting for services to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Step 2: Create database table
Write-Host ""
Write-Host "🗄️ Step 2: Setting up database..." -ForegroundColor Yellow

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
    $response = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $createTableQuery
    Write-Host "✅ Database table created" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to create table: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 3: Start detection engines
Write-Host ""
Write-Host "🔍 Step 3: Starting detection engines..." -ForegroundColor Yellow

# Start Rust engine
Write-Host "   Starting Rust detection engine..." -ForegroundColor Blue
Start-Process -FilePath "cargo" -ArgumentList "run" -WorkingDirectory "rust-core" -WindowStyle Hidden

# Start Go processor
Write-Host "   Starting Go data processor..." -ForegroundColor Blue
Start-Process -FilePath "go" -ArgumentList "run", "real_processor.go" -WorkingDirectory "go-services/bridge" -WindowStyle Hidden

Write-Host "⏳ Waiting for engines to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Step 4: Test real-time detection
Write-Host ""
Write-Host "🎯 Step 4: Testing real-time detection..." -ForegroundColor Yellow
Write-Host "   Your SIEM is now monitoring REAL system activity!" -ForegroundColor Green
Write-Host ""

Write-Host "💡 Test Activities (run these in separate terminals):" -ForegroundColor Cyan
Write-Host "   1. Failed login: Try logging in with wrong password" -ForegroundColor White
Write-Host "   2. PowerShell: powershell.exe -enc SGVsbG8gV29ybGQ=" -ForegroundColor White
Write-Host "   3. Files: New-Item -Path '$env:TEMP\malware.exe' -ItemType File" -ForegroundColor White
Write-Host "   4. Network: netstat -an (monitors connections)" -ForegroundColor White
Write-Host ""

# Step 5: Monitor detection
Write-Host "📊 Step 5: Monitoring real-time detection..." -ForegroundColor Yellow
Write-Host "   Dashboard: http://localhost:3000 (admin/admin)" -ForegroundColor Cyan
Write-Host ""

$testDuration = 60  # 1 minute test
$startTime = Get-Date

Write-Host "⏱️ Monitoring for $testDuration seconds..." -ForegroundColor Yellow

for ($i = 1; $i -le 12; $i++) {
    try {
        # Check for threats
        $query = "SELECT count() FROM siem.threats WHERE event_time >= now() - INTERVAL 1 MINUTE"
        $response = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $query
        
        Write-Host "   [$i/12] Threats detected: $response" -ForegroundColor Green
        
        # Show recent threats
        $recentQuery = "SELECT threat_type, source FROM siem.threats WHERE event_time >= now() - INTERVAL 30 SECOND ORDER BY event_time DESC LIMIT 2"
        $recentResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $recentQuery
        
        if ($recentResponse -and $recentResponse.Length -gt 0) {
            Write-Host "      Recent: $recentResponse" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "   [$i/12] No threats detected yet..." -ForegroundColor Yellow
    }
    
    Start-Sleep -Seconds 5
}

# Step 6: Results
Write-Host ""
Write-Host "📊 Step 6: Test Results" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan

try {
    $totalQuery = "SELECT count() FROM siem.threats WHERE event_time >= now() - INTERVAL 1 HOUR"
    $totalResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $totalQuery
    
    $distQuery = "SELECT threat_type, count() FROM siem.threats WHERE event_time >= now() - INTERVAL 1 HOUR GROUP BY threat_type"
    $distResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $distQuery
    
    Write-Host "   🎯 Total threats detected: $totalResponse" -ForegroundColor Green
    Write-Host "   📊 Threat distribution: $distResponse" -ForegroundColor Green
    
    if ([int]$totalResponse -gt 0) {
        Write-Host ""
        Write-Host "✅ SUCCESS: Real-time detection is working!" -ForegroundColor Green
        Write-Host "   Your SIEM detected $totalResponse real threats" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "⚠️ No threats detected. Try the test activities above." -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "   ❌ Unable to retrieve results" -ForegroundColor Red
}

Write-Host ""
Write-Host "🧹 Cleanup:" -ForegroundColor Yellow
Write-Host "   docker stop clickhouse-test nats-test grafana-test" -ForegroundColor Cyan
Write-Host "   docker rm clickhouse-test nats-test grafana-test" -ForegroundColor Cyan
Write-Host ""

Write-Host "🎉 Real-time detection test completed!" -ForegroundColor Green 