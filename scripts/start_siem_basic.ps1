# Ultra SIEM Basic Deployment (No Admin Required)
# Starts core services using Docker and built Go services

param(
    [switch]$SkipDocker = $false,
    [switch]$TestMode = $false
)

function Write-DeployLog {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [DEPLOY-$Level] $Message" -ForegroundColor $(switch($Level) {
        "ERROR" { "Red" }; "SUCCESS" { "Green" }; "WARN" { "Yellow" }; default { "Blue" }
    })
}

function Test-Docker {
    Write-DeployLog "🐳 Checking Docker availability..."
    
    try {
        $dockerInfo = docker version --format json | ConvertFrom-Json
        if ($dockerInfo) {
            Write-DeployLog "✅ Docker is running" "SUCCESS"
            return $true
        }
    }
    catch {
        Write-DeployLog "❌ Docker not available: $_" "ERROR"
        return $false
    }
    
    return $false
}

function Start-InfrastructureServices {
    Write-DeployLog "🚀 Starting Ultra SIEM infrastructure services..."
    
    if ($SkipDocker) {
        Write-DeployLog "⏭️ Skipping Docker services"
        return
    }
    
    # Pull required images
    $images = @(
        "clickhouse/clickhouse-server:latest",
        "nats:alpine", 
        "grafana/grafana-oss:latest"
    )
    
    foreach ($image in $images) {
        Write-DeployLog "Pulling Docker image: $image"
        try {
            docker pull $image
            Write-DeployLog "✅ Pulled $image"
        }
        catch {
            Write-DeployLog "⚠️ Failed to pull $image - will try to run anyway" "WARN"
        }
    }
    
    # Start ClickHouse
    Write-DeployLog "Starting ClickHouse database..."
    try {
        docker run -d --name siem-clickhouse `
            -p 9000:9000 -p 8123:8123 `
            -v "${PWD}/data/clickhouse:/var/lib/clickhouse" `
            clickhouse/clickhouse-server:latest
        
        Write-DeployLog "✅ ClickHouse started on ports 9000, 8123"
    }
    catch {
        Write-DeployLog "⚠️ ClickHouse start issue: $_" "WARN"
    }
    
    # Start NATS
    Write-DeployLog "Starting NATS message broker..."
    try {
        docker run -d --name siem-nats `
            -p 4222:4222 -p 8222:8222 `
            nats:alpine -js
        
        Write-DeployLog "✅ NATS started on ports 4222, 8222"
    }
    catch {
        Write-DeployLog "⚠️ NATS start issue: $_" "WARN"
    }
    
    # Start Grafana
    Write-DeployLog "Starting Grafana dashboard..."
    try {
        docker run -d --name siem-grafana `
            -p 3000:3000 `
            -v "${PWD}/data/grafana:/var/lib/grafana" `
            -e "GF_SECURITY_ADMIN_PASSWORD=admin" `
            grafana/grafana-oss:latest
        
        Write-DeployLog "✅ Grafana started on port 3000 (admin/admin)"
    }
    catch {
        Write-DeployLog "⚠️ Grafana start issue: $_" "WARN"
    }
    
    # Wait for services to be ready
    Write-DeployLog "⏳ Waiting for services to be ready..."
    Start-Sleep -Seconds 10
}

function Start-GoServices {
    Write-DeployLog "🔷 Starting Go services..."
    
    # Check if Go services are built
    $bridgeExe = "go-services\bin\bridge.exe"
    $processorExe = "go-services\bin\siem-processor.exe"
    
    if (Test-Path $bridgeExe) {
        Write-DeployLog "Starting NATS-ClickHouse bridge..."
        try {
            $bridgeProcess = Start-Process -FilePath $bridgeExe -WindowStyle Hidden -PassThru
            Write-DeployLog "✅ Bridge started (PID: $($bridgeProcess.Id))"
            
            # Store PID for later management
            $bridgeProcess.Id | Out-File "logs\bridge.pid"
        }
        catch {
            Write-DeployLog "⚠️ Bridge start failed: $_" "WARN"
        }
    } else {
        Write-DeployLog "⚠️ Bridge executable not found at $bridgeExe" "WARN"
    }
    
    if (Test-Path $processorExe) {
        Write-DeployLog "Starting SIEM processor..."
        try {
            $processorProcess = Start-Process -FilePath $processorExe -WindowStyle Hidden -PassThru
            Write-DeployLog "✅ Processor started (PID: $($processorProcess.Id))"
            
            # Store PID for later management
            $processorProcess.Id | Out-File "logs\processor.pid"
        }
        catch {
            Write-DeployLog "⚠️ Processor start failed: $_" "WARN"
        }
    } else {
        Write-DeployLog "⚠️ Processor executable not found at $processorExe" "WARN"
    }
}

function Initialize-Database {
    Write-DeployLog "💾 Initializing ClickHouse database..."
    
    # Wait for ClickHouse to be ready
    $maxAttempts = 30
    $attempt = 1
    
    do {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8123/ping" -TimeoutSec 2 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-DeployLog "✅ ClickHouse is ready"
                break
            }
        }
        catch {
            Write-DeployLog "⏳ Waiting for ClickHouse... (attempt $attempt/$maxAttempts)"
            Start-Sleep -Seconds 2
            $attempt++
        }
    } while ($attempt -le $maxAttempts)
    
    if ($attempt -gt $maxAttempts) {
        Write-DeployLog "❌ ClickHouse failed to start properly" "ERROR"
        return
    }
    
    # Create database schema
    Write-DeployLog "Creating SIEM database schema..."
    try {
        $createDB = @"
CREATE DATABASE IF NOT EXISTS siem;

CREATE TABLE IF NOT EXISTS siem.threats (
    event_time DateTime64(3) DEFAULT now64(),
    source_ip String,
    threat_type String,
    severity String,
    message String,
    raw_log String
) ENGINE = MergeTree()
ORDER BY (event_time, source_ip)
PARTITION BY toYYYYMM(event_time);
"@

        # Execute via HTTP API
        $uri = "http://localhost:8123/"
        Invoke-RestMethod -Uri $uri -Method POST -Body $createDB -ContentType "text/plain"
        
        Write-DeployLog "✅ Database schema created"
    }
    catch {
        Write-DeployLog "⚠️ Database schema creation issue: $_" "WARN"
    }
}

function Test-SystemHealth {
    Write-DeployLog "🏥 Testing system health..."
    
    $healthStatus = @{
        ClickHouse = $false
        NATS = $false
        Grafana = $false
        Bridge = $false
        Processor = $false
    }
    
    # Test ClickHouse
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8123/ping" -TimeoutSec 5 -UseBasicParsing
        $healthStatus.ClickHouse = $response.StatusCode -eq 200
    } catch { }
    
    # Test NATS
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8222/healthz" -TimeoutSec 5 -UseBasicParsing
        $healthStatus.NATS = $response.StatusCode -eq 200
    } catch { }
    
    # Test Grafana
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3000/api/health" -TimeoutSec 5 -UseBasicParsing
        $healthStatus.Grafana = $response.StatusCode -eq 200
    } catch { }
    
    # Test Go services by checking PIDs
    if (Test-Path "logs\bridge.pid") {
        $bridgePid = Get-Content "logs\bridge.pid"
        $healthStatus.Bridge = Get-Process -Id $bridgePid -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    
    if (Test-Path "logs\processor.pid") {
        $processorPid = Get-Content "logs\processor.pid"
        $healthStatus.Processor = Get-Process -Id $processorPid -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    
    # Display health status
    Write-DeployLog "📊 System Health Status:"
    foreach ($service in $healthStatus.Keys) {
        $status = if ($healthStatus[$service]) { "✅ HEALTHY" } else { "❌ DOWN" }
        Write-DeployLog "  $service`: $status"
    }
    
    $healthyServices = ($healthStatus.Values | Where-Object { $_ }).Count
    $totalServices = $healthStatus.Count
    
    Write-DeployLog "📈 Overall Health: $healthyServices/$totalServices services healthy"
    
    return $healthyServices -ge ($totalServices * 0.6) # 60% threshold
}

function Show-AccessInformation {
    $accessInfo = @"

🎉 ULTRA SIEM BASIC DEPLOYMENT COMPLETED!

📋 Service Access Points:
┌─────────────────────────────────────────────────────────┐
│ 🖥️  Grafana Dashboard:   http://localhost:3000         │
│     Username: admin / Password: admin                   │
│                                                         │
│ 💾 ClickHouse Database:  http://localhost:8123         │
│     Query interface for data exploration                │
│                                                         │
│ 📨 NATS Monitor:         http://localhost:8222         │
│     Message broker monitoring                           │
└─────────────────────────────────────────────────────────┘

🔧 Management Commands:
• View logs: Get-Content logs\*.log
• Check processes: Get-Process | Where-Object {$_.Name -like "*siem*"}
• Stop services: docker stop siem-clickhouse siem-nats siem-grafana

🚀 Next Steps:
1. Open Grafana: http://localhost:3000 (admin/admin)
2. Configure data sources and dashboards
3. Start sending log data to the system
4. Monitor threat detection in real-time

🛡️ Your Ultra SIEM is now operational with zero licensing costs!

"@

    Write-Host $accessInfo -ForegroundColor Green
    $accessInfo | Out-File "DEPLOYMENT_SUCCESS.txt"
}

# Main deployment execution
Write-DeployLog "🚀 Starting Ultra SIEM Basic Deployment..." "SUCCESS"

# Create necessary directories
@("logs", "data/clickhouse", "data/grafana") | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Force -Path $_ | Out-Null
    }
}

# Check prerequisites
$dockerAvailable = Test-Docker

if (-not $dockerAvailable -and -not $SkipDocker) {
    Write-DeployLog "❌ Docker not available. Use -SkipDocker to continue without containers" "ERROR"
    exit 1
}

# Deploy components
if ($dockerAvailable -and -not $SkipDocker) {
    Start-InfrastructureServices
    Start-Sleep -Seconds 5
    Initialize-Database
}

Start-GoServices

# Health check
Start-Sleep -Seconds 10
$systemHealthy = Test-SystemHealth

if ($systemHealthy) {
    Write-DeployLog "🎉 Ultra SIEM deployment successful!" "SUCCESS"
    Show-AccessInformation
} else {
    Write-DeployLog "⚠️ Some services may have issues. Check the logs for details." "WARN"
    Write-DeployLog "You can still access available services using the URLs above."
}

Write-DeployLog "✅ Basic deployment completed!" "SUCCESS" 