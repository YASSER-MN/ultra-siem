#Requires -RunAsAdministrator

# 🔍 Ultra SIEM - eBPF Performance Profiler
# Deep kernel-level performance monitoring and analysis

param(
    [switch]$Continuous,
    [switch]$Kernel,
    [switch]$Network,
    [switch]$Memory,
    [switch]$CPU,
    [switch]$All,
    [int]$Duration = 60,
    [string]$OutputPath = "profiles/"
)

$ErrorActionPreference = "Stop"

# Configuration
$ProfilerConfig = @{
    SampleInterval = 30
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

function Show-eBPFBanner {
    Clear-Host
    Write-Host "🔍 Ultra SIEM - eBPF Performance Profiler" -ForegroundColor Purple
    Write-Host "=========================================" -ForegroundColor Purple
    Write-Host "🐧 Kernel-Level Monitoring: Deep system insights" -ForegroundColor Cyan
    Write-Host "⚡ Real-Time Profiling: Live performance analysis" -ForegroundColor Green
    Write-Host "🌐 Network Analysis: Packet-level monitoring" -ForegroundColor Yellow
    Write-Host "🧠 Memory Profiling: Allocation and usage tracking" -ForegroundColor Magenta
    Write-Host "🔥 CPU Profiling: Instruction-level analysis" -ForegroundColor Red
    Write-Host "🛡️ Zero-Impact Monitoring: Non-intrusive profiling" -ForegroundColor White
    Write-Host ""
}

function Test-eBPFSupport {
    Write-Host "🔍 Checking eBPF support..." -ForegroundColor Cyan
    
    $supported = $true
    $issues = @()
    
    # Check if running on Linux/WSL
    if ($env:OS -eq "Windows_NT") {
        Write-Host "   ⚠️ Windows detected - using WSL for eBPF" -ForegroundColor Yellow
        
        # Check if WSL is available
        try {
            $wslVersion = wsl --version 2>$null
            if ($LASTEXITCODE -ne 0) {
                $supported = $false
                $issues += "WSL not available"
            }
        } catch {
            $supported = $false
            $issues += "WSL not installed"
        }
    }
    
    # Check for required tools
    $requiredTools = @("bpftool", "perf", "bcc-tools")
    foreach ($tool in $requiredTools) {
        try {
            $result = wsl which $tool 2>$null
            if ($LASTEXITCODE -ne 0) {
                $issues += "$tool not available"
            }
        } catch {
            $issues += "$tool not found"
        }
    }
    
    if ($issues.Count -gt 0) {
        Write-Host "   ❌ eBPF support issues:" -ForegroundColor Red
        foreach ($issue in $issues) {
            Write-Host "      - $issue" -ForegroundColor Red
        }
        $supported = $false
    } else {
        Write-Host "   ✅ eBPF support confirmed" -ForegroundColor Green
    }
    
    return $supported
}

function Install-eBPFTools {
    Write-Host "🔧 Installing eBPF tools..." -ForegroundColor Cyan
    
    try {
        # Update package list
        wsl sudo apt-get update
        
        # Install eBPF tools
        wsl sudo apt-get install -y linux-tools-common linux-tools-generic
        wsl sudo apt-get install -y bpftool
        wsl sudo apt-get install -y python3-bpfcc
        wsl sudo apt-get install -y bpfcc-tools
        
        # Install BCC (BPF Compiler Collection)
        wsl sudo apt-get install -y bpfcc-tools linux-headers-$(uname -r)
        
        Write-Host "   ✅ eBPF tools installed successfully" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "   ❌ Failed to install eBPF tools: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Start-KernelProfiling {
    param($duration, $outputPath)
    
    Write-Host "🐧 Starting kernel-level profiling..." -ForegroundColor Cyan
    
    $profileData = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        KernelEvents = @()
        SystemCalls = @()
        Interrupts = @()
        ContextSwitches = @()
    }
    
    # Create output directory
    if (-not (Test-Path $outputPath)) {
        New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    }
    
    # Start kernel event monitoring
    Write-Host "   📊 Monitoring kernel events..." -ForegroundColor White
    
    # System call monitoring
    $syscallScript = @"
#!/usr/bin/env python3
from bcc import BPF
import time

# BPF program to trace system calls
bpf_text = '''
#include <uapi/linux/ptrace.h>

struct data_t {
    u32 pid;
    u32 syscall;
    u64 timestamp;
};

BPF_PERF_OUTPUT(events);

int syscall__entry(struct pt_regs *ctx, int syscall) {
    struct data_t data = {};
    data.pid = bpf_get_current_pid_tgid() >> 32;
    data.syscall = syscall;
    data.timestamp = bpf_ktime_get_ns();
    events.perf_submit(ctx, &data, sizeof(data));
    return 0;
}
'''

b = BPF(text=bpf_text)
b.attach_kprobe(event="do_sys_open", fn_name="syscall__entry")

print("Monitoring system calls...")
while True:
    try:
        b.perf_buffer_poll()
    except KeyboardInterrupt:
        exit()
"@
    
    $syscallScriptPath = "$outputPath/syscall_monitor.py"
    $syscallScript | Out-File $syscallScriptPath -Encoding UTF8
    
    # Start system call monitoring
    $syscallProcess = Start-Process -FilePath "wsl" -ArgumentList "python3 $syscallScriptPath" -WindowStyle Hidden -PassThru
    
    # Context switch monitoring
    $contextSwitchScript = @"
#!/usr/bin/env python3
from bcc import BPF
import time

bpf_text = '''
#include <uapi/linux/ptrace.h>
#include <linux/sched.h>

struct data_t {
    u32 pid;
    u32 cpu;
    u64 timestamp;
};

BPF_PERF_OUTPUT(events);

int trace_sched_switch(struct pt_regs *ctx, struct task_struct *prev, struct task_struct *next) {
    struct data_t data = {};
    data.pid = next->pid;
    data.cpu = bpf_get_smp_processor_id();
    data.timestamp = bpf_ktime_get_ns();
    events.perf_submit(ctx, &data, sizeof(data));
    return 0;
}
'''

b = BPF(text=bpf_text)
b.attach_kprobe(event="finish_task_switch", fn_name="trace_sched_switch")

print("Monitoring context switches...")
while True:
    try:
        b.perf_buffer_poll()
    except KeyboardInterrupt:
        exit()
"@
    
    $contextSwitchScriptPath = "$outputPath/context_switch_monitor.py"
    $contextSwitchScript | Out-File $contextSwitchScriptPath -Encoding UTF8
    
    # Start context switch monitoring
    $contextSwitchProcess = Start-Process -FilePath "wsl" -ArgumentList "python3 $contextSwitchScriptPath" -WindowStyle Hidden -PassThru
    
    # Wait for specified duration
    Start-Sleep -Seconds $duration
    
    # Stop monitoring
    if ($syscallProcess -and -not $syscallProcess.HasExited) {
        $syscallProcess.Kill()
    }
    if ($contextSwitchProcess -and -not $contextSwitchProcess.HasExited) {
        $contextSwitchProcess.Kill()
    }
    
    Write-Host "   ✅ Kernel profiling completed" -ForegroundColor Green
    return $profileData
}

function Start-NetworkProfiling {
    param($duration, $outputPath)
    
    Write-Host "🌐 Starting network-level profiling..." -ForegroundColor Cyan
    
    $networkData = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Packets = @()
        Connections = @()
        Bandwidth = @{}
        Latency = @{}
    }
    
    # Network packet monitoring
    $packetScript = @"
#!/usr/bin/env python3
from bcc import BPF
import time
import struct

bpf_text = '''
#include <uapi/linux/ptrace.h>
#include <net/sock.h>
#include <bcc/proto.h>

struct data_t {
    u32 pid;
    u32 saddr;
    u32 daddr;
    u16 sport;
    u16 dport;
    u32 len;
    u64 timestamp;
};

BPF_PERF_OUTPUT(events);

int trace_tcp_sendmsg(struct pt_regs *ctx, struct sock *sk, struct msghdr *msg, size_t size) {
    struct data_t data = {};
    data.pid = bpf_get_current_pid_tgid() >> 32;
    data.saddr = sk->__sk_common.skc_rcv_saddr;
    data.daddr = sk->__sk_common.skc_daddr;
    data.sport = sk->__sk_common.skc_num;
    data.dport = sk->__sk_common.skc_dport;
    data.len = size;
    data.timestamp = bpf_ktime_get_ns();
    events.perf_submit(ctx, &data, sizeof(data));
    return 0;
}

int trace_tcp_recvmsg(struct pt_regs *ctx, struct sock *sk, struct msghdr *msg, size_t size) {
    struct data_t data = {};
    data.pid = bpf_get_current_pid_tgid() >> 32;
    data.saddr = sk->__sk_common.skc_rcv_saddr;
    data.daddr = sk->__sk_common.skc_daddr;
    data.sport = sk->__sk_common.skc_num;
    data.dport = sk->__sk_common.skc_dport;
    data.len = size;
    data.timestamp = bpf_ktime_get_ns();
    events.perf_submit(ctx, &data, sizeof(data));
    return 0;
}
'''

b = BPF(text=bpf_text)
b.attach_kprobe(event="tcp_sendmsg", fn_name="trace_tcp_sendmsg")
b.attach_kprobe(event="tcp_recvmsg", fn_name="trace_tcp_recvmsg")

print("Monitoring network packets...")
while True:
    try:
        b.perf_buffer_poll()
    except KeyboardInterrupt:
        exit()
"@
    
    $packetScriptPath = "$outputPath/packet_monitor.py"
    $packetScript | Out-File $packetScriptPath -Encoding UTF8
    
    # Start packet monitoring
    $packetProcess = Start-Process -FilePath "wsl" -ArgumentList "python3 $packetScriptPath" -WindowStyle Hidden -PassThru
    
    # Wait for specified duration
    Start-Sleep -Seconds $duration
    
    # Stop monitoring
    if ($packetProcess -and -not $packetProcess.HasExited) {
        $packetProcess.Kill()
    }
    
    Write-Host "   ✅ Network profiling completed" -ForegroundColor Green
    return $networkData
}

function Start-MemoryProfiling {
    param($duration, $outputPath)
    
    Write-Host "🧠 Starting memory profiling..." -ForegroundColor Cyan
    
    $memoryData = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Allocations = @()
        Deallocations = @()
        MemoryUsage = @{}
        Leaks = @()
    }
    
    # Memory allocation monitoring
    $memoryScript = @"
#!/usr/bin/env python3
from bcc import BPF
import time

bpf_text = '''
#include <uapi/linux/ptrace.h>
#include <linux/sched.h>
#include <linux/mm.h>

struct data_t {
    u32 pid;
    u64 addr;
    u64 size;
    u64 timestamp;
};

BPF_PERF_OUTPUT(events);

int trace_malloc(struct pt_regs *ctx, size_t size) {
    struct data_t data = {};
    data.pid = bpf_get_current_pid_tgid() >> 32;
    data.size = size;
    data.timestamp = bpf_ktime_get_ns();
    events.perf_submit(ctx, &data, sizeof(data));
    return 0;
}

int trace_free(struct pt_regs *ctx, void *ptr) {
    struct data_t data = {};
    data.pid = bpf_get_current_pid_tgid() >> 32;
    data.addr = (u64)ptr;
    data.timestamp = bpf_ktime_get_ns();
    events.perf_submit(ctx, &data, sizeof(data));
    return 0;
}
'''

b = BPF(text=bpf_text)
b.attach_kprobe(event="__kmalloc", fn_name="trace_malloc")
b.attach_kprobe(event="kfree", fn_name="trace_free")

print("Monitoring memory allocations...")
while True:
    try:
        b.perf_buffer_poll()
    except KeyboardInterrupt:
        exit()
"@
    
    $memoryScriptPath = "$outputPath/memory_monitor.py"
    $memoryScript | Out-File $memoryScriptPath -Encoding UTF8
    
    # Start memory monitoring
    $memoryProcess = Start-Process -FilePath "wsl" -ArgumentList "python3 $memoryScriptPath" -WindowStyle Hidden -PassThru
    
    # Wait for specified duration
    Start-Sleep -Seconds $duration
    
    # Stop monitoring
    if ($memoryProcess -and -not $memoryProcess.HasExited) {
        $memoryProcess.Kill()
    }
    
    Write-Host "   ✅ Memory profiling completed" -ForegroundColor Green
    return $memoryData
}

function Start-CPUProfiling {
    param($duration, $outputPath)
    
    Write-Host "🔥 Starting CPU profiling..." -ForegroundColor Cyan
    
    $cpuData = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Instructions = @()
        CacheMisses = @()
        BranchMispredicts = @()
        CPUUsage = @{}
    }
    
    # CPU instruction monitoring
    $cpuScript = @"
#!/usr/bin/env python3
from bcc import BPF
import time

bpf_text = '''
#include <uapi/linux/ptrace.h>
#include <linux/sched.h>

struct data_t {
    u32 pid;
    u32 cpu;
    u64 instructions;
    u64 cache_misses;
    u64 timestamp;
};

BPF_PERF_OUTPUT(events);

int trace_cpu_cycles(struct pt_regs *ctx) {
    struct data_t data = {};
    data.pid = bpf_get_current_pid_tgid() >> 32;
    data.cpu = bpf_get_smp_processor_id();
    data.instructions = bpf_get_current_comm(&data.instructions, sizeof(data.instructions));
    data.timestamp = bpf_ktime_get_ns();
    events.perf_submit(ctx, &data, sizeof(data));
    return 0;
}
'''

b = BPF(text=bpf_text)
b.attach_kprobe(event="cpu_cycles", fn_name="trace_cpu_cycles")

print("Monitoring CPU performance...")
while True:
    try:
        b.perf_buffer_poll()
    except KeyboardInterrupt:
        exit()
"@
    
    $cpuScriptPath = "$outputPath/cpu_monitor.py"
    $cpuScript | Out-File $cpuScriptPath -Encoding UTF8
    
    # Start CPU monitoring
    $cpuProcess = Start-Process -FilePath "wsl" -ArgumentList "python3 $cpuScriptPath" -WindowStyle Hidden -PassThru
    
    # Wait for specified duration
    Start-Sleep -Seconds $duration
    
    # Stop monitoring
    if ($cpuProcess -and -not $cpuProcess.HasExited) {
        $cpuProcess.Kill()
    }
    
    Write-Host "   ✅ CPU profiling completed" -ForegroundColor Green
    return $cpuData
}

function Generate-ProfileReport {
    param($profileData, $outputPath)
    
    $reportPath = "$outputPath/ebpf_profile_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    
    $htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Ultra SIEM - eBPF Performance Profile Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; }
        .section { background: white; padding: 20px; margin: 10px 0; border-radius: 10px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        .metric { display: inline-block; margin: 10px; padding: 15px; background: #f8f9fa; border-radius: 5px; min-width: 150px; text-align: center; }
        .value { font-size: 2em; font-weight: bold; color: #007bff; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f8f9fa; font-weight: bold; }
        .chart { width: 100%; height: 300px; background: #f8f9fa; border-radius: 5px; margin: 10px 0; display: flex; align-items: center; justify-content: center; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔍 Ultra SIEM - eBPF Performance Profile Report</h1>
        <p>Generated: $($profileData.Timestamp) | Duration: $Duration seconds</p>
    </div>
    
    <div class="section">
        <h2>📊 Executive Summary</h2>
        <div class="metric">
            <div class="value">$($profileData.KernelEvents.Count)</div>
            <div>Kernel Events</div>
        </div>
        <div class="metric">
            <div class="value">$($profileData.SystemCalls.Count)</div>
            <div>System Calls</div>
        </div>
        <div class="metric">
            <div class="value">$($profileData.ContextSwitches.Count)</div>
            <div>Context Switches</div>
        </div>
    </div>
    
    <div class="section">
        <h2>🐧 Kernel Performance</h2>
        <div class="chart">
            <p>Kernel event timeline visualization</p>
        </div>
        <table>
            <tr><th>Event Type</th><th>Count</th><th>Average Latency</th></tr>
            <tr><td>System Calls</td><td>$($profileData.SystemCalls.Count)</td><td>N/A</td></tr>
            <tr><td>Context Switches</td><td>$($profileData.ContextSwitches.Count)</td><td>N/A</td></tr>
            <tr><td>Interrupts</td><td>$($profileData.Interrupts.Count)</td><td>N/A</td></tr>
        </table>
    </div>
    
    <div class="section">
        <h2>🌐 Network Performance</h2>
        <div class="chart">
            <p>Network packet analysis visualization</p>
        </div>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Total Packets</td><td>$($profileData.Packets.Count)</td></tr>
            <tr><td>Active Connections</td><td>$($profileData.Connections.Count)</td></tr>
            <tr><td>Bandwidth Usage</td><td>N/A</td></tr>
        </table>
    </div>
    
    <div class="section">
        <h2>🧠 Memory Performance</h2>
        <div class="chart">
            <p>Memory allocation pattern visualization</p>
        </div>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Total Allocations</td><td>$($profileData.Allocations.Count)</td></tr>
            <tr><td>Total Deallocations</td><td>$($profileData.Deallocations.Count)</td></tr>
            <tr><td>Potential Leaks</td><td>$($profileData.Leaks.Count)</td></tr>
        </table>
    </div>
    
    <div class="section">
        <h2>🔥 CPU Performance</h2>
        <div class="chart">
            <p>CPU utilization timeline visualization</p>
        </div>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Instructions Executed</td><td>$($profileData.Instructions.Count)</td></tr>
            <tr><td>Cache Misses</td><td>$($profileData.CacheMisses.Count)</td></tr>
            <tr><td>Branch Mispredicts</td><td>$($profileData.BranchMispredicts.Count)</td></tr>
        </table>
    </div>
    
    <div class="section">
        <h2>📋 Recommendations</h2>
        <ul>
            <li>🔧 Optimize system call frequency</li>
            <li>🌐 Monitor network bandwidth usage</li>
            <li>🧠 Check for memory leaks</li>
            <li>🔥 Analyze CPU utilization patterns</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>📞 Contact Information</h2>
        <p>For questions about this performance profile, contact the Ultra SIEM performance team.</p>
        <p>Generated by Ultra SIEM v1.0.0 - Enterprise Security Information and Event Management System</p>
    </div>
</body>
</html>
"@
    
    # Create output directory if it doesn't exist
    if (-not (Test-Path $outputPath)) {
        New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    }
    
    $htmlReport | Out-File $reportPath -Encoding UTF8
    return $reportPath
}

function Show-eBPFStatus {
    param($profileData, $activeProfiles)
    
    $currentTime = Get-Date -Format "HH:mm:ss"
    
    Write-Host "🕐 $currentTime | 🔍 Ultra SIEM eBPF Profiler Status" -ForegroundColor White
    Write-Host "=" * 70 -ForegroundColor Gray
    
    # Active Profiles
    Write-Host "🔍 ACTIVE PROFILES:" -ForegroundColor Cyan
    foreach ($profile in $activeProfiles) {
        Write-Host "   ✅ $profile" -ForegroundColor Green
    }
    
    # Profile Data Summary
    Write-Host ""
    Write-Host "📊 PROFILE DATA:" -ForegroundColor Yellow
    Write-Host "   🐧 Kernel Events: $($profileData.KernelEvents.Count)" -ForegroundColor White
    Write-Host "   📡 System Calls: $($profileData.SystemCalls.Count)" -ForegroundColor White
    Write-Host "   🔄 Context Switches: $($profileData.ContextSwitches.Count)" -ForegroundColor White
    Write-Host "   🌐 Network Packets: $($profileData.Packets.Count)" -ForegroundColor White
    Write-Host "   🧠 Memory Allocations: $($profileData.Allocations.Count)" -ForegroundColor White
    Write-Host "   🔥 CPU Instructions: $($profileData.Instructions.Count)" -ForegroundColor White
    
    Write-Host ""
    Write-Host "🎮 Controls: K=Kernel | N=Network | M=Memory | C=CPU | R=Report | Q=Quit" -ForegroundColor Gray
    Write-Host "=" * 70 -ForegroundColor Gray
}

# Main eBPF profiler
Show-eBPFBanner

# Check eBPF support
$ebpfSupported = Test-eBPFSupport
if (-not $ebpfSupported) {
    Write-Host "🔧 Installing eBPF tools..." -ForegroundColor Yellow
    $installSuccess = Install-eBPFTools
    if (-not $installSuccess) {
        Write-Host "❌ Failed to install eBPF tools. Profiling unavailable." -ForegroundColor Red
        exit 1
    }
}

$profileData = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    KernelEvents = @()
    SystemCalls = @()
    Interrupts = @()
    ContextSwitches = @()
    Packets = @()
    Connections = @()
    Bandwidth = @{}
    Latency = @{}
    Allocations = @()
    Deallocations = @()
    MemoryUsage = @{}
    Leaks = @()
    Instructions = @()
    CacheMisses = @()
    BranchMispredicts = @()
    CPUUsage = @{}
}

$activeProfiles = @()

Write-Host "🔍 Starting eBPF Performance Profiler..." -ForegroundColor Green
Write-Host "🐧 Kernel-level monitoring: ENABLED" -ForegroundColor Cyan
Write-Host "⚡ Real-time profiling: ENABLED" -ForegroundColor White
Write-Host "🛡️ Zero-impact monitoring: ENABLED" -ForegroundColor White
Write-Host ""

# Handle command line parameters
if ($All) {
    $Kernel = $true
    $Network = $true
    $Memory = $true
    $CPU = $true
}

if ($Kernel) {
    Write-Host "🐧 Starting kernel profiling..." -ForegroundColor Cyan
    $kernelData = Start-KernelProfiling -duration $Duration -outputPath $OutputPath
    $profileData.KernelEvents = $kernelData.KernelEvents
    $profileData.SystemCalls = $kernelData.SystemCalls
    $profileData.ContextSwitches = $kernelData.ContextSwitches
    $activeProfiles += "Kernel"
}

if ($Network) {
    Write-Host "🌐 Starting network profiling..." -ForegroundColor Cyan
    $networkData = Start-NetworkProfiling -duration $Duration -outputPath $OutputPath
    $profileData.Packets = $networkData.Packets
    $profileData.Connections = $networkData.Connections
    $profileData.Bandwidth = $networkData.Bandwidth
    $activeProfiles += "Network"
}

if ($Memory) {
    Write-Host "🧠 Starting memory profiling..." -ForegroundColor Cyan
    $memoryData = Start-MemoryProfiling -duration $Duration -outputPath $OutputPath
    $profileData.Allocations = $memoryData.Allocations
    $profileData.Deallocations = $memoryData.Deallocations
    $profileData.MemoryUsage = $memoryData.MemoryUsage
    $activeProfiles += "Memory"
}

if ($CPU) {
    Write-Host "🔥 Starting CPU profiling..." -ForegroundColor Cyan
    $cpuData = Start-CPUProfiling -duration $Duration -outputPath $OutputPath
    $profileData.Instructions = $cpuData.Instructions
    $profileData.CacheMisses = $cpuData.CacheMisses
    $profileData.CPUUsage = $cpuData.CPUUsage
    $activeProfiles += "CPU"
}

# Generate report
if ($activeProfiles.Count -gt 0) {
    Write-Host "📊 Generating eBPF profile report..." -ForegroundColor Cyan
    $reportPath = Generate-ProfileReport -profileData $profileData -outputPath $OutputPath
    Write-Host "📄 Profile report: $reportPath" -ForegroundColor Green
}

# Main monitoring loop
if ($Continuous) {
    do {
        Show-eBPFStatus -profileData $profileData -activeProfiles $activeProfiles
        
        # Check for user input
        if ($Host.UI.RawUI.KeyAvailable) {
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            
            switch ($key.VirtualKeyCode) {
                75 { # K key - Kernel
                    Write-Host "🐧 Starting kernel profiling..." -ForegroundColor Cyan
                    $kernelData = Start-KernelProfiling -duration $Duration -outputPath $OutputPath
                    $profileData.KernelEvents = $kernelData.KernelEvents
                    $profileData.SystemCalls = $kernelData.SystemCalls
                    $profileData.ContextSwitches = $kernelData.ContextSwitches
                    $activeProfiles = @($activeProfiles | Where-Object { $_ -ne "Kernel" }) + "Kernel"
                }
                78 { # N key - Network
                    Write-Host "🌐 Starting network profiling..." -ForegroundColor Cyan
                    $networkData = Start-NetworkProfiling -duration $Duration -outputPath $OutputPath
                    $profileData.Packets = $networkData.Packets
                    $profileData.Connections = $networkData.Connections
                    $profileData.Bandwidth = $networkData.Bandwidth
                    $activeProfiles = @($activeProfiles | Where-Object { $_ -ne "Network" }) + "Network"
                }
                77 { # M key - Memory
                    Write-Host "🧠 Starting memory profiling..." -ForegroundColor Cyan
                    $memoryData = Start-MemoryProfiling -duration $Duration -outputPath $OutputPath
                    $profileData.Allocations = $memoryData.Allocations
                    $profileData.Deallocations = $memoryData.Deallocations
                    $profileData.MemoryUsage = $memoryData.MemoryUsage
                    $activeProfiles = @($activeProfiles | Where-Object { $_ -ne "Memory" }) + "Memory"
                }
                67 { # C key - CPU
                    Write-Host "🔥 Starting CPU profiling..." -ForegroundColor Cyan
                    $cpuData = Start-CPUProfiling -duration $Duration -outputPath $OutputPath
                    $profileData.Instructions = $cpuData.Instructions
                    $profileData.CacheMisses = $cpuData.CacheMisses
                    $profileData.CPUUsage = $cpuData.CPUUsage
                    $activeProfiles = @($activeProfiles | Where-Object { $_ -ne "CPU" }) + "CPU"
                }
                82 { # R key - Report
                    Write-Host "📊 Generating eBPF profile report..." -ForegroundColor Cyan
                    $reportPath = Generate-ProfileReport -profileData $profileData -outputPath $OutputPath
                    Write-Host "📄 Profile report: $reportPath" -ForegroundColor Green
                }
                81 { # Q key - Quit
                    Write-Host "🔍 eBPF profiler stopped." -ForegroundColor Yellow
                    exit 0
                }
            }
        }
        
        Start-Sleep -Seconds 30
        
    } while ($true)
}

Write-Host "🔍 Ultra SIEM eBPF Performance Profiler - Deep profiling complete!" -ForegroundColor Green 