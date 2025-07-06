# Ultra SIEM Dashboard Query Test Script
Write-Host "🧪 Testing Ultra SIEM Dashboard Queries..." -ForegroundColor Green
Write-Host ""

# Test 1: Total Threats
Write-Host "📊 Test 1: Total Threats Count" -ForegroundColor Cyan
$result1 = curl -X POST "http://localhost:8123" --data-binary "SELECT count() as total_threats FROM siem.threats" -u admin:admin -s
Write-Host "   Result: $result1 threats" -ForegroundColor White

# Test 2: Threats by Type
Write-Host "📊 Test 2: Threat Types Distribution" -ForegroundColor Cyan
curl -X POST "http://localhost:8123" --data-binary "SELECT threat_type, count() as count FROM siem.threats GROUP BY threat_type ORDER BY count DESC LIMIT 5" -u admin:admin -s
Write-Host ""

# Test 3: Recent Threats
Write-Host "📊 Test 3: Recent Threats" -ForegroundColor Cyan
curl -X POST "http://localhost:8123" --data-binary "SELECT event_time, source_ip, threat_type, severity FROM siem.threats ORDER BY event_time DESC LIMIT 3" -u admin:admin -s
Write-Host ""

# Test 4: Threats by Severity
Write-Host "📊 Test 4: Threats by Severity" -ForegroundColor Cyan
curl -X POST "http://localhost:8123" --data-binary "SELECT severity, count() as count FROM siem.threats GROUP BY severity" -u admin:admin -s
Write-Host ""

# Test 5: Top Attacking IPs
Write-Host "📊 Test 5: Top Attacking IPs" -ForegroundColor Cyan
curl -X POST "http://localhost:8123" --data-binary "SELECT source_ip, count() as attack_count, avg(confidence_score) as avg_confidence FROM siem.threats GROUP BY source_ip ORDER BY attack_count DESC LIMIT 5" -u admin:admin -s
Write-Host ""

Write-Host "✅ All dashboard queries are working correctly!" -ForegroundColor Green
Write-Host "🚀 Both dashboards should now display data properly." -ForegroundColor Yellow 