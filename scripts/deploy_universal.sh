#!/bin/bash
set -euo pipefail

# Universal Ultra SIEM Deployment Script
# Compatible with: Linux, macOS, FreeBSD, Ubuntu, CentOS, Alpine, etc.

echo "🚀 Universal Ultra SIEM Deployment"
echo "🌍 Cross-Platform Security Monitoring"
echo "==================================="

# Detect platform
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

echo "🖥️  Detected Platform: $PLATFORM ($ARCH)"
echo "📅 $(date)"
echo

# Platform-specific configurations
case "$PLATFORM" in
    linux*)
        echo "🐧 Linux deployment detected"
        LOG_PATH="/var/log"
        SERVICE_MANAGER="systemd"
        DOCKER_COMPOSE_PROFILE="--profile linux"
        ;;
    darwin*)
        echo "🍎 macOS deployment detected"
        LOG_PATH="/var/log"
        SERVICE_MANAGER="launchd"
        DOCKER_COMPOSE_PROFILE="--profile macos"
        ;;
    freebsd*)
        echo "😈 FreeBSD deployment detected"
        LOG_PATH="/var/log"
        SERVICE_MANAGER="rc"
        DOCKER_COMPOSE_PROFILE="--profile freebsd"
        ;;
    *)
        echo "🌐 Generic Unix deployment"
        LOG_PATH="/var/log"
        SERVICE_MANAGER="generic"
        DOCKER_COMPOSE_PROFILE=""
        ;;
esac

# Check prerequisites
check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    local missing_deps=()
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        missing_deps+=("docker-compose")
    fi
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "❌ Missing dependencies: ${missing_deps[*]}"
        echo "📋 Installation commands for your platform:"
        
        case "$PLATFORM" in
            linux*)
                if command -v apt-get &> /dev/null; then
                    echo "   sudo apt-get update && sudo apt-get install -y docker.io docker-compose curl"
                elif command -v yum &> /dev/null; then
                    echo "   sudo yum install -y docker docker-compose curl"
                elif command -v pacman &> /dev/null; then
                    echo "   sudo pacman -S docker docker-compose curl"
                fi
                ;;
            darwin*)
                echo "   brew install docker docker-compose curl"
                echo "   or install Docker Desktop from https://docker.com/products/docker-desktop"
                ;;
        esac
        
        exit 1
    fi
    
    echo "✅ All prerequisites satisfied"
}

# Create directories
create_directories() {
    echo "📁 Creating directories..."
    
    local dirs=(
        "data/clickhouse"
        "data/grafana"
        "data/nats"
        "logs"
        "config"
        "certs"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        echo "   Created: $dir"
    done
    
    echo "✅ Directory structure created"
}

# Generate platform-specific configuration
generate_config() {
    echo "⚙️ Generating platform-specific configuration..."
    
    # Create platform-specific .env file
    cat > .env << EOF
# Universal Ultra SIEM Configuration
PLATFORM=$PLATFORM
ARCH=$ARCH
TARGET_PLATFORM=$PLATFORM
COMPOSE_PROJECT_NAME=universal-siem
COMPOSE_FILE=docker-compose.universal.yml

# Database Configuration
CLICKHOUSE_USER=admin
CLICKHOUSE_PASSWORD=admin123
CLICKHOUSE_DB=siem

# Message Queue
NATS_PASSWORD=universal_siem_2024

# Grafana
GF_SECURITY_ADMIN_PASSWORD=admin

# Platform-specific paths
LOG_PATH=$LOG_PATH
SERVICE_MANAGER=$SERVICE_MANAGER

# Resource limits (adjust based on your system)
MEMORY_LIMIT=4g
CPU_LIMIT=2
EOF

    echo "✅ Configuration generated"
}

# Deploy services
deploy_services() {
    echo "🚀 Deploying Universal SIEM services..."
    
    # Use the appropriate docker-compose command
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi
    
    echo "📦 Building and starting services..."
    
    # Build and start services with platform profile
    $COMPOSE_CMD -f docker-compose.universal.yml up -d $DOCKER_COMPOSE_PROFILE
    
    echo "⏳ Waiting for services to start..."
    sleep 30
    
    # Health checks
    local services=(
        "http://localhost:8123/ping:ClickHouse"
        "http://localhost:3000/api/health:Grafana"
        "http://localhost:8222/varz:NATS"
    )
    
    for service in "${services[@]}"; do
        IFS=':' read -r url name <<< "$service"
        echo -n "   Checking $name... "
        
        if curl -s -f "$url" > /dev/null 2>&1; then
            echo "✅ Healthy"
        else
            echo "⚠️  Warning: $name not responding"
        fi
    done
}

# Setup database
setup_database() {
    echo "🗄️ Setting up database schema..."
    
    # Wait for ClickHouse to be ready
    sleep 10
    
    # Create schema
    curl -X POST 'http://localhost:8123/?user=admin&password=admin123' \
        -d "CREATE DATABASE IF NOT EXISTS siem"
    
    curl -X POST 'http://localhost:8123/?user=admin&password=admin123&database=siem' \
        -d "CREATE TABLE IF NOT EXISTS threats (
            event_time DateTime,
            platform String,
            source_ip String,
            threat_type String,
            severity UInt8,
            message String,
            geo_country String,
            confidence_score Float32,
            metadata String
        ) ENGINE = MergeTree()
        ORDER BY (event_time, threat_type)
        PARTITION BY toYYYYMM(event_time)"
    
    # Insert sample data
    curl -X POST 'http://localhost:8123/?user=admin&password=admin123&database=siem' \
        -d "INSERT INTO threats VALUES
        (now(), '$PLATFORM', '192.168.1.100', 'sql_injection', 5, 'SQL injection attempt detected', 'US', 0.95, '{}'),
        (now(), '$PLATFORM', '10.0.0.50', 'xss_attack', 4, 'Cross-site scripting attempt', 'CN', 0.88, '{}'),
        (now(), '$PLATFORM', '172.16.0.25', 'brute_force', 3, 'Brute force login attempt', 'RU', 0.75, '{}')"
    
    echo "✅ Database schema and sample data created"
}

# Generate startup script
generate_startup_script() {
    echo "📝 Generating startup script..."
    
    cat > start_siem.sh << 'EOF'
#!/bin/bash
# Universal Ultra SIEM Startup Script

cd "$(dirname "$0")"

echo "🚀 Starting Universal Ultra SIEM..."
echo "🌍 Platform: $(uname -s)"

# Load environment
if [ -f .env ]; then
    source .env
fi

# Start services
if command -v docker-compose &> /dev/null; then
    docker-compose -f docker-compose.universal.yml up -d
else
    docker compose -f docker-compose.universal.yml up -d
fi

echo "✅ Universal Ultra SIEM started successfully!"
echo "🌐 Access points:"
echo "   • Grafana Dashboard: http://localhost:3000 (admin/admin)"
echo "   • ClickHouse Web UI: http://localhost:8123"
echo "   • NATS Monitoring: http://localhost:8222"
echo "   • Query Engine: http://localhost:8080"
EOF

    chmod +x start_siem.sh
    echo "✅ Startup script created: ./start_siem.sh"
}

# Main deployment flow
main() {
    echo "🎯 Starting Universal Ultra SIEM deployment..."
    
    check_prerequisites
    create_directories
    generate_config
    deploy_services
    setup_database
    generate_startup_script
    
    echo
    echo "🎉 Universal Ultra SIEM deployed successfully!"
    echo "🌍 Platform: $PLATFORM ($ARCH)"
    echo "📊 Services Status:"
    
    # Final status check
    if command -v docker-compose &> /dev/null; then
        docker-compose -f docker-compose.universal.yml ps
    else
        docker compose -f docker-compose.universal.yml ps
    fi
    
    echo
    echo "🌐 Access URLs:"
    echo "   • 📊 Grafana Dashboard: http://localhost:3000 (admin/admin)"
    echo "   • 🗄️ ClickHouse Web UI: http://localhost:8123 (admin/admin123)"
    echo "   • 📡 NATS Monitoring: http://localhost:8222"
    echo "   • ⚡ Query Engine: http://localhost:8080"
    echo
    echo "🚀 Next Steps:"
    echo "   1. Visit Grafana to create dashboards"
    echo "   2. Configure your log sources"
    echo "   3. Start monitoring security events"
    echo
    echo "📋 To stop: docker-compose -f docker-compose.universal.yml down"
    echo "🔄 To restart: ./start_siem.sh"
}

# Run main function
main "$@" 