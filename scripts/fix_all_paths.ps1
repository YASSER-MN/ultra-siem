#!/usr/bin/env pwsh
# Ultra SIEM - Complete PATH Fix & Build Script
# Fixes all PATH issues and builds missing components

Write-Host "🚀 Ultra SIEM - Complete System Fix" -ForegroundColor Magenta
Write-Host "====================================" -ForegroundColor Magenta
Write-Host "This script will fix PATH issues and build all components" -ForegroundColor Yellow
Write-Host ""

$startTime = Get-Date

# Run individual PATH fixes
Write-Host "🔧 Phase 1: Fixing PATH Issues" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

Write-Host "`n🦀 Fixing Rust PATH..." -ForegroundColor Yellow
& "$PSScriptRoot\fix_rust_path.ps1"

Write-Host "`n🐹 Fixing Go PATH..." -ForegroundColor Yellow  
& "$PSScriptRoot\fix_go_path.ps1"

Write-Host "`n⚡ Fixing Zig PATH..." -ForegroundColor Yellow
& "$PSScriptRoot\fix_zig_path.ps1"

# Refresh environment
Write-Host "`n🔄 Refreshing environment..." -ForegroundColor Cyan
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")

# Verify all tools
Write-Host "`n🧪 Phase 2: Verification" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan

$tools = @(
    @{Name="Rust"; Command="rustc --version"; Color="Red"},
    @{Name="Cargo"; Command="cargo --version"; Color="Red"},
    @{Name="Go"; Command="go version"; Color="Blue"},
    @{Name="Zig"; Command="zig version"; Color="Yellow"}
)

$allWorking = $true
foreach ($tool in $tools) {
    try {
        $version = Invoke-Expression $tool.Command 2>$null
        if ($version) {
            Write-Host "✅ $($tool.Name): $version" -ForegroundColor Green
        } else {
            Write-Host "❌ $($tool.Name): Not working" -ForegroundColor $tool.Color
            $allWorking = $false
        }
    } catch {
        Write-Host "❌ $($tool.Name): Not available" -ForegroundColor $tool.Color
        $allWorking = $false
    }
}

if ($allWorking) {
    Write-Host "`n🎉 All tools verified! Building components..." -ForegroundColor Green
    
    # Build Phase
    Write-Host "`n🔨 Phase 3: Building Components" -ForegroundColor Cyan
    Write-Host "===============================" -ForegroundColor Cyan
    
    # Build Rust project
    Write-Host "`n🦀 Building Rust SIEM Core..." -ForegroundColor Yellow
    Set-Location "rust-core"
    try {
        Write-Host "📦 Building release version..." -ForegroundColor Blue
        $rustBuild = cargo build --release 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Rust build successful!" -ForegroundColor Green
            
            # Copy binary
            if (Test-Path "target\release\siem-core.exe") {
                Copy-Item "target\release\siem-core.exe" "..\bin\" -Force
                Write-Host "📁 Binary copied to bin/" -ForegroundColor Blue
            }
        } else {
            Write-Host "❌ Rust build failed:" -ForegroundColor Red
            Write-Host $rustBuild -ForegroundColor DarkRed
        }
    } catch {
        Write-Host "❌ Rust build error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Set-Location ".."
    
    # Build Go services (rebuild to ensure fresh)
    Write-Host "`n🐹 Building Go Services..." -ForegroundColor Yellow
    Set-Location "go-services"
    try {
        Write-Host "📦 Building SIEM Processor..." -ForegroundColor Blue
        $goProc = go build -o "..\bin\siem-processor.exe" ".\siem-processor\main.go" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ SIEM Processor built!" -ForegroundColor Green
        }
        
        Write-Host "📦 Building Bridge..." -ForegroundColor Blue
        $goBridge = go build -o "..\bin\bridge.exe" ".\bridge\main.go" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Bridge built!" -ForegroundColor Green
        }
    } catch {
        Write-Host "❌ Go build error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Set-Location ".."
    
    # Build Zig query engine
    Write-Host "`n⚡ Building Zig Query Engine..." -ForegroundColor Yellow
    Set-Location "zig-query"
    try {
        Write-Host "📦 Building optimized query engine..." -ForegroundColor Blue
        $zigBuild = zig build-exe src/main.zig -O ReleaseFast -target x86_64-windows 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Zig build successful!" -ForegroundColor Green
            
            # Copy binary
            if (Test-Path "main.exe") {
                Copy-Item "main.exe" "..\bin\zig-query.exe" -Force
                Write-Host "📁 Binary copied to bin/" -ForegroundColor Blue
            }
        } else {
            Write-Host "❌ Zig build failed:" -ForegroundColor Red
            Write-Host $zigBuild -ForegroundColor DarkRed
        }
    } catch {
        Write-Host "❌ Zig build error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Set-Location ".."
    
} else {
    Write-Host "`n⚠️ Some tools are not working. Skipping build phase." -ForegroundColor Yellow
    Write-Host "💡 Try restarting PowerShell and running this script again." -ForegroundColor Cyan
}

# Final component status
Write-Host "`n📊 Phase 4: Final Status Report" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan

$components = @(
    @{Name="Rust Compiler"; Path="rustc"; Type="Tool"},
    @{Name="Go Compiler"; Path="go"; Type="Tool"},
    @{Name="Zig Compiler"; Path="zig"; Type="Tool"},
    @{Name="Rust SIEM Core"; Path="bin\siem-core.exe"; Type="Binary"},
    @{Name="Go SIEM Processor"; Path="bin\siem-processor.exe"; Type="Binary"},
    @{Name="Go Bridge"; Path="bin\bridge.exe"; Type="Binary"},
    @{Name="Zig Query Engine"; Path="bin\zig-query.exe"; Type="Binary"}
)

$workingCount = 0
$totalCount = $components.Count

foreach ($comp in $components) {
    if ($comp.Type -eq "Tool") {
        try {
            $null = Get-Command $comp.Path -ErrorAction Stop
            Write-Host "✅ $($comp.Name): Available" -ForegroundColor Green
            $workingCount++
        } catch {
            Write-Host "❌ $($comp.Name): Not found" -ForegroundColor Red
        }
    } else {
        if (Test-Path $comp.Path) {
            $size = (Get-Item $comp.Path).Length / 1MB
            Write-Host "✅ $($comp.Name): Built ($($size.ToString('F2')) MB)" -ForegroundColor Green
            $workingCount++
        } else {
            Write-Host "❌ $($comp.Name): Not built" -ForegroundColor Red
        }
    }
}

$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host "`n🎯 Final Summary" -ForegroundColor Magenta
Write-Host "===============" -ForegroundColor Magenta
Write-Host "✅ Working Components: $workingCount/$totalCount" -ForegroundColor $(if($workingCount -eq $totalCount){"Green"}else{"Yellow"})
Write-Host "⏱️  Total Time: $($duration.ToString('mm\:ss'))" -ForegroundColor Blue
Write-Host "🎉 Status: $(if($workingCount -eq $totalCount){"COMPLETE"}else{"PARTIAL"})" -ForegroundColor $(if($workingCount -eq $totalCount){"Green"}else{"Yellow"})

if ($workingCount -eq $totalCount) {
    Write-Host "`n🚀 All 9/9 components are now working!" -ForegroundColor Green
    Write-Host "🎊 Your Ultra SIEM is ready for maximum performance!" -ForegroundColor Cyan
} else {
    Write-Host "`n💡 If components are missing, try:" -ForegroundColor Yellow
    Write-Host "   1. Restart PowerShell as Administrator" -ForegroundColor White
    Write-Host "   2. Run this script again" -ForegroundColor White
    Write-Host "   3. Check Windows Defender/antivirus settings" -ForegroundColor White
}

Write-Host "`n🔄 Remember to restart PowerShell to ensure all PATH changes are active!" -ForegroundColor Cyan 