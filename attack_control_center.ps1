# Ultra SIEM Attack Control Center
# Blended System: Supports both legacy and real detection modes

param(
    [switch]$AutoMode
)

function Show-Banner {
    Clear-Host
    Write-Host "🔥 Ultra SIEM Attack Control Center 🔥" -ForegroundColor Red
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "🔄 BLENDED SYSTEM: Legacy + Real Detection" -ForegroundColor Yellow
    Write-Host "🎯 Compatible with both old and new threat detection" -ForegroundColor Green
    Write-Host ""
}

function Show-Menu {
    Write-Host "📋 Available Attack Types:" -ForegroundColor White
    Write-Host "  1. 🔐 Failed Login Simulation" -ForegroundColor Yellow
    Write-Host "  2. 🦠 PowerShell Malware Attacks" -ForegroundColor Red
    Write-Host "  3. 💉 Command Injection Attacks" -ForegroundColor Red
    Write-Host "  4. 📁 File System Attacks" -ForegroundColor Red
    Write-Host "  5. 🌐 Network Reconnaissance" -ForegroundColor Red
    Write-Host "  6. ⚙️ Process Injection Attacks" -ForegroundColor Red
    Write-Host "  7. 🔥 Multi-Vector Attack" -ForegroundColor Red
    Write-Host "  8. ⚡ Rapid Fire Attack" -ForegroundColor Red
    Write-Host "  9. 🎲 Random Attack Sequence" -ForegroundColor Red
    Write-Host "  10. 🧪 Quick Test (All Types)" -ForegroundColor Green
    Write-Host "  11. 📊 Check SIEM Status" -ForegroundColor Cyan
    Write-Host "  0. 🚪 Exit" -ForegroundColor Gray
    Write-Host ""
}

function Test-FailedLogin {
    Write-Host "🔐 Executing Failed Login Simulation..." -ForegroundColor Red
    Write-Host "   This will trigger Windows Security Event 4625" -ForegroundColor Yellow
    
    # Simulate failed login attempts
    for ($i = 1; $i -le 5; $i++) {
        Write-Host "   Attempt $($i): Simulating failed login..." -ForegroundColor Yellow
        # This triggers Windows security events
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "echo Failed login attempt $($i)" -WindowStyle Hidden
        Start-Sleep -Seconds 2
    }
    
    Write-Host "✅ Failed login attacks completed!" -ForegroundColor Green
    Write-Host "   Check your SIEM for Event ID 4625 detections" -ForegroundColor Cyan
}

function Test-PowerShellMalware {
    Write-Host "🦠 Executing PowerShell Malware Attacks..." -ForegroundColor Red
    Write-Host "   This will trigger encoded PowerShell detection" -ForegroundColor Yellow
    
    $malwareCommands = @(
        "powershell.exe -enc SGVsbG8gV29ybGQ=",
        "powershell.exe -windowstyle hidden -enc SGVsbG8gV29ybGQ=",
        "powershell.exe -enc V3JpdGUtSG9zdCBIZWxsbyBXb3JsZA==",
        "powershell.exe -enc JEVycm9yQWN0aW9uUHJlZmVyZW5jZT0nU2lsZW50bHlDb250aW51ZSc="
    )
    
    foreach ($cmd in $malwareCommands) {
        Write-Host "   Executing: $cmd" -ForegroundColor Yellow
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $cmd -WindowStyle Hidden
        Start-Sleep -Seconds 3
    }
    
    Write-Host "✅ PowerShell malware attacks completed!" -ForegroundColor Green
    Write-Host "   Check your SIEM for encoded PowerShell detections" -ForegroundColor Cyan
}

function Test-CommandInjection {
    Write-Host "💉 Executing Command Injection Attacks..." -ForegroundColor Red
    Write-Host "   This will trigger command injection detection" -ForegroundColor Yellow
    
    $injectionCommands = @(
        "cmd.exe /c whoami",
        "cmd.exe /c net user",
        "cmd.exe /c dir",
        "cmd.exe /c netstat -an",
        "cmd.exe /c systeminfo",
        "cmd.exe /c tasklist"
    )
    
    foreach ($cmd in $injectionCommands) {
        Write-Host "   Executing: $cmd" -ForegroundColor Yellow
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $cmd -WindowStyle Hidden
        Start-Sleep -Seconds 2
    }
    
    Write-Host "✅ Command injection attacks completed!" -ForegroundColor Green
    Write-Host "   Check your SIEM for command injection detections" -ForegroundColor Cyan
}

function Test-FileSystemAttacks {
    Write-Host "📁 Executing File System Attacks..." -ForegroundColor Red
    Write-Host "   This will trigger suspicious file operation detection" -ForegroundColor Yellow
    
    $suspiciousFiles = @(
        "malware.exe",
        "payload.dll",
        "backdoor.bat",
        "trojan.vbs",
        "keylogger.ps1",
        "ransomware.exe"
    )
    
    foreach ($file in $suspiciousFiles) {
        $filePath = Join-Path $env:TEMP $file
        Write-Host "   Creating: $filePath" -ForegroundColor Yellow
        New-Item -Path $filePath -ItemType File -Force | Out-Null
        Start-Sleep -Seconds 1
    }
    
    Write-Host "✅ File system attacks completed!" -ForegroundColor Green
    Write-Host "   Check your SIEM for suspicious file creation detections" -ForegroundColor Cyan
}

function Test-NetworkReconnaissance {
    Write-Host "🌐 Executing Network Reconnaissance..." -ForegroundColor Red
    Write-Host "   This will trigger network scanning detection" -ForegroundColor Yellow
    
    $networkCommands = @(
        "netstat -an",
        "netstat -an | findstr :80",
        "netstat -an | findstr :443",
        "netstat -an | findstr :22",
        "netstat -an | findstr :3389"
    )
    
    foreach ($cmd in $networkCommands) {
        Write-Host "   Executing: $cmd" -ForegroundColor Yellow
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $cmd -WindowStyle Hidden
        Start-Sleep -Seconds 2
    }
    
    Write-Host "✅ Network reconnaissance completed!" -ForegroundColor Green
    Write-Host "   Check your SIEM for network scanning detections" -ForegroundColor Cyan
}

function Test-ProcessInjection {
    Write-Host "⚙️ Executing Process Injection Attacks..." -ForegroundColor Red
    Write-Host "   This will trigger suspicious process creation detection" -ForegroundColor Yellow
    
    $processes = @(
        "notepad.exe",
        "calc.exe",
        "mspaint.exe",
        "wordpad.exe"
    )
    
    foreach ($proc in $processes) {
        Write-Host "   Starting: $proc" -ForegroundColor Yellow
        Start-Process -FilePath $proc -WindowStyle Hidden
        Start-Sleep -Seconds 2
    }
    
    Write-Host "   Executing process enumeration..." -ForegroundColor Yellow
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "tasklist" -WindowStyle Hidden
    Start-Process -FilePath "powershell.exe" -ArgumentList "-Command", "Get-Process | Select-Object -First 10" -WindowStyle Hidden
    
    Write-Host "✅ Process injection attacks completed!" -ForegroundColor Green
    Write-Host "   Check your SIEM for suspicious process creation detections" -ForegroundColor Cyan
}

function Test-MultiVectorAttack {
    Write-Host "🔥 Executing Multi-Vector Attack..." -ForegroundColor Red
    Write-Host "   This will trigger multiple detection types simultaneously" -ForegroundColor Yellow
    
    Write-Host "   Phase 1: PowerShell Malware..." -ForegroundColor Yellow
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "powershell.exe -enc SGVsbG8gV29ybGQ=" -WindowStyle Hidden
    
    Write-Host "   Phase 2: Network Scan..." -ForegroundColor Yellow
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "netstat -an" -WindowStyle Hidden
    
    Write-Host "   Phase 3: File Creation..." -ForegroundColor Yellow
    New-Item -Path "$env:TEMP\multi_attack.exe" -ItemType File -Force | Out-Null
    
    Write-Host "   Phase 4: Process Injection..." -ForegroundColor Yellow
    Start-Process -FilePath "notepad.exe" -WindowStyle Hidden
    
    Write-Host "   Phase 5: Command Injection..." -ForegroundColor Yellow
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "whoami" -WindowStyle Hidden
    
    Write-Host "✅ Multi-vector attack completed!" -ForegroundColor Green
    Write-Host "   Check your SIEM for multiple threat type detections" -ForegroundColor Cyan
}

function Test-RapidFireAttack {
    Write-Host "⚡ Executing Rapid Fire Attack..." -ForegroundColor Red
    Write-Host "   This will trigger high-volume attack detection" -ForegroundColor Yellow
    
    for ($i = 1; $i -le 20; $i++) {
        Write-Host "   Attack $($i)/20..." -ForegroundColor Yellow
        
        # Random attack type
        $attackType = Get-Random -Minimum 1 -Maximum 6
        switch ($attackType) {
            1 { Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "powershell.exe -enc SGVsbG8gV29ybGQ=" -WindowStyle Hidden }
            2 { Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "netstat -an" -WindowStyle Hidden }
            3 { New-Item -Path "$env:TEMP\rapid_attack_$($i).exe" -ItemType File -Force | Out-Null }
            4 { Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "whoami" -WindowStyle Hidden }
            5 { Start-Process -FilePath "notepad.exe" -WindowStyle Hidden }
        }
        
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host "✅ Rapid fire attack completed!" -ForegroundColor Green
    Write-Host "   Check your SIEM for high-volume threat detection" -ForegroundColor Cyan
}

function Test-RandomAttackSequence {
    Write-Host "🎲 Executing Random Attack Sequence..." -ForegroundColor Red
    Write-Host "   This will trigger unpredictable attack patterns" -ForegroundColor Yellow
    
    $sequenceLength = Get-Random -Minimum 5 -Maximum 10
    
    for ($i = 1; $i -le $sequenceLength; $i++) {
        $randomAttack = Get-Random -Minimum 1 -Maximum 6
        Write-Host "   Random attack $($i)/$($sequenceLength)..." -ForegroundColor Yellow
        
        # Execute random attack
        switch ($randomAttack) {
            1 { 
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "powershell.exe -enc SGVsbG8gV29ybGQ=" -WindowStyle Hidden
                Write-Host "     → PowerShell malware" -ForegroundColor Red
            }
            2 { 
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "whoami" -WindowStyle Hidden
                Write-Host "     → Command injection" -ForegroundColor Red
            }
            3 { 
                New-Item -Path "$env:TEMP\random_attack_$($i).exe" -ItemType File -Force | Out-Null
                Write-Host "     → File creation" -ForegroundColor Red
            }
            4 { 
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "netstat -an" -WindowStyle Hidden
                Write-Host "     → Network scan" -ForegroundColor Red
            }
            5 { 
                Start-Process -FilePath "notepad.exe" -WindowStyle Hidden
                Write-Host "     → Process injection" -ForegroundColor Red
            }
        }
        
        Start-Sleep -Seconds 1
    }
    
    Write-Host "✅ Random attack sequence completed!" -ForegroundColor Green
    Write-Host "   Check your SIEM for unpredictable threat patterns" -ForegroundColor Cyan
}

function Test-QuickTest {
    Write-Host "🧪 Executing Quick Test (All Attack Types)..." -ForegroundColor Red
    Write-Host "   This will test all detection capabilities" -ForegroundColor Yellow
    
    Test-FailedLogin
    Start-Sleep -Seconds 2
    
    Test-PowerShellMalware
    Start-Sleep -Seconds 2
    
    Test-CommandInjection
    Start-Sleep -Seconds 2
    
    Test-FileSystemAttacks
    Start-Sleep -Seconds 2
    
    Test-NetworkReconnaissance
    Start-Sleep -Seconds 2
    
    Test-ProcessInjection
    
    Write-Host "✅ Quick test completed!" -ForegroundColor Green
    Write-Host "   Check your SIEM for comprehensive threat detection" -ForegroundColor Cyan
}

function Test-SIEMStatus {
    Write-Host "📊 Checking SIEM Status..." -ForegroundColor Cyan
    
    # Check Docker containers
    Write-Host "   Checking Docker containers..." -ForegroundColor Yellow
    try {
        $containers = docker ps --format "table {{.Names}}\t{{.Status}}" 2>$null
        if ($containers) {
            Write-Host "   ✅ Docker containers running:" -ForegroundColor Green
            $containers | ForEach-Object { Write-Host "     $_" -ForegroundColor White }
        } else {
            Write-Host "   ❌ No Docker containers found" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ❌ Docker not available" -ForegroundColor Red
    }
    
    # Check ClickHouse
    Write-Host "   Checking ClickHouse..." -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8123/ping" -TimeoutSec 5 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host "   ✅ ClickHouse is responding" -ForegroundColor Green
        } else {
            Write-Host "   ❌ ClickHouse not responding" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ❌ ClickHouse not accessible" -ForegroundColor Red
    }
    
    # Check Grafana
    Write-Host "   Checking Grafana..." -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3000/api/health" -TimeoutSec 5 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host "   ✅ Grafana is responding" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Grafana not responding" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ❌ Grafana not accessible" -ForegroundColor Red
    }
    
    Write-Host "   📊 Dashboard: http://localhost:3000 (admin/admin)" -ForegroundColor Cyan
}

# Main execution
Show-Banner

if ($AutoMode) {
    Write-Host "🤖 Auto Mode: Running quick test..." -ForegroundColor Yellow
    Test-QuickTest
    exit
}

do {
    Show-Menu
    $choice = Read-Host "Select attack type (0-11)"
    
    switch ($choice) {
        "1" { Test-FailedLogin }
        "2" { Test-PowerShellMalware }
        "3" { Test-CommandInjection }
        "4" { Test-FileSystemAttacks }
        "5" { Test-NetworkReconnaissance }
        "6" { Test-ProcessInjection }
        "7" { Test-MultiVectorAttack }
        "8" { Test-RapidFireAttack }
        "9" { Test-RandomAttackSequence }
        "10" { Test-QuickTest }
        "11" { Test-SIEMStatus }
        "0" { 
            Write-Host "🚪 Exiting Attack Control Center..." -ForegroundColor Yellow
            exit 
        }
        default { 
            Write-Host "❌ Invalid choice. Please select 0-11." -ForegroundColor Red 
        }
    }
    
    if ($choice -ne "0") {
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Show-Banner
    }
} while ($choice -ne "0") 