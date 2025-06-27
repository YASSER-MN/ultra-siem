param(
    [int]$Events = 100000,
    [int]$Duration = 60
)

Write-Host "🎯 Ultra SIEM Performance Benchmark" -ForegroundColor Cyan
Write-Host "   Target Events: $Events" -ForegroundColor White
Write-Host "   Duration: $Duration seconds" -ForegroundColor White

$startTime = Get-Date

# Generate synthetic threat events
Write-Host "🔥 Generating synthetic threat events..." -ForegroundColor Yellow

$threats = @(
    "<script>alert('XSS Test')</script>",
    "'; DROP TABLE users; --",
    "../../etc/passwd",
    "javascript:alert('test')",
    "UNION SELECT * FROM passwords",
    "onload=alert('xss')",
    "<iframe src='javascript:alert(1)'>"
)

$jobs = @()
$eventsPerJob = [math]::Ceiling($Events / [Environment]::ProcessorCount)

for ($i = 0; $i -lt [Environment]::ProcessorCount; $i++) {
    $job = Start-Job -ScriptBlock {
        param($StartEvent, $EndEvent, $Threats, $VectorUrl)
        
        for ($j = $StartEvent; $j -lt $EndEvent; $j++) {
            $threat = $Threats | Get-Random
            $payload = @{
                timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                source_ip = "192.168.1.$((Get-Random -Min 1 -Max 254))"
                event_id = (Get-Random -Min 1000 -Max 9999)
                message = "Test event $j - $threat"
                threat_type = if ($threat -match "<script|javascript:") { "xss" } 
                             elseif ($threat -match "UNION|DROP") { "sql_injection" }
                             else { "suspicious" }
                severity = (Get-Random -Min 1 -Max 5)
                confidence = [math]::Round((Get-Random -Min 50 -Max 100) / 100.0, 2)
            } | ConvertTo-Json -Compress
            
            try {
                Invoke-RestMethod -Uri $VectorUrl -Method POST -Body $payload -ContentType "application/json" -TimeoutSec 1
            }
            catch {
                # Ignore errors for benchmark
            }
            
            if ($j % 1000 -eq 0) {
                Write-Progress -Activity "Generating events" -Status "Generated $j events"
            }
        }
    } -ArgumentList ($i * $eventsPerJob), (($i + 1) * $eventsPerJob), $threats, "http://localhost:8686/events"
    
    $jobs += $job
}

# Wait for all jobs to complete
Write-Host "⏳ Waiting for event generation to complete..." -ForegroundColor Yellow
$jobs | Wait-Job | Out-Null
$jobs | Remove-Job

$generationTime = (Get-Date) - $startTime
Write-Host "✅ Generated $Events events in $([math]::Round($generationTime.TotalSeconds, 2)) seconds" -ForegroundColor Green

# Wait for processing
Write-Host "⏳ Waiting for event processing..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Query ClickHouse for results
Write-Host "📊 Analyzing results..." -ForegroundColor Yellow

try {
    # Check total threats processed
    $totalThreats = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Body "SELECT count() FROM threats WHERE timestamp >= now() - INTERVAL 5 MINUTE FORMAT JSON" -ContentType "text/plain"
    $threatCount = $totalThreats.data[0][0]
    
    # Check threat distribution
    $threatTypes = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Body "SELECT threat_type, count() as count FROM threats WHERE timestamp >= now() - INTERVAL 5 MINUTE GROUP BY threat_type FORMAT JSON" -ContentType "text/plain"
    
    # Performance metrics
    $processingRate = [math]::Round($threatCount / $generationTime.TotalSeconds, 2)
    $detectionRate = [math]::Round(($threatCount / $Events) * 100, 2)
    
    Write-Host "`n📈 Benchmark Results:" -ForegroundColor Green
    Write-Host "   Events Generated: $Events" -ForegroundColor White
    Write-Host "   Events Processed: $threatCount" -ForegroundColor White
    Write-Host "   Processing Rate: $processingRate events/sec" -ForegroundColor White
    Write-Host "   Detection Rate: $detectionRate%" -ForegroundColor White
    Write-Host "   Total Time: $([math]::Round($generationTime.TotalSeconds, 2)) seconds" -ForegroundColor White
    
    # Threat type breakdown
    Write-Host "`n🎯 Threat Distribution:" -ForegroundColor Cyan
    foreach ($threat in $threatTypes.data) {
        Write-Host "   $($threat[0]): $($threat[1]) events" -ForegroundColor Yellow
    }
    
    # Performance assessment
    if ($processingRate -gt 10000) {
        Write-Host "`n🚀 EXCELLENT: Processing rate exceeds 10K EPS!" -ForegroundColor Green
    }
    elseif ($processingRate -gt 5000) {
        Write-Host "`n✅ GOOD: Processing rate above 5K EPS" -ForegroundColor Green
    }
    elseif ($processingRate -gt 1000) {
        Write-Host "`n⚠️  MODERATE: Processing rate above 1K EPS" -ForegroundColor Yellow
    }
    else {
        Write-Host "`n❌ LOW: Processing rate below 1K EPS - check configuration" -ForegroundColor Red
    }
    
    # Memory usage check
    $dockerStats = docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
    Write-Host "`n💻 Resource Usage:" -ForegroundColor Cyan
    Write-Host $dockerStats -ForegroundColor White
    
}
catch {
    Write-Host "❌ Failed to query ClickHouse: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Make sure ClickHouse is running and accessible" -ForegroundColor Yellow
}

Write-Host "`n✅ Benchmark complete!" -ForegroundColor Green 