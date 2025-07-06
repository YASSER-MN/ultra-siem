# 🚀 Ultra SIEM - Demo Quick Start Script
# This script automates the entire demo setup process

param(
    [switch]$SkipInfrastructure,
    [switch]$SkipEngines,
    [switch]$SkipMonitor,
    [switch]$SkipAttackCenter
)

Write-Host "🚀 Ultra SIEM - Demo Quick Start" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Check if we're in the right directory
if (-not (Test-Path "docker-compose.simple.yml")) {
    Write-Host "❌ Error: Please run this script from the SIEM root directory" -ForegroundColor Red
    Write-Host "   Current directory: $(Get-Location)" -ForegroundColor Yellow
    Write-Host "   Expected: C:\Users\yasse\Desktop\Workspace\siem" -ForegroundColor Yellow
    exit 1
}

# Step 1: Start Infrastructure
if (-not $SkipInfrastructure) {
    Write-Host "📦 Step 1: Starting Infrastructure..." -ForegroundColor Green
    Write-Host "   Starting Docker containers..." -ForegroundColor Yellow
    
    docker-compose -f docker-compose.simple.yml up -d
    
    Write-Host "   ⏳ Waiting for services to be healthy..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    
    # Verify services
    $containers = docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    Write-Host "   📊 Container Status:" -ForegroundColor Cyan
    Write-Host $containers -ForegroundColor White
    
    Write-Host "✅ Infrastructure ready!" -ForegroundColor Green
    Write-Host ""
}

# Step 2: Start Detection Engines
if (-not $SkipEngines) {
    Write-Host "🔍 Step 2: Starting Detection Engines..." -ForegroundColor Green
    
    # Start Rust engine in background
    Write-Host "   🦀 Starting Rust detection engine..." -ForegroundColor Yellow
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit", "-Command", "cd '$PWD\rust-core'; cargo run" -WindowStyle Normal
    
    Start-Sleep -Seconds 5
    
    # Start Go processor in background
    Write-Host "   🐹 Starting Go data processor..." -ForegroundColor Yellow
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit", "-Command", "cd '$PWD\go-services\bridge'; go run main.go" -WindowStyle Normal
    
    Write-Host "   ⏳ Waiting for engines to initialize..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    Write-Host "✅ Detection engines started!" -ForegroundColor Green
    Write-Host ""
}

# Step 3: Start Monitor
if (-not $SkipMonitor) {
    Write-Host "📊 Step 3: Starting SIEM Monitor..." -ForegroundColor Green
    Write-Host "   📈 Opening real-time monitor..." -ForegroundColor Yellow
    
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit", "-Command", "cd '$PWD'; .\siem_monitor_simple.ps1" -WindowStyle Normal
    
    Write-Host "✅ Monitor started!" -ForegroundColor Green
    Write-Host ""
}

# Step 4: Start Attack Control Center
if (-not $SkipAttackCenter) {
    Write-Host "🎯 Step 4: Starting Attack Control Center..." -ForegroundColor Green
    Write-Host "   🔧 Opening attack simulation interface..." -ForegroundColor Yellow
    
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit", "-Command", "cd '$PWD'; .\attack_control_center.ps1" -WindowStyle Normal
    
    Write-Host "✅ Attack control center started!" -ForegroundColor Green
    Write-Host ""
}

# Final status
Write-Host "🎉 Ultra SIEM Demo Setup Complete!" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Demo Components:" -ForegroundColor White
Write-Host "   ✅ Infrastructure: Docker containers running" -ForegroundColor Green
Write-Host "   ✅ Rust Engine: Real-time threat detection" -ForegroundColor Green
Write-Host "   ✅ Go Processor: Event processing" -ForegroundColor Green
Write-Host "   ✅ SIEM Monitor: Real-time dashboard" -ForegroundColor Green
Write-Host "   ✅ Attack Center: Threat simulation" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 Access Points:" -ForegroundColor White
Write-Host "   📊 Grafana Dashboard: http://localhost:3000 (admin/admin)" -ForegroundColor Cyan
Write-Host "   🗄️ ClickHouse: http://localhost:8123 (admin/admin)" -ForegroundColor Cyan
Write-Host "   📡 NATS Monitor: http://localhost:8222/varz" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎯 Demo Instructions:" -ForegroundColor White
Write-Host "   1. Wait 30 seconds for all engines to fully initialize" -ForegroundColor Yellow
Write-Host "   2. Use the Attack Control Center to launch simulated attacks" -ForegroundColor Yellow
Write-Host "   3. Watch real-time detection in the SIEM Monitor" -ForegroundColor Yellow
Write-Host "   4. View analytics in the Grafana Dashboard" -ForegroundColor Yellow
Write-Host ""
Write-Host "⏱️ Total setup time: ~2 minutes" -ForegroundColor Green
Write-Host "🎬 Demo duration: 20 minutes" -ForegroundColor Green
Write-Host ""
Write-Host "🚀 You're ready for your presentation!" -ForegroundColor Cyan 