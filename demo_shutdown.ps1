# 🛑 Ultra SIEM - Demo Shutdown Script
# This script cleanly shuts down all demo components

Write-Host "🛑 Ultra SIEM - Demo Shutdown" -ForegroundColor Red
Write-Host "=============================" -ForegroundColor Red
Write-Host ""

# Step 1: Stop all SIEM-related processes
Write-Host "🔍 Step 1: Stopping SIEM Processes..." -ForegroundColor Yellow

$siemProcesses = Get-Process | Where-Object {
    $_.ProcessName -like "*cargo*" -or 
    $_.ProcessName -like "*rust*" -or 
    $_.ProcessName -like "*go*" -or 
    $_.ProcessName -like "*siem*" -or
    $_.ProcessName -like "*powershell*" -and $_.MainWindowTitle -like "*SIEM*"
}

if ($siemProcesses) {
    Write-Host "   Found $($siemProcesses.Count) SIEM processes to stop..." -ForegroundColor Yellow
    foreach ($proc in $siemProcesses) {
        try {
            Write-Host "   Stopping: $($proc.ProcessName) (PID: $($proc.Id))" -ForegroundColor Cyan
            $proc.Kill()
        }
        catch {
            $errorMsg = $_.Exception.Message
            Write-Host "   ⚠️ Could not stop $($proc.ProcessName): $errorMsg" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "   No SIEM processes found running" -ForegroundColor Green
}

Write-Host "✅ SIEM processes stopped!" -ForegroundColor Green
Write-Host ""

# Step 2: Stop Docker containers
Write-Host "🐳 Step 2: Stopping Docker Containers..." -ForegroundColor Yellow

try {
    $containers = docker ps --format "{{.Names}}" | Where-Object { $_ -like "*siem*" }
    
    if ($containers) {
        Write-Host "   Found $($containers.Count) SIEM containers to stop..." -ForegroundColor Yellow
        foreach ($container in $containers) {
            Write-Host "   Stopping: $container" -ForegroundColor Cyan
            docker stop $container
        }
        
        Write-Host "   Removing containers..." -ForegroundColor Yellow
        docker-compose -f docker-compose.simple.yml down
    } else {
        Write-Host "   No SIEM containers found running" -ForegroundColor Green
    }
} catch {
    $errorMsg = $_.Exception.Message
    Write-Host "   ⚠️ Error stopping containers: $errorMsg" -ForegroundColor Yellow
}

Write-Host "✅ Docker containers stopped!" -ForegroundColor Green
Write-Host ""

# Step 3: Clean up temporary files
Write-Host "🧹 Step 3: Cleaning Up Temporary Files..." -ForegroundColor Yellow

$tempFiles = @(
    "$env:TEMP\malware.exe",
    "$env:TEMP\payload.dll", 
    "$env:TEMP\backdoor.bat",
    "$env:TEMP\trojan.vbs",
    "$env:TEMP\keylogger.ps1",
    "$env:TEMP\ransomware.exe",
    "$env:TEMP\multi_attack.exe"
)

foreach ($file in $tempFiles) {
    if (Test-Path $file) {
        try {
            Remove-Item $file -Force
            Write-Host "   Removed: $file" -ForegroundColor Cyan
        }
        catch {
            $errorMsg = $_.Exception.Message
            Write-Host "   ⚠️ Could not remove $file: $errorMsg" -ForegroundColor Yellow
        }
    }
}

# Remove any rapid fire attack files
Get-ChildItem "$env:TEMP\rapid_attack_*.exe" -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem "$env:TEMP\random_attack_*.exe" -ErrorAction SilentlyContinue | Remove-Item -Force

Write-Host "✅ Temporary files cleaned!" -ForegroundColor Green
Write-Host ""

# Step 4: Final status
Write-Host "🎉 Ultra SIEM Demo Shutdown Complete!" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Shutdown Summary:" -ForegroundColor White
Write-Host "   ✅ SIEM processes: Stopped" -ForegroundColor Green
Write-Host "   ✅ Docker containers: Stopped" -ForegroundColor Green
Write-Host "   ✅ Temporary files: Cleaned" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 Services Status:" -ForegroundColor White
Write-Host "   📊 Grafana: http://localhost:3000 (should be offline)" -ForegroundColor Red
Write-Host "   🗄️ ClickHouse: http://localhost:8123 (should be offline)" -ForegroundColor Red
Write-Host "   📡 NATS: http://localhost:8222 (should be offline)" -ForegroundColor Red
Write-Host ""
Write-Host "💡 To restart the demo, run: .\demo_quick_start.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "🛑 Demo environment fully shut down!" -ForegroundColor Green 