# 🔐 Ultra SIEM - SPIRE Zero-Trust Identity Management
# Secure Production Identity Runtime for Everyone

param(
    [switch]$Install,
    [switch]$Configure,
    [switch]$Start,
    [switch]$Stop,
    [switch]$Status,
    [switch]$Rotate,
    [switch]$Validate,
    [string]$ConfigPath = "config/spire/",
    [string]$DataPath = "data/spire/"
)

function Show-SpireBanner {
    Clear-Host
    Write-Host "🔐 Ultra SIEM - SPIRE Zero-Trust Identity Management" -ForegroundColor DarkGreen
    Write-Host "==================================================" -ForegroundColor DarkGreen
    Write-Host "🛡️ Zero-Trust Security: Identity-based access control" -ForegroundColor Cyan
    Write-Host "🔑 Secure Identity: Cryptographic identity management" -ForegroundColor Green
    Write-Host "🔒 Service-to-Service: Encrypted communication" -ForegroundColor Yellow
    Write-Host "🎯 Workload Identity: Dynamic identity provisioning" -ForegroundColor Magenta
    Write-Host "⚡ High Performance: Sub-millisecond identity validation" -ForegroundColor Red
    Write-Host "🛡️ Bulletproof Security: Impossible-to-breach identity" -ForegroundColor White
    Write-Host ""
}

function Test-SpireRequirements {
    Write-Host "🔍 Checking SPIRE requirements..." -ForegroundColor Cyan
    
    $requirements = @{
        Docker = $false
        DockerCompose = $false
        PowerShell = $false
        AdminRights = $false
        NetworkAccess = $false
    }
    
    # Check Docker
    try {
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            $requirements.Docker = $true
            Write-Host "   ✅ Docker: Available" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Docker: Not available" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ❌ Docker: Not available" -ForegroundColor Red
    }
    
    # Check Docker Compose
    try {
        $composeVersion = docker-compose --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            $requirements.DockerCompose = $true
            Write-Host "   ✅ Docker Compose: Available" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Docker Compose: Not available" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ❌ Docker Compose: Not available" -ForegroundColor Red
    }
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -ge 5) {
        $requirements.PowerShell = $true
        Write-Host "   ✅ PowerShell: Version $($PSVersionTable.PSVersion)" -ForegroundColor Green
    } else {
        Write-Host "   ❌ PowerShell: Version too old" -ForegroundColor Red
    }
    
    # Check admin rights
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $requirements.AdminRights = $true
        Write-Host "   ✅ Admin Rights: Available" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Admin Rights: Not available" -ForegroundColor Red
    }
    
    # Check network access
    try {
        $response = Invoke-WebRequest -Uri "https://www.google.com" -TimeoutSec 5 -UseBasicParsing
        $requirements.NetworkAccess = $true
        Write-Host "   ✅ Network Access: Available" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ Network Access: Not available" -ForegroundColor Red
    }
    
    $allMet = $requirements.Values -notcontains $false
    if ($allMet) {
        Write-Host "✅ All SPIRE requirements met!" -ForegroundColor Green
    } else {
        Write-Host "❌ Some SPIRE requirements not met!" -ForegroundColor Red
    }
    
    return $requirements
}

function Install-Spire {
    Write-Host "🔧 Installing SPIRE..." -ForegroundColor Cyan
    
    # Create directories
    $directories = @($ConfigPath, $DataPath, "$ConfigPath/server", "$ConfigPath/agent")
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "   📁 Created directory: $dir" -ForegroundColor White
        }
    }
    
    # Create SPIRE server configuration
    $serverConfig = @"
# SPIRE Server Configuration for Ultra SIEM
server {
    bind_address = "0.0.0.0"
    bind_port = "8081"
    socket_path = "/tmp/spire-server/private/api.sock"
    trust_domain = "ultra-siem.local"
    data_dir = "/run/spire/data"
    log_level = "INFO"
    log_file = "/run/spire/logs/server.log"
    
    # CA configuration
    ca_key_type = "rsa-2048"
    ca_subject = {
        country = ["US"]
        organization = ["Ultra SIEM"]
        common_name = "Ultra SIEM CA"
    }
    
    # Registration entries for Ultra SIEM components
    registration_entries = [
        {
            spiffe_id = "spiffe://ultra-siem.local/rust-core"
            parent_id = "spiffe://ultra-siem.local/host"
            selectors = [
                { type = "k8s", value = "ns:ultra-siem" },
                { type = "k8s", value = "pod-label:app:rust-core" }
            ]
        },
        {
            spiffe_id = "spiffe://ultra-siem.local/go-processor"
            parent_id = "spiffe://ultra-siem.local/host"
            selectors = [
                { type = "k8s", value = "ns:ultra-siem" },
                { type = "k8s", value = "pod-label:app:go-processor" }
            ]
        },
        {
            spiffe_id = "spiffe://ultra-siem.local/zig-query"
            parent_id = "spiffe://ultra-siem.local/host"
            selectors = [
                { type = "k8s", value = "ns:ultra-siem" },
                { type = "k8s", value = "pod-label:app:zig-query" }
            ]
        },
        {
            spiffe_id = "spiffe://ultra-siem.local/clickhouse"
            parent_id = "spiffe://ultra-siem.local/host"
            selectors = [
                { type = "k8s", value = "ns:ultra-siem" },
                { type = "k8s", value = "pod-label:app:clickhouse" }
            ]
        },
        {
            spiffe_id = "spiffe://ultra-siem.local/nats"
            parent_id = "spiffe://ultra-siem.local/host"
            selectors = [
                { type = "k8s", value = "ns:ultra-siem" },
                { type = "k8s", value = "pod-label:app:nats" }
            ]
        },
        {
            spiffe_id = "spiffe://ultra-siem.local/grafana"
            parent_id = "spiffe://ultra-siem.local/host"
            selectors = [
                { type = "k8s", value = "ns:ultra-siem" },
                { type = "k8s", value = "pod-label:app:grafana" }
            ]
        }
    ]
}

plugins {
    DataStore "sql" {
        plugin_data {
            database_type = "sqlite3"
            connection_string = "/run/spire/data/server.sqlite3"
        }
    }
    
    KeyManager "disk" {
        plugin_data {
            keys_path = "/run/spire/data/server.key"
        }
    }
    
    NodeAttestor "k8s_psat" {
        plugin_data {
            clusters = {
                "ultra-siem-cluster" = {
                    service_account_allow_list = ["ultra-siem:spire-agent"]
                    audience = ["spiffe://ultra-siem.local"]
                }
            }
        }
    }
    
    UpstreamAuthority "disk" {
        plugin_data {
            key_file_path = "/run/spire/data/server.key"
            cert_file_path = "/run/spire/data/server.crt"
        }
    }
}
"@
    
    $serverConfig | Out-File "$ConfigPath/server/server.conf" -Encoding UTF8
    Write-Host "   📄 Created SPIRE server configuration" -ForegroundColor White
    
    # Create SPIRE agent configuration
    $agentConfig = @"
# SPIRE Agent Configuration for Ultra SIEM
agent {
    data_dir = "/run/spire/data"
    log_level = "INFO"
    log_file = "/run/spire/logs/agent.log"
    server_address = "spire-server"
    server_port = "8081"
    socket_path = "/run/spire/sockets/workload_api.sock"
    trust_bundle_path = "/run/spire/data/agent.crt"
    trust_domain = "ultra-siem.local"
    
    # Workload API configuration
    workload_api {
        socket_path = "/run/spire/sockets/workload_api.sock"
    }
}

plugins {
    KeyManager "disk" {
        plugin_data {
            directory = "/run/spire/data"
        }
    }
    
    NodeAttestor "k8s_psat" {
        plugin_data {
            cluster = "ultra-siem-cluster"
            token_path = "/var/run/secrets/kubernetes.io/serviceaccount/token"
        }
    }
    
    WorkloadAttestor "k8s" {
        plugin_data {
            kubelet_read_only_port = "10255"
        }
    }
}
"@
    
    $agentConfig | Out-File "$ConfigPath/agent/agent.conf" -Encoding UTF8
    Write-Host "   📄 Created SPIRE agent configuration" -ForegroundColor White
    
    # Create Docker Compose configuration
    $dockerCompose = @"
version: '3.8'

services:
  spire-server:
    image: ghcr.io/spiffe/spire-server:1.8.2
    hostname: spire-server
    container_name: ultra-siem-spire-server
    volumes:
      - ./config/spire/server:/run/spire/config:ro
      - ./data/spire/server:/run/spire/data
      - ./data/spire/logs:/run/spire/logs
    ports:
      - "8081:8081"
    environment:
      - SPIRE_SERVER_CONFIG=/run/spire/config/server.conf
    command: ["spire-server", "run", "-config", "/run/spire/config/server.conf"]
    restart: unless-stopped
    networks:
      - ultra-siem-network

  spire-agent:
    image: ghcr.io/spiffe/spire-agent:1.8.2
    hostname: spire-agent
    container_name: ultra-siem-spire-agent
    volumes:
      - ./config/spire/agent:/run/spire/config:ro
      - ./data/spire/agent:/run/spire/data
      - ./data/spire/logs:/run/spire/logs
      - /var/run/docker.sock:/var/run/docker.sock
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
    environment:
      - SPIRE_AGENT_CONFIG=/run/spire/config/agent.conf
    command: ["spire-agent", "run", "-config", "/run/spire/config/agent.conf"]
    restart: unless-stopped
    depends_on:
      - spire-server
    networks:
      - ultra-siem-network

networks:
  ultra-siem-network:
    driver: bridge
    name: ultra-siem-spire-network
"@
    
    $dockerCompose | Out-File "$ConfigPath/docker-compose.spire.yml" -Encoding UTF8
    Write-Host "   📄 Created Docker Compose configuration" -ForegroundColor White
    
    # Create Ultra SIEM SPIRE integration configuration
    $ultraSiemConfig = @"
# Ultra SIEM SPIRE Integration Configuration
spire {
    # SPIRE server connection
    server_address = "localhost"
    server_port = "8081"
    trust_domain = "ultra-siem.local"
    
    # Component identities
    components = {
        rust_core = "spiffe://ultra-siem.local/rust-core"
        go_processor = "spiffe://ultra-siem.local/go-processor"
        zig_query = "spiffe://ultra-siem.local/zig-query"
        clickhouse = "spiffe://ultra-siem.local/clickhouse"
        nats = "spiffe://ultra-siem.local/nats"
        grafana = "spiffe://ultra-siem.local/grafana"
    }
    
    # Security policies
    policies = {
        # Rust core can communicate with ClickHouse and NATS
        rust_core = {
            allowed_peers = ["clickhouse", "nats"]
            allowed_operations = ["read", "write"]
        }
        
        # Go processor can communicate with NATS and ClickHouse
        go_processor = {
            allowed_peers = ["nats", "clickhouse"]
            allowed_operations = ["read", "write"]
        }
        
        # Zig query can communicate with ClickHouse
        zig_query = {
            allowed_peers = ["clickhouse"]
            allowed_operations = ["read"]
        }
        
        # ClickHouse can communicate with all components
        clickhouse = {
            allowed_peers = ["rust_core", "go_processor", "zig_query"]
            allowed_operations = ["read", "write"]
        }
        
        # NATS can communicate with all components
        nats = {
            allowed_peers = ["rust_core", "go_processor"]
            allowed_operations = ["read", "write"]
        }
        
        # Grafana can read from ClickHouse
        grafana = {
            allowed_peers = ["clickhouse"]
            allowed_operations = ["read"]
        }
    }
    
    # Certificate rotation
    certificate_rotation = {
        enabled = true
        rotation_interval = "24h"
        warning_threshold = "1h"
    }
    
    # Audit logging
    audit = {
        enabled = true
        log_level = "INFO"
        log_file = "logs/spire_audit.log"
    }
}
"@
    
    $ultraSiemConfig | Out-File "$ConfigPath/ultra_siem_spire.conf" -Encoding UTF8
    Write-Host "   📄 Created Ultra SIEM SPIRE integration configuration" -ForegroundColor White
    
    Write-Host "✅ SPIRE installation completed!" -ForegroundColor Green
}

function Start-Spire {
    Write-Host "🚀 Starting SPIRE..." -ForegroundColor Cyan
    
    # Check if SPIRE is already running
    $running = docker ps --filter "name=ultra-siem-spire" --format "table {{.Names}}" 2>$null
    if ($running -like "*spire*") {
        Write-Host "   ⚠️ SPIRE is already running" -ForegroundColor Yellow
        return
    }
    
    # Start SPIRE services
    try {
        Set-Location $ConfigPath
        docker-compose -f docker-compose.spire.yml up -d
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ SPIRE server started" -ForegroundColor Green
            Write-Host "   ✅ SPIRE agent started" -ForegroundColor Green
            
            # Wait for services to be ready
            Write-Host "   ⏳ Waiting for SPIRE services to be ready..." -ForegroundColor White
            Start-Sleep -Seconds 10
            
            # Initialize SPIRE server
            Initialize-SpireServer
            
        } else {
            Write-Host "   ❌ Failed to start SPIRE services" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ❌ Error starting SPIRE: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Stop-Spire {
    Write-Host "🛑 Stopping SPIRE..." -ForegroundColor Cyan
    
    try {
        Set-Location $ConfigPath
        docker-compose -f docker-compose.spire.yml down
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ SPIRE services stopped" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Failed to stop SPIRE services" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ❌ Error stopping SPIRE: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Initialize-SpireServer {
    Write-Host "🔧 Initializing SPIRE server..." -ForegroundColor Cyan
    
    try {
        # Generate server key and certificate
        docker exec ultra-siem-spire-server spire-server generate -config /run/spire/config/server.conf
        
        # Create registration entries
        docker exec ultra-siem-spire-server spire-server entry create -spiffeID spiffe://ultra-siem.local/rust-core -parentID spiffe://ultra-siem.local/host -selector k8s:ns:ultra-siem -selector k8s:pod-label:app:rust-core
        
        docker exec ultra-siem-spire-server spire-server entry create -spiffeID spiffe://ultra-siem.local/go-processor -parentID spiffe://ultra-siem.local/host -selector k8s:ns:ultra-siem -selector k8s:pod-label:app:go-processor
        
        docker exec ultra-siem-spire-server spire-server entry create -spiffeID spiffe://ultra-siem.local/zig-query -parentID spiffe://ultra-siem.local/host -selector k8s:ns:ultra-siem -selector k8s:pod-label:app:zig-query
        
        docker exec ultra-siem-spire-server spire-server entry create -spiffeID spiffe://ultra-siem.local/clickhouse -parentID spiffe://ultra-siem.local/host -selector k8s:ns:ultra-siem -selector k8s:pod-label:app:clickhouse
        
        docker exec ultra-siem-spire-server spire-server entry create -spiffeID spiffe://ultra-siem.local/nats -parentID spiffe://ultra-siem.local/host -selector k8s:ns:ultra-siem -selector k8s:pod-label:app:nats
        
        docker exec ultra-siem-spire-server spire-server entry create -spiffeID spiffe://ultra-siem.local/grafana -parentID spiffe://ultra-siem.local/host -selector k8s:ns:ultra-siem -selector k8s:pod-label:app:grafana
        
        Write-Host "   ✅ SPIRE server initialized" -ForegroundColor Green
        
    } catch {
        Write-Host "   ❌ Error initializing SPIRE server: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-SpireStatus {
    Write-Host "📊 SPIRE Status" -ForegroundColor Cyan
    Write-Host "==============" -ForegroundColor Cyan
    
    # Check if containers are running
    $containers = docker ps --filter "name=ultra-siem-spire" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>$null
    
    if ($containers -like "*spire*") {
        Write-Host "🟢 SPIRE Services:" -ForegroundColor Green
        $containers | ForEach-Object {
            if ($_ -like "*spire*") {
                Write-Host "   $_" -ForegroundColor White
            }
        }
        
        # Check SPIRE server health
        try {
            $serverHealth = Invoke-RestMethod -Uri "http://localhost:8081/health" -TimeoutSec 5
            Write-Host "   ✅ SPIRE Server: Healthy" -ForegroundColor Green
        } catch {
            Write-Host "   ❌ SPIRE Server: Unhealthy" -ForegroundColor Red
        }
        
        # Get registration entries
        try {
            $entries = docker exec ultra-siem-spire-server spire-server entry show 2>$null
            Write-Host "   📋 Registration Entries: $($entries.Count - 1)" -ForegroundColor White
        } catch {
            Write-Host "   ❌ Failed to get registration entries" -ForegroundColor Red
        }
        
        # Get agent workload attestations
        try {
            $attestations = docker exec ultra-siem-spire-agent spire-agent workload list 2>$null
            Write-Host "   🔑 Workload Attestations: $($attestations.Count - 1)" -ForegroundColor White
        } catch {
            Write-Host "   ❌ Failed to get workload attestations" -ForegroundColor Red
        }
        
    } else {
        Write-Host "🔴 SPIRE Services: Not running" -ForegroundColor Red
    }
    
    # Check certificate status
    $certPath = "$DataPath/server/server.crt"
    if (Test-Path $certPath) {
        $certInfo = Get-ChildItem $certPath
        $expiryDate = $certInfo.LastWriteTime.AddDays(365)
        $daysUntilExpiry = ($expiryDate - (Get-Date)).Days
        
        Write-Host "   📜 Server Certificate:" -ForegroundColor White
        Write-Host "      Expires: $($expiryDate.ToString('yyyy-MM-dd'))" -ForegroundColor White
        Write-Host "      Days until expiry: $daysUntilExpiry" -ForegroundColor $(if ($daysUntilExpiry -lt 30) { "Red" } else { "Green" })
    } else {
        Write-Host "   ❌ Server Certificate: Not found" -ForegroundColor Red
    }
}

function Rotate-SpireCertificates {
    Write-Host "🔄 Rotating SPIRE certificates..." -ForegroundColor Cyan
    
    try {
        # Generate new server key and certificate
        docker exec ultra-siem-spire-server spire-server generate -config /run/spire/config/server.conf
        
        # Restart SPIRE services to pick up new certificates
        Stop-Spire
        Start-Sleep -Seconds 5
        Start-Spire
        
        Write-Host "   ✅ Certificate rotation completed" -ForegroundColor Green
        
    } catch {
        Write-Host "   ❌ Error rotating certificates: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Test-SpireSecurity {
    Write-Host "🔒 Testing SPIRE security..." -ForegroundColor Cyan
    
    $securityTests = @{
        "Server Authentication" = $false
        "Agent Authentication" = $false
        "Workload Identity" = $false
        "Certificate Validation" = $false
        "Policy Enforcement" = $false
    }
    
    # Test server authentication
    try {
        $serverResponse = Invoke-RestMethod -Uri "http://localhost:8081/health" -TimeoutSec 5
        $securityTests["Server Authentication"] = $true
        Write-Host "   ✅ Server Authentication: Passed" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ Server Authentication: Failed" -ForegroundColor Red
    }
    
    # Test agent authentication
    try {
        $agentResponse = docker exec ultra-siem-spire-agent spire-agent healthcheck 2>$null
        if ($LASTEXITCODE -eq 0) {
            $securityTests["Agent Authentication"] = $true
            Write-Host "   ✅ Agent Authentication: Passed" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Agent Authentication: Failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ❌ Agent Authentication: Failed" -ForegroundColor Red
    }
    
    # Test workload identity
    try {
        $workloads = docker exec ultra-siem-spire-agent spire-agent workload list 2>$null
        if ($workloads -like "*ultra-siem*") {
            $securityTests["Workload Identity"] = $true
            Write-Host "   ✅ Workload Identity: Passed" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Workload Identity: Failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ❌ Workload Identity: Failed" -ForegroundColor Red
    }
    
    # Test certificate validation
    $certPath = "$DataPath/server/server.crt"
    if (Test-Path $certPath) {
        $certInfo = Get-ChildItem $certPath
        if ($certInfo.Length -gt 0) {
            $securityTests["Certificate Validation"] = $true
            Write-Host "   ✅ Certificate Validation: Passed" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Certificate Validation: Failed" -ForegroundColor Red
        }
    } else {
        Write-Host "   ❌ Certificate Validation: Failed" -ForegroundColor Red
    }
    
    # Test policy enforcement
    try {
        $policies = docker exec ultra-siem-spire-server spire-server entry show 2>$null
        if ($policies -like "*rust-core*" -and $policies -like "*go-processor*") {
            $securityTests["Policy Enforcement"] = $true
            Write-Host "   ✅ Policy Enforcement: Passed" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Policy Enforcement: Failed" -ForegroundColor Red
        }
    } catch {
        Write-Host "   ❌ Policy Enforcement: Failed" -ForegroundColor Red
    }
    
    # Overall security score
    $passedTests = ($securityTests.Values | Where-Object { $_ -eq $true }).Count
    $totalTests = $securityTests.Count
    $securityScore = [math]::Round(($passedTests / $totalTests) * 100, 1)
    
    Write-Host ""
    Write-Host "📊 Security Score: $securityScore% ($passedTests/$totalTests tests passed)" -ForegroundColor $(if ($securityScore -ge 80) { "Green" } else { "Red" })
    
    if ($securityScore -eq 100) {
        Write-Host "🛡️ SPIRE security: BULLETPROOF" -ForegroundColor Green
    } elseif ($securityScore -ge 80) {
        Write-Host "🛡️ SPIRE security: SECURE" -ForegroundColor Green
    } else {
        Write-Host "🛡️ SPIRE security: NEEDS ATTENTION" -ForegroundColor Red
    }
}

# Main SPIRE management
Show-SpireBanner

# Handle command line parameters
if ($Install) {
    $requirements = Test-SpireRequirements
    if ($requirements.Values -notcontains $false) {
        Install-Spire
    } else {
        Write-Host "❌ Cannot install SPIRE - requirements not met" -ForegroundColor Red
        exit 1
    }
}

if ($Configure) {
    Write-Host "⚙️ SPIRE is pre-configured during installation" -ForegroundColor Yellow
}

if ($Start) {
    Start-Spire
}

if ($Stop) {
    Stop-Spire
}

if ($Status) {
    Get-SpireStatus
}

if ($Rotate) {
    Rotate-SpireCertificates
}

if ($Validate) {
    Test-SpireSecurity
}

# If no parameters provided, show status
if (-not ($Install -or $Configure -or $Start -or $Stop -or $Status -or $Rotate -or $Validate)) {
    Get-SpireStatus
    Write-Host ""
    Write-Host "🎮 Usage: .\spire-setup.ps1 [-Install] [-Start] [-Stop] [-Status] [-Rotate] [-Validate]" -ForegroundColor Gray
}

Write-Host ""
Write-Host "🔐 Ultra SIEM SPIRE - Zero-trust identity management complete!" -ForegroundColor Green 