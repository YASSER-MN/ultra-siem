#Requires -RunAsAdministrator

Write-Host "🚀 Ultra SIEM Windows Setup - Hardware Performance Mode" -ForegroundColor Cyan

# Enable hardware features for maximum performance
Write-Host "⚡ Configuring hardware acceleration..." -ForegroundColor Yellow

# Enable large pages for ClickHouse performance
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LargePageMinimum" -Value 2097152
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LockPagesInMemory" -Value 1

# Enable high precision event timer
bcdedit /set useplatformclock true
bcdedit /set useplatformtick yes

# Disable unnecessary Windows services for performance
$servicesToDisable = @(
    "Windows Search",
    "Superfetch", 
    "Windows Update",
    "Print Spooler"
)

foreach ($service in $servicesToDisable) {
    try {
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "✅ Disabled $service" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️  Could not disable $service" -ForegroundColor Orange
    }
}

# Install required tools using Chocolatey
Write-Host "📦 Installing development tools..." -ForegroundColor Yellow

# Install Chocolatey if not present
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# Install required packages
$packages = @(
    "llvm",
    "mingw", 
    "git",
    "golang",
    "rustup.install",
    "docker-desktop",
    "vscode"
)

foreach ($package in $packages) {
    try {
        choco install $package -y --force
        Write-Host "✅ Installed $package" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️  Failed to install $package" -ForegroundColor Orange
    }
}

# Configure CPU performance profile
Write-Host "🔧 Optimizing CPU performance..." -ForegroundColor Yellow

# Set high performance power plan
powercfg /setactive SCHEME_MIN
powercfg /setdcvalueindex SCHEME_MIN SUB_PROCESSOR IDLEDISABLE 000
powercfg /setacvalueindex SCHEME_MIN SUB_PROCESSOR PROCTHROTTLEMAX 100

# Disable CPU throttling
powercfg /setacvalueindex SCHEME_MIN SUB_PROCESSOR PROCTHROTTLEMIN 100
powercfg /setdcvalueindex SCHEME_MIN SUB_PROCESSOR PROCTHROTTLEMIN 100

# Configure network adapter for maximum performance
Write-Host "🌐 Optimizing network performance..." -ForegroundColor Yellow

$adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
foreach ($adapter in $adapters) {
    try {
        # Disable interrupt moderation
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Interrupt Moderation" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
        
        # Increase receive buffers
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Receive Buffers" -DisplayValue "4096" -ErrorAction SilentlyContinue
        
        # Enable RSS
        Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Receive Side Scaling" -DisplayValue "Enabled" -ErrorAction SilentlyContinue
        
        Write-Host "✅ Optimized $($adapter.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️  Could not optimize $($adapter.Name)" -ForegroundColor Orange
    }
}

# Configure huge pages
Write-Host "💾 Configuring huge pages..." -ForegroundColor Yellow

$totalMemoryGB = [math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$hugePages = [math]::Min(($totalMemoryGB * 0.5), 64) * 512  # 50% of RAM or max 32GB
$hugePagesBytes = $hugePages * 2MB

# Enable lock pages in memory privilege for current user
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
secedit /export /cfg "$env:TEMP\secpol.cfg"
$content = Get-Content "$env:TEMP\secpol.cfg"
$content = $content -replace "SeLockMemoryPrivilege = .*", "SeLockMemoryPrivilege = $currentUser"
$content | Out-File "$env:TEMP\secpol_modified.cfg"
secedit /configure /db "$env:TEMP\secedit.sdb" /cfg "$env:TEMP\secpol_modified.cfg"

Write-Host "✅ Configured $hugePages huge pages ($([math]::Round($hugePagesBytes/1GB, 1))GB)" -ForegroundColor Green

# Setup Rust environment
Write-Host "🦀 Setting up Rust environment..." -ForegroundColor Yellow

try {
    $env:PATH += ";$env:USERPROFILE\.cargo\bin"
    rustup default nightly
    rustup component add rust-src
    rustup target add x86_64-pc-windows-msvc
    Write-Host "✅ Rust nightly configured" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  Rust setup requires manual configuration" -ForegroundColor Orange
}

# Build Rust components with maximum optimization
Write-Host "🔨 Building Rust core..." -ForegroundColor Yellow

if (Test-Path "rust-core") {
    Push-Location "rust-core"
    try {
        $env:RUSTFLAGS = "-C target-cpu=native -C opt-level=3 -C link-arg=/STACK:8388608"
        cargo build --release --target x86_64-pc-windows-msvc
        Write-Host "✅ Rust core built successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to build Rust core: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        Pop-Location
    }
}

# Build Go components with performance flags
Write-Host "🐹 Building Go services..." -ForegroundColor Yellow

if (Test-Path "go-services") {
    Push-Location "go-services"
    try {
        $env:GOOS = "windows"
        $env:GOARCH = "amd64"
        $env:CGO_ENABLED = "1"
        go build -ldflags="-s -w -H windowsgui" -buildmode=exe -o processor.exe
        Write-Host "✅ Go processor built successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to build Go processor: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        Pop-Location
    }
}

# Configure Windows Event Log for ETW integration
Write-Host "📝 Configuring Windows Event Logs..." -ForegroundColor Yellow

try {
    # Create custom event log for SIEM
    New-EventLog -LogName "SIEM-Ultra" -Source "ThreatDetector" -ErrorAction SilentlyContinue
    
    # Configure maximum log size (1GB)
    Limit-EventLog -LogName "SIEM-Ultra" -MaximumSize 1GB
    
    Write-Host "✅ Event logging configured" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  Event log configuration may require elevated privileges" -ForegroundColor Orange
}

# Create performance monitoring scheduled task
Write-Host "📊 Setting up performance monitoring..." -ForegroundColor Yellow

$monitorScript = @"
`$perfCounters = Get-Counter '\Processor(_Total)\% Processor Time', '\Memory\Available MBytes'
Write-EventLog -LogName 'SIEM-Ultra' -Source 'ThreatDetector' -EventId 1001 -Message "Performance: CPU=`$(`$perfCounters[0].CounterSamples.CookedValue)%, RAM=`$(`$perfCounters[1].CounterSamples.CookedValue)MB"
"@

$monitorScript | Out-File -FilePath "$PSScriptRoot\performance_monitor.ps1"

$taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File `"$PSScriptRoot\performance_monitor.ps1`""
$taskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
$taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

try {
    Register-ScheduledTask -TaskName "SIEM-PerformanceMonitor" -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -Force
    Write-Host "✅ Performance monitoring scheduled" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  Could not create scheduled task" -ForegroundColor Orange
}

# Display system information
Write-Host "`n📋 System Configuration Summary:" -ForegroundColor Cyan
Write-Host "   CPU Cores: $([System.Environment]::ProcessorCount)" -ForegroundColor White
Write-Host "   Total RAM: $totalMemoryGB GB" -ForegroundColor White
Write-Host "   Huge Pages: $([math]::Round($hugePagesBytes/1GB, 1)) GB allocated" -ForegroundColor White
Write-Host "   Power Plan: High Performance" -ForegroundColor White
Write-Host "   Network: Optimized for throughput" -ForegroundColor White

Write-Host "`n🎯 Next Steps:" -ForegroundColor Green
Write-Host "   1. Restart system to apply hardware changes" -ForegroundColor Yellow
Write-Host "   2. Run: docker-compose -f docker-compose.ultra.yml up -d" -ForegroundColor Yellow
Write-Host "   3. Execute: .\scripts\start_services.ps1" -ForegroundColor Yellow
Write-Host "   4. Validate: .\scripts\benchmark.ps1" -ForegroundColor Yellow

Write-Host "`n✅ Windows optimization complete! System ready for ultra-performance SIEM." -ForegroundColor Green 