Write-Host "🚀 Starting Ultra SIEM Services..." -ForegroundColor Cyan

# Check if Docker is running
try {
    docker info | Out-Null
    Write-Host "✅ Docker is running" -ForegroundColor Green
}
catch {
    Write-Host "❌ Docker is not running. Please start Docker Desktop." -ForegroundColor Red
    exit 1
}

# Start infrastructure services
Write-Host "🐳 Starting infrastructure containers..." -ForegroundColor Yellow
docker-compose -f docker-compose.ultra.yml up -d

# Wait for services to be ready
Write-Host "⏳ Waiting for services to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Check service health
$services = @(
    @{Name="NATS"; URL="http://localhost:8222/healthz"},
    @{Name="ClickHouse"; URL="http://localhost:8123/ping"},
    @{Name="Grafana"; URL="http://localhost:3000/api/health"}
)

foreach ($service in $services) {
    try {
        $response = Invoke-WebRequest -Uri $service.URL -TimeoutSec 5 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host "✅ $($service.Name) is healthy" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "⚠️  $($service.Name) is not responding" -ForegroundColor Orange
    }
}

# Start Rust collector if built
if (Test-Path "rust-core\target\release\siem-rust-core.exe") {
    Write-Host "🦀 Starting Rust threat collector..." -ForegroundColor Yellow
    Start-Process -FilePath "rust-core\target\release\siem-rust-core.exe" -WindowStyle Minimized
    Write-Host "✅ Rust collector started" -ForegroundColor Green
}
else {
    Write-Host "⚠️  Rust collector not found. Run setup_windows.ps1 first." -ForegroundColor Orange
}

# Start Go processor if built
if (Test-Path "go-services\processor.exe") {
    Write-Host "🐹 Starting Go event processor..." -ForegroundColor Yellow
    Start-Process -FilePath "go-services\processor.exe" -WindowStyle Minimized
    Write-Host "✅ Go processor started" -ForegroundColor Green
}
else {
    Write-Host "⚠️  Go processor not found. Run setup_windows.ps1 first." -ForegroundColor Orange
}

Write-Host "`n🎯 Service URLs:" -ForegroundColor Green
Write-Host "   Grafana Dashboard: http://localhost:3000 (admin/ultra_secure_grafana_2024)" -ForegroundColor Yellow
Write-Host "   NATS Monitor: http://localhost:8222" -ForegroundColor Yellow
Write-Host "   ClickHouse: http://localhost:8123" -ForegroundColor Yellow
Write-Host "   Vector API: http://localhost:8686" -ForegroundColor Yellow

Write-Host "`n✅ Ultra SIEM is now running!" -ForegroundColor Green 