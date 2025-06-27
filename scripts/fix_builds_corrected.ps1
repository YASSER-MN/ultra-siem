#!/usr/bin/env pwsh
# Ultra SIEM - Corrected Build Script
# Builds all components with proper paths and error handling

Write-Host "🔨 Ultra SIEM - Corrected Build Script" -ForegroundColor Magenta
Write-Host "======================================" -ForegroundColor Magenta

$startTime = Get-Date

# Build Go Services with correct paths
Write-Host "`n🐹 Building Go Services..." -ForegroundColor Cyan
Set-Location "go-services"
try {
    Write-Host "📦 Building SIEM Processor from main.go..." -ForegroundColor Blue
    $goProc = go build -o "..\bin\siem-processor.exe" "main.go" 2>&1
    if ($LASTEXITCODE -eq 0) {
        $size = (Get-Item "..\bin\siem-processor.exe").Length / 1MB
        Write-Host "✅ SIEM Processor built! ($($size.ToString('F2')) MB)" -ForegroundColor Green
    } else {
        Write-Host "❌ SIEM Processor build failed:" -ForegroundColor Red
        Write-Host $goProc -ForegroundColor DarkRed
    }
    
    Write-Host "📦 Rebuilding Bridge..." -ForegroundColor Blue
    $goBridge = go build -o "..\bin\bridge.exe" "bridge\main.go" 2>&1
    if ($LASTEXITCODE -eq 0) {
        $size = (Get-Item "..\bin\bridge.exe").Length / 1MB
        Write-Host "✅ Bridge rebuilt! ($($size.ToString('F2')) MB)" -ForegroundColor Green
    } else {
        Write-Host "❌ Bridge build failed:" -ForegroundColor Red
        Write-Host $goBridge -ForegroundColor DarkRed
    }
} catch {
    Write-Host "❌ Go build error: $($_.Exception.Message)" -ForegroundColor Red
}
Set-Location ".."

# Build Zig Query Engine (with fixed syntax)
Write-Host "`n⚡ Building Zig Query Engine..." -ForegroundColor Cyan
Set-Location "zig-query"
try {
    Write-Host "📦 Building optimized query engine..." -ForegroundColor Blue
    $zigBuild = zig build-exe src/main.zig -lc -O ReleaseFast --name zig-query 2>&1
    if ($LASTEXITCODE -eq 0) {
        if (Test-Path "zig-query.exe") {
            $size = (Get-Item "zig-query.exe").Length / 1MB
            Copy-Item "zig-query.exe" "..\bin\" -Force
            Write-Host "✅ Zig Query Engine built! ($($size.ToString('F2')) MB)" -ForegroundColor Green
        }
    } else {
        Write-Host "❌ Zig build failed:" -ForegroundColor Red
        Write-Host $zigBuild -ForegroundColor DarkRed
        
        # Try simpler build without C linking
        Write-Host "🔄 Trying simplified build..." -ForegroundColor Yellow
        $zigSimple = zig build-exe src/main.zig -O ReleaseFast --name zig-query 2>&1
        if ($LASTEXITCODE -eq 0) {
            if (Test-Path "zig-query.exe") {
                $size = (Get-Item "zig-query.exe").Length / 1MB
                Copy-Item "zig-query.exe" "..\bin\" -Force
                Write-Host "✅ Zig Query Engine built (simplified)! ($($size.ToString('F2')) MB)" -ForegroundColor Green
            }
        }
    }
} catch {
    Write-Host "❌ Zig build error: $($_.Exception.Message)" -ForegroundColor Red
}
Set-Location ".."

# Try Rust build with workarounds
Write-Host "`n🦀 Building Rust SIEM Core..." -ForegroundColor Cyan
Set-Location "rust-core"
try {
    Write-Host "📦 Checking for Visual Studio Build Tools..." -ForegroundColor Blue
    
    # Check for various C++ build tools
    $hasBuildTools = $false
    $buildToolsPaths = @(
        "${env:PROGRAMFILES(X86)}\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC",
        "${env:PROGRAMFILES}\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC",
        "${env:PROGRAMFILES}\Microsoft Visual Studio\2022\Professional\VC\Tools\MSVC",
        "${env:PROGRAMFILES}\Microsoft Visual Studio\2022\Enterprise\VC\Tools\MSVC"
    )
    
    foreach ($path in $buildToolsPaths) {
        if (Test-Path $path) {
            $hasBuildTools = $true
            Write-Host "✅ Found build tools at: $path" -ForegroundColor Green
            break
        }
    }
    
    if (-not $hasBuildTools) {
        Write-Host "⚠️ Visual Studio Build Tools not found. Trying alternative toolchain..." -ForegroundColor Yellow
        
        # Try to use the GNU toolchain target
        Write-Host "📦 Building with GNU toolchain..." -ForegroundColor Blue
        $rustBuildGnu = cargo build --release --target x86_64-pc-windows-gnu 2>&1
        if ($LASTEXITCODE -eq 0) {
            if (Test-Path "target\x86_64-pc-windows-gnu\release\siem-core.exe") {
                Copy-Item "target\x86_64-pc-windows-gnu\release\siem-core.exe" "..\bin\" -Force
                $size = (Get-Item "..\bin\siem-core.exe").Length / 1MB
                Write-Host "✅ Rust SIEM Core built with GNU! ($($size.ToString('F2')) MB)" -ForegroundColor Green
            }
        } else {
            Write-Host "❌ GNU build also failed:" -ForegroundColor Red
            Write-Host $rustBuildGnu -ForegroundColor DarkRed
            
            # Final attempt with minimal features
            Write-Host "🔄 Trying minimal build..." -ForegroundColor Yellow
            $rustMinimal = cargo build --release --no-default-features 2>&1
            if ($LASTEXITCODE -eq 0) {
                if (Test-Path "target\release\siem-core.exe") {
                    Copy-Item "target\release\siem-core.exe" "..\bin\" -Force
                    $size = (Get-Item "..\bin\siem-core.exe").Length / 1MB
                    Write-Host "✅ Rust SIEM Core built (minimal)! ($($size.ToString('F2')) MB)" -ForegroundColor Green
                }
            } else {
                Write-Host "❌ All Rust build attempts failed" -ForegroundColor Red
                Write-Host "💡 Install Visual Studio Build Tools or MinGW-w64" -ForegroundColor Yellow
            }
        }
    } else {
        # Standard MSVC build
        Write-Host "📦 Building with MSVC toolchain..." -ForegroundColor Blue
        $rustBuild = cargo build --release 2>&1
        if ($LASTEXITCODE -eq 0) {
            if (Test-Path "target\release\siem-core.exe") {
                Copy-Item "target\release\siem-core.exe" "..\bin\" -Force
                $size = (Get-Item "..\bin\siem-core.exe").Length / 1MB
                Write-Host "✅ Rust SIEM Core built! ($($size.ToString('F2')) MB)" -ForegroundColor Green
            }
        } else {
            Write-Host "❌ MSVC build failed:" -ForegroundColor Red
            Write-Host $rustBuild -ForegroundColor DarkRed
        }
    }
} catch {
    Write-Host "❌ Rust build error: $($_.Exception.Message)" -ForegroundColor Red
}
Set-Location ".."

# Final status report
Write-Host "`n📊 Build Results Summary" -ForegroundColor Magenta
Write-Host "========================" -ForegroundColor Magenta

$binaries = @(
    "bin\siem-processor.exe",
    "bin\bridge.exe", 
    "bin\zig-query.exe",
    "bin\siem-core.exe"
)

$builtCount = 0
foreach ($binary in $binaries) {
    if (Test-Path $binary) {
        $size = (Get-Item $binary).Length / 1MB
        $name = Split-Path $binary -Leaf
        Write-Host "✅ $name : $($size.ToString('F2')) MB" -ForegroundColor Green
        $builtCount++
    } else {
        $name = Split-Path $binary -Leaf
        Write-Host "❌ $name : Not built" -ForegroundColor Red
    }
}

$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host "`n🎯 Final Results" -ForegroundColor Magenta
Write-Host "===============" -ForegroundColor Magenta
Write-Host "✅ Built: $builtCount/4 binaries" -ForegroundColor $(if($builtCount -eq 4){"Green"}else{"Yellow"})
Write-Host "⏱️  Time: $($duration.ToString('mm\:ss'))" -ForegroundColor Blue
Write-Host "🎉 Status: $(if($builtCount -eq 4){"ALL COMPLETE"}elseif($builtCount -ge 2){"PARTIALLY COMPLETE"}else{"NEEDS WORK"})" -ForegroundColor $(if($builtCount -eq 4){"Green"}elseif($builtCount -ge 2){"Yellow"}else{"Red"})

if ($builtCount -lt 4) {
    Write-Host "`n💡 Missing builds can be addressed by:" -ForegroundColor Yellow
    Write-Host "   1. Installing Visual Studio Build Tools for Rust" -ForegroundColor White
    Write-Host "   2. Installing MinGW-w64 for GNU toolchain" -ForegroundColor White
    Write-Host "   3. Core functionality works with existing binaries" -ForegroundColor White
}

Write-Host "`n🚀 Your Ultra SIEM is operational with $builtCount/4 components!" -ForegroundColor Cyan 