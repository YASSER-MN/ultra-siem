# 📊 Ultra SIEM - Real-Time Monitor
# Live threat detection monitoring with detailed analytics

$headers = @{
    "X-ClickHouse-User" = "admin"
    "X-ClickHouse-Key" = "admin"
}

function Show-MonitorHeader {
    Clear-Host
    Write-Host "📊 Ultra SIEM - Real-Time Threat Monitor" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🔍 Monitoring: siem.threats table" -ForegroundColor Yellow
    Write-Host "📡 NATS: http://localhost:8222/varz" -ForegroundColor Yellow
    Write-Host "📊 Grafana: http://localhost:3000 (admin/admin)" -ForegroundColor Yellow
    Write-Host ""
}

function Get-ThreatStats {
    try {
        # Get total threats in last hour
        $totalQuery = "SELECT count() FROM siem.threats WHERE event_time >= now() - INTERVAL 1 HOUR"
        $totalResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $totalQuery
        
        # Get threats in last minute
        $recentQuery = "SELECT count() FROM siem.threats WHERE event_time >= now() - INTERVAL 1 MINUTE"
        $recentResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $recentQuery
        
        # Get threat distribution
        $distQuery = "SELECT threat_type, count() FROM siem.threats WHERE event_time >= now() - INTERVAL 1 HOUR GROUP BY threat_type ORDER BY count() DESC"
        $distResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $distQuery
        
        # Get average confidence
        $confQuery = "SELECT avg(confidence_score) FROM siem.threats WHERE event_time >= now() - INTERVAL 1 HOUR"
        $confResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $confQuery
        
        return @{
            TotalThreats = [int]$totalResponse
            RecentThreats = [int]$recentResponse
            Distribution = $distResponse
            AvgConfidence = $confResponse
        }
    } catch {
        return @{
            TotalThreats = 0
            RecentThreats = 0
            Distribution = ""
            AvgConfidence = "0"
            Error = $_.Exception.Message
        }
    }
}

function Get-RecentThreats {
    try {
        $query = "SELECT event_time, threat_type, source_ip, severity, confidence_score FROM siem.threats WHERE event_time >= now() - INTERVAL 5 MINUTE ORDER BY event_time DESC LIMIT 10"
        $response = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $query
        return $response
    } catch {
        return ""
    }
}

function Show-ThreatDashboard {
    param($stats, $recentThreats)
    
    # Header
    Write-Host "📈 Threat Statistics" -ForegroundColor Green
    Write-Host "===================" -ForegroundColor Green
    Write-Host "   🎯 Total threats (1 hour): $($stats.TotalThreats)" -ForegroundColor White
    Write-Host "   ⚡ Recent threats (1 minute): $($stats.RecentThreats)" -ForegroundColor White
    
    if ($stats.AvgConfidence -ne "0") {
        Write-Host "   📊 Average confidence: $($stats.AvgConfidence)" -ForegroundColor White
    }
    
    if ($stats.Error) {
        Write-Host "   ❌ Error: $($stats.Error)" -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Threat Distribution
    if ($stats.Distribution -and $stats.Distribution.Length -gt 0) {
        Write-Host "📊 Threat Distribution (1 hour)" -ForegroundColor Green
        Write-Host "=============================" -ForegroundColor Green
        $stats.Distribution.Split("`n") | ForEach-Object {
            if ($_ -match "(.+?)\s+(\d+)") {
                $threatType = $matches[1]
                $count = $matches[2]
                Write-Host "   🔴 $threatType`: $count threats" -ForegroundColor Red
            }
        }
        Write-Host ""
    }
    
    # Recent Threats
    if ($recentThreats -and $recentThreats.Length -gt 0) {
        Write-Host "🚨 Recent Threats (Last 5 minutes)" -ForegroundColor Green
        Write-Host "=================================" -ForegroundColor Green
        $recentThreats.Split("`n") | ForEach-Object {
            if ($_ -match "(.+?)\s+(.+?)\s+(.+?)\s+(.+?)\s+([\d.]+)") {
                $time = $matches[1]
                $type = $matches[2]
                $ip = $matches[3]
                $severity = $matches[4]
                $confidence = $matches[5]
                
                $severityColor = switch ($severity) {
                    "HIGH" { "Red" }
                    "MEDIUM" { "Yellow" }
                    "LOW" { "Green" }
                    default { "White" }
                }
                
                Write-Host "   ⏰ $time | $type | $ip | $severity | $confidence" -ForegroundColor $severityColor
            }
        }
        Write-Host ""
    } else {
        Write-Host "🚨 Recent Threats (Last 5 minutes)" -ForegroundColor Green
        Write-Host "=================================" -ForegroundColor Green
        Write-Host "   No recent threats detected" -ForegroundColor Yellow
        Write-Host ""
    }
}

function Show-SystemStatus {
    Write-Host "🔧 System Status" -ForegroundColor Green
    Write-Host "===============" -ForegroundColor Green
    
    # Check ClickHouse
    try {
        $clickhouseResponse = Invoke-RestMethod -Uri "http://localhost:8123/ping" -TimeoutSec 3
        Write-Host "   ✅ ClickHouse: Online" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ ClickHouse: Offline" -ForegroundColor Red
    }
    
    # Check NATS
    try {
        $natsResponse = Invoke-RestMethod -Uri "http://localhost:8222/varz" -TimeoutSec 3
        Write-Host "   ✅ NATS: Online" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ NATS: Offline" -ForegroundColor Red
    }
    
    # Check Grafana
    try {
        $grafanaResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/health" -TimeoutSec 3
        Write-Host "   ✅ Grafana: Online" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ Grafana: Offline" -ForegroundColor Red
    }
    
    # Check detection engines
    $rustProcess = Get-Process | Where-Object {$_.ProcessName -like "*cargo*" -or $_.ProcessName -like "*rust*"}
    if ($rustProcess) {
        Write-Host "   ✅ Rust Engine: Running" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Rust Engine: Stopped" -ForegroundColor Red
    }
    
    $goProcess = Get-Process | Where-Object {$_.ProcessName -like "*go*"}
    if ($goProcess) {
        Write-Host "   ✅ Go Processor: Running" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Go Processor: Stopped" -ForegroundColor Red
    }
    
    Write-Host ""
}

function Show-Controls {
    Write-Host "🎮 Controls" -ForegroundColor Green
    Write-Host "==========" -ForegroundColor Green
    Write-Host "   Press 'R' to refresh" -ForegroundColor White
    Write-Host "   Press 'Q' to quit" -ForegroundColor White
    Write-Host "   Press 'A' to open attack control center" -ForegroundColor White
    Write-Host "   Press 'D' to open dashboard" -ForegroundColor White
    Write-Host ""
}

# Main monitoring loop
$monitoring = $true
$refreshInterval = 5  # seconds

Write-Host "🚀 Starting Ultra SIEM Real-Time Monitor..." -ForegroundColor Green
Write-Host "   Press any key to start monitoring..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

while ($monitoring) {
    Show-MonitorHeader
    
    # Get current stats
    $stats = Get-ThreatStats
    $recentThreats = Get-RecentThreats
    
    # Show dashboard
    Show-ThreatDashboard -stats $stats -recentThreats $recentThreats
    Show-SystemStatus
    Show-Controls
    
    # Wait for user input or auto-refresh
    $startTime = Get-Date
    $keyPressed = $false
    
    while (((Get-Date) - $startTime).TotalSeconds -lt $refreshInterval) -and (-not $keyPressed) {
        if ($Host.UI.RawUI.KeyAvailable) {
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            $keyPressed = $true
            
            switch ($key.Character.ToUpper()) {
                "R" { 
                    Write-Host "🔄 Refreshing..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                }
                "Q" { 
                    $monitoring = $false
                    Write-Host "🚪 Exiting monitor..." -ForegroundColor Yellow
                }
                "A" { 
                    Write-Host "🎯 Opening attack control center..." -ForegroundColor Yellow
                    Start-Process -FilePath "powershell.exe" -ArgumentList "-File", "attack_control_center.ps1"
                }
                "D" { 
                    Write-Host "📊 Opening dashboard..." -ForegroundColor Yellow
                    Start-Process "http://localhost:3000"
                }
            }
        } else {
            Start-Sleep -Milliseconds 100
        }
    }
}

Write-Host "🎉 Monitoring session ended!" -ForegroundColor Green
Write-Host "   Check the logs for detailed threat information" -ForegroundColor Cyan 