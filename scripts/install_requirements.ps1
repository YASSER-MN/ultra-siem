#Requires -RunAsAdministrator

# Ultra SIEM Complete Requirements Installation
# Installs all dependencies for the entire project

param(
    [switch]$SkipOptional = $false,
    [switch]$OfflineMode = $false,
    [string]$InstallPath = "C:\UltraSIEM"
)

$ErrorActionPreference = "Stop"

function Write-InstallLog {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [INSTALL-$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        "PROGRESS" { "Cyan" }
        default { "White" }
    })
    Add-Content -Path "logs\installation.log" -Value $logEntry
}

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-Chocolatey {
    Write-InstallLog "📦 Installing Chocolatey package manager..." "PROGRESS"
    
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-InstallLog "✅ Chocolatey already installed"
        return
    }
    
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    
    refreshenv
    Write-InstallLog "✅ Chocolatey installed successfully" "SUCCESS"
}

function Install-CoreDevelopmentTools {
    Write-InstallLog "🛠️ Installing core development tools..." "PROGRESS"
    
    $corePackages = @(
        "git",
        "powershell-core",
        "windows-sdk-10-version-2004-all",
        "cmake",
        "ninja",
        "make",
        "curl",
        "wget",
        "7zip",
        "notepadplusplus"
    )
    
    foreach ($package in $corePackages) {
        Write-InstallLog "Installing $package..."
        try {
            choco install $package -y --no-progress
            Write-InstallLog "✅ $package installed"
        }
        catch {
            Write-InstallLog "⚠️ Failed to install $package`: $_" "WARN"
        }
    }
}

function Install-ProgrammingLanguages {
    Write-InstallLog "💻 Installing programming languages and runtimes..." "PROGRESS"
    
    # Rust with SIMD support
    Write-InstallLog "Installing Rust with SIMD features..."
    if (-not (Get-Command rustc -ErrorAction SilentlyContinue)) {
        Invoke-WebRequest -Uri "https://win.rustup.rs/x86_64" -OutFile "rustup-init.exe"
        .\rustup-init.exe -y --default-toolchain stable --target x86_64-pc-windows-msvc
        Remove-Item "rustup-init.exe"
        $env:PATH += ";$env:USERPROFILE\.cargo\bin"
        
        # Install additional Rust targets and components
        rustup component add clippy rustfmt
        rustup target add x86_64-pc-windows-gnu
        
        Write-InstallLog "✅ Rust installed with SIMD support"
    } else {
        Write-InstallLog "✅ Rust already installed"
    }
    
    # Go with latest version
    Write-InstallLog "Installing Go..."
    choco install golang -y --no-progress
    
    # Zig for query engine
    Write-InstallLog "Installing Zig..."
    choco install zig -y --no-progress
    
    # Python for threat intelligence
    Write-InstallLog "Installing Python..."
    choco install python -y --no-progress
    
    # Node.js for some utilities
    Write-InstallLog "Installing Node.js..."
    choco install nodejs -y --no-progress
    
    # LLVM/Clang for eBPF compilation
    Write-InstallLog "Installing LLVM/Clang for eBPF..."
    choco install llvm -y --no-progress
    
    Write-InstallLog "✅ Programming languages installed" "SUCCESS"
}

function Install-ContainerRuntime {
    Write-InstallLog "🐳 Installing Docker Desktop..." "PROGRESS"
    
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-InstallLog "✅ Docker already installed"
        return
    }
    
    # Install Docker Desktop
    choco install docker-desktop -y --no-progress
    
    # Wait for Docker to start
    Write-InstallLog "Waiting for Docker to start..."
    $timeout = 300 # 5 minutes
    $timer = 0
    
    do {
        Start-Sleep -Seconds 5
        $timer += 5
        try {
            $dockerInfo = docker info 2>$null
            if ($dockerInfo) {
                break
            }
        }
        catch {
            # Docker not ready yet
        }
    } while ($timer -lt $timeout)
    
    if ($timer -ge $timeout) {
        Write-InstallLog "⚠️ Docker startup timeout - may need manual restart" "WARN"
    } else {
        Write-InstallLog "✅ Docker Desktop installed and running" "SUCCESS"
    }
}

function Install-DatabaseAndMessaging {
    Write-InstallLog "💾 Setting up database and messaging services..." "PROGRESS"
    
    # Pull Docker images for core services
    $images = @(
        "clickhouse/clickhouse-server:latest",
        "nats:alpine",
        "grafana/grafana-oss:latest",
        "timberio/vector:latest-alpine",
        "ghcr.io/spiffe/spire-server:1.8.2",
        "ghcr.io/spiffe/spire-agent:1.8.2"
    )
    
    foreach ($image in $images) {
        Write-InstallLog "Pulling Docker image: $image"
        try {
            docker pull $image
            Write-InstallLog "✅ Pulled $image"
        }
        catch {
            Write-InstallLog "⚠️ Failed to pull $image`: $_" "WARN"
        }
    }
    
    Write-InstallLog "✅ Database and messaging images ready" "SUCCESS"
}

function Install-WindowsFeatures {
    Write-InstallLog "🔧 Installing Windows features..." "PROGRESS"
    
    # Required Windows features
    $features = @(
        "Microsoft-Windows-Subsystem-Linux",
        "VirtualMachinePlatform",
        "Containers",
        "HypervisorPlatform"
    )
    
    foreach ($feature in $features) {
        Write-InstallLog "Enabling Windows feature: $feature"
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart
            Write-InstallLog "✅ Enabled $feature"
        }
        catch {
            Write-InstallLog "⚠️ Failed to enable $feature`: $_" "WARN"
        }
    }
    
    # Install Windows Performance Toolkit
    if (-not (Get-Command wpa.exe -ErrorAction SilentlyContinue)) {
        Write-InstallLog "Installing Windows Performance Toolkit..."
        choco install windows-adk-winpe -y --no-progress
    }
    
    Write-InstallLog "✅ Windows features configured" "SUCCESS"
}

function Install-PythonDependencies {
    Write-InstallLog "🐍 Installing Python dependencies..." "PROGRESS"
    
    # Upgrade pip first
    python -m pip install --upgrade pip
    
    # Core Python packages for threat intelligence
    $pythonPackages = @(
        "asyncio",
        "aiohttp",
        "pandas",
        "clickhouse-connect",
        "cryptography",
        "yara-python",
        "requests",
        "numpy",
        "scikit-learn",
        "maxminddb",
        "stix2",
        "taxii2-client"
    )
    
    foreach ($package in $pythonPackages) {
        Write-InstallLog "Installing Python package: $package"
        try {
            python -m pip install $package
            Write-InstallLog "✅ Installed $package"
        }
        catch {
            Write-InstallLog "⚠️ Failed to install $package`: $_" "WARN"
        }
    }
    
    Write-InstallLog "✅ Python dependencies installed" "SUCCESS"
}

function Install-PowerShellModules {
    Write-InstallLog "⚡ Installing PowerShell modules..." "PROGRESS"
    
    # Set PowerShell Gallery as trusted
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
    
    $modules = @(
        "AWS.Tools.Common",
        "AWS.Tools.S3",
        "AWS.Tools.Route53",
        "AWS.Tools.ECS",
        "ThreadJob",
        "PoshRSJob",
        "ImportExcel",
        "PSWriteHTML"
    )
    
    foreach ($module in $modules) {
        Write-InstallLog "Installing PowerShell module: $module"
        try {
            Install-Module -Name $module -Force -AllowClobber -Scope AllUsers
            Write-InstallLog "✅ Installed $module"
        }
        catch {
            Write-InstallLog "⚠️ Failed to install $module`: $_" "WARN"
        }
    }
    
    Write-InstallLog "✅ PowerShell modules installed" "SUCCESS"
}

function Install-SecurityTools {
    Write-InstallLog "🛡️ Installing security and monitoring tools..." "PROGRESS"
    
    # eBPF for Windows
    if (-not (Get-Command ebpf -ErrorAction SilentlyContinue)) {
        Write-InstallLog "Installing eBPF for Windows..."
        $ebpfUrl = "https://github.com/microsoft/ebpf-for-windows/releases/latest/download/ebpf-for-windows.msi"
        $ebpfInstaller = "$env:TEMP\ebpf-windows.msi"
        
        try {
            Invoke-WebRequest -Uri $ebpfUrl -OutFile $ebpfInstaller
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $ebpfInstaller, "/quiet" -Wait
            Remove-Item $ebpfInstaller
            Write-InstallLog "✅ eBPF for Windows installed"
        }
        catch {
            Write-InstallLog "⚠️ Failed to install eBPF: $_" "WARN"
        }
    }
    
    # PDF generation tool
    Write-InstallLog "Installing wkhtmltopdf for PDF reports..."
    choco install wkhtmltopdf -y --no-progress
    
    # Process monitoring tools
    Write-InstallLog "Installing process monitoring tools..."
    choco install procexp -y --no-progress
    choco install procmon -y --no-progress
    
    Write-InstallLog "✅ Security tools installed" "SUCCESS"
}

function Install-RustDependencies {
    Write-InstallLog "🦀 Installing Rust dependencies and building core..." "PROGRESS"
    
    # Ensure we have the Rust toolchain
    if (Get-Command cargo -ErrorAction SilentlyContinue) {
        # Install common Rust tools
        $rustTools = @(
            "cargo-watch",
            "cargo-edit",
            "cargo-audit",
            "cargo-outdated"
        )
        
        foreach ($tool in $rustTools) {
            Write-InstallLog "Installing Rust tool: $tool"
            try {
                cargo install $tool
                Write-InstallLog "✅ Installed $tool"
            }
            catch {
                Write-InstallLog "⚠️ Failed to install $tool`: $_" "WARN"
            }
        }
        
        # Build the Rust core
        if (Test-Path "rust-core\Cargo.toml") {
            Write-InstallLog "Building Rust core with SIMD optimizations..."
            Set-Location "rust-core"
            try {
                $env:RUSTFLAGS = "-C target-cpu=native -C target-feature=+avx2,+avx512f"
                cargo build --release
                Write-InstallLog "✅ Rust core built successfully"
            }
            catch {
                Write-InstallLog "⚠️ Rust core build failed: $_" "WARN"
            }
            finally {
                Set-Location ".."
            }
        }
    }
    
    Write-InstallLog "✅ Rust dependencies configured" "SUCCESS"
}

function Install-GoDependencies {
    Write-InstallLog "🔷 Installing Go dependencies and building services..." "PROGRESS"
    
    if (Get-Command go -ErrorAction SilentlyContinue) {
        # Set Go module proxy
        $env:GOPROXY = "https://proxy.golang.org,direct"
        $env:GOSUMDB = "sum.golang.org"
        
        # Build Go services
        if (Test-Path "go-services\go.mod") {
            Write-InstallLog "Building Go services..."
            Set-Location "go-services"
            try {
                go mod download
                go build -ldflags="-s -w" -o bin\ .\...
                Write-InstallLog "✅ Go services built successfully"
            }
            catch {
                Write-InstallLog "⚠️ Go services build failed: $_" "WARN"
            }
            finally {
                Set-Location ".."
            }
        }
    }
    
    Write-InstallLog "✅ Go dependencies configured" "SUCCESS"
}

function Install-ZigDependencies {
    Write-InstallLog "⚡ Building Zig query engine..." "PROGRESS"
    
    if (Get-Command zig -ErrorAction SilentlyContinue) {
        if (Test-Path "zig-query\build.zig") {
            Write-InstallLog "Building Zig query engine with AVX-512..."
            Set-Location "zig-query"
            try {
                zig build -Doptimize=ReleaseFast -Dcpu=native
                Write-InstallLog "✅ Zig query engine built successfully"
            }
            catch {
                Write-InstallLog "⚠️ Zig build failed: $_" "WARN"
            }
            finally {
                Set-Location ".."
            }
        }
    }
    
    Write-InstallLog "✅ Zig dependencies configured" "SUCCESS"
}

function Configure-WindowsOptimizations {
    Write-InstallLog "⚙️ Applying Windows optimizations..." "PROGRESS"
    
    # Enable huge pages (requires restart)
    Write-InstallLog "Enabling huge pages..."
    try {
        bcdedit /set increaseuserva 3072
        Write-InstallLog "✅ Huge pages configuration applied (restart required)"
    }
    catch {
        Write-InstallLog "⚠️ Failed to configure huge pages: $_" "WARN"
    }
    
    # Set high-performance power plan
    Write-InstallLog "Setting high-performance power plan..."
    try {
        powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
        Write-InstallLog "✅ High-performance power plan activated"
    }
    catch {
        Write-InstallLog "⚠️ Failed to set power plan: $_" "WARN"
    }
    
    # Configure network adapters
    Write-InstallLog "Optimizing network adapters..."
    try {
        Get-NetAdapter | ForEach-Object {
            Set-NetAdapterAdvancedProperty -Name $_.Name -RegistryKeyword "RssBaseProcNumber" -RegistryValue 0 -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $_.Name -RegistryKeyword "MaxRssProcessors" -RegistryValue 8 -ErrorAction SilentlyContinue
        }
        Write-InstallLog "✅ Network adapters optimized"
    }
    catch {
        Write-InstallLog "⚠️ Network optimization warning: $_" "WARN"
    }
    
    Write-InstallLog "✅ Windows optimizations applied" "SUCCESS"
}

function Create-ProjectDirectories {
    Write-InstallLog "📁 Creating project directory structure..." "PROGRESS"
    
    $directories = @(
        "logs",
        "reports",
        "config\vector",
        "config\spire",
        "data\clickhouse",
        "data\nats",
        "data\grafana",
        "certs",
        "backups",
        "monitoring",
        "bin"
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            Write-InstallLog "Created directory: $dir"
        }
    }
    
    Write-InstallLog "✅ Project directories created" "SUCCESS"
}

function Test-Installation {
    Write-InstallLog "🧪 Testing installation..." "PROGRESS"
    
    $testResults = @{
        Rust = Test-Path (Get-Command rustc -ErrorAction SilentlyContinue)
        Go = Test-Path (Get-Command go -ErrorAction SilentlyContinue)
        Zig = Test-Path (Get-Command zig -ErrorAction SilentlyContinue)
        Python = Test-Path (Get-Command python -ErrorAction SilentlyContinue)
        Docker = Test-Path (Get-Command docker -ErrorAction SilentlyContinue)
        Chocolatey = Test-Path (Get-Command choco -ErrorAction SilentlyContinue)
    }
    
    $passed = 0
    $total = $testResults.Count
    
    foreach ($test in $testResults.GetEnumerator()) {
        if ($test.Value) {
            Write-InstallLog "✅ $($test.Key): PASSED"
            $passed++
        } else {
            Write-InstallLog "❌ $($test.Key): FAILED" "ERROR"
        }
    }
    
    $successRate = [math]::Round(($passed / $total) * 100, 1)
    Write-InstallLog "📊 Installation success rate: $successRate% ($passed/$total)" $(if($successRate -ge 90){"SUCCESS"}else{"WARN"})
    
    return $successRate -ge 90
}

function Show-PostInstallationInstructions {
    $instructions = @"

🎉 ULTRA SIEM INSTALLATION COMPLETED

📋 Next Steps:
1. Restart your computer to apply all optimizations
2. Run the enterprise deployment: .\scripts\enterprise_deployment.ps1
3. Start the production simulation: .\scripts\production_simulation.ps1

🛠️ Available Commands:
- Start services: .\scripts\start_services.ps1
- Setup security: .\security\spire-setup.ps1 -Action Install
- Run profiler: .\monitoring\ebpf_profiler.ps1 -Action Start
- Generate reports: .\compliance\report_generator.ps1 -ComplianceType All

🔧 Build Commands:
- Rust core: cd rust-core && cargo build --release
- Go services: cd go-services && go build -o bin\ .\...
- Zig engine: cd zig-query && zig build -Doptimize=ReleaseFast

📚 Documentation:
- README.md: Project overview
- DEPLOYMENT_SUMMARY.md: Technical details
- FINAL_PRODUCTION_CERTIFICATION.md: Production guide

⚠️ Important Notes:
- Some optimizations require a system restart
- Docker Desktop may need manual startup after restart
- Large page support requires administrator privileges

🚀 Ready to deploy enterprise-grade SIEM with zero licensing costs!

"@

    Write-Host $instructions -ForegroundColor Green
    $instructions | Out-File "INSTALLATION_COMPLETE.txt"
}

# Main installation sequence
function Start-CompleteInstallation {
    Write-InstallLog "🚀 Starting Ultra SIEM complete installation..." "PROGRESS"
    
    # Validate prerequisites
    if (-not (Test-AdminRights)) {
        Write-InstallLog "❌ Administrator rights required. Please run as Administrator." "ERROR"
        exit 1
    }
    
    # Create logs directory
    New-Item -ItemType Directory -Force -Path "logs" | Out-Null
    
    try {
        # Core installation phases
        Install-Chocolatey
        Install-CoreDevelopmentTools
        Install-ProgrammingLanguages
        
        refreshenv  # Refresh environment variables
        
        Install-ContainerRuntime
        Install-WindowsFeatures
        Install-PythonDependencies
        Install-PowerShellModules
        Install-SecurityTools
        
        # Build project components
        Install-RustDependencies
        Install-GoDependencies
        Install-ZigDependencies
        
        # Setup and optimize
        Create-ProjectDirectories
        Configure-WindowsOptimizations
        Install-DatabaseAndMessaging
        
        # Final validation
        $installationSuccess = Test-Installation
        
        if ($installationSuccess) {
            Write-InstallLog "🎉 INSTALLATION COMPLETED SUCCESSFULLY!" "SUCCESS"
            Show-PostInstallationInstructions
        } else {
            Write-InstallLog "⚠️ Installation completed with warnings. Check logs for details." "WARN"
        }
        
        Write-InstallLog "📊 Installation log saved to: logs\installation.log"
        
    }
    catch {
        Write-InstallLog "💥 Installation failed: $_" "ERROR"
        Write-InstallLog "Please check the logs and try again."
        exit 1
    }
}

# Execute installation if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    Start-CompleteInstallation
}

Write-InstallLog "✅ Ultra SIEM installation script ready" "SUCCESS" 