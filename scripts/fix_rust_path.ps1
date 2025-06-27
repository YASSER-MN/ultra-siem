#!/usr/bin/env pwsh
# Ultra SIEM - Rust PATH Fix Script
# Efficiently finds and fixes Rust installation without system freeze

Write-Host "🦀 Ultra SIEM - Rust PATH Fix" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

$rustFound = $false
$rustPath = $null

# Check if rust is already in PATH
Write-Host "🔍 Checking if Rust is in PATH..." -ForegroundColor Yellow
try {
    $rustVersion = rustc --version 2>$null
    if ($rustVersion) {
        Write-Host "✅ Rust already in PATH: $rustVersion" -ForegroundColor Green
        $rustFound = $true
    }
} catch {
    Write-Host "❌ Rust not in PATH" -ForegroundColor Yellow
}

if (!$rustFound) {
    Write-Host "🔍 Searching common Rust locations..." -ForegroundColor Yellow
    
    # Common Rust installation paths
    $commonPaths = @(
        "$env:USERPROFILE\.cargo\bin",
        "$env:USERPROFILE\.rustup\toolchains\stable-x86_64-pc-windows-msvc\bin",
        "$env:LOCALAPPDATA\cargo\bin",
        "$env:PROGRAMFILES\Rust\bin",
        "C:\Rust\bin"
    )
    
    foreach ($path in $commonPaths) {
        Write-Host "  Checking: $path" -ForegroundColor DarkGray
        
        if (Test-Path $path) {
            $rustExe = Get-ChildItem -Path $path -Name "rustc.exe" -ErrorAction SilentlyContinue
            if ($rustExe) {
                $rustPath = $path
                Write-Host "✅ Found Rust at: $rustPath" -ForegroundColor Green
                $rustFound = $true
                break
            }
        }
    }
}

if ($rustFound -and $rustPath) {
    Write-Host "🔧 Adding Rust to PATH..." -ForegroundColor Cyan
    
    # Add to current session
    $env:PATH += ";$rustPath"
    
    # Add to user PATH permanently
    try {
        $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if ($userPath -notlike "*$rustPath*") {
            $newPath = "$userPath;$rustPath"
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
            Write-Host "✅ Added to user PATH permanently" -ForegroundColor Green
        } else {
            Write-Host "ℹ️ Already in user PATH" -ForegroundColor Blue
        }
    } catch {
        Write-Host "⚠️ Could not add to permanent PATH: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Test Rust
    Write-Host "🧪 Testing Rust installation..." -ForegroundColor Cyan
    try {
        $version = rustc --version
        Write-Host "✅ Rust working: $version" -ForegroundColor Green
        
        $cargoVersion = cargo --version
        Write-Host "✅ Cargo working: $cargoVersion" -ForegroundColor Green
        
    } catch {
        Write-Host "❌ Rust test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} elseif (!$rustFound) {
    Write-Host "❌ Rust not found. Installing fresh copy..." -ForegroundColor Red
    
    Write-Host "📥 Downloading Rust installer..." -ForegroundColor Cyan
    $rustUrl = "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe"
    $rustInstaller = "$env:TEMP\rustup-init.exe"
    
    try {
        Invoke-WebRequest -Uri $rustUrl -OutFile $rustInstaller -UseBasicParsing
        Write-Host "✅ Downloaded Rust installer" -ForegroundColor Green
        
        Write-Host "🔧 Installing Rust..." -ForegroundColor Cyan
        & $rustInstaller -y --default-toolchain stable
        
        # Add standard Rust paths
        $cargoPath = "$env:USERPROFILE\.cargo\bin"
        if (Test-Path $cargoPath) {
            $env:PATH += ";$cargoPath"
            $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
            $newPath = "$userPath;$cargoPath"
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
            Write-Host "✅ Rust installation completed!" -ForegroundColor Green
        }
        
        Remove-Item $rustInstaller -ErrorAction SilentlyContinue
        
    } catch {
        Write-Host "❌ Rust installation failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n🎯 PATH Fix Summary:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
if ($rustFound) {
    Write-Host "✅ Rust Status: WORKING" -ForegroundColor Green
    Write-Host "📍 Location: $rustPath" -ForegroundColor Blue
    Write-Host "🔧 PATH: CONFIGURED" -ForegroundColor Green
} else {
    Write-Host "❌ Rust Status: NOT FOUND" -ForegroundColor Red
    Write-Host "💡 Try running as Administrator or manual installation" -ForegroundColor Yellow
}

Write-Host "`n🔄 Please restart PowerShell to ensure PATH changes take effect" -ForegroundColor Cyan 