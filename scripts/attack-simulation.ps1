# Ultra SIEM Attack Simulation Script
# This script generates various attack patterns to test threat detection

param(
    [string]$Target = "localhost",
    [int]$Duration = 60,
    [switch]$SQLInjection,
    [switch]$BruteForce,
    [switch]$DDoS,
    [switch]$XSS,
    [switch]$AllAttacks
)

Write-Host "🚨 Ultra SIEM Attack Simulation Starting..." -ForegroundColor Red
Write-Host "Target: $Target | Duration: $Duration seconds" -ForegroundColor Yellow

function Test-SQLInjection {
    Write-Host "🔴 Simulating SQL Injection Attacks..." -ForegroundColor Red
    
    $sqlPayloads = @(
        "' OR '1'='1",
        "' UNION SELECT * FROM users--",
        "'; DROP TABLE users;--",
        "' OR 1=1#",
        "admin'--",
        "' OR 'x'='x",
        "1' AND 1=1--",
        "' UNION ALL SELECT @@version--"
    )
    
    foreach ($payload in $sqlPayloads) {
        try {
            $encodedPayload = [System.Web.HttpUtility]::UrlEncode($payload)
            $url = "http://$Target:8123/?query=SELECT * FROM system.tables WHERE name='$encodedPayload'"
            Invoke-WebRequest -Uri $url -TimeoutSec 5 -ErrorAction SilentlyContinue
            Write-Host "  ⚡ SQL Injection attempt: $payload" -ForegroundColor Magenta
            Start-Sleep -Milliseconds 500
        } catch {
            # Expected to fail - we're testing detection, not exploitation
        }
    }
}

function Test-BruteForce {
    Write-Host "🔴 Simulating Brute Force Attacks..." -ForegroundColor Red
    
    $usernames = @("admin", "root", "user", "test", "guest", "administrator")
    $passwords = @("password", "123456", "admin", "root", "test", "guest")
    
    foreach ($username in $usernames) {
        foreach ($password in $passwords) {
            try {
                $url = "http://$username`:$password@$Target:8123/ping"
                Invoke-WebRequest -Uri $url -TimeoutSec 2 -ErrorAction SilentlyContinue
                Write-Host "  ⚡ Brute force attempt: $username/$password" -ForegroundColor Magenta
                Start-Sleep -Milliseconds 200
            } catch {
                # Expected to fail - we're testing detection
            }
        }
    }
}

function Test-DDoS {
    Write-Host "🔴 Simulating DDoS Attack..." -ForegroundColor Red
    
    $jobs = @()
    for ($i = 1; $i -le 20; $i++) {
        $jobs += Start-Job -ScriptBlock {
            param($target)
            for ($j = 1; $j -le 100; $j++) {
                try {
                    Invoke-WebRequest -Uri "http://$target:8123/ping" -TimeoutSec 1 -ErrorAction SilentlyContinue
                } catch {}
                Start-Sleep -Milliseconds 50
            }
        } -ArgumentList $Target
    }
    
    Write-Host "  ⚡ Launching 20 concurrent attack threads..." -ForegroundColor Magenta
    $jobs | Wait-Job -Timeout 30 | Remove-Job
}

function Test-XSS {
    Write-Host "🔴 Simulating XSS Attacks..." -ForegroundColor Red
    
    $xssPayloads = @(
        "<script>alert('XSS')</script>",
        "<img src=x onerror=alert('XSS')>",
        "javascript:alert('XSS')",
        "<svg onload=alert('XSS')>",
        "';alert('XSS');//"
    )
    
    foreach ($payload in $xssPayloads) {
        try {
            $encodedPayload = [System.Web.HttpUtility]::UrlEncode($payload)
            $url = "http://$Target:3000/api/search?q=$encodedPayload"
            Invoke-WebRequest -Uri $url -TimeoutSec 5 -ErrorAction SilentlyContinue
            Write-Host "  ⚡ XSS attempt: $payload" -ForegroundColor Magenta
            Start-Sleep -Milliseconds 300
        } catch {
            # Expected to fail - we're testing detection
        }
    }
}

function Test-PortScanning {
    Write-Host "🔴 Simulating Port Scanning..." -ForegroundColor Red
    
    $ports = @(21, 22, 23, 25, 53, 80, 110, 143, 443, 993, 995, 1433, 3306, 3389, 5432, 8080, 8443)
    
    foreach ($port in $ports) {
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $tcpClient.ConnectAsync($Target, $port).Wait(100)
            $tcpClient.Close()
            Write-Host "  ⚡ Port scan: $port" -ForegroundColor Magenta
        } catch {
            # Expected to fail - we're testing detection
        }
        Start-Sleep -Milliseconds 100
    }
}

# Add System.Web for URL encoding
Add-Type -AssemblyName System.Web

# Execute selected attacks
if ($AllAttacks -or $SQLInjection) { Test-SQLInjection }
if ($AllAttacks -or $BruteForce) { Test-BruteForce }
if ($AllAttacks -or $DDoS) { Test-DDoS }
if ($AllAttacks -or $XSS) { Test-XSS }
if ($AllAttacks) { Test-PortScanning }

Write-Host "✅ Attack simulation completed!" -ForegroundColor Green
Write-Host "📊 Check Ultra SIEM dashboards for threat detection results" -ForegroundColor Cyan 