#!/usr/bin/env pwsh

# 🚀 Ultra SIEM Dashboard Setup Script
# Automatically configures ClickHouse datasource and imports dashboards

Write-Host "🛡️  Ultra SIEM Dashboard Setup" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

# Configuration
$GRAFANA_URL = "http://localhost:3000"
$GRAFANA_USER = "admin"
$GRAFANA_PASS = "admin"
$CLICKHOUSE_URL = "http://clickhouse:8123"

# Base64 encode credentials for API auth
$credentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${GRAFANA_USER}:${GRAFANA_PASS}"))
$headers = @{
    "Authorization" = "Basic $credentials"
    "Content-Type" = "application/json"
}

Write-Host "⏳ Waiting for services to be ready..." -ForegroundColor Yellow

# Wait for Grafana
do {
    try {
        $response = Invoke-RestMethod -Uri "$GRAFANA_URL/api/health" -Method GET -ErrorAction SilentlyContinue
        if ($response.database -eq "ok") {
            Write-Host "✅ Grafana is ready" -ForegroundColor Green
            break
        }
    }
    catch {
        Write-Host "⏳ Waiting for Grafana..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
    }
} while ($true)

# Wait for ClickHouse
do {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8123/ping" -Method GET -ErrorAction SilentlyContinue
        if ($response -eq "Ok.") {
            Write-Host "✅ ClickHouse is ready" -ForegroundColor Green
            break
        }
    }
    catch {
        Write-Host "⏳ Waiting for ClickHouse..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
    }
} while ($true)

Write-Host ""
Write-Host "🔌 Setting up ClickHouse datasource..." -ForegroundColor Cyan

# Create ClickHouse datasource
$datasource = @{
    name = "ClickHouse-SIEM"
    type = "grafana-clickhouse-datasource"
    access = "proxy"
    url = $CLICKHOUSE_URL
    database = "siem"
    basicAuth = $false
    isDefault = $true
    jsonData = @{
        defaultDatabase = "siem"
        queryTimeout = "60s"
        dialTimeout = "10s"
        httpHeaders = @(
            @{
                name = "X-ClickHouse-Format"
                value = "JSONCompact"
            }
        )
    }
    secureJsonData = @{}
} | ConvertTo-Json -Depth 10

try {
    $result = Invoke-RestMethod -Uri "$GRAFANA_URL/api/datasources" -Method POST -Headers $headers -Body $datasource
    Write-Host "✅ ClickHouse datasource created successfully" -ForegroundColor Green
}
catch {
    if ($_.Exception.Response.StatusCode -eq 409) {
        Write-Host "ℹ️  ClickHouse datasource already exists" -ForegroundColor Yellow
    }
    else {
        Write-Host "❌ Failed to create datasource: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "📊 Importing dashboards..." -ForegroundColor Cyan

# Import main SIEM dashboard
$mainDashboard = Get-Content -Path "grafana/provisioning/dashboards/siem_dashboard.json" -Raw | ConvertFrom-Json

$dashboardImport = @{
    dashboard = $mainDashboard.dashboard
    overwrite = $true
    inputs = @(
        @{
            name = "DS_CLICKHOUSE-SIEM"
            type = "datasource"
            pluginId = "grafana-clickhouse-datasource"
            value = "ClickHouse-SIEM"
        }
    )
} | ConvertTo-Json -Depth 20

try {
    $result = Invoke-RestMethod -Uri "$GRAFANA_URL/api/dashboards/import" -Method POST -Headers $headers -Body $dashboardImport
    Write-Host "✅ Main SIEM dashboard imported successfully" -ForegroundColor Green
    Write-Host "   Dashboard URL: $GRAFANA_URL/d/$($result.dashboard.uid)" -ForegroundColor Gray
}
catch {
    Write-Host "❌ Failed to import main dashboard: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Response: $($_.Exception.Response)" -ForegroundColor Red
}

# Import threats dashboard
$threatsDashboard = Get-Content -Path "grafana/provisioning/dashboards/threats.json" -Raw | ConvertFrom-Json

$threatsImport = @{
    dashboard = $threatsDashboard.dashboard
    overwrite = $true
    inputs = @(
        @{
            name = "DS_CLICKHOUSE-SIEM"
            type = "datasource"
            pluginId = "grafana-clickhouse-datasource"
            value = "ClickHouse-SIEM"
        }
    )
} | ConvertTo-Json -Depth 20

try {
    $result = Invoke-RestMethod -Uri "$GRAFANA_URL/api/dashboards/import" -Method POST -Headers $headers -Body $threatsImport
    Write-Host "✅ Threats dashboard imported successfully" -ForegroundColor Green
    Write-Host "   Dashboard URL: $GRAFANA_URL/d/$($result.dashboard.uid)" -ForegroundColor Gray
}
catch {
    Write-Host "❌ Failed to import threats dashboard: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎯 Testing data connection..." -ForegroundColor Cyan

# Test ClickHouse query
try {
    $query = "SELECT count() as threat_count FROM siem.threats WHERE event_time >= now() - INTERVAL 1 HOUR"
    $testQuery = @{
        targets = @(
            @{
                datasource = @{
                    type = "grafana-clickhouse-datasource"
                    uid = "ClickHouse-SIEM"
                }
                query = $query
                refId = "A"
            }
        )
        from = (Get-Date).AddHours(-1).ToString("o")
        to = (Get-Date).ToString("o")
    } | ConvertTo-Json -Depth 10

    $testResult = Invoke-RestMethod -Uri "$GRAFANA_URL/api/ds/query" -Method POST -Headers $headers -Body $testQuery
    
    if ($testResult -and $testResult.Count -gt 0) {
        $threatCount = $testResult[0].frames[0].data.values[0][0]
        Write-Host "✅ Data connection successful - Found $threatCount threats in last hour" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️  Data connection established but no recent threat data found" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "⚠️  Could not test data connection - dashboards may still work" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎉 Dashboard setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📱 Access your dashboards at:" -ForegroundColor Cyan
Write-Host "   🌐 Grafana: http://localhost:3000" -ForegroundColor White
Write-Host "   👤 Username: admin" -ForegroundColor White
Write-Host "   Password: admin" -ForegroundColor White
Write-Host ""
Write-Host "📊 Available dashboards:" -ForegroundColor Cyan
Write-Host "   • Ultra SIEM - Threat Monitor" -ForegroundColor White
Write-Host "   • Threat Analysis Dashboard" -ForegroundColor White
Write-Host ""
Write-Host "🔍 ClickHouse data browser: http://localhost:8123/play" -ForegroundColor Cyan 