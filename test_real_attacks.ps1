# 🎯 Ultra SIEM - Real Attack Testing Script
# This script performs realistic attacks that should definitely trigger detection

param(
    [switch]$Aggressive,
    [switch]$Stealth,
    [switch]$All
)

Write-Host "🎯 Ultra SIEM - Real Attack Testing" -ForegroundColor Red
Write-Host "===================================" -ForegroundColor Red
Write-Host ""

if ($Aggressive -or $All) {
    Write-Host "🔥 AGGRESSIVE ATTACK MODE" -ForegroundColor Red
    Write-Host "=========================" -ForegroundColor Red
    
    # 1. Multiple failed login attempts (should trigger Event ID 4625)
    Write-Host "🔐 Testing Failed Login Detection..." -ForegroundColor Yellow
    for ($i = 1; $i -le 10; $i++) {
        Write-Host "   Attempt $($i): Trying invalid credentials..." -ForegroundColor Cyan
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "net user invaliduser$($i) invalidpass$($i)" -WindowStyle Hidden
        Start-Sleep -Milliseconds 500
    }
    
    # 2. PowerShell encoded commands (malware simulation)
    Write-Host "🦠 Testing PowerShell Malware Detection..." -ForegroundColor Yellow
    $encodedCommands = @(
        "powershell.exe -enc SGVsbG8gV29ybGQ=",  # Hello World
        "powershell.exe -enc V3JpdGUtSG9zdCBIZWxsbyBXb3JsZA==",  # Write-Host Hello World
        "powershell.exe -enc JEVycm9yQWN0aW9uUHJlZmVyZW5jZT0nU2lsZW50bHlDb250aW51ZSc=",  # ErrorActionPreference
        "powershell.exe -enc JEludm9rZS1FeHByZXNzaW9uICdHZXQtUHJvY2Vzcyc=",  # Invoke-Expression
        "powershell.exe -enc JFN0YXJ0LVByb2Nlc3MgLWZpbGVwYXRoICdub3RlcGFkLmV4ZSc="  # Start-Process
    )
    
    foreach ($cmd in $encodedCommands) {
        Write-Host "   Executing: $cmd" -ForegroundColor Cyan
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $cmd -WindowStyle Hidden
        Start-Sleep -Seconds 2
    }
    
    # 3. Suspicious file operations
    Write-Host "📁 Testing File System Attack Detection..." -ForegroundColor Yellow
    $suspiciousFiles = @(
        "malware.exe",
        "payload.dll", 
        "backdoor.bat",
        "trojan.vbs",
        "keylogger.ps1",
        "ransomware.exe",
        "exploit.py",
        "shellcode.bin"
    )
    
    foreach ($file in $suspiciousFiles) {
        $filePath = Join-Path $env:TEMP $file
        Write-Host "   Creating: $filePath" -ForegroundColor Cyan
        New-Item -Path $filePath -ItemType File -Force | Out-Null
        Start-Sleep -Milliseconds 300
    }
    
    # 4. Network reconnaissance
    Write-Host "🌐 Testing Network Reconnaissance Detection..." -ForegroundColor Yellow
    $networkCommands = @(
        "netstat -an",
        "netstat -an | findstr :80",
        "netstat -an | findstr :443", 
        "netstat -an | findstr :22",
        "netstat -an | findstr :3389",
        "netstat -an | findstr :8080",
        "netstat -an | findstr :21"
    )
    
    foreach ($cmd in $networkCommands) {
        Write-Host "   Executing: $cmd" -ForegroundColor Cyan
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $cmd -WindowStyle Hidden
        Start-Sleep -Seconds 1
    }
    
    # 5. Process injection and enumeration
    Write-Host "⚙️ Testing Process Attack Detection..." -ForegroundColor Yellow
    $processCommands = @(
        "tasklist",
        "tasklist /v",
        "wmic process get name,processid,parentprocessid",
        "Get-Process | Select-Object -First 20",
        "Get-Process | Where-Object {$_.ProcessName -like '*svchost*'}",
        "Get-Process | Where-Object {$_.ProcessName -like '*explorer*'}"
    )
    
    foreach ($cmd in $processCommands) {
        Write-Host "   Executing: $cmd" -ForegroundColor Cyan
        if ($cmd -like "*Get-Process*") {
            Start-Process -FilePath "powershell.exe" -ArgumentList "-Command", $cmd -WindowStyle Hidden
        } else {
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $cmd -WindowStyle Hidden
        }
        Start-Sleep -Seconds 1
    }
    
    # 6. System information gathering
    Write-Host "🔍 Testing System Reconnaissance..." -ForegroundColor Yellow
    $sysCommands = @(
        "systeminfo",
        "whoami",
        "whoami /all",
        "net user",
        "net localgroup administrators",
        "ipconfig /all",
        "route print"
    )
    
    foreach ($cmd in $sysCommands) {
        Write-Host "   Executing: $cmd" -ForegroundColor Cyan
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $cmd -WindowStyle Hidden
        Start-Sleep -Seconds 1
    }
}

if ($Stealth -or $All) {
    Write-Host "🕵️ STEALTH ATTACK MODE" -ForegroundColor Yellow
    Write-Host "=======================" -ForegroundColor Yellow
    
    # 1. Subtle file operations
    Write-Host "📁 Testing Stealth File Operations..." -ForegroundColor Yellow
    $stealthFiles = @(
        "config.ini",
        "data.txt",
        "temp.dat",
        "cache.bin",
        "log.txt"
    )
    
    foreach ($file in $stealthFiles) {
        $filePath = Join-Path $env:TEMP $file
        Write-Host "   Creating: $filePath" -ForegroundColor Cyan
        New-Item -Path $filePath -ItemType File -Force | Out-Null
        Start-Sleep -Milliseconds 200
    }
    
    # 2. Subtle network activity
    Write-Host "🌐 Testing Stealth Network Activity..." -ForegroundColor Yellow
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "ping -n 1 8.8.8.8" -WindowStyle Hidden
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "ping -n 1 1.1.1.1" -WindowStyle Hidden
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "nslookup google.com" -WindowStyle Hidden
    
    # 3. Registry operations
    Write-Host "🔧 Testing Registry Operations..." -ForegroundColor Yellow
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "reg query HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion" -WindowStyle Hidden
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "reg query HKEY_CURRENT_USER\Software" -WindowStyle Hidden
}

if (-not $Aggressive -and -not $Stealth -and -not $All) {
    Write-Host "🎯 QUICK ATTACK TEST" -ForegroundColor Green
    Write-Host "====================" -ForegroundColor Green
    
    # Quick test with most likely to trigger attacks
    Write-Host "🔐 Quick Failed Login Test..." -ForegroundColor Yellow
    for ($i = 1; $i -le 5; $i++) {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "net user testuser$($i) wrongpass" -WindowStyle Hidden
        Start-Sleep -Milliseconds 300
    }
    
    Write-Host "🦠 Quick PowerShell Test..." -ForegroundColor Yellow
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "powershell.exe -enc SGVsbG8gV29ybGQ=" -WindowStyle Hidden
    
    Write-Host "📁 Quick File Test..." -ForegroundColor Yellow
    New-Item -Path "$env:TEMP\test_malware.exe" -ItemType File -Force | Out-Null
    
    Write-Host "🌐 Quick Network Test..." -ForegroundColor Yellow
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "netstat -an" -WindowStyle Hidden
}

Write-Host ""
Write-Host "✅ Attack testing completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Check your SIEM for detections:" -ForegroundColor Cyan
Write-Host "   - Monitor: .\siem_monitor_simple.ps1" -ForegroundColor White
Write-Host "   - Dashboard: http://localhost:3000" -ForegroundColor White
Write-Host "   - Database: http://localhost:8123" -ForegroundColor White
Write-Host ""
Write-Host "💡 Expected detections:" -ForegroundColor Yellow
Write-Host "   - Failed login attempts (Event ID 4625)" -ForegroundColor White
Write-Host "   - PowerShell encoded commands" -ForegroundColor White
Write-Host "   - Suspicious file creation" -ForegroundColor White
Write-Host "   - Network reconnaissance" -ForegroundColor White
Write-Host "   - Process enumeration" -ForegroundColor White
Write-Host ""
Write-Host "🎯 If no detections, the Rust engine may not be running!" -ForegroundColor Red 