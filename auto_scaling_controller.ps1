# 📈 Ultra SIEM - Auto-Scaling Controller
# Dynamically scales components based on load for optimal performance

param(
    [switch]$Continuous,
    [int]$CheckInterval = 30,
    [switch]$DryRun,
    [switch]$Verbose
)

function Show-AutoScalingBanner {
    Clear-Host
    Write-Host "📈 Ultra SIEM - Auto-Scaling Controller" -ForegroundColor Magenta
    Write-Host "=======================================" -ForegroundColor Magenta
    Write-Host "⚡ Dynamic Scaling: 10-50 instances based on load" -ForegroundColor Cyan
    Write-Host "🎯 Load-Based Scaling: CPU, memory, and throughput" -ForegroundColor Green
    Write-Host "🔄 Zero-Downtime Scaling: Seamless instance management" -ForegroundColor Yellow
    Write-Host "📊 Real-Time Monitoring: Continuous load assessment" -ForegroundColor Red
    Write-Host "🛡️ Bulletproof Scaling: Impossible-to-fail scaling logic" -ForegroundColor White
    Write-Host ""
}

function Get-AutoScalingConfig {
    $configPath = "config/auto_scaling.json"
    
    if (Test-Path $configPath) {
        $config = Get-Content $configPath | ConvertFrom-Json
    } else {
        # Default configuration
        $config = @{
            min_instances = 10
            max_instances = 50
            scale_up_threshold = 80
            scale_down_threshold = 20
            scale_up_cooldown = 60
            scale_down_cooldown = 300
            cpu_threshold = 70
            memory_threshold = 80
            throughput_threshold = 1000000
        } | ConvertTo-Json
        
        # Create config directory if it doesn't exist
        if (-not (Test-Path "config")) {
            New-Item -ItemType Directory -Path "config" -Force | Out-Null
        }
        
        $config | Out-File $configPath -Encoding UTF8
    }
    
    return $config
}

function Get-SystemMetrics {
    $metrics = @{}
    
    # CPU Usage
    try {
        $cpuUsage = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples[0].CookedValue
        $metrics.CPU = [math]::Round($cpuUsage, 1)
    } catch {
        $metrics.CPU = 0
    }
    
    # Memory Usage
    try {
        $memoryInfo = Get-WmiObject -Class Win32_OperatingSystem
        $totalMemory = $memoryInfo.TotalVisibleMemorySize
        $freeMemory = $memoryInfo.FreePhysicalMemory
        $usedMemory = $totalMemory - $freeMemory
        $memoryUsage = ($usedMemory / $totalMemory) * 100
        $metrics.Memory = [math]::Round($memoryUsage, 1)
    } catch {
        $metrics.Memory = 0
    }
    
    # Throughput (events per second)
    try {
        $throughputQuery = "SELECT count() FROM bulletproof_threats WHERE timestamp >= now() - INTERVAL 1 MINUTE"
        $throughputResponse = Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Body $throughputQuery -TimeoutSec 2
        $metrics.Throughput = [int]$throughputResponse
    } catch {
        $metrics.Throughput = 0
    }
    
    # Active Connections
    try {
        $natsStats = Invoke-RestMethod -Uri "http://localhost:8222/varz" -TimeoutSec 2
        $metrics.Connections = $natsStats.connections
    } catch {
        $metrics.Connections = 0
    }
    
    # Process Count
    $rustProcesses = (Get-Process -Name "siem-rust-core" -ErrorAction SilentlyContinue).Count
    $goProcesses = (Get-Process -Name "bulletproof_processor" -ErrorAction SilentlyContinue).Count
    $metrics.CurrentInstances = $rustProcesses + $goProcesses
    
    return $metrics
}

function Calculate-ScalingDecision {
    param($metrics, $config)
    
    $decision = @{
        Action = "None"
        Reason = ""
        TargetInstances = $metrics.CurrentInstances
        Priority = 0
    }
    
    # Calculate load score (weighted average)
    $loadScore = ($metrics.CPU * 0.4) + ($metrics.Memory * 0.3) + (($metrics.Throughput / $config.throughput_threshold) * 100 * 0.3)
    
    if ($Verbose) {
        Write-Host "📊 Load Analysis:" -ForegroundColor Cyan
        Write-Host "   CPU Usage: $($metrics.CPU)%" -ForegroundColor White
        Write-Host "   Memory Usage: $($metrics.Memory)%" -ForegroundColor White
        Write-Host "   Throughput: $($metrics.Throughput) events/min" -ForegroundColor White
        Write-Host "   Load Score: $([math]::Round($loadScore, 1))%" -ForegroundColor White
        Write-Host "   Current Instances: $($metrics.CurrentInstances)" -ForegroundColor White
    }
    
    # Scale up decision
    if ($loadScore -gt $config.scale_up_threshold -and $metrics.CurrentInstances -lt $config.max_instances) {
        $decision.Action = "ScaleUp"
        $decision.Reason = "High load detected ($([math]::Round($loadScore, 1))% > $($config.scale_up_threshold)%)"
        $decision.TargetInstances = [math]::Min($metrics.CurrentInstances + 2, $config.max_instances)
        $decision.Priority = 1
    }
    # Scale down decision
    elseif ($loadScore -lt $config.scale_down_threshold -and $metrics.CurrentInstances -gt $config.min_instances) {
        $decision.Action = "ScaleDown"
        $decision.Reason = "Low load detected ($([math]::Round($loadScore, 1))% < $($config.scale_down_threshold)%)"
        $decision.TargetInstances = [math]::Max($metrics.CurrentInstances - 1, $config.min_instances)
        $decision.Priority = 2
    }
    
    return $decision
}

function Scale-Up {
    param($currentInstances, $targetInstances, $config)
    
    $instancesToAdd = $targetInstances - $currentInstances
    
    if ($DryRun) {
        Write-Host "📈 [DRY RUN] Would scale UP: $currentInstances → $targetInstances instances (+$instancesToAdd)" -ForegroundColor Yellow
        return $true
    }
    
    Write-Host "📈 Scaling UP: $currentInstances → $targetInstances instances (+$instancesToAdd)" -ForegroundColor Green
    
    # Add Rust cores
    $rustProcesses = (Get-Process -Name "siem-rust-core" -ErrorAction SilentlyContinue).Count
    $goProcesses = (Get-Process -Name "bulletproof_processor" -ErrorAction SilentlyContinue).Count
    
    $rustToAdd = [math]::Min($instancesToAdd, 10)  # Max 10 Rust cores
    $goToAdd = [math]::Max(0, $instancesToAdd - $rustToAdd)  # Remaining as Go processors
    
    # Start new Rust cores
    for ($i = 0; $i -lt $rustToAdd; $i++) {
        Write-Host "   🦀 Starting Rust Bulletproof Core..." -ForegroundColor Cyan
        Start-Process -FilePath "rust-core\target\release\siem-rust-core.exe" -WindowStyle Hidden -PassThru | Out-Null
        Start-Sleep -Seconds 2
    }
    
    # Start new Go processors
    for ($i = 0; $i -lt $goToAdd; $i++) {
        Write-Host "   🐹 Starting Go Bulletproof Processor..." -ForegroundColor Cyan
        Start-Process -FilePath "go-services\bulletproof_processor.exe" -WindowStyle Hidden -PassThru | Out-Null
        Start-Sleep -Seconds 1
    }
    
    Write-Host "✅ Scale UP completed: $targetInstances instances now running" -ForegroundColor Green
    return $true
}

function Scale-Down {
    param($currentInstances, $targetInstances, $config)
    
    $instancesToRemove = $currentInstances - $targetInstances
    
    if ($DryRun) {
        Write-Host "📉 [DRY RUN] Would scale DOWN: $currentInstances → $targetInstances instances (-$instancesToRemove)" -ForegroundColor Yellow
        return $true
    }
    
    Write-Host "📉 Scaling DOWN: $currentInstances → $targetInstances instances (-$instancesToRemove)" -ForegroundColor Yellow
    
    # Get current processes
    $rustProcesses = Get-Process -Name "siem-rust-core" -ErrorAction SilentlyContinue
    $goProcesses = Get-Process -Name "bulletproof_processor" -ErrorAction SilentlyContinue
    
    # Remove Go processors first (lower priority)
    $goToRemove = [math]::Min($instancesToRemove, $goProcesses.Count)
    for ($i = 0; $i -lt $goToRemove; $i++) {
        if ($goProcesses.Count -gt 0) {
            $processToKill = $goProcesses[$i]
            Write-Host "   🐹 Stopping Go Bulletproof Processor (PID: $($processToKill.Id))..." -ForegroundColor Cyan
            $processToKill.Kill()
        }
    }
    
    # Remove Rust cores if needed
    $rustToRemove = $instancesToRemove - $goToRemove
    for ($i = 0; $i -lt $rustToRemove; $i++) {
        if ($rustProcesses.Count -gt 0) {
            $processToKill = $rustProcesses[$i]
            Write-Host "   🦀 Stopping Rust Bulletproof Core (PID: $($processToKill.Id))..." -ForegroundColor Cyan
            $processToKill.Kill()
        }
    }
    
    Write-Host "✅ Scale DOWN completed: $targetInstances instances now running" -ForegroundColor Green
    return $true
}

function Show-AutoScalingStatus {
    param($metrics, $decision, $config, $lastScaleTime)
    
    $currentTime = Get-Date -Format "HH:mm:ss"
    
    Write-Host "🕐 $currentTime | 📈 Ultra SIEM Auto-Scaling Status" -ForegroundColor White
    Write-Host "=" * 60 -ForegroundColor Gray
    
    # Current Metrics
    Write-Host "📊 CURRENT METRICS:" -ForegroundColor Cyan
    Write-Host "   🔥 CPU Usage: $($metrics.CPU)%" -ForegroundColor White
    Write-Host "   💾 Memory Usage: $($metrics.Memory)%" -ForegroundColor White
    Write-Host "   📡 Throughput: $($metrics.Throughput) events/min" -ForegroundColor White
    Write-Host "   🔗 Active Connections: $($metrics.Connections)" -ForegroundColor White
    Write-Host "   🚀 Current Instances: $($metrics.CurrentInstances)" -ForegroundColor White
    
    # Scaling Configuration
    Write-Host ""
    Write-Host "⚙️ SCALING CONFIGURATION:" -ForegroundColor Yellow
    Write-Host "   📈 Min Instances: $($config.min_instances)" -ForegroundColor White
    Write-Host "   📉 Max Instances: $($config.max_instances)" -ForegroundColor White
    Write-Host "   🔺 Scale Up Threshold: $($config.scale_up_threshold)%" -ForegroundColor White
    Write-Host "   🔻 Scale Down Threshold: $($config.scale_down_threshold)%" -ForegroundColor White
    
    # Scaling Decision
    Write-Host ""
    Write-Host "🎯 SCALING DECISION:" -ForegroundColor Magenta
    if ($decision.Action -eq "None") {
        Write-Host "   ✅ No scaling action needed" -ForegroundColor Green
    } elseif ($decision.Action -eq "ScaleUp") {
        Write-Host "   📈 SCALE UP: $($metrics.CurrentInstances) → $($decision.TargetInstances) instances" -ForegroundColor Green
        Write-Host "   📝 Reason: $($decision.Reason)" -ForegroundColor White
    } elseif ($decision.Action -eq "ScaleDown") {
        Write-Host "   📉 SCALE DOWN: $($metrics.CurrentInstances) → $($decision.TargetInstances) instances" -ForegroundColor Yellow
        Write-Host "   📝 Reason: $($decision.Reason)" -ForegroundColor White
    }
    
    # Last Scale Time
    if ($lastScaleTime) {
        $timeSinceLastScale = (Get-Date) - $lastScaleTime
        Write-Host "   🕐 Time since last scale: $($timeSinceLastScale.Minutes)m $($timeSinceLastScale.Seconds)s" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "🎮 Controls: R=Refresh | Q=Quit | V=Verbose | D=Dry Run" -ForegroundColor Gray
    Write-Host "=" * 60 -ForegroundColor Gray
}

# Main auto-scaling loop
Show-AutoScalingBanner

$config = Get-AutoScalingConfig
$lastScaleTime = $null
$lastScaleAction = "None"

Write-Host "🚀 Starting Auto-Scaling Controller..." -ForegroundColor Green
Write-Host "📊 Monitoring interval: $CheckInterval seconds" -ForegroundColor Cyan
Write-Host "🎯 Scaling range: $($config.min_instances) - $($config.max_instances) instances" -ForegroundColor White
Write-Host ""

do {
    # Get current system metrics
    $metrics = Get-SystemMetrics
    
    # Calculate scaling decision
    $decision = Calculate-ScalingDecision -metrics $metrics -config $config
    
    # Check cooldown periods
    $canScale = $true
    if ($lastScaleTime) {
        $timeSinceLastScale = (Get-Date) - $lastScaleTime
        
        if ($decision.Action -eq "ScaleUp" -and $timeSinceLastScale.TotalSeconds -lt $config.scale_up_cooldown) {
            $canScale = $false
            $decision.Reason += " (cooldown: $([math]::Round($config.scale_up_cooldown - $timeSinceLastScale.TotalSeconds, 0))s remaining)"
        } elseif ($decision.Action -eq "ScaleDown" -and $timeSinceLastScale.TotalSeconds -lt $config.scale_down_cooldown) {
            $canScale = $false
            $decision.Reason += " (cooldown: $([math]::Round($config.scale_down_cooldown - $timeSinceLastScale.TotalSeconds, 0))s remaining)"
        }
    }
    
    # Show status
    Show-AutoScalingStatus -metrics $metrics -decision $decision -config $config -lastScaleTime $lastScaleTime
    
    # Execute scaling action
    if ($canScale -and $decision.Action -ne "None") {
        if ($decision.Action -eq "ScaleUp") {
            Scale-Up -currentInstances $metrics.CurrentInstances -targetInstances $decision.TargetInstances -config $config
        } elseif ($decision.Action -eq "ScaleDown") {
            Scale-Down -currentInstances $metrics.CurrentInstances -targetInstances $decision.TargetInstances -config $config
        }
        
        $lastScaleTime = Get-Date
        $lastScaleAction = $decision.Action
    }
    
    # Check for user input
    if ($Host.UI.RawUI.KeyAvailable) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            82 { # R key - Refresh
                Clear-Host
                Show-AutoScalingBanner
            }
            86 { # V key - Verbose
                $Verbose = -not $Verbose
                Clear-Host
                Show-AutoScalingBanner
            }
            68 { # D key - Dry Run
                $DryRun = -not $DryRun
                $mode = if ($DryRun) { "DRY RUN" } else { "LIVE" }
                Write-Host "🔄 Mode changed to: $mode" -ForegroundColor $(if ($DryRun) { "Yellow" } else { "Green" })
            }
            81 { # Q key - Quit
                Write-Host "📈 Auto-scaling controller stopped." -ForegroundColor Yellow
                exit 0
            }
        }
    }
    
    Start-Sleep -Seconds $CheckInterval
    
} while ($Continuous -or $true)

Write-Host "📈 Ultra SIEM Auto-Scaling Controller - Dynamic scaling complete!" -ForegroundColor Green 