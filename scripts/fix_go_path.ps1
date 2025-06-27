#!/usr/bin/env pwsh
# Ultra SIEM - Go PATH Fix Script
# Efficiently finds and fixes Go installation without system freeze

Write-Host "🐹 Ultra SIEM - Go PATH Fix" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

$goFound = $false
$goPath = $null

# Check if go is already in PATH
Write-Host "🔍 Checking if Go is in PATH..." -ForegroundColor Yellow
try {
    $goVersion = go version 2>$null
    if ($goVersion) {
        Write-Host "✅ Go already in PATH: $goVersion" -ForegroundColor Green
        $goFound = $true
    }
} catch {
    Write-Host "❌ Go not in PATH" -ForegroundColor Yellow
}

if (!$goFound) {
    Write-Host "🔍 Searching common Go locations..." -ForegroundColor Yellow
    
    # Common Go installation paths
    $commonPaths = @(
        "$env:PROGRAMFILES\Go\bin",
        "$env:PROGRAMFILES(X86)\Go\bin",
        "$env:LOCALAPPDATA\Go\bin",
        "$env:USERPROFILE\go\bin",
        "C:\Go\bin",
        "C:\tools\go\bin"
    )
    
    foreach ($path in $commonPaths) {
        Write-Host "  Checking: $path" -ForegroundColor DarkGray
        
        if (Test-Path $path) {
            $goExe = Get-ChildItem -Path $path -Name "go.exe" -ErrorAction SilentlyContinue
            if ($goExe) {
                $goPath = $path
                Write-Host "✅ Found Go at: $goPath" -ForegroundColor Green
                $goFound = $true
                break
            }
        }
    }
}

if (!$goFound) {
    Write-Host "🔍 Quick search in Downloads folder..." -ForegroundColor Yellow
    
    $downloadsPath = "$env:USERPROFILE\Downloads"
    if (Test-Path $downloadsPath) {
        $goDirs = Get-ChildItem -Path $downloadsPath -Directory -Name "go*" -ErrorAction SilentlyContinue | Select-Object -First 3
        foreach ($goDir in $goDirs) {
            $fullPath = Join-Path $downloadsPath $goDir "bin"
            if (Test-Path $fullPath) {
                $goExe = Get-ChildItem -Path $fullPath -Name "go.exe" -ErrorAction SilentlyContinue
                if ($goExe) {
                    $goPath = $fullPath
                    Write-Host "✅ Found Go at: $goPath" -ForegroundColor Green
                    $goFound = $true
                    break
                }
            }
        }
    }
}

if ($goFound -and $goPath) {
    Write-Host "🔧 Adding Go to PATH..." -ForegroundColor Cyan
    
    # Add to current session
    $env:PATH += ";$goPath"
    
    # Add to user PATH permanently
    try {
        $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if ($userPath -notlike "*$goPath*") {
            $newPath = "$userPath;$goPath"
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
            Write-Host "✅ Added to user PATH permanently" -ForegroundColor Green
        } else {
            Write-Host "ℹ️ Already in user PATH" -ForegroundColor Blue
        }
    } catch {
        Write-Host "⚠️ Could not add to permanent PATH: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Test Go
    Write-Host "🧪 Testing Go installation..." -ForegroundColor Cyan
    try {
        $version = go version
        Write-Host "✅ Go working: $version" -ForegroundColor Green
        
        # Test basic compilation
        Write-Host "🧪 Testing Go compilation..." -ForegroundColor Cyan
        $testCode = 'package main
import "fmt"
func main() { fmt.Println("Go works!") }'
        $testFile = "test_go.go"
        Set-Content -Path $testFile -Value $testCode
        
        $compileResult = go run $testFile 2>&1
        if ($compileResult -like "*Go works!*") {
            Write-Host "✅ Go compilation test passed" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Go compilation test: $compileResult" -ForegroundColor Yellow
        }
        
        Remove-Item $testFile -ErrorAction SilentlyContinue
        
    } catch {
        Write-Host "❌ Go test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} elseif (!$goFound) {
    Write-Host "❌ Go not found. Installing fresh copy..." -ForegroundColor Red
    
    Write-Host "📥 Downloading Go..." -ForegroundColor Cyan
    $goUrl = "https://go.dev/dl/go1.21.6.windows-amd64.msi"
    $goInstaller = "$env:TEMP\go-installer.msi"
    
    try {
        Invoke-WebRequest -Uri $goUrl -OutFile $goInstaller -UseBasicParsing
        Write-Host "✅ Downloaded Go installer" -ForegroundColor Green
        
        Write-Host "🔧 Installing Go..." -ForegroundColor Cyan
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", $goInstaller, "/quiet" -Wait
        
        # Add standard Go path
        $standardGoPath = "$env:PROGRAMFILES\Go\bin"
        if (Test-Path $standardGoPath) {
            $env:PATH += ";$standardGoPath"
            $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
            $newPath = "$userPath;$standardGoPath"
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
            Write-Host "✅ Go installation completed!" -ForegroundColor Green
        }
        
        Remove-Item $goInstaller -ErrorAction SilentlyContinue
        
    } catch {
        Write-Host "❌ Go installation failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 You may need to install manually from https://golang.org/dl/" -ForegroundColor Yellow
    }
}

Write-Host "`n🎯 PATH Fix Summary:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
if ($goFound) {
    Write-Host "✅ Go Status: WORKING" -ForegroundColor Green
    Write-Host "📍 Location: $goPath" -ForegroundColor Blue
    Write-Host "🔧 PATH: CONFIGURED" -ForegroundColor Green
} else {
    Write-Host "❌ Go Status: NOT FOUND" -ForegroundColor Red
    Write-Host "💡 Try running as Administrator or manual installation" -ForegroundColor Yellow
}

Write-Host "`n🔄 Please restart PowerShell to ensure PATH changes take effect" -ForegroundColor Cyan 