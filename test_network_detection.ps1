# 🧪 Test Network Detection
# Test real-time network traffic monitoring

Write-Host "🧪 Testing Network Detection" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host ""

Write-Host "🔍 This test will trigger network traffic detection" -ForegroundColor Yellow
Write-Host ""

# Test 1: Suspicious Network Connections
Write-Host "🎯 Test 1: Suspicious Network Connections" -ForegroundColor Green
Write-Host "   This will trigger suspicious connection detection" -ForegroundColor White
Write-Host ""

Write-Host "💡 To test suspicious connection detection:" -ForegroundColor Cyan
Write-Host "   1. Open Command Prompt" -ForegroundColor White
Write-Host "   2. Run: netstat -an" -ForegroundColor White
Write-Host "   3. Run: netstat -an | findstr :80" -ForegroundColor White
Write-Host "   4. Run: netstat -an | findstr :443" -ForegroundColor White
Write-Host ""

Write-Host "⏳ Waiting for network connection tests..." -ForegroundColor Yellow
Write-Host "   (Press any key when you've completed the connection tests)" -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Test 2: DNS Query Detection
Write-Host ""
Write-Host "🎯 Test 2: DNS Query Detection" -ForegroundColor Green
Write-Host "   This will trigger DNS query monitoring" -ForegroundColor White
Write-Host ""

Write-Host "💡 To test DNS query detection:" -ForegroundColor Cyan
Write-Host "   1. Open Command Prompt" -ForegroundColor White
Write-Host "   2. Run: nslookup google.com" -ForegroundColor White
Write-Host "   3. Run: nslookup microsoft.com" -ForegroundColor White
Write-Host "   4. Run: ping google.com" -ForegroundColor White
Write-Host ""

Write-Host "⏳ Waiting for DNS query tests..." -ForegroundColor Yellow
Write-Host "   (Press any key when you've completed the DNS tests)" -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Test 3: Port Scanning Detection
Write-Host ""
Write-Host "🎯 Test 3: Port Scanning Detection" -ForegroundColor Green
Write-Host "   This will trigger port scanning detection" -ForegroundColor White
Write-Host ""

Write-Host "💡 To test port scanning detection:" -ForegroundColor Cyan
Write-Host "   1. Open Command Prompt as Administrator" -ForegroundColor White
Write-Host "   2. Run: netstat -an | findstr LISTENING" -ForegroundColor White
Write-Host "   3. Run: netstat -an | findstr ESTABLISHED" -ForegroundColor White
Write-Host ""

Write-Host "⏳ Waiting for port scanning tests..." -ForegroundColor Yellow
Write-Host "   (Press any key when you've completed the port tests)" -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Test 4: Web Traffic Detection
Write-Host ""
Write-Host "🎯 Test 4: Web Traffic Detection" -ForegroundColor Green
Write-Host "   This will trigger web traffic monitoring" -ForegroundColor White
Write-Host ""

Write-Host "💡 To test web traffic detection:" -ForegroundColor Cyan
Write-Host "   1. Open a web browser" -ForegroundColor White
Write-Host "   2. Visit: http://google.com" -ForegroundColor White
Write-Host "   3. Visit: https://microsoft.com" -ForegroundColor White
Write-Host "   4. Visit: http://localhost:3000 (Grafana dashboard)" -ForegroundColor White
Write-Host ""

Write-Host "⏳ Waiting for web traffic tests..." -ForegroundColor Yellow
Write-Host "   (Press any key when you've completed the web traffic tests)" -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host ""
Write-Host "✅ Network Detection Test Completed!" -ForegroundColor Green
Write-Host "   Check your SIEM dashboard for detected network activity" -ForegroundColor Yellow
Write-Host "   Dashboard: http://localhost:3000 (admin/admin)" -ForegroundColor Cyan

$headers = @{
    "X-ClickHouse-User" = "admin"
    "X-ClickHouse-Key" = "admin"
}

# Example query usage:
$response = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $query

# Use fields: event_time, source_ip, threat_type, severity, message, confidence_score, geo_country 