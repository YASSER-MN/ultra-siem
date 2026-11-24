# Ultra SIEM User-Mode Requirements Installation
# Installs what can be installed without Administrator privileges

param(
    [switch]$SkipBuild = $false
)

$ErrorActionPreference = "Continue"  # Continue on errors for user installations

function Write-UserLog {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [USER-$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        "PROGRESS" { "Cyan" }
        default { "White" }
    })
    
    # Create logs directory if it doesn't exist
    if (-not (Test-Path "logs")) {
        New-Item -ItemType Directory -Force -Path "logs" | Out-Null
    }
    Add-Content -Path "logs\user_installation.log" -Value $logEntry
}

function Test-Command {
    param($CommandName)
    return [bool](Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Install-Rust {
    Write-UserLog "🦀 Installing Rust..." "PROGRESS"
    
    if (Test-Command "rustc") {
        Write-UserLog "✅ Rust already installed"
        return $true
    }
    
    try {
        # Download Rust installer
        $rustupUrl = "https://win.rustup.rs/x86_64"
        $rustupPath = "$env:TEMP\rustup-init.exe"
        
        Write-UserLog "Downloading Rust installer..."
        Invoke-WebRequest -Uri $rustupUrl -OutFile $rustupPath
        
        # Install Rust
        Write-UserLog "Installing Rust with default settings..."
        & $rustupPath -y --default-toolchain stable --target x86_64-pc-windows-msvc
        
        # Clean up
        Remove-Item $rustupPath -ErrorAction SilentlyContinue
        
        # Update PATH for current session
        $env:PATH += ";$env:USERPROFILE\.cargo\bin"
        
        # Install additional components
        if (Test-Command "rustup") {
            rustup component add clippy rustfmt
            rustup target add x86_64-pc-windows-gnu
        }
        
        Write-UserLog "✅ Rust installed successfully" "SUCCESS"
        return $true
    }
    catch {
        Write-UserLog "❌ Failed to install Rust: $_" "ERROR"
        return $false
    }
}

function Install-Go {
    Write-UserLog "🔷 Checking Go installation..." "PROGRESS"
    
    if (Test-Command "go") {
        Write-UserLog "✅ Go already installed"
        return $true
    }
    
    Write-UserLog "⚠️ Go not found. Please install manually:" "WARN"
    Write-UserLog "1. Download from: https://golang.org/dl/"
    Write-UserLog "2. Run installer as Administrator"
    return $false
}

function Install-Zig {
    Write-UserLog "⚡ Installing Zig..." "PROGRESS"
    
    if (Test-Command "zig") {
        Write-UserLog "✅ Zig already installed"
        return $true
    }
    
    try {
        # Download Zig
        $zigVersion = "0.11.0"
        $zigUrl = "https://ziglang.org/download/$zigVersion/zig-windows-x86_64-$zigVersion.zip"
        $zigZip = "$env:TEMP\zig.zip"
        $zigDir = "$env:USERPROFILE\zig"
        
        Write-UserLog "Downloading Zig $zigVersion..."
        Invoke-WebRequest -Uri $zigUrl -OutFile $zigZip
        
        # Extract to user directory
        Write-UserLog "Extracting Zig..."
        Expand-Archive -Path $zigZip -DestinationPath $zigDir -Force
        
        # Add to PATH for current session
        $zigPath = "$zigDir\zig-windows-x86_64-$zigVersion"
        $env:PATH += ";$zigPath"
        
        # Update user PATH permanently
        $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if ($userPath -notlike "*$zigPath*") {
            [Environment]::SetEnvironmentVariable("PATH", "$userPath;$zigPath", "User")
        }
        
        Remove-Item $zigZip -ErrorAction SilentlyContinue
        
        Write-UserLog "✅ Zig installed successfully" "SUCCESS"
        return $true
    }
    catch {
        Write-UserLog "❌ Failed to install Zig: $_" "ERROR"
        return $false
    }
}

function Install-Python {
    Write-UserLog "🐍 Checking Python installation..." "PROGRESS"
    
    if (Test-Command "python") {
        Write-UserLog "✅ Python already installed"
        
        # Install Python packages
        Write-UserLog "Installing Python dependencies..."
        $packages = @(
            "asyncio",
            "aiohttp", 
            "pandas",
            "clickhouse-connect",
            "cryptography",
            "requests",
            "numpy"
        )
        
        foreach ($package in $packages) {
            try {
                Write-UserLog "Installing $package..."
                python -m pip install $package --user --quiet
                Write-UserLog "✅ Installed $package"
            }
            catch {
                Write-UserLog "⚠️ Failed to install $package" "WARN"
            }
        }
        
        return $true
    }
    
    Write-UserLog "⚠️ Python not found. Please install manually:" "WARN"
    Write-UserLog "1. Download from: https://www.python.org/downloads/"
    Write-UserLog "2. Run installer and check 'Add to PATH'"
    return $false
}

function Install-PowerShellModules {
    Write-UserLog "⚡ Installing PowerShell modules..." "PROGRESS"
    
    # Set PowerShell Gallery as trusted for current user
    try {
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
    }
    catch {
        Write-UserLog "⚠️ Could not set PSGallery as trusted" "WARN"
    }
    
    $modules = @(
        "ThreadJob",
        "ImportExcel",
        "PSWriteHTML"
    )
    
    foreach ($module in $modules) {
        try {
            Write-UserLog "Installing PowerShell module: $module"
            Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
            Write-UserLog "✅ Installed $module"
        }
        catch {
            Write-UserLog "⚠️ Failed to install $module`: $_" "WARN"
        }
    }
    
    Write-UserLog "✅ PowerShell modules installation completed"
}

function Create-ProjectStructure {
    Write-UserLog "📁 Creating project directory structure..." "PROGRESS"
    
    $directories = @(
        "logs",
        "reports", 
        "config\vector",
        "config\spire",
        "data",
        "certs",
        "monitoring",
        "bin"
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            try {
                New-Item -ItemType Directory -Force -Path $dir | Out-Null
                Write-UserLog "Created directory: $dir"
            }
            catch {
                Write-UserLog "⚠️ Failed to create directory $dir" "WARN"
            }
        }
    }
    
    Write-UserLog "✅ Project structure created" "SUCCESS"
}

function Build-RustProject {
    Write-UserLog "🔨 Building Rust project..." "PROGRESS"
    
    if (-not (Test-Command "cargo")) {
        Write-UserLog "⚠️ Cargo not available, skipping Rust build" "WARN"
        return $false
    }
    
    if (-not (Test-Path "rust-core\Cargo.toml")) {
        Write-UserLog "⚠️ Rust project not found, skipping build" "WARN"
        return $false
    }
    
    try {
        Set-Location "rust-core"
        
        # Set optimization flags
        $env:RUSTFLAGS = "-C target-cpu=native"
        
        Write-UserLog "Building Rust core (this may take a few minutes)..."
        cargo build --release
        
        if (Test-Path "target\release\rust-core.exe") {
            Write-UserLog "✅ Rust core built successfully" "SUCCESS"
            return $true
        } else {
            Write-UserLog "⚠️ Rust build completed but executable not found" "WARN"
            return $false
        }
    }
    catch {
        Write-UserLog "❌ Rust build failed: $_" "ERROR"
        return $false
    }
    finally {
        Set-Location ".."
    }
}

function Build-GoProject {
    Write-UserLog "🔨 Building Go project..." "PROGRESS"
    
    if (-not (Test-Command "go")) {
        Write-UserLog "⚠️ Go not available, skipping Go build" "WARN"
        return $false
    }
    
    if (-not (Test-Path "go-services\go.mod")) {
        Write-UserLog "⚠️ Go project not found, skipping build" "WARN"
        return $false
    }
    
    try {
        Set-Location "go-services"
        
        Write-UserLog "Downloading Go dependencies..."
        go mod download
        
        Write-UserLog "Building Go services..."
        if (-not (Test-Path "bin")) {
            New-Item -ItemType Directory -Force -Path "bin" | Out-Null
        }
        
        go build -ldflags="-s -w" -o bin\ .\...
        
        $binFiles = Get-ChildItem "bin" -Filter "*.exe" | Measure-Object
        if ($binFiles.Count -gt 0) {
            Write-UserLog "✅ Go services built successfully ($($binFiles.Count) executables)" "SUCCESS"
            return $true
        } else {
            Write-UserLog "⚠️ Go build completed but no executables found" "WARN"
            return $false
        }
    }
    catch {
        Write-UserLog "❌ Go build failed: $_" "ERROR"
        return $false
    }
    finally {
        Set-Location ".."
    }
}

function Build-ZigProject {
    Write-UserLog "🔨 Building Zig project..." "PROGRESS"
    
    if (-not (Test-Command "zig")) {
        Write-UserLog "⚠️ Zig not available, skipping Zig build" "WARN"
        return $false
    }
    
    if (-not (Test-Path "zig-query\build.zig")) {
        Write-UserLog "⚠️ Zig project not found, skipping build" "WARN"
        return $false
    }
    
    try {
        Set-Location "zig-query"
        
        Write-UserLog "Building Zig query engine..."
        zig build -Doptimize=ReleaseFast
        
        if (Test-Path "zig-out\bin") {
            $binFiles = Get-ChildItem "zig-out\bin" | Measure-Object
            if ($binFiles.Count -gt 0) {
                Write-UserLog "✅ Zig query engine built successfully" "SUCCESS"
                return $true
            }
        }
        
        Write-UserLog "⚠️ Zig build completed but no executables found" "WARN"
        return $false
    }
    catch {
        Write-UserLog "❌ Zig build failed: $_" "ERROR"
        return $false
    }
    finally {
        Set-Location ".."
    }
}

function Show-NextSteps {
    $nextSteps = @"

🎉 USER-MODE INSTALLATION COMPLETED

✅ What was installed:
- Rust toolchain with Cargo
- Zig programming language
- PowerShell modules
- Python dependencies (if Python was available)
- Project directory structure

🔨 Build Results:
- Rust core: $(if(Test-Path "rust-core\target\release\rust-core.exe"){"✅ Built"}else{"❌ Failed"})
- Go services: $(if(Test-Path "go-services\bin"){"✅ Built"}else{"❌ Failed"})
- Zig engine: $(if(Test-Path "zig-query\zig-out\bin"){"✅ Built"}else{"❌ Failed"})

⚠️ Still needed (requires Administrator):
1. Docker Desktop
2. Go programming language  
3. Windows feature enablement
4. System optimizations

📋 Next Steps:

1. **Install remaining tools manually:**
   - Go: https://golang.org/dl/
   - Docker Desktop: https://docs.docker.com/desktop/windows/install/
   - Python: https://www.python.org/downloads/ (if not installed)

2. **Run as Administrator:**
   ```powershell
   # Right-click PowerShell -> "Run as Administrator"
   .\scripts\install_requirements.ps1
   ```

3. **Or continue with manual steps:**
   ```powershell
   # Follow the detailed guide
   Get-Content INSTALLATION_GUIDE.md
   ```

4. **Test your installation:**
   ```powershell
   # Verify tools are working
   rustc --version
   zig version
   python --version
   go version  # (after installing Go)
   docker --version  # (after installing Docker)
   ```

5. **Deploy the system:**
   ```powershell
   .\scripts\enterprise_deployment.ps1
   ```

📄 Check the installation log: logs\user_installation.log

🚀 You're well on your way to deploying Ultra SIEM!

"@

    Write-Host $nextSteps -ForegroundColor Green
    $nextSteps | Out-File "USER_INSTALLATION_COMPLETE.txt"
}

# Main execution
Write-UserLog "🚀 Starting Ultra SIEM user-mode installation..." "PROGRESS"

# Track installation success
$installationResults = @{
    Rust = Install-Rust
    Zig = Install-Zig
    Python = Install-Python
    PowerShell = $true
    ProjectStructure = $true
}

# Install PowerShell modules
Install-PowerShellModules

# Create project structure
Create-ProjectStructure

# Build projects if tools are available and not skipped
if (-not $SkipBuild) {
    $buildResults = @{
        RustBuild = Build-RustProject
        GoBuild = Build-GoProject
        ZigBuild = Build-ZigProject
    }
    
    $installationResults += $buildResults
}

# Check Go separately (usually requires admin install)
$installationResults.Go = Test-Command "go"

# Summary
$successCount = ($installationResults.Values | Where-Object { $_ -eq $true }).Count
$totalCount = $installationResults.Count

Write-UserLog "📊 Installation Summary: $successCount/$totalCount components successful" $(if($successCount -eq $totalCount){"SUCCESS"}else{"WARN"})

foreach ($component in $installationResults.GetEnumerator()) {
    $status = if ($component.Value) { "✅ SUCCESS" } else { "❌ FAILED" }
    Write-UserLog "$($component.Key): $status"
}

Show-NextSteps

Write-UserLog "✅ User-mode installation completed!" "SUCCESS" 