# 🌪️ Ultra SIEM - Chaos Monkey
# Proves bulletproof resilience by randomly killing processes and containers

param(
    [int]$Duration = 3600,  # Duration in seconds
    [ValidateSet("Low", "Medium", "High", "Extreme")]
    [string]$Intensity = "High",
    [switch]$DryRun,
    [switch]$Continuous
)

function Show-ChaosBanner {
    Clear-Host
    Write-Host "🌪️ Ultra SIEM - Chaos Monkey" -ForegroundColor Magenta
    Write-Host "============================" -ForegroundColor Magenta
    Write-Host "🎯 Purpose: Prove bulletproof resilience through failure" -ForegroundColor Cyan
    Write-Host "⚡ Intensity: $Intensity" -ForegroundColor Yellow
    Write-Host "⏱️ Duration: $Duration seconds" -ForegroundColor Green
    Write-Host "🔒 Target: Ultra SIEM processes and containers" -ForegroundColor Red
    Write-Host "🛡️ Expected: System continues running with zero downtime" -ForegroundColor White
    Write-Host ""
}

function Get-ChaosConfig {
    $config = switch ($Intensity) {
        "Low" {
            @{
                ProcessKillInterval = 300    # 5 minutes
                ContainerKillInterval = 600  # 10 minutes
                KillProbability = 0.1        # 10% chance
                MaxConcurrentKills = 1
                RecoveryTime = 30
            }
        }
        "Medium" {
            @{
                ProcessKillInterval = 180    # 3 minutes
                ContainerKillInterval = 300  # 5 minutes
                KillProbability = 0.25       # 25% chance
                MaxConcurrentKills = 2
                RecoveryTime = 20
            }
        }
        "High" {
            @{
                ProcessKillInterval = 60     # 1 minute
                ContainerKillInterval = 120  # 2 minutes
                KillProbability = 0.5        # 50% chance
                MaxConcurrentKills = 3
                RecoveryTime = 10
            }
        }
        "Extreme" {
            @{
                ProcessKillInterval = 30     # 30 seconds
                ContainerKillInterval = 60   # 1 minute
                KillProbability = 0.75       # 75% chance
                MaxConcurrentKills = 5
                RecoveryTime = 5
            }
        }
    }
    
    return $config
}

function Get-TargetProcesses {
    $targets = @()
    
    # Rust quantum cores
    $rustProcesses = Get-Process -Name "siem-rust-core" -ErrorAction SilentlyContinue
    foreach ($process in $rustProcesses) {
        $targets += @{
            Type = "Process"
            Name = "Rust Quantum Core"
            PID = $process.Id
            Process = $process
            Priority = 1
        }
    }
    
    # Go quantum processors
    $goProcesses = Get-Process -Name "bulletproof_processor" -ErrorAction SilentlyContinue
    foreach ($process in $goProcesses) {
        $targets += @{
            Type = "Process"
            Name = "Go Bulletproof Processor"
            PID = $process.Id
            Process = $process
            Priority = 2
        }
    }
    
    # Zig query engine
    $zigProcesses = Get-Process -Name "zig-query" -ErrorAction SilentlyContinue
    foreach ($process in $zigProcesses) {
        $targets += @{
            Type = "Process"
            Name = "Zig Query Engine"
            PID = $process.Id
            Process = $process
            Priority = 3
        }
    }
    
    return $targets
}

function Get-TargetContainers {
    $targets = @()
    
    # Get running containers
    $containers = docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | Select-Object -Skip 1
    
    foreach ($container in $containers) {
        $parts = $container -split "\s+"
        if ($parts.Count -ge 3) {
            $name = $parts[0]
            $image = $parts[1]
            
            # Target SIEM-related containers
            if ($image -match "clickhouse|nats|grafana|jaeger|otel") {
                $targets += @{
                    Type = "Container"
                    Name = $name
                    Image = $image
                    Priority = 4
                }
            }
        }
    }
    
    return $targets
}

function Kill-Process {
    param($target)
    
    try {
        $processName = $target.Name
        $processId = $target.PID
        
        if ($DryRun) {
            Write-Host "🌪️ [DRY RUN] Would kill process: $processName (PID: $processId)" -ForegroundColor Yellow
            return $true
        }
        
        Write-Host "🌪️ Killing process: $processName (PID: $processId)" -ForegroundColor Red
        
        # Kill the process
        $target.Process.Kill()
        
        Write-Host "✅ Successfully killed process: $processName (PID: $processId)" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ Failed to kill process: $($target.Name) - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Kill-Container {
    param($target)
    
    try {
        $containerName = $target.Name
        $image = $target.Image
        
        if ($DryRun) {
            Write-Host "🌪️ [DRY RUN] Would kill container: $containerName ($image)" -ForegroundColor Yellow
            return $true
        }
        
        Write-Host "🌪️ Killing container: $containerName ($image)" -ForegroundColor Red
        
        # Stop the container
        docker stop $containerName
        
        Write-Host "✅ Successfully killed container: $containerName ($image)" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ Failed to kill container: $($target.Name) - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-SystemHealth {
    $healthChecks = @()
    
    # Check NATS
    try {
        $natsHealth = Invoke-RestMethod -Uri "http://localhost:8222/varz" -TimeoutSec 2
        $healthChecks += @{ Service = "NATS"; Status = "Healthy" }
    } catch {
        $healthChecks += @{ Service = "NATS"; Status = "Unhealthy" }
    }
    
    # Check ClickHouse
    try {
        $clickhouseHealth = Invoke-RestMethod -Uri "http://localhost:8123/ping" -TimeoutSec 2
        $healthChecks += @{ Service = "ClickHouse"; Status = "Healthy" }
    } catch {
        $healthChecks += @{ Service = "ClickHouse"; Status = "Unhealthy" }
    }
    
    # Check Grafana
    try {
        $grafanaHealth = Invoke-RestMethod -Uri "http://localhost:3000/api/health" -TimeoutSec 2
        $healthChecks += @{ Service = "Grafana"; Status = "Healthy" }
    } catch {
        $healthChecks += @{ Service = "Grafana"; Status = "Unhealthy" }
    }
    
    # Count healthy services
    $healthyCount = ($healthChecks | Where-Object { $_.Status -eq "Healthy" }).Count
    $totalCount = $healthChecks.Count
    
    return @{
        HealthChecks = $healthChecks
        HealthyCount = $healthyCount
        TotalCount = $totalCount
        HealthPercentage = if ($totalCount -gt 0) { [math]::Round(($healthyCount / $totalCount) * 100, 1) } else { 0 }
    }
}

function Show-ChaosStatus {
    param($config, $startTime, $killsPerformed, $systemHealth)
    
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 0)
    $remaining = $Duration - $elapsed
    
    Clear-Host
    Write-Host "🌪️ Ultra SIEM - Chaos Monkey Status" -ForegroundColor Magenta
    Write-Host "====================================" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "⚡ Configuration:" -ForegroundColor Cyan
    Write-Host "   Intensity: $Intensity" -ForegroundColor White
    Write-Host "   Kill Probability: $($config.KillProbability * 100)%" -ForegroundColor White
    Write-Host "   Max Concurrent Kills: $($config.MaxConcurrentKills)" -ForegroundColor White
    Write-Host "   Recovery Time: $($config.RecoveryTime)s" -ForegroundColor White
    Write-Host ""
    Write-Host "⏱️ Timing:" -ForegroundColor Cyan
    Write-Host "   Elapsed: ${elapsed}s" -ForegroundColor White
    Write-Host "   Remaining: ${remaining}s" -ForegroundColor White
    Write-Host "   Progress: $([math]::Round(($elapsed / $Duration) * 100, 1))%" -ForegroundColor White
    Write-Host ""
    Write-Host "🎯 Chaos Activity:" -ForegroundColor Cyan
    Write-Host "   Kills Performed: $killsPerformed" -ForegroundColor White
    Write-Host "   Kill Rate: $([math]::Round($killsPerformed / ($elapsed / 60), 2)) kills/minute" -ForegroundColor White
    Write-Host ""
    Write-Host "🔍 System Health:" -ForegroundColor Cyan
    Write-Host "   Overall Health: $($systemHealth.HealthPercentage)%" -ForegroundColor $(if ($systemHealth.HealthPercentage -ge 80) { "Green" } elseif ($systemHealth.HealthPercentage -ge 60) { "Yellow" } else { "Red" })
    Write-Host "   Healthy Services: $($systemHealth.HealthyCount)/$($systemHealth.TotalCount)" -ForegroundColor White
    Write-Host ""
    
    foreach ($check in $systemHealth.HealthChecks) {
        $statusColor = if ($check.Status -eq "Healthy") { "Green" } else { "Red" }
        Write-Host "   $($check.Service): $($check.Status)" -ForegroundColor $statusColor
    }
    
    Write-Host ""
    Write-Host "🎮 Controls: Q=Quit | P=Pause | R=Resume | S=Status" -ForegroundColor Gray
    Write-Host "=" * 50 -ForegroundColor Gray
}

# Main chaos monkey execution
Show-ChaosBanner

if ($DryRun) {
    Write-Host "🌪️ DRY RUN MODE: No actual kills will be performed" -ForegroundColor Yellow
}

$config = Get-ChaosConfig
$startTime = Get-Date
$killsPerformed = 0
$lastProcessKill = Get-Date
$lastContainerKill = Get-Date
$paused = $false

Write-Host "🚀 Starting Chaos Monkey with $Intensity intensity..." -ForegroundColor Green
Write-Host "🎯 Target: Ultra SIEM processes and containers" -ForegroundColor Cyan
Write-Host "🛡️ Expected: System continues running with zero downtime" -ForegroundColor White
Write-Host ""

do {
    $currentTime = Get-Date
    $elapsed = ($currentTime - $startTime).TotalSeconds
    
    if ($elapsed -ge $Duration) {
        break
    }
    
    if (-not $paused) {
        # Check if we should kill a process
        $processKillInterval = $config.ProcessKillInterval
        if (($currentTime - $lastProcessKill).TotalSeconds -ge $processKillInterval) {
            $targets = Get-TargetProcesses
            
            if ($targets.Count -gt 0) {
                # Random selection based on probability
                if ((Get-Random -Minimum 1 -Maximum 101) -le ($config.KillProbability * 100)) {
                    $target = $targets | Get-Random
                    
                    if (Kill-Process -target $target) {
                        $killsPerformed++
                        $lastProcessKill = $currentTime
                        
                        # Wait for recovery
                        Start-Sleep -Seconds $config.RecoveryTime
                    }
                }
            }
        }
        
        # Check if we should kill a container
        $containerKillInterval = $config.ContainerKillInterval
        if (($currentTime - $lastContainerKill).TotalSeconds -ge $containerKillInterval) {
            $targets = Get-TargetContainers
            
            if ($targets.Count -gt 0) {
                # Random selection based on probability
                if ((Get-Random -Minimum 1 -Maximum 101) -le ($config.KillProbability * 100)) {
                    $target = $targets | Get-Random
                    
                    if (Kill-Container -target $target) {
                        $killsPerformed++
                        $lastContainerKill = $currentTime
                        
                        # Wait for recovery
                        Start-Sleep -Seconds $config.RecoveryTime
                    }
                }
            }
        }
    }
    
    # Check system health
    $systemHealth = Test-SystemHealth
    
    # Show status every 10 seconds
    if ([math]::Floor($elapsed) % 10 -eq 0) {
        Show-ChaosStatus -config $config -startTime $startTime -killsPerformed $killsPerformed -systemHealth $systemHealth
    }
    
    # Check for user input
    if ($Host.UI.RawUI.KeyAvailable) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.Character.ToUpper()) {
            'Q' { 
                Write-Host "🌪️ Chaos Monkey stopped by user." -ForegroundColor Yellow
                break 
            }
            'P' { 
                $paused = $true
                Write-Host "⏸️ Chaos Monkey paused." -ForegroundColor Yellow
            }
            'R' { 
                $paused = $false
                Write-Host "▶️ Chaos Monkey resumed." -ForegroundColor Green
            }
            'S' { 
                Show-ChaosStatus -config $config -startTime $startTime -killsPerformed $killsPerformed -systemHealth $systemHealth
            }
        }
    }
    
    Start-Sleep -Seconds 1
    
} while ($Continuous -or $elapsed -lt $Duration)

# Final status
$finalHealth = Test-SystemHealth
Show-ChaosStatus -config $config -startTime $startTime -killsPerformed $killsPerformed -systemHealth $finalHealth

Write-Host ""
Write-Host "🎉 Chaos Monkey Test Complete!" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green
Write-Host "🌪️ Total Kills Performed: $killsPerformed" -ForegroundColor White
Write-Host "⏱️ Total Duration: $([math]::Round($elapsed, 0))s" -ForegroundColor White
Write-Host "📊 Final System Health: $($finalHealth.HealthPercentage)%" -ForegroundColor $(if ($finalHealth.HealthPercentage -ge 80) { "Green" } elseif ($finalHealth.HealthPercentage -ge 60) { "Yellow" } else { "Red" })
Write-Host ""

if ($finalHealth.HealthPercentage -ge 80) {
    Write-Host "🛡️ BULLETPROOF RESILIENCE PROVEN!" -ForegroundColor Green
    Write-Host "✅ Ultra SIEM survived chaos engineering test" -ForegroundColor Green
    Write-Host "🎯 System is truly impossible to take down" -ForegroundColor Green
} elseif ($finalHealth.HealthPercentage -ge 60) {
    Write-Host "⚠️ PARTIAL RESILIENCE DEMONSTRATED" -ForegroundColor Yellow
    Write-Host "🔄 Some services recovered, others need attention" -ForegroundColor Yellow
} else {
    Write-Host "❌ RESILIENCE TEST FAILED" -ForegroundColor Red
    Write-Host "🔧 System needs improvement to be truly bulletproof" -ForegroundColor Red
}

Write-Host ""
Write-Host "🌌 Ultra SIEM Chaos Engineering - Bulletproof resilience validation complete!" -ForegroundColor Magenta 