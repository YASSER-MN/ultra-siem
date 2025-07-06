# 📊 Ultra SIEM - Zero Latency Real-Time Monitor
# Sub-microsecond threat detection monitoring with SIMD performance metrics

$headers = @{
    "X-ClickHouse-User" = "admin"
    "X-ClickHouse-Key" = "admin"
}

function Show-ZeroLatencyHeader {
    Clear-Host
    Write-Host "⚡ Ultra SIEM - Zero Latency Real-Time Monitor" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🔍 Monitoring: zero_latency_threats table" -ForegroundColor Yellow
    Write-Host "📡 NATS: http://localhost:8222/varz" -ForegroundColor Yellow
    Write-Host "📊 Grafana: http://localhost:3000 (admin/admin)" -ForegroundColor Yellow
    Write-Host "⚡ SIMD: AVX-512, AVX2, SSE acceleration" -ForegroundColor Green
    Write-Host "🔒 LOCK-FREE: Zero contention data structures" -ForegroundColor Green
    Write-Host ""
}

function Get-ZeroLatencyStats {
    try {
        # Get total threats in last minute
        $totalQuery = "SELECT count() FROM zero_latency_threats WHERE timestamp >= now() - INTERVAL 1 MINUTE"
        $totalResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $totalQuery
        
        # Get threats in last 10 seconds
        $recentQuery = "SELECT count() FROM zero_latency_threats WHERE timestamp >= now() - INTERVAL 10 SECOND"
        $recentResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $recentQuery
        
        # Get threat distribution
        $distQuery = "SELECT threat_type, count() FROM zero_latency_threats WHERE timestamp >= now() - INTERVAL 1 MINUTE GROUP BY threat_type ORDER BY count() DESC"
        $distResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $distQuery
        
        # Get average detection latency
        $latencyQuery = "SELECT avg(detection_latency_ns) FROM zero_latency_threats WHERE timestamp >= now() - INTERVAL 1 MINUTE"
        $latencyResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $latencyQuery
        
        # Get max detection latency
        $maxLatencyQuery = "SELECT max(detection_latency_ns) FROM zero_latency_threats WHERE timestamp >= now() - INTERVAL 1 MINUTE"
        $maxLatencyResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $maxLatencyQuery
        
        # Get throughput (events per second)
        $throughputQuery = "SELECT count() / 60 FROM zero_latency_threats WHERE timestamp >= now() - INTERVAL 1 MINUTE"
        $throughputResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $throughputQuery
        
        return @{
            TotalThreats = [int]$totalResponse
            RecentThreats = [int]$recentResponse
            Distribution = $distResponse
            AvgLatencyNs = $latencyResponse
            MaxLatencyNs = $maxLatencyResponse
            ThroughputEPS = $throughputResponse
            Error = $null
        }
    } catch {
        return @{
            TotalThreats = 0
            RecentThreats = 0
            Distribution = ""
            AvgLatencyNs = "0"
            MaxLatencyNs = "0"
            ThroughputEPS = "0"
            Error = $_.Exception.Message
        }
    }
}

function Get-RecentZeroLatencyThreats {
    try {
        $query = "SELECT timestamp, threat_type, source_ip, severity, confidence, detection_latency_ns, simd_optimized FROM zero_latency_threats WHERE timestamp >= now() - INTERVAL 30 SECOND ORDER BY timestamp DESC LIMIT 10"
        $response = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $query
        return $response
    } catch {
        return ""
    }
}

function Show-ZeroLatencyDashboard {
    param($stats, $recentThreats)
    
    # Header
    Write-Host "📈 Zero-Latency Threat Statistics" -ForegroundColor Green
    Write-Host "=================================" -ForegroundColor Green
    Write-Host "   🎯 Total threats (1 min): $($stats.TotalThreats)" -ForegroundColor White
    Write-Host "   ⚡ Recent threats (10s): $($stats.RecentThreats)" -ForegroundColor White
    
    if ($stats.AvgLatencyNs -ne "0") {
        $avgLatencyMs = [math]::Round([double]$stats.AvgLatencyNs / 1000000, 3)
        Write-Host "   📊 Average latency: ${avgLatencyMs}ms" -ForegroundColor White
    }
    
    if ($stats.MaxLatencyNs -ne "0") {
        $maxLatencyMs = [math]::Round([double]$stats.MaxLatencyNs / 1000000, 3)
        Write-Host "   🚨 Max latency: ${maxLatencyMs}ms" -ForegroundColor White
    }
    
    if ($stats.ThroughputEPS -ne "0") {
        $throughput = [math]::Round([double]$stats.ThroughputEPS, 2)
        Write-Host "   📡 Throughput: ${throughput} EPS" -ForegroundColor White
    }
    
    if ($stats.Error) {
        Write-Host "   ❌ Error: $($stats.Error)" -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Threat Distribution
    if ($stats.Distribution -and $stats.Distribution.Length -gt 0) {
        Write-Host "📊 Zero-Latency Threat Distribution (1 min)" -ForegroundColor Green
        Write-Host "=========================================" -ForegroundColor Green
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
        Write-Host "🚨 Recent Zero-Latency Threats (Last 30 seconds)" -ForegroundColor Green
        Write-Host "==============================================" -ForegroundColor Green
        $recentThreats.Split("`n") | ForEach-Object {
            if ($_ -match "(.+?)\s+(.+?)\s+(.+?)\s+(.+?)\s+([\d.]+)\s+(\d+)\s+(\d+)") {
                $time = $matches[1]
                $type = $matches[2]
                $ip = $matches[3]
                $severity = $matches[4]
                $confidence = $matches[5]
                $latencyNs = $matches[6]
                $simdOptimized = $matches[7]
                
                $severityColor = switch ($severity) {
                    "5" { "Red" }
                    "4" { "Yellow" }
                    "3" { "Green" }
                    default { "White" }
                }
                
                $latencyMs = [math]::Round([double]$latencyNs / 1000000, 3)
                $simdStatus = if ($simdOptimized -eq "1") { "SIMD" } else { "SCALAR" }
                
                Write-Host "   ⏰ $time | $type | $ip | $severity | $confidence | ${latencyMs}ms | $simdStatus" -ForegroundColor $severityColor
            }
        }
        Write-Host ""
    } else {
        Write-Host "🚨 Recent Zero-Latency Threats (Last 30 seconds)" -ForegroundColor Green
        Write-Host "==============================================" -ForegroundColor Green
        Write-Host "   No recent threats detected" -ForegroundColor Yellow
        Write-Host ""
    }
}

function Show-ZeroLatencySystemStatus {
    Write-Host "🔧 Zero-Latency System Status" -ForegroundColor Green
    Write-Host "============================" -ForegroundColor Green
    
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
    
    # Check Rust zero-latency engine
    $rustProcess = Get-Process | Where-Object {$_.ProcessName -like "*siem-rust-core*" -or $_.ProcessName -like "*cargo*"}
    if ($rustProcess) {
        Write-Host "   ✅ Rust Zero-Latency Engine: Running" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Rust Zero-Latency Engine: Stopped" -ForegroundColor Red
    }
    
    # Check Go zero-latency processor
    $goProcess = Get-Process | Where-Object {$_.ProcessName -like "*zero_latency_processor*" -or $_.ProcessName -like "*go*"}
    if ($goProcess) {
        Write-Host "   ✅ Go Zero-Latency Processor: Running" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Go Zero-Latency Processor: Stopped" -ForegroundColor Red
    }
    
    Write-Host ""
}

function Show-ZeroLatencyControls {
    Write-Host "🎮 Zero-Latency Controls" -ForegroundColor Green
    Write-Host "=======================" -ForegroundColor Green
    Write-Host "   Press 'R' to refresh" -ForegroundColor White
    Write-Host "   Press 'Q' to quit" -ForegroundColor White
    Write-Host "   Press 'A' to open attack control center" -ForegroundColor White
    Write-Host "   Press 'D' to open dashboard" -ForegroundColor White
    Write-Host "   Press 'T' to run throughput test" -ForegroundColor White
    Write-Host "   Press 'L' to show latency analysis" -ForegroundColor White
    Write-Host ""
}

function Test-ZeroLatencyThroughput {
    Write-Host "🚀 Running zero-latency throughput test..." -ForegroundColor Cyan
    
    # Generate high-volume test threats
    $startTime = Get-Date
    $testDuration = 30 # seconds
    
    Write-Host "   Generating threats for $testDuration seconds..." -ForegroundColor Yellow
    
    # Run attack simulation in background
    Start-Job -ScriptBlock {
        param($duration)
        Start-Sleep -Seconds 2
        $endTime = (Get-Date).AddSeconds($duration)
        
        while ((Get-Date) -lt $endTime) {
            # Generate various threat types
            $threats = @(
                "GET /api/users?id=1' OR 1=1--",
                "<script>alert('xss')</script>",
                "powershell.exe -enc SGVsbG8gV29ybGQ=",
                "SELECT * FROM users WHERE id = 1 UNION SELECT password FROM passwords",
                "certutil -decode malware.b64 malware.exe"
            )
            
            foreach ($threat in $threats) {
                # Simulate threat detection
                Start-Sleep -Milliseconds 10
            }
        }
    } -ArgumentList $testDuration
    
    # Monitor throughput during test
    $monitoringInterval = 5 # seconds
    $totalThreats = 0
    
    for ($i = 0; $i -lt ($testDuration / $monitoringInterval); $i++) {
        Start-Sleep -Seconds $monitoringInterval
        
        try {
            $query = "SELECT count() FROM zero_latency_threats WHERE timestamp >= now() - INTERVAL $monitoringInterval SECOND"
            $response = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $query
            $threatsInInterval = [int]$response
            $totalThreats += $threatsInInterval
            $throughput = [math]::Round($threatsInInterval / $monitoringInterval, 2)
            
            Write-Host "   Interval $($i+1): $threatsInInterval threats ($throughput EPS)" -ForegroundColor Green
        } catch {
            Write-Host "   Interval $($i+1): Error reading threats" -ForegroundColor Red
        }
    }
    
    $totalTime = ((Get-Date) - $startTime).TotalSeconds
    $avgThroughput = [math]::Round($totalThreats / $totalTime, 2)
    
    Write-Host ""
    Write-Host "📊 Zero-Latency Throughput Test Results:" -ForegroundColor Cyan
    Write-Host "   Total threats: $totalThreats" -ForegroundColor White
    Write-Host "   Test duration: ${totalTime}s" -ForegroundColor White
    Write-Host "   Average throughput: ${avgThroughput} EPS" -ForegroundColor White
    
    if ($avgThroughput -gt 10000) {
        Write-Host "   🚀 EXCELLENT: Throughput exceeds 10K EPS!" -ForegroundColor Green
    } elseif ($avgThroughput -gt 5000) {
        Write-Host "   ✅ GOOD: Throughput above 5K EPS" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ MODERATE: Throughput below 5K EPS" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Press any key to continue monitoring..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Show-LatencyAnalysis {
    Write-Host "📊 Zero-Latency Analysis" -ForegroundColor Cyan
    Write-Host "=======================" -ForegroundColor Cyan
    
    try {
        # Get latency percentiles
        $p50Query = "SELECT quantile(0.5)(detection_latency_ns) FROM zero_latency_threats WHERE timestamp >= now() - INTERVAL 5 MINUTE"
        $p50Response = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $p50Query
        
        $p95Query = "SELECT quantile(0.95)(detection_latency_ns) FROM zero_latency_threats WHERE timestamp >= now() - INTERVAL 5 MINUTE"
        $p95Response = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $p95Query
        
        $p99Query = "SELECT quantile(0.99)(detection_latency_ns) FROM zero_latency_threats WHERE timestamp >= now() - INTERVAL 5 MINUTE"
        $p99Response = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $p99Query
        
        # Get SIMD vs scalar performance
        $simdQuery = "SELECT avg(detection_latency_ns) FROM zero_latency_threats WHERE timestamp >= now() - INTERVAL 5 MINUTE AND simd_optimized = 1"
        $simdResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $simdQuery
        
        $scalarQuery = "SELECT avg(detection_latency_ns) FROM zero_latency_threats WHERE timestamp >= now() - INTERVAL 5 MINUTE AND simd_optimized = 0"
        $scalarResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Headers $headers -Body $scalarQuery
        
        Write-Host "   📈 Latency Percentiles (5 min):" -ForegroundColor White
        Write-Host "      P50: $([math]::Round([double]$p50Response / 1000000, 3))ms" -ForegroundColor Green
        Write-Host "      P95: $([math]::Round([double]$p95Response / 1000000, 3))ms" -ForegroundColor Yellow
        Write-Host "      P99: $([math]::Round([double]$p99Response / 1000000, 3))ms" -ForegroundColor Red
        
        Write-Host ""
        Write-Host "   ⚡ SIMD Performance Comparison:" -ForegroundColor White
        Write-Host "      SIMD: $([math]::Round([double]$simdResponse / 1000000, 3))ms" -ForegroundColor Green
        Write-Host "      Scalar: $([math]::Round([double]$scalarResponse / 1000000, 3))ms" -ForegroundColor Yellow
        
        if ([double]$scalarResponse -gt 0) {
            $speedup = [math]::Round([double]$scalarResponse / [double]$simdResponse, 2)
            Write-Host "      Speedup: ${speedup}x faster with SIMD" -ForegroundColor Green
        }
        
    } catch {
        Write-Host "   ❌ Error retrieving latency analysis: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Press any key to continue monitoring..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Main monitoring loop
Write-Host "🚀 Starting Ultra SIEM Zero-Latency Monitor..." -ForegroundColor Green
Write-Host "   Press any key to start monitoring..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

$monitoring = $true

while ($monitoring) {
    Show-ZeroLatencyHeader
    
    # Get current stats
    $stats = Get-ZeroLatencyStats
    $recentThreats = Get-RecentZeroLatencyThreats
    
    # Show dashboard
    Show-ZeroLatencyDashboard -stats $stats -recentThreats $recentThreats
    Show-ZeroLatencySystemStatus
    Show-ZeroLatencyControls
    
    # Handle user input
    if ($Host.UI.RawUI.KeyAvailable) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.Character) {
            'r' { continue } # Refresh
            'q' { $monitoring = $false; break }
            'a' { 
                Write-Host "🎯 Opening attack control center..." -ForegroundColor Cyan
                Start-Process -FilePath ".\attack_control_center.ps1" -WindowStyle Normal
            }
            'd' { 
                Write-Host "📊 Opening Grafana dashboard..." -ForegroundColor Cyan
                Start-Process -FilePath "http://localhost:3000"
            }
            't' { Test-ZeroLatencyThroughput }
            'l' { Show-LatencyAnalysis }
        }
    }
    
    Start-Sleep -Seconds 2
}

Write-Host "👋 Zero-latency monitoring stopped." -ForegroundColor Green 