# 🚀 Ultra SIEM Installation Guide

## Quick Start

### **Step 1: Run as Administrator**

```powershell
# Right-click PowerShell and select "Run as Administrator"
# Then navigate to the project directory and run:
cd C:\Users\yasse\Desktop\Workspace\siem
.\scripts\install_requirements.ps1
```

---

## 📋 Manual Installation (if automated script fails)

### **Prerequisites Check**

```powershell
# Check Windows version (Windows 10/11 required)
Get-ComputerInfo | Select WindowsProductName, WindowsVersion

# Check available memory (16GB+ recommended)
Get-CimInstance -ClassName Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
```

### **1. Install Chocolatey Package Manager**

```powershell
# Run as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
```

### **2. Install Development Tools**

```powershell
# Core development tools
choco install git -y
choco install powershell-core -y
choco install cmake -y
choco install 7zip -y

# Programming languages
choco install golang -y
choco install python -y
choco install nodejs -y
choco install llvm -y  # For eBPF compilation
```

### **3. Install Rust with SIMD Support**

```powershell
# Download and install Rust
Invoke-WebRequest -Uri "https://win.rustup.rs/x86_64" -OutFile "rustup-init.exe"
.\rustup-init.exe -y --default-toolchain stable --target x86_64-pc-windows-msvc
Remove-Item "rustup-init.exe"

# Add to PATH and install components
$env:PATH += ";$env:USERPROFILE\.cargo\bin"
rustup component add clippy rustfmt
rustup target add x86_64-pc-windows-gnu
```

### **4. Install Zig**

```powershell
# Download latest Zig
$zigUrl = "https://ziglang.org/download/0.11.0/zig-windows-x86_64-0.11.0.zip"
Invoke-WebRequest -Uri $zigUrl -OutFile "zig.zip"
Expand-Archive "zig.zip" -DestinationPath "C:\zig"
Remove-Item "zig.zip"

# Add to PATH
$env:PATH += ";C:\zig\zig-windows-x86_64-0.11.0"
[Environment]::SetEnvironmentVariable("PATH", "$env:PATH;C:\zig\zig-windows-x86_64-0.11.0", "Machine")
```

### **5. Install Docker Desktop**

```powershell
# Install Docker Desktop
choco install docker-desktop -y

# Wait for installation and restart if prompted
# After restart, start Docker Desktop from Start Menu
```

### **6. Install Python Dependencies**

```powershell
# Upgrade pip
python -m pip install --upgrade pip

# Install required packages
python -m pip install asyncio aiohttp pandas clickhouse-connect cryptography yara-python requests numpy scikit-learn maxminddb stix2 taxii2-client
```

### **7. Install PowerShell Modules**

```powershell
# Set PSGallery as trusted
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted

# Install required modules
Install-Module -Name AWS.Tools.Common -Force -AllowClobber
Install-Module -Name AWS.Tools.S3 -Force -AllowClobber
Install-Module -Name AWS.Tools.Route53 -Force -AllowClobber
Install-Module -Name ThreadJob -Force -AllowClobber
Install-Module -Name ImportExcel -Force -AllowClobber
```

### **8. Enable Windows Features**

```powershell
# Enable required Windows features (requires restart)
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart
Enable-WindowsOptionalFeature -Online -FeatureName Containers -All -NoRestart
```

### **9. Install Security Tools**

```powershell
# PDF generation for reports
choco install wkhtmltopdf -y

# Process monitoring tools
choco install procexp -y
choco install procmon -y

# eBPF for Windows (optional - cutting edge)
$ebpfUrl = "https://github.com/microsoft/ebpf-for-windows/releases/latest/download/ebpf-for-windows.msi"
Invoke-WebRequest -Uri $ebpfUrl -OutFile "ebpf-windows.msi"
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "ebpf-windows.msi", "/quiet" -Wait
Remove-Item "ebpf-windows.msi"
```

---

## 🐳 Docker Setup

### **Pull Required Images**

```powershell
# Start Docker Desktop first, then pull images
docker pull clickhouse/clickhouse-server:latest
docker pull nats:alpine
docker pull grafana/grafana-oss:latest
docker pull timberio/vector:latest-alpine
docker pull ghcr.io/spiffe/spire-server:1.8.2
docker pull ghcr.io/spiffe/spire-agent:1.8.2
```

---

## 🛠️ Build Project Components

### **Build Rust Core**

```powershell
cd rust-core
$env:RUSTFLAGS = "-C target-cpu=native -C target-feature=+avx2,+avx512f"
cargo build --release
cd ..
```

### **Build Go Services**

```powershell
cd go-services
go mod download
go build -ldflags="-s -w" -o bin\ .\...
cd ..
```

### **Build Zig Query Engine**

```powershell
cd zig-query
zig build -Doptimize=ReleaseFast -Dcpu=native
cd ..
```

---

## ⚡ Windows Optimizations (Administrator Required)

### **Enable High Performance**

```powershell
# Set high-performance power plan
powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# Enable huge pages (requires restart)
bcdedit /set increaseuserva 3072
```

### **Network Optimization**

```powershell
# Optimize network adapters for high throughput
Get-NetAdapter | ForEach-Object {
    Set-NetAdapterAdvancedProperty -Name $_.Name -RegistryKeyword "RssBaseProcNumber" -RegistryValue 0 -ErrorAction SilentlyContinue
    Set-NetAdapterAdvancedProperty -Name $_.Name -RegistryKeyword "MaxRssProcessors" -RegistryValue 8 -ErrorAction SilentlyContinue
}
```

---

## 🧪 Verify Installation

### **Test All Components**

```powershell
# Test programming languages
rustc --version
go version
zig version
python --version

# Test Docker
docker --version
docker info

# Test tools
git --version
choco --version
```

### **Test Project Builds**

```powershell
# Check if binaries were created
Test-Path "rust-core\target\release\rust-core.exe"
Test-Path "go-services\bin\*.exe"
Test-Path "zig-query\zig-out\bin\*.exe"
```

---

## 🚀 Quick Deployment

### **After Installation Complete**

```powershell
# 1. Deploy the entire system
.\scripts\enterprise_deployment.ps1

# 2. Start all services
.\scripts\start_services.ps1

# 3. Run production simulation (optional)
.\scripts\production_simulation.ps1 -DurationHours 1
```

---

## 🆘 Troubleshooting

### **Common Issues**

#### **"Command not found" errors**

```powershell
# Refresh environment variables
refreshenv
# Or restart PowerShell
```

#### **Docker not starting**

```powershell
# Restart Docker Desktop service
Restart-Service docker
# Or restart Docker Desktop application
```

#### **Build failures**

```powershell
# Update Rust toolchain
rustup update

# Clean and rebuild
cd rust-core
cargo clean
cargo build --release
```

#### **Permission errors**

```powershell
# Run PowerShell as Administrator
# Check execution policy
Get-ExecutionPolicy
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### **System Requirements**

- **OS**: Windows 10/11 (64-bit)
- **RAM**: 16GB minimum, 32GB recommended
- **CPU**: Intel/AMD with AVX2 support (AVX-512 preferred)
- **Storage**: 100GB free space (SSD recommended)
- **Network**: Gigabit ethernet recommended

### **Optional Features**

- **WSL2**: For Linux compatibility (not required)
- **Hyper-V**: For advanced containerization
- **Developer Mode**: For easier debugging

---

## 📞 Support

If you encounter issues:

1. **Check logs**: `logs\installation.log`
2. **Review error messages**: Most are self-explanatory
3. **Check system requirements**: Ensure your system meets minimums
4. **Try manual steps**: Use the manual installation section
5. **Restart and retry**: Many issues resolve with a system restart

---

## 🎉 Success!

Once installation is complete, you'll have:

- ✅ All development tools and runtimes
- ✅ Docker with required images
- ✅ Built project components
- ✅ Optimized Windows configuration
- ✅ Ready for enterprise deployment

**Next step**: Run `.\scripts\enterprise_deployment.ps1` to deploy the complete Ultra SIEM system!
