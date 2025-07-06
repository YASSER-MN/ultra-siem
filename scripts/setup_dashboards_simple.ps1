# Ultra SIEM Dashboard Setup Script
Write-Host "Ultra SIEM Dashboard Setup" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

$GRAFANA_URL = "http://localhost:3000"
$GRAFANA_USER = "admin"
$GRAFANA_PASS = "admin"

# Create Basic Auth header
$pair = "$GRAFANA_USER`:$GRAFANA_PASS"
$encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
$basicAuthValue = "Basic $encodedCreds"

Write-Host "Waiting for services..." -ForegroundColor Yellow

# Wait for Grafana
do {
    try {
        $response = Invoke-RestMethod -Uri "$GRAFANA_URL/api/health" -Method GET -ErrorAction SilentlyContinue
        if ($response.database -eq "ok") {
            Write-Host "Grafana is ready" -ForegroundColor Green
            break
        }
    }
    catch {
        Write-Host "Waiting for Grafana..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
    }
} while ($true)

# Wait for ClickHouse
do {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8123/ping" -Method GET -ErrorAction SilentlyContinue
        if ($response -eq "Ok.") {
            Write-Host "ClickHouse is ready" -ForegroundColor Green
            break
        }
    }
    catch {
        Write-Host "Waiting for ClickHouse..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
    }
} while ($true)

Write-Host ""
Write-Host "Setting up ClickHouse datasource..." -ForegroundColor Cyan

# Create ClickHouse datasource JSON
$datasourceJson = @"
{
  "name": "ClickHouse-SIEM",
  "type": "grafana-clickhouse-datasource",
  "access": "proxy",
  "url": "http://clickhouse:8123",
  "database": "siem",
  "basicAuth": false,
  "isDefault": true,
  "jsonData": {
    "defaultDatabase": "siem",
    "queryTimeout": "60s",
    "dialTimeout": "10s"
  },
  "secureJsonData": {}
}
"@

try {
    $headers = @{
        "Authorization" = $basicAuthValue
        "Content-Type" = "application/json"
    }
    
    $result = Invoke-RestMethod -Uri "$GRAFANA_URL/api/datasources" -Method POST -Headers $headers -Body $datasourceJson
    Write-Host "ClickHouse datasource created successfully" -ForegroundColor Green
}
catch {
    if ($_.Exception.Response.StatusCode -eq 409) {
        Write-Host "ClickHouse datasource already exists" -ForegroundColor Yellow
    }
    else {
        Write-Host "Failed to create datasource: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Dashboard setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Access your dashboards at:" -ForegroundColor Cyan
Write-Host "  Grafana: http://localhost:3000" -ForegroundColor White
Write-Host "  Username: admin" -ForegroundColor White
Write-Host "  Password: admin" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Go to http://localhost:3000" -ForegroundColor White
Write-Host "2. Login with admin/admin" -ForegroundColor White
Write-Host "3. Go to Dashboards -> Import" -ForegroundColor White
Write-Host "4. Upload the JSON files from grafana/provisioning/dashboards/" -ForegroundColor White 