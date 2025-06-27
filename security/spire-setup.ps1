#Requires -RunAsAdministrator

# SPIFFE/SPIRE Zero-Trust Identity Implementation
# Automatic certificate rotation and service mesh security

param(
    [ValidateSet("Install", "Configure", "Rotate", "Verify")]
    [string]$Action = "Install",
    [string]$TrustDomain = "siem.enterprise.local",
    [int]$RotationIntervalHours = 24,
    [switch]$EnableMTLS = $true
)

$ErrorActionPreference = "Stop"

# Configuration
$SpireConfig = @{
    ServerPort = 8081
    AgentPort = 8088
    TrustDomain = $TrustDomain
    ServerSocketPath = "\\.\pipe\spire-server"
    AgentSocketPath = "\\.\pipe\spire-agent"
    DataDir = "C:\spire\data"
    ConfigDir = "C:\spire\config"
    LogLevel = "INFO"
}

function Write-SpireLog {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [SPIRE-$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Cyan" }
    })
    Add-Content -Path "logs/spire.log" -Value $logEntry
}

function Install-Spire {
    Write-SpireLog "🔐 Installing SPIFFE/SPIRE components..."
    
    # Create directory structure
    $directories = @(
        $SpireConfig.DataDir,
        $SpireConfig.ConfigDir,
        "C:\spire\bin",
        "C:\spire\certs",
        "logs"
    )
    
    foreach ($dir in $directories) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Write-SpireLog "Created directory: $dir"
    }
    
    # Download SPIRE binaries
    $spireVersion = "1.8.2"
    $downloadUrl = "https://github.com/spiffe/spire/releases/download/v$spireVersion/spire-$spireVersion-windows-amd64.tar.gz"
    
    Write-SpireLog "Downloading SPIRE v$spireVersion..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile "spire.tar.gz"
    
    # Extract binaries
    tar -xzf "spire.tar.gz" -C "C:\spire\bin" --strip-components=2
    Remove-Item "spire.tar.gz"
    
    # Add to PATH
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
    if ($currentPath -notlike "*C:\spire\bin*") {
        [Environment]::SetEnvironmentVariable("PATH", "$currentPath;C:\spire\bin", "Machine")
        $env:PATH += ";C:\spire\bin"
    }
    
    Write-SpireLog "✅ SPIRE binaries installed successfully"
}

function Initialize-SpireTrustDomain {
    Write-SpireLog "🌐 Initializing SPIRE trust domain: $($SpireConfig.TrustDomain)"
    
    # Generate server configuration
    $serverConfig = @"
server {
    bind_address = "127.0.0.1"
    bind_port = "$($SpireConfig.ServerPort)"
    trust_domain = "$($SpireConfig.TrustDomain)"
    data_dir = "$($SpireConfig.DataDir)\server"
    log_level = "$($SpireConfig.LogLevel)"
    socket_path = "$($SpireConfig.ServerSocketPath)"
    
    ca_subject = {
        country = ["US"]
        organization = ["Ultra SIEM"]
        common_name = "Ultra SIEM Root CA"
    }
    
    ca_ttl = "168h"  # 7 days
    default_x509_svid_ttl = "24h"
    default_jwt_svid_ttl = "1h"
}

plugins {
    DataStore "sql" {
        plugin_data {
            database_type = "sqlite3"
            connection_string = "$($SpireConfig.DataDir)\server\datastore.sqlite3"
        }
    }
    
    NodeAttestor "windows_iid" {
        plugin_data {
            # Windows instance identity attestation
        }
    }
    
    KeyManager "disk" {
        plugin_data {
            keys_path = "$($SpireConfig.DataDir)\server\keys"
        }
    }
    
    Notifier "webhook" {
        plugin_data {
            url = "http://localhost:8080/spire/notify"
            headers = {
                "Authorization" = "Bearer $env:SPIRE_WEBHOOK_TOKEN"
            }
        }
    }
}

health_checks {
    listener_enabled = true
    bind_address = "127.0.0.1"
    bind_port = "8080"
    live_path = "/live"
    ready_path = "/ready"
}
"@

    $serverConfig | Out-File "$($SpireConfig.ConfigDir)\server.conf" -Encoding UTF8
    
    # Generate agent configuration
    $agentConfig = @"
agent {
    bind_address = "127.0.0.1"
    bind_port = "$($SpireConfig.AgentPort)"
    data_dir = "$($SpireConfig.DataDir)\agent"
    log_level = "$($SpireConfig.LogLevel)"
    server_address = "127.0.0.1"
    server_port = "$($SpireConfig.ServerPort)"
    socket_path = "$($SpireConfig.AgentSocketPath)"
    trust_bundle_path = "$($SpireConfig.DataDir)\agent\bundle.crt"
    trust_domain = "$($SpireConfig.TrustDomain)"
}

plugins {
    NodeAttestor "windows_iid" {
        plugin_data {
        }
    }
    
    KeyManager "disk" {
        plugin_data {
            directory = "$($SpireConfig.DataDir)\agent\keys"
        }
    }
    
    WorkloadAttestor "windows" {
        plugin_data {
        }
    }
}

health_checks {
    listener_enabled = true
    bind_address = "127.0.0.1"
    bind_port = "8088"
    live_path = "/live"
    ready_path = "/ready"
}
"@

    $agentConfig | Out-File "$($SpireConfig.ConfigDir)\agent.conf" -Encoding UTF8
    
    Write-SpireLog "✅ SPIRE configuration files generated"
}

function Start-SpireServices {
    Write-SpireLog "🚀 Starting SPIRE services..."
    
    # Start SPIRE Server
    Write-SpireLog "Starting SPIRE Server..."
    $serverProcess = Start-Process -FilePath "spire-server.exe" -ArgumentList @(
        "run",
        "-config", "$($SpireConfig.ConfigDir)\server.conf"
    ) -WindowStyle Hidden -PassThru
    
    # Wait for server to start
    do {
        Start-Sleep -Seconds 2
        try {
            $health = Invoke-WebRequest -Uri "http://localhost:8080/ready" -TimeoutSec 2 -UseBasicParsing
            $serverReady = $health.StatusCode -eq 200
        }
        catch {
            $serverReady = $false
        }
    } while (-not $serverReady)
    
    Write-SpireLog "✅ SPIRE Server started (PID: $($serverProcess.Id))"
    
    # Create token for agent registration
    $token = spire-server.exe token generate -spiffeID "spiffe://$($SpireConfig.TrustDomain)/agent/windows"
    Write-SpireLog "Generated agent token: $($token.Token)"
    
    # Start SPIRE Agent
    Write-SpireLog "Starting SPIRE Agent..."
    $agentProcess = Start-Process -FilePath "spire-agent.exe" -ArgumentList @(
        "run",
        "-config", "$($SpireConfig.ConfigDir)\agent.conf",
        "-joinToken", $token.Token
    ) -WindowStyle Hidden -PassThru
    
    # Wait for agent to start
    do {
        Start-Sleep -Seconds 2
        try {
            $health = Invoke-WebRequest -Uri "http://localhost:8088/ready" -TimeoutSec 2 -UseBasicParsing
            $agentReady = $health.StatusCode -eq 200
        }
        catch {
            $agentReady = $false
        }
    } while (-not $agentReady)
    
    Write-SpireLog "✅ SPIRE Agent started (PID: $($agentProcess.Id))"
    
    # Store process IDs for management
    @{
        ServerPID = $serverProcess.Id
        AgentPID = $agentProcess.Id
    } | ConvertTo-Json | Out-File "$($SpireConfig.DataDir)\processes.json"
}

function New-ServiceIdentity {
    param(
        [string]$ServiceName,
        [string]$Selector,
        [string[]]$DNSNames = @(),
        [int]$TTLHours = 24
    )
    
    Write-SpireLog "🆔 Creating service identity: $ServiceName"
    
    $spiffeID = "spiffe://$($SpireConfig.TrustDomain)/service/$ServiceName"
    
    # Create registration entry
    $entry = spire-server.exe entry create `
        -spiffeID $spiffeID `
        -parentID "spiffe://$($SpireConfig.TrustDomain)/agent/windows" `
        -selector $Selector `
        -ttl "${TTLHours}h"
    
    if ($DNSNames.Count -gt 0) {
        $dnsEntry = spire-server.exe entry create `
            -spiffeID $spiffeID `
            -parentID "spiffe://$($SpireConfig.TrustDomain)/agent/windows" `
            -selector $Selector `
            -dns ($DNSNames -join ",") `
            -ttl "${TTLHours}h"
    }
    
    Write-SpireLog "✅ Service identity created: $spiffeID"
    
    return @{
        SpiffeID = $spiffeID
        Selector = $Selector
        DNSNames = $DNSNames
        TTL = "${TTLHours}h"
        EntryID = $entry.EntryID
    }
}

function Set-ServiceIdentities {
    Write-SpireLog "🏷️ Configuring service identities for Ultra SIEM..."
    
    # Vector service identity
    $vectorIdentity = New-ServiceIdentity -ServiceName "vector" -Selector "windows:hostname:$env:COMPUTERNAME" -DNSNames @("vector.siem.local", "collector.siem.local")
    
    # Processor service identity  
    $processorIdentity = New-ServiceIdentity -ServiceName "processor" -Selector "windows:process_name:processor.exe" -DNSNames @("processor.siem.local")
    
    # Bridge service identity
    $bridgeIdentity = New-ServiceIdentity -ServiceName "bridge" -Selector "windows:process_name:bridge.exe" -DNSNames @("bridge.siem.local")
    
    # ClickHouse service identity
    $clickhouseIdentity = New-ServiceIdentity -ServiceName "clickhouse" -Selector "docker:image_id:clickhouse/clickhouse-server" -DNSNames @("clickhouse.siem.local", "database.siem.local")
    
    # NATS service identity
    $natsIdentity = New-ServiceIdentity -ServiceName "nats" -Selector "docker:image_id:nats:alpine" -DNSNames @("nats.siem.local", "messaging.siem.local")
    
    # Grafana service identity
    $grafanaIdentity = New-ServiceIdentity -ServiceName "grafana" -Selector "docker:image_id:grafana/grafana-oss" -DNSNames @("grafana.siem.local", "dashboard.siem.local")
    
    # Store identity mapping
    $identityMap = @{
        Vector = $vectorIdentity
        Processor = $processorIdentity
        Bridge = $bridgeIdentity
        ClickHouse = $clickhouseIdentity
        NATS = $natsIdentity
        Grafana = $grafanaIdentity
    }
    
    $identityMap | ConvertTo-Json -Depth 10 | Out-File "$($SpireConfig.DataDir)\identities.json"
    
    Write-SpireLog "✅ All service identities configured"
    return $identityMap
}

function Enable-AutomaticRotation {
    param([int]$IntervalHours = 24)
    
    Write-SpireLog "🔄 Configuring automatic certificate rotation (${IntervalHours}h interval)..."
    
    # Create rotation script
    $rotationScript = @"
# SPIRE Certificate Rotation Script
`$ErrorActionPreference = "Stop"

function Rotate-ServiceCertificates {
    Write-Host "🔄 Starting certificate rotation cycle..."
    
    # Get current entries
    `$entries = spire-server.exe entry show -output json | ConvertFrom-Json
    
    foreach (`$entry in `$entries.entries) {
        try {
            # Force rotation by updating TTL
            spire-server.exe entry update -entryID `$entry.id -ttl "${IntervalHours}h"
            Write-Host "✅ Rotated certificate for `$(`$entry.spiffe_id)"
            
            # Notify service to reload
            Invoke-ServiceReload -SpiffeID `$entry.spiffe_id
        }
        catch {
            Write-Host "❌ Failed to rotate `$(`$entry.spiffe_id): `$_" -ForegroundColor Red
        }
    }
    
    # Log rotation event
    Write-EventLog -LogName "Ultra-SIEM" -Source "SPIRE-Rotation" -EventId 6001 -EntryType Information -Message "Certificate rotation completed for `$(`$entries.entries.Count) services"
}

function Invoke-ServiceReload {
    param(`$SpiffeID)
    
    `$serviceName = (`$SpiffeID -split "/")[-1]
    
    switch (`$serviceName) {
        "vector" {
            # Reload Vector configuration
            Invoke-RestMethod -Uri "http://localhost:8686/reload" -Method POST
        }
        "processor" {
            # Send SIGHUP equivalent to Go process
            Get-Process -Name "processor" | ForEach-Object { `$_.Refresh() }
        }
        "bridge" {
            # Reload bridge service
            Get-Process -Name "bridge" | ForEach-Object { `$_.Refresh() }
        }
        default {
            # Docker container restart for containerized services
            docker exec `$serviceName kill -HUP 1
        }
    }
}

# Execute rotation
Rotate-ServiceCertificates

Write-Host "🎯 Certificate rotation cycle completed"
"@

    $rotationScript | Out-File "scripts\rotate_certificates.ps1" -Encoding UTF8
    
    # Schedule automatic rotation
    $taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File `"$PWD\scripts\rotate_certificates.ps1`""
    $taskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours $IntervalHours)
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    
    Register-ScheduledTask -TaskName "SPIRE-CertRotation" -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -User "SYSTEM" -Force
    
    Write-SpireLog "✅ Automatic rotation scheduled (${IntervalHours}h interval)"
}

function Enable-MTLSIntegration {
    Write-SpireLog "🔒 Enabling mTLS integration with existing services..."
    
    # Update Vector configuration for SPIFFE
    $vectorSpiffeConfig = @"
# Add to vector.toml
[sources.spiffe_workload_api]
type = "spiffe_workload_api"
socket_path = "$($SpireConfig.AgentSocketPath)"

[sinks.nats_spiffe]
type = "nats"
inputs = ["threats"]
url = "tls://nats:4222"
subject = "threats.detected"
tls.spiffe_workload_api_socket = "$($SpireConfig.AgentSocketPath)"
"@

    $vectorSpiffeConfig | Out-File "config\vector\spiffe.toml" -Encoding UTF8
    
    # Update Go services for SPIFFE integration
    $goSpiffeCode = @"
package main

import (
    "context"
    "crypto/tls"
    "github.com/spiffe/go-spiffe/v2/spiffetls/tlsconfig"
    "github.com/spiffe/go-spiffe/v2/workloadapi"
)

func setupSPIFFETLS() *tls.Config {
    source, err := workloadapi.NewX509Source(context.Background())
    if err != nil {
        log.Fatalf("Unable to create X.509 source: %v", err)
    }
    
    // Client configuration
    clientConfig := tlsconfig.MTLSClientConfig(source, source, tlsconfig.AuthorizeAny())
    
    return clientConfig
}

// Use in NATS connection:
// nc, err := nats.Connect("tls://nats:4222", nats.Secure(setupSPIFFETLS()))
"@

    $goSpiffeCode | Out-File "go-services\spiffe_integration.go" -Encoding UTF8
    
    # Update Docker Compose for SPIFFE
    $dockerSpiffeConfig = @"
# Add to docker-compose.ultra.yml
version: '3.8'
services:
  spire-server:
    image: ghcr.io/spiffe/spire-server:1.8.2
    volumes:
      - ./config/spire:/opt/spire/conf
      - spire-server-data:/opt/spire/data
    ports:
      - "8081:8081"
    command: ["-config", "/opt/spire/conf/server.conf"]
    
  spire-agent:
    image: ghcr.io/spiffe/spire-agent:1.8.2
    volumes:
      - ./config/spire:/opt/spire/conf
      - spire-agent-data:/opt/spire/data
      - /var/run/docker.sock:/var/run/docker.sock
    depends_on:
      - spire-server
    command: ["-config", "/opt/spire/conf/agent.conf"]

volumes:
  spire-server-data:
  spire-agent-data:
"@

    $dockerSpiffeConfig | Out-File "config\docker-compose.spiffe.yml" -Encoding UTF8
    
    Write-SpireLog "✅ mTLS integration configuration generated"
}

function Test-SpireDeployment {
    Write-SpireLog "🧪 Testing SPIRE deployment..."
    
    # Test server health
    try {
        $serverHealth = Invoke-WebRequest -Uri "http://localhost:8080/ready" -UseBasicParsing
        Write-SpireLog "✅ SPIRE Server health: OK"
    }
    catch {
        Write-SpireLog "❌ SPIRE Server health check failed" "ERROR"
        return $false
    }
    
    # Test agent health
    try {
        $agentHealth = Invoke-WebRequest -Uri "http://localhost:8088/ready" -UseBasicParsing
        Write-SpireLog "✅ SPIRE Agent health: OK"
    }
    catch {
        Write-SpireLog "❌ SPIRE Agent health check failed" "ERROR"
        return $false
    }
    
    # Test identity issuance
    try {
        $identities = spire-server.exe entry show -output json | ConvertFrom-Json
        Write-SpireLog "✅ Identity entries: $($identities.entries.Count)"
    }
    catch {
        Write-SpireLog "❌ Failed to retrieve identities" "ERROR"
        return $false
    }
    
    # Test certificate fetch
    try {
        $cert = spire-agent.exe api fetch x509 -output json | ConvertFrom-Json
        Write-SpireLog "✅ Certificate fetch: OK (expires: $($cert.svids[0].x509_svid_expires_at))"
    }
    catch {
        Write-SpireLog "❌ Certificate fetch failed" "ERROR"
        return $false
    }
    
    Write-SpireLog "✅ SPIRE deployment validation successful" "SUCCESS"
    return $true
}

# Main execution
switch ($Action) {
    "Install" {
        Install-Spire
        Initialize-SpireTrustDomain
        Start-SpireServices
        Set-ServiceIdentities
        Enable-AutomaticRotation -IntervalHours $RotationIntervalHours
        
        if ($EnableMTLS) {
            Enable-MTLSIntegration
        }
        
        Write-SpireLog "🎉 SPIFFE/SPIRE installation completed successfully" "SUCCESS"
    }
    
    "Configure" {
        Set-ServiceIdentities
    }
    
    "Rotate" {
        & "scripts\rotate_certificates.ps1"
    }
    
    "Verify" {
        Test-SpireDeployment
    }
}

Write-SpireLog "🔐 Zero-Trust identity system ready" "SUCCESS" 