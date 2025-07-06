# Ultra SIEM - Simple Status Check
# Quick status check without freezing

Write-Host "Ultra SIEM - Quick Status Check" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""

# Check infrastructure status
Write-Host "Infrastructure Status:" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green

# Check ClickHouse
try {
    $clickhouseResponse = Invoke-RestMethod -Uri "http://localhost:8123/ping" -TimeoutSec 3
    Write-Host "   ClickHouse: Online" -ForegroundColor Green
} catch {
    Write-Host "   ClickHouse: Offline" -ForegroundColor Red
}

# Check NATS
try {
    $natsResponse = Invoke-RestMethod -Uri "http://localhost:8222/varz" -TimeoutSec 3
    Write-Host "   NATS: Online" -ForegroundColor Green
} catch {
    Write-Host "   NATS: Offline" -ForegroundColor Red
}

# Check Grafana
try {
    $grafanaResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/health" -TimeoutSec 3
    Write-Host "   Grafana: Online" -ForegroundColor Green
} catch {
    Write-Host "   Grafana: Offline" -ForegroundColor Red
}

Write-Host ""

# Check threat statistics
Write-Host "Threat Statistics:" -ForegroundColor Green
Write-Host "=================" -ForegroundColor Green

$headers = @{
    "X-ClickHouse-User" = "admin"
    "X-ClickHouse-Key" = "admin"
}

try {
    # Get total threats in last hour
    $totalQuery = "SELECT count() FROM siem.threats WHERE event_time >= now() - INTERVAL 1 HOUR"
    $totalResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $totalQuery
    
    # Get threats in last minute
    $recentQuery = "SELECT count() FROM siem.threats WHERE event_time >= now() - INTERVAL 1 MINUTE"
    $recentResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $recentQuery
    
    Write-Host "   Total threats (1 hour): $totalResponse" -ForegroundColor White
    Write-Host "   Recent threats (1 minute): $recentResponse" -ForegroundColor White
} catch {
    Write-Host "   Error connecting to database: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Access Points:" -ForegroundColor Green
Write-Host "=============" -ForegroundColor Green
Write-Host "   Grafana Dashboard: http://localhost:3000 (admin/admin)" -ForegroundColor Yellow
Write-Host "   ClickHouse: http://localhost:8123 (admin/admin)" -ForegroundColor Yellow
Write-Host "   NATS Monitor: http://localhost:8222/varz" -ForegroundColor Yellow

Write-Host ""
Write-Host "Status check completed!" -ForegroundColor Green 