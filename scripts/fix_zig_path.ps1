#!/usr/bin/env pwsh
# Ultra SIEM - Zig PATH Fix Script
# Efficiently finds and fixes Zig installation without system freeze

Write-Host "🔧 Ultra SIEM - Zig PATH Fix" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

$zigFound = $false
$zigPath = $null

# Check if zig is already in PATH
Write-Host "🔍 Checking if Zig is in PATH..." -ForegroundColor Yellow
try {
    $zigVersion = zig version 2>$null
    if ($zigVersion) {
        Write-Host "✅ Zig already in PATH: $zigVersion" -ForegroundColor Green
        $zigFound = $true
    }
} catch {
    Write-Host "❌ Zig not in PATH" -ForegroundColor Yellow
}

if (!$zigFound) {
    Write-Host "🔍 Searching common Zig locations..." -ForegroundColor Yellow
    
    # Common installation paths
    $commonPaths = @(
        "$env:USERPROFILE\.zig",
        "$env:LOCALAPPDATA\zig",
        "$env:PROGRAMFILES\zig",
        "$env:PROGRAMFILES(X86)\zig",
        "C:\zig",
        "C:\tools\zig",
        "$PWD\zig-windows-x86_64-*",
        "$env:USERPROFILE\Downloads\zig-windows-x86_64-*"
    )
    
    foreach ($path in $commonPaths) {
        Write-Host "  Checking: $path" -ForegroundColor DarkGray
        
        if (Test-Path $path) {
            $zigExe = Get-ChildItem -Path $path -Name "zig.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($zigExe) {
                $zigPath = Split-Path (Join-Path $path $zigExe.Name) -Parent
                Write-Host "✅ Found Zig at: $zigPath" -ForegroundColor Green
                $zigFound = $true
                break
            }
        }
    }
}

if (!$zigFound) {
    Write-Host "🔍 Quick search in Downloads and temp folders..." -ForegroundColor Yellow
    
    $downloadsPaths = @(
        "$env:USERPROFILE\Downloads",
        "$env:TEMP",
        "$env:TMP"
    )
    
    foreach ($dlPath in $downloadsPaths) {
        if (Test-Path $dlPath) {
            $zigDirs = Get-ChildItem -Path $dlPath -Directory -Name "zig-*" -ErrorAction SilentlyContinue | Select-Object -First 5
            foreach ($zigDir in $zigDirs) {
                $fullPath = Join-Path $dlPath $zigDir
                $zigExe = Get-ChildItem -Path $fullPath -Name "zig.exe" -ErrorAction SilentlyContinue
                if ($zigExe) {
                    $zigPath = $fullPath
                    Write-Host "✅ Found Zig at: $zigPath" -ForegroundColor Green
                    $zigFound = $true
                    break
                }
            }
            if ($zigFound) { break }
        }
    }
}

if ($zigFound -and $zigPath) {
    Write-Host "🔧 Adding Zig to PATH..." -ForegroundColor Cyan
    
    # Add to current session
    $env:PATH += ";$zigPath"
    
    # Add to user PATH permanently
    try {
        $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if ($userPath -notlike "*$zigPath*") {
            $newPath = "$userPath;$zigPath"
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
            Write-Host "✅ Added to user PATH permanently" -ForegroundColor Green
        } else {
            Write-Host "ℹ️ Already in user PATH" -ForegroundColor Blue
        }
    } catch {
        Write-Host "⚠️ Could not add to permanent PATH: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Test Zig
    Write-Host "🧪 Testing Zig installation..." -ForegroundColor Cyan
    try {
        $version = & "$zigPath\zig.exe" version
        Write-Host "✅ Zig working: $version" -ForegroundColor Green
        
        # Test basic compilation
        Write-Host "🧪 Testing Zig compilation..." -ForegroundColor Cyan
        $testCode = 'const std = @import("std"); pub fn main() void { std.debug.print("Zig works!\n", .{}); }'
        $testFile = "test_zig.zig"
        Set-Content -Path $testFile -Value $testCode
        
        $compileResult = & "$zigPath\zig.exe" run $testFile 2>&1
        if ($compileResult -like "*Zig works!*") {
            Write-Host "✅ Zig compilation test passed" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Zig compilation test failed: $compileResult" -ForegroundColor Yellow
        }
        
        Remove-Item $testFile -ErrorAction SilentlyContinue
        
    } catch {
        Write-Host "❌ Zig test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
} elseif (!$zigFound) {
    Write-Host "❌ Zig not found. Installing fresh copy..." -ForegroundColor Red
    
    Write-Host "📥 Downloading Zig..." -ForegroundColor Cyan
    $zigUrl = "https://ziglang.org/download/0.11.0/zig-windows-x86_64-0.11.0.zip"
    $zigZip = "$env:TEMP\zig-windows.zip"
    $zigExtract = "$env:USERPROFILE\.zig"
    
    try {
        Invoke-WebRequest -Uri $zigUrl -OutFile $zigZip -UseBasicParsing
        Write-Host "✅ Downloaded Zig" -ForegroundColor Green
        
        Write-Host "📂 Extracting Zig..." -ForegroundColor Cyan
        if (Test-Path $zigExtract) {
            Remove-Item $zigExtract -Recurse -Force
        }
        Expand-Archive -Path $zigZip -DestinationPath $zigExtract -Force
        
        # Find the extracted folder
        $extractedFolder = Get-ChildItem -Path $zigExtract -Directory | Select-Object -First 1
        if ($extractedFolder) {
            $zigPath = $extractedFolder.FullName
            Write-Host "✅ Zig extracted to: $zigPath" -ForegroundColor Green
            
            # Add to PATH
            $env:PATH += ";$zigPath"
            $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
            $newPath = "$userPath;$zigPath"
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
            
            Write-Host "✅ Zig installation completed!" -ForegroundColor Green
        }
        
        Remove-Item $zigZip -ErrorAction SilentlyContinue
        
    } catch {
        Write-Host "❌ Zig installation failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n🎯 PATH Fix Summary:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
if ($zigFound) {
    Write-Host "✅ Zig Status: WORKING" -ForegroundColor Green
    Write-Host "📍 Location: $zigPath" -ForegroundColor Blue
    Write-Host "🔧 PATH: CONFIGURED" -ForegroundColor Green
} else {
    Write-Host "❌ Zig Status: NOT FOUND" -ForegroundColor Red
    Write-Host "💡 Try running as Administrator or manual installation" -ForegroundColor Yellow
}

Write-Host "`n🔄 Please restart PowerShell to ensure PATH changes take effect" -ForegroundColor Cyan 