# 🚀 Ultra SIEM Email Alert Setup Script
# This script helps you configure email alerts for Ultra SIEM

Write-Host "📧 Ultra SIEM Email Alert Setup" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Check if .env file exists
$envFile = ".env"
$envExists = Test-Path $envFile

if ($envExists) {
    Write-Host "✅ .env file found" -ForegroundColor Green
} else {
    Write-Host "📝 Creating .env file..." -ForegroundColor Yellow
    New-Item -Path $envFile -ItemType File -Force | Out-Null
}

# Check if GMAIL_APP_PASSWORD is already set
$currentPassword = Get-Content $envFile -ErrorAction SilentlyContinue | Where-Object { $_ -match "GMAIL_APP_PASSWORD" }

if ($currentPassword) {
    Write-Host "⚠️  GMAIL_APP_PASSWORD already configured in .env file" -ForegroundColor Yellow
    Write-Host "Current setting: $currentPassword" -ForegroundColor Gray
    Write-Host ""
    
    $update = Read-Host "Do you want to update it? (y/n)"
    if ($update -ne "y" -and $update -ne "Y") {
        Write-Host "Skipping password update..." -ForegroundColor Yellow
        goto :restart_services
    }
}

Write-Host "🔐 Gmail App Password Setup" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To send email alerts, you need a Gmail App Password:" -ForegroundColor White
Write-Host ""
Write-Host "1. Go to: https://myaccount.google.com/" -ForegroundColor Yellow
Write-Host "2. Click 'Security' in the left sidebar" -ForegroundColor Yellow
Write-Host "3. Enable '2-Step Verification' if not already enabled" -ForegroundColor Yellow
Write-Host "4. Click 'App passwords'" -ForegroundColor Yellow
Write-Host "5. Select 'Mail' and 'Other (Custom name)'" -ForegroundColor Yellow
Write-Host "6. Name it 'Ultra SIEM'" -ForegroundColor Yellow
Write-Host "7. Click 'Generate'" -ForegroundColor Yellow
Write-Host "8. Copy the 16-character password (looks like: abcd efgh ijkl mnop)" -ForegroundColor Yellow
Write-Host ""

$appPassword = Read-Host "Enter your Gmail App Password (16 characters)" -AsSecureString
$appPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($appPassword))

# Validate password format
if ($appPasswordPlain.Length -ne 16 -and $appPasswordPlain.Length -ne 19) {
    Write-Host "⚠️  Warning: App password should be 16 characters (or 19 with spaces)" -ForegroundColor Yellow
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Host "Setup cancelled." -ForegroundColor Red
        exit
    }
}

# Remove spaces from password
$appPasswordPlain = $appPasswordPlain -replace '\s', ''

# Update .env file
$envContent = Get-Content $envFile -ErrorAction SilentlyContinue | Where-Object { $_ -notmatch "GMAIL_APP_PASSWORD" }
$envContent += "GMAIL_APP_PASSWORD=$appPasswordPlain"
$envContent | Set-Content $envFile

Write-Host "✅ Gmail App Password configured successfully!" -ForegroundColor Green
Write-Host ""

:restart_services
Write-Host "🚀 Restarting Ultra SIEM Services" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Stop existing containers
Write-Host "Stopping existing containers..." -ForegroundColor Yellow
docker-compose -f docker-compose.simple.yml down

# Start with new configuration
Write-Host "Starting services with new email configuration..." -ForegroundColor Yellow
docker-compose -f docker-compose.simple.yml up -d

# Wait for services to start
Write-Host "Waiting for services to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Check service status
Write-Host "Checking service status..." -ForegroundColor Yellow
docker-compose -f docker-compose.simple.yml ps

Write-Host ""
Write-Host "✅ Email alert setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📧 Your email alerts will be sent to: yassermn238@gmail.com" -ForegroundColor Cyan
Write-Host ""
Write-Host "🔍 To test email alerts:" -ForegroundColor White
Write-Host "1. Go to: http://localhost:3000 (admin/admin)" -ForegroundColor Yellow
Write-Host "2. Navigate to Alerting → Contact points" -ForegroundColor Yellow
Write-Host "3. Click 'Admin Email'" -ForegroundColor Yellow
Write-Host "4. Click 'Test' button" -ForegroundColor Yellow
Write-Host "5. Check your email for the test message" -ForegroundColor Yellow
Write-Host ""
Write-Host "📊 To view logs: docker-compose -f docker-compose.simple.yml logs grafana" -ForegroundColor Gray
Write-Host ""
Write-Host "🎉 Ultra SIEM is now configured to send you real-time security alerts!" -ForegroundColor Green 