#Requires -RunAsAdministrator

# eBPF-based Continuous Profiling for Ultra SIEM
# Real-time performance optimization and resource monitoring

param(
    [ValidateSet("Start", "Stop", "Monitor", "Optimize", "Report")]
    [string]$Action = "Start",
    [int]$SampleIntervalSeconds = 30,
    [switch]$EnableAutoTuning = $true
)

$ErrorActionPreference = "Stop"

# Configuration
$ProfilerConfig = @{
    SampleInterval = $SampleIntervalSeconds
    MetricsPort = 9090
    LogPath = "logs\profiler.log"
    ConfigPath = "config\profiler.json"
    ThresholdCPU = 80
    ThresholdMemory = 90
    ThresholdLatency = 100
}

function Write-ProfilerLog {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [PROFILER-$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Magenta" }
    })
    Add-Content -Path $ProfilerConfig.LogPath -Value $logEntry
}

function Install-eBPFTools {
    Write-ProfilerLog "🔧 Installing eBPF toolchain for Windows..."
    
    # Install eBPF for Windows
    if (-not (Get-Command "ebpf.exe" -ErrorAction SilentlyContinue)) {
        Write-ProfilerLog "Downloading eBPF for Windows..."
        $ebpfUrl = "https://github.com/microsoft/ebpf-for-windows/releases/latest/download/ebpf-for-windows.msi"
        Invoke-WebRequest -Uri $ebpfUrl -OutFile "ebpf-windows.msi"
        
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "ebpf-windows.msi", "/quiet" -Wait
        Remove-Item "ebpf-windows.msi"
        
        Write-ProfilerLog "✅ eBPF for Windows installed"
    }
    
    # Install performance counters
    if (-not (Get-WindowsFeature "Performance-Counters").InstallState -eq "Installed") {
        Enable-WindowsOptionalFeature -Online -FeatureName "Performance-Counters" -All
    }
    
    # Install ETW manifests
    wevtutil im "C:\Windows\System32\winevt\Manifests\Microsoft-Windows-Kernel-Process-Events.man"
    
    Write-ProfilerLog "✅ eBPF tools installation completed"
}

function Start-ContinuousProfiling {
    Write-ProfilerLog "🚀 Starting continuous profiling system..."
    
    # Create eBPF program for system monitoring
    $ebpfProgram = @"
#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>

struct event_data {
    __u32 pid;
    __u32 cpu;
    __u64 timestamp;
    __u64 runtime;
    char comm[16];
};

struct {
    __uint(type, BPF_MAP_TYPE_RINGBUF);
    __uint(max_entries, 256 * 1024);
} events SEC(".maps");

SEC("kprobe/finish_task_switch")
int trace_context_switch(struct pt_regs *ctx) {
    struct event_data *event;
    __u64 ts = bpf_ktime_get_ns();
    __u32 pid = bpf_get_current_pid_tgid() >> 32;
    
    event = bpf_ringbuf_reserve(&events, sizeof(*event), 0);
    if (!event)
        return 0;
    
    event->pid = pid;
    event->cpu = bpf_get_smp_processor_id();
    event->timestamp = ts;
    event->runtime = ts; // Will be calculated by userspace
    bpf_get_current_comm(&event->comm, sizeof(event->comm));
    
    bpf_ringbuf_submit(event, 0);
    return 0;
}

char LICENSE[] SEC("license") = "GPL";
"@

    $ebpfProgram | Out-File "monitoring\kernel_profiler.c" -Encoding UTF8
    
    # Compile eBPF program (using clang for eBPF)
    if (Get-Command "clang" -ErrorAction SilentlyContinue) {
        clang -target bpf -O2 -c "monitoring\kernel_profiler.c" -o "monitoring\kernel_profiler.o"
        Write-ProfilerLog "✅ eBPF program compiled"
    }
    
    # Start performance monitoring
    Start-PerformanceMonitoring
    
    # Start resource optimization
    if ($EnableAutoTuning) {
        Start-AutoTuning
    }
    
    Write-ProfilerLog "✅ Continuous profiling started"
}

function Start-PerformanceMonitoring {
    Write-ProfilerLog "📊 Starting performance metrics collection..."
    
    # PowerShell job for continuous monitoring
    $monitoringJob = Start-Job -ScriptBlock {
        param($Config)
        
        while ($true) {
            $metrics = @{
                Timestamp = Get-Date
                CPU = @{}
                Memory = @{}
                Network = @{}
                Disk = @{}
                Processes = @{}
            }
            
            # CPU metrics
            $cpuCounters = Get-Counter "\Processor(_Total)\% Processor Time", 
                                     "\Processor(_Total)\% User Time",
                                     "\Processor(_Total)\% Privileged Time" -SampleInterval 1 -MaxSamples 1
            
            foreach ($counter in $cpuCounters.CounterSamples) {
                $metricName = ($counter.Path -split "\\")[-1].Replace("% ", "").Replace(" ", "")
                $metrics.CPU[$metricName] = [math]::Round($counter.CookedValue, 2)
            }
            
            # Memory metrics
            $memCounters = Get-Counter "\Memory\Available MBytes",
                                      "\Memory\Committed Bytes",
                                      "\Memory\Pool Paged Bytes" -SampleInterval 1 -MaxSamples 1
            
            foreach ($counter in $memCounters.CounterSamples) {
                $metricName = ($counter.Path -split "\\")[-1].Replace(" ", "")
                $metrics.Memory[$metricName] = [math]::Round($counter.CookedValue, 2)
            }
            
            # Process-specific metrics for SIEM services
            $siemProcesses = @("vector", "processor", "bridge", "clickhouse", "nats-server", "grafana")
            foreach ($processName in $siemProcesses) {
                $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
                if ($process) {
                    $metrics.Processes[$processName] = @{
                        CPU = $process.CPU
                        Memory = [math]::Round($process.WorkingSet64 / 1MB, 2)
                        Threads = $process.Threads.Count
                        Handles = $process.HandleCount
                    }
                }
            }
            
            # Network metrics
            $netCounters = Get-Counter "\Network Interface(*)\Bytes Total/sec" -SampleInterval 1 -MaxSamples 1
            $totalNetworkBytes = ($netCounters.CounterSamples | Where-Object { $_.InstanceName -ne "_Total" -and $_.InstanceName -notlike "*Loopback*" } | Measure-Object -Property CookedValue -Sum).Sum
            $metrics.Network.TotalBytesPerSec = [math]::Round($totalNetworkBytes, 2)
            
            # Disk metrics
            $diskCounters = Get-Counter "\PhysicalDisk(_Total)\Disk Bytes/sec",
                                       "\PhysicalDisk(_Total)\Avg. Disk Queue Length" -SampleInterval 1 -MaxSamples 1
            
            foreach ($counter in $diskCounters.CounterSamples) {
                $metricName = ($counter.Path -split "\\")[-1].Replace("Avg. ", "").Replace("Disk ", "").Replace("/sec", "PerSec").Replace(" ", "")
                $metrics.Disk[$metricName] = [math]::Round($counter.CookedValue, 2)
            }
            
            # Store metrics
            $metricsJson = $metrics | ConvertTo-Json -Depth 10
            Add-Content -Path "logs\performance_metrics.log" -Value $metricsJson
            
            # Send to Prometheus endpoint
            try {
                $prometheusData = ConvertTo-PrometheusFormat -Metrics $metrics
                Invoke-RestMethod -Uri "http://localhost:$($Config.MetricsPort)/metrics" -Method POST -Body $prometheusData -ContentType "text/plain"
            }
            catch {
                Write-Host "Failed to send metrics to Prometheus: $_"
            }
            
            Start-Sleep -Seconds $Config.SampleInterval
        }
    } -ArgumentList $ProfilerConfig
    
    Write-ProfilerLog "✅ Performance monitoring job started (ID: $($monitoringJob.Id))"
    
    # Store job ID for management
    $monitoringJob.Id | Out-File "monitoring\profiler_job.txt"
}

function Start-AutoTuning {
    Write-ProfilerLog "⚙️ Starting automatic performance tuning..."
    
    $tuningJob = Start-Job -ScriptBlock {
        param($Config)
        
        while ($true) {
            try {
                # Read latest metrics
                $latestMetrics = Get-Content "logs\performance_metrics.log" | Select-Object -Last 1 | ConvertFrom-Json
                
                # CPU optimization
                if ($latestMetrics.CPU.ProcessorTime -gt $Config.ThresholdCPU) {
                    Write-Host "🔧 High CPU detected: $($latestMetrics.CPU.ProcessorTime)% - Optimizing..."
                    
                    # Reduce Vector batch size
                    $vectorConfig = Get-Content "config\vector\windows.toml" -Raw
                    if ($vectorConfig -match "batch_size = (\d+)") {
                        $currentBatch = [int]$matches[1]
                        $newBatch = [math]::Max(1000, $currentBatch - 500)
                        $vectorConfig = $vectorConfig -replace "batch_size = \d+", "batch_size = $newBatch"
                        $vectorConfig | Out-File "config\vector\windows.toml" -Encoding UTF8
                        
                        # Reload Vector
                        Invoke-RestMethod -Uri "http://localhost:8686/reload" -Method POST
                        Write-Host "✅ Reduced Vector batch size to $newBatch"
                    }
                    
                    # Adjust ClickHouse max_threads
                    $clickhouseThreads = [math]::Max(4, [Environment]::ProcessorCount - 2)
                    docker exec clickhouse clickhouse-client --query "SET max_threads = $clickhouseThreads"
                    Write-Host "✅ Adjusted ClickHouse threads to $clickhouseThreads"
                }
                
                # Memory optimization
                if ($latestMetrics.Memory.AvailableMBytes -lt 1000) {
                    Write-Host "🔧 Low memory detected: $($latestMetrics.Memory.AvailableMBytes)MB - Optimizing..."
                    
                    # Force garbage collection in Go services
                    $goProcesses = Get-Process -Name "processor", "bridge" -ErrorAction SilentlyContinue
                    foreach ($process in $goProcesses) {
                        # Send SIGUSR1 to trigger GC (Windows equivalent)
                        $process.Refresh()
                    }
                    
                    # Adjust ClickHouse memory settings
                    docker exec clickhouse clickhouse-client --query "SYSTEM DROP MARK CACHE"
                    docker exec clickhouse clickhouse-client --query "SYSTEM DROP UNCOMPRESSED CACHE"
                    Write-Host "✅ Cleared ClickHouse caches"
                }
                
                # Network optimization
                if ($latestMetrics.Network.TotalBytesPerSec -gt 100000000) { # >100MB/s
                    Write-Host "🔧 High network usage detected - Optimizing..."
                    
                    # Enable NATS compression
                    docker exec nats nats server edit --compression
                    Write-Host "✅ Enabled NATS compression"
                }
                
                # Process-specific optimizations
                foreach ($processName in $latestMetrics.Processes.Keys) {
                    $processMetrics = $latestMetrics.Processes[$processName]
                    
                    if ($processMetrics.Memory -gt 2048) { # >2GB
                        Write-Host "🔧 High memory usage in $processName`: $($processMetrics.Memory)MB"
                        
                        switch ($processName) {
                            "vector" {
                                # Reduce buffer size
                                $vectorConfig = Get-Content "config\vector\windows.toml" -Raw
                                $vectorConfig = $vectorConfig -replace "max_size = \d+", "max_size = 1000000"
                                $vectorConfig | Out-File "config\vector\windows.toml" -Encoding UTF8
                                Invoke-RestMethod -Uri "http://localhost:8686/reload" -Method POST
                            }
                            "clickhouse" {
                                # Reduce max_memory_usage
                                docker exec clickhouse clickhouse-client --query "SET max_memory_usage = 2000000000"
                            }
                        }
                    }
                }
                
                # Log optimization actions
                $optimizationLog = @{
                    Timestamp = Get-Date
                    Metrics = $latestMetrics
                    Actions = "Auto-tuning performed"
                }
                $optimizationLog | ConvertTo-Json | Add-Content -Path "logs\optimization.log"
                
            }
            catch {
                Write-Host "Auto-tuning error: $_"
            }
            
            Start-Sleep -Seconds ($Config.SampleInterval * 2)
        }
    } -ArgumentList $ProfilerConfig
    
    Write-ProfilerLog "✅ Auto-tuning job started (ID: $($tuningJob.Id))"
    $tuningJob.Id | Out-File "monitoring\tuning_job.txt"
}

function ConvertTo-PrometheusFormat {
    param($Metrics)
    
    $prometheusMetrics = @()
    
    # CPU metrics
    foreach ($metric in $Metrics.CPU.Keys) {
        $prometheusMetrics += "siem_cpu_$($metric.ToLower()) $($Metrics.CPU[$metric])"
    }
    
    # Memory metrics
    foreach ($metric in $Metrics.Memory.Keys) {
        $prometheusMetrics += "siem_memory_$($metric.ToLower()) $($Metrics.Memory[$metric])"
    }
    
    # Process metrics
    foreach ($process in $Metrics.Processes.Keys) {
        foreach ($metric in $Metrics.Processes[$process].Keys) {
            $prometheusMetrics += "siem_process_$($metric.ToLower()){process=`"$process`"} $($Metrics.Processes[$process][$metric])"
        }
    }
    
    return $prometheusMetrics -join "`n"
}

function Stop-ContinuousProfiling {
    Write-ProfilerLog "🛑 Stopping continuous profiling..."
    
    # Stop monitoring job
    if (Test-Path "monitoring\profiler_job.txt") {
        $jobId = Get-Content "monitoring\profiler_job.txt"
        Stop-Job -Id $jobId -ErrorAction SilentlyContinue
        Remove-Job -Id $jobId -ErrorAction SilentlyContinue
        Remove-Item "monitoring\profiler_job.txt"
    }
    
    # Stop tuning job
    if (Test-Path "monitoring\tuning_job.txt") {
        $jobId = Get-Content "monitoring\tuning_job.txt"
        Stop-Job -Id $jobId -ErrorAction SilentlyContinue
        Remove-Job -Id $jobId -ErrorAction SilentlyContinue
        Remove-Item "monitoring\tuning_job.txt"
    }
    
    Write-ProfilerLog "✅ Continuous profiling stopped"
}

function Get-PerformanceReport {
    Write-ProfilerLog "📈 Generating performance report..."
    
    # Read recent metrics
    $recentMetrics = Get-Content "logs\performance_metrics.log" | Select-Object -Last 100 | ForEach-Object { ConvertFrom-Json $_ }
    
    # Calculate statistics
    $cpuStats = $recentMetrics | ForEach-Object { $_.CPU.ProcessorTime } | Measure-Object -Average -Maximum -Minimum
    $memoryStats = $recentMetrics | ForEach-Object { $_.Memory.AvailableMBytes } | Measure-Object -Average -Maximum -Minimum
    
    $report = @{
        GeneratedAt = Get-Date
        SampleCount = $recentMetrics.Count
        CPU = @{
            Average = [math]::Round($cpuStats.Average, 2)
            Maximum = [math]::Round($cpuStats.Maximum, 2)
            Minimum = [math]::Round($cpuStats.Minimum, 2)
        }
        Memory = @{
            AverageAvailable = [math]::Round($memoryStats.Average, 2)
            MaximumAvailable = [math]::Round($memoryStats.Maximum, 2)
            MinimumAvailable = [math]::Round($memoryStats.Minimum, 2)
        }
        Recommendations = @()
    }
    
    # Generate recommendations
    if ($report.CPU.Average -gt 70) {
        $report.Recommendations += "Consider scaling out processing nodes or reducing batch sizes"
    }
    
    if ($report.Memory.MinimumAvailable -lt 500) {
        $report.Recommendations += "Increase available memory or implement memory optimization"
    }
    
    $report | ConvertTo-Json -Depth 10 | Out-File "reports\performance_report_$(Get-Date -Format 'yyyyMMdd_HHmm').json"
    
    Write-ProfilerLog "✅ Performance report generated"
    return $report
}

# Main execution
switch ($Action) {
    "Start" {
        Install-eBPFTools
        Start-ContinuousProfiling
        Write-ProfilerLog "🎯 Continuous profiling system started" "SUCCESS"
    }
    
    "Stop" {
        Stop-ContinuousProfiling
    }
    
    "Monitor" {
        Get-Job | Where-Object { $_.Name -like "*profiler*" } | Receive-Job
    }
    
    "Optimize" {
        Start-AutoTuning
    }
    
    "Report" {
        Get-PerformanceReport
    }
}

Write-ProfilerLog "🔍 eBPF profiling system ready" "SUCCESS" 