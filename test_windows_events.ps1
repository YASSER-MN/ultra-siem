# 🧪 Test Windows Event Detection
# Test real-time Windows security event monitoring

Write-Host "🧪 Testing Windows Event Detection" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "🔍 This test will trigger Windows security events for detection" -ForegroundColor Yellow
Write-Host ""

# Test 1: Failed Login Attempts
Write-Host "🎯 Test 1: Failed Login Detection" -ForegroundColor Green
Write-Host "   This will trigger Event ID 4625 (Failed Login)" -ForegroundColor White
Write-Host ""

Write-Host "💡 To test failed login detection:" -ForegroundColor Cyan
Write-Host "   1. Press Ctrl+Alt+Delete" -ForegroundColor White
Write-Host "   2. Click 'Switch User'" -ForegroundColor White
Write-Host "   3. Try to log in with a wrong password" -ForegroundColor White
Write-Host "   4. Repeat 2-3 times" -ForegroundColor White
Write-Host ""

Write-Host "⏳ Waiting for failed login attempts..." -ForegroundColor Yellow
Write-Host "   (Press any key when you've completed the failed logins)" -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Test 2: Process Creation
Write-Host ""
Write-Host "🎯 Test 2: Process Creation Detection" -ForegroundColor Green
Write-Host "   This will trigger process creation events" -ForegroundColor White
Write-Host ""

Write-Host "💡 To test process creation detection:" -ForegroundColor Cyan
Write-Host "   1. Open PowerShell" -ForegroundColor White
Write-Host "   2. Run: Get-Process | Select-Object -First 5" -ForegroundColor White
Write-Host "   3. Run: tasklist" -ForegroundColor White
Write-Host ""

Write-Host "⏳ Waiting for process creation events..." -ForegroundColor Yellow
Write-Host "   (Press any key when you've completed the process tests)" -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Test 3: Service Events
Write-Host ""
Write-Host "🎯 Test 3: Service Event Detection" -ForegroundColor Green
Write-Host "   This will trigger service-related events" -ForegroundColor White
Write-Host ""

Write-Host "💡 To test service event detection:" -ForegroundColor Cyan
Write-Host "   1. Open PowerShell as Administrator" -ForegroundColor White
Write-Host "   2. Run: Get-Service | Select-Object -First 10" -ForegroundColor White
Write-Host "   3. Run: sc query" -ForegroundColor White
Write-Host ""

Write-Host "⏳ Waiting for service events..." -ForegroundColor Yellow
Write-Host "   (Press any key when you've completed the service tests)" -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host ""
Write-Host "✅ Windows Event Detection Test Completed!" -ForegroundColor Green
Write-Host "   Check your SIEM dashboard for detected events" -ForegroundColor Yellow
Write-Host "   Dashboard: http://localhost:3000 (admin/admin)" -ForegroundColor Cyan

$headers = @{
    "X-ClickHouse-User" = "admin"
    "X-ClickHouse-Key" = "admin"
}

# Example query usage:
$response = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $query

# Use fields: event_time, source_ip, threat_type, severity, message, confidence_score, geo_country 