# Ultra SIEM Dashboard Access Script
Write-Host "🚀 Opening Ultra SIEM Dashboard..." -ForegroundColor Green
Write-Host "📊 Grafana Dashboard: http://localhost:3000" -ForegroundColor Cyan
Write-Host "👤 Username: admin" -ForegroundColor Yellow
Write-Host "🔑 Password: admin" -ForegroundColor Yellow
Write-Host ""
Write-Host "📂 How to Access Dashboards:" -ForegroundColor Magenta
Write-Host "   1. Login to Grafana (admin/admin)" -ForegroundColor White
Write-Host "   2. Click on 'Dashboards' in the left sidebar" -ForegroundColor White
Write-Host "   3. Look for the 'SIEM' folder" -ForegroundColor White
Write-Host "   4. Open the SIEM folder to find:" -ForegroundColor White
Write-Host "      • 🛡️ Ultra SIEM - Threat Monitor" -ForegroundColor Cyan
Write-Host "      • 🚀 Ultra SIEM - Real-Time Threat Dashboard" -ForegroundColor Cyan
Write-Host ""
Write-Host "📈 Dashboard Features:" -ForegroundColor Magenta
Write-Host "   🚨 Real-Time Threat Count - Total threats (30+)" -ForegroundColor White
Write-Host "   ⚡ Threats by Severity - HIGH, MEDIUM, CRITICAL breakdown" -ForegroundColor White
Write-Host "   🔥 Recent Threats - Latest threat details" -ForegroundColor White
Write-Host "   📊 Threat Types Distribution - SQL Injection, XSS, Malware, etc." -ForegroundColor White
Write-Host "   🔥 High Severity Threats - Detailed threat list" -ForegroundColor White
Write-Host "   📈 Threats Over Time - Historical threat timeline" -ForegroundColor White
Write-Host "   🎯 Top Attacking IPs - Most active source IPs" -ForegroundColor White
Write-Host ""

# Open the dashboard in default browser
Start-Process "http://localhost:3000"

Write-Host "✅ Dashboard opened! Follow the steps above to navigate to the SIEM dashboards." -ForegroundColor Green 