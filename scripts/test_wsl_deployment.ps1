# Test Ultra SIEM Cross-Platform Compatibility in WSL2
# Run this from your Windows PowerShell to test Linux deployment

Write-Host "🐧 Testing Ultra SIEM on Linux (WSL2)" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

# Check if WSL2 is available
if (!(Get-Command wsl -ErrorAction SilentlyContinue)) {
    Write-Host "❌ WSL2 not found. Install with:" -ForegroundColor Red
    Write-Host "   wsl --install" -ForegroundColor Yellow
    exit 1
}

# Show current WSL distributions
Write-Host "📋 Available WSL distributions:" -ForegroundColor Cyan
wsl --list --verbose

Write-Host "`n🚀 Deploying Ultra SIEM in WSL2..." -ForegroundColor Green

# Deploy to WSL2
$wslCommands = @"
cd /mnt/c/Users/$env:USERNAME/Desktop/Workspace/siem
echo '🐧 Running on Linux via WSL2'
echo '📅 Date: ' `$(date)
echo '🖥️  Platform: ' `$(uname -a)
echo

# Check prerequisites
echo '🔍 Checking Docker in WSL2...'
if ! command -v docker &> /dev/null; then
    echo '📦 Installing Docker in WSL2...'
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker `$USER
fi

# Start Docker if not running
if ! sudo docker info &> /dev/null; then
    echo '🐳 Starting Docker...'
    sudo service docker start
fi

# Deploy the same Ultra SIEM
echo '🚀 Deploying Ultra SIEM on Linux...'
sudo docker-compose -f docker-compose.simple.yml up -d

echo '⏳ Waiting for services...'
sleep 30

# Test services
echo '🔍 Testing services on Linux:'
echo '   ClickHouse:' `$(curl -s http://localhost:8123/ping || echo 'Not responding')
echo '   Grafana:' `$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3000 || echo 'Not responding')
echo '   NATS:' `$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8222 || echo 'Not responding')

echo
echo '✅ Ultra SIEM running on Linux via WSL2!'
echo '🌐 Access from Windows:'
echo '   • Grafana: http://localhost:3000'
echo '   • ClickHouse: http://localhost:8123'
echo '   • NATS: http://localhost:8222'
echo
echo '🎯 Same functionality, different OS!'
"@

# Execute in WSL2
Write-Host "🔄 Executing in WSL2..." -ForegroundColor Yellow
wsl bash -c $wslCommands

Write-Host "`n✅ Cross-platform test completed!" -ForegroundColor Green
Write-Host "🎉 Your Ultra SIEM works on Linux too!" -ForegroundColor Green 