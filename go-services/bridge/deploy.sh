#!/bin/bash

# Ultra SIEM Bridge Deployment Script
# Enterprise-grade deployment with zero-trust compliance

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BRIDGE_NAME="ultra-siem-bridge"
BRIDGE_VERSION="2.0.0"
DOCKER_IMAGE="ultra-siem/bridge:${BRIDGE_VERSION}"
CONFIG_FILE="config.yaml"
LOG_DIR="/var/log/ultra-siem"
CERT_DIR="/etc/ultra-siem/certs"
DATA_DIR="/var/lib/ultra-siem"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. Consider using a non-root user for production."
    fi
}

# Function to check system requirements
check_requirements() {
    print_status "Checking system requirements..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check available memory
    MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    MEMORY_GB=$((MEMORY_KB / 1024 / 1024))
    if [ $MEMORY_GB -lt 4 ]; then
        print_warning "System has less than 4GB RAM. Performance may be degraded."
    fi
    
    # Check available disk space
    DISK_SPACE=$(df / | awk 'NR==2 {print $4}')
    DISK_SPACE_GB=$((DISK_SPACE / 1024 / 1024))
    if [ $DISK_SPACE_GB -lt 10 ]; then
        print_warning "System has less than 10GB free disk space."
    fi
    
    print_success "System requirements check completed."
}

# Function to create directories
create_directories() {
    print_status "Creating necessary directories..."
    
    sudo mkdir -p $LOG_DIR
    sudo mkdir -p $CERT_DIR
    sudo mkdir -p $DATA_DIR
    sudo mkdir -p /etc/ultra-siem/config
    
    # Set proper permissions
    sudo chown -R $USER:$USER $LOG_DIR
    sudo chown -R $USER:$USER $DATA_DIR
    sudo chmod 755 $LOG_DIR
    sudo chmod 755 $DATA_DIR
    sudo chmod 700 $CERT_DIR
    
    print_success "Directories created successfully."
}

# Function to generate TLS certificates
generate_certificates() {
    print_status "Generating TLS certificates..."
    
    if [ ! -f "$CERT_DIR/ca.key" ]; then
        # Generate CA key and certificate
        openssl genrsa -out $CERT_DIR/ca.key 4096
        openssl req -new -x509 -days 365 -key $CERT_DIR/ca.key -out $CERT_DIR/ca.crt \
            -subj "/C=US/ST=CA/L=San Francisco/O=Ultra SIEM/CN=Ultra SIEM CA"
        
        # Generate server key and certificate
        openssl genrsa -out $CERT_DIR/server.key 2048
        openssl req -new -key $CERT_DIR/server.key -out $CERT_DIR/server.csr \
            -subj "/C=US/ST=CA/L=San Francisco/O=Ultra SIEM/CN=ultra-siem-bridge"
        
        # Sign server certificate with CA
        openssl x509 -req -days 365 -in $CERT_DIR/server.csr \
            -CA $CERT_DIR/ca.crt -CAkey $CERT_DIR/ca.key -CAcreateserial \
            -out $CERT_DIR/server.crt
        
        print_success "TLS certificates generated successfully."
    else
        print_status "TLS certificates already exist."
    fi
}

# Function to build Docker image
build_image() {
    print_status "Building Ultra SIEM Bridge Docker image..."
    
    # Build the image
    docker build -t $DOCKER_IMAGE .
    
    if [ $? -eq 0 ]; then
        print_success "Docker image built successfully."
    else
        print_error "Failed to build Docker image."
        exit 1
    fi
}

# Function to create Docker Compose file
create_docker_compose() {
    print_status "Creating Docker Compose configuration..."
    
    cat > docker-compose.bridge.yml << EOF
version: '3.8'

services:
  ultra-siem-bridge:
    image: ${DOCKER_IMAGE}
    container_name: ${BRIDGE_NAME}
    restart: unless-stopped
    environment:
      - NATS_URL=nats://nats:4222
      - CLICKHOUSE_URL=clickhouse:9000
      - CLICKHOUSE_USER=admin
      - CLICKHOUSE_PASS=admin
      - CLICKHOUSE_DB=ultra_siem
      - BATCH_SIZE=100
      - BATCH_TIMEOUT=5s
      - MAX_RETRIES=3
      - RETRY_DELAY=1s
      - ENABLE_TLS=false
      - ENABLE_METRICS=true
      - METRICS_PORT=8080
      - LOG_LEVEL=info
      - MAX_CONNECTIONS=10
      - CONNECTION_TIMEOUT=10s
      - QUERY_TIMEOUT=60s
    volumes:
      - ${CONFIG_FILE}:/app/config.yaml:ro
      - ${LOG_DIR}:/var/log/ultra-siem
      - ${CERT_DIR}:/etc/ultra-siem/certs:ro
      - ${DATA_DIR}:/var/lib/ultra-siem
    ports:
      - "8080:8080"  # Metrics endpoint
    networks:
      - ultra-siem-network
    depends_on:
      - nats
      - clickhouse
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
        reservations:
          memory: 512M
          cpus: '0.5'
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
        window: 120s

networks:
  ultra-siem-network:
    external: true
EOF

    print_success "Docker Compose configuration created."
}

# Function to deploy the bridge
deploy_bridge() {
    print_status "Deploying Ultra SIEM Bridge..."
    
    # Start the bridge
    docker-compose -f docker-compose.bridge.yml up -d
    
    if [ $? -eq 0 ]; then
        print_success "Ultra SIEM Bridge deployed successfully."
    else
        print_error "Failed to deploy Ultra SIEM Bridge."
        exit 1
    fi
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    # Wait for container to start
    sleep 10
    
    # Check if container is running
    if docker ps | grep -q $BRIDGE_NAME; then
        print_success "Bridge container is running."
    else
        print_error "Bridge container is not running."
        exit 1
    fi
    
    # Check health endpoint
    if curl -f http://localhost:8080/health &> /dev/null; then
        print_success "Health check passed."
    else
        print_warning "Health check failed. Bridge may still be starting up."
    fi
    
    # Check logs for errors
    if docker logs $BRIDGE_NAME 2>&1 | grep -i error; then
        print_warning "Found errors in bridge logs. Check logs for details."
    else
        print_success "No errors found in bridge logs."
    fi
}

# Function to configure monitoring
configure_monitoring() {
    print_status "Configuring monitoring..."
    
    # Create Prometheus configuration
    cat > prometheus-bridge.yml << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'ultra-siem-bridge'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/metrics'
    scrape_interval: 5s
EOF

    # Create Grafana dashboard configuration
    cat > grafana-bridge-dashboard.json << EOF
{
  "dashboard": {
    "title": "Ultra SIEM Bridge Metrics",
    "panels": [
      {
        "title": "Events Processed",
        "type": "stat",
        "targets": [
          {
            "expr": "ultra_siem_events_processed_total",
            "legendFormat": "Events"
          }
        ]
      },
      {
        "title": "Threats Processed",
        "type": "stat",
        "targets": [
          {
            "expr": "ultra_siem_threats_processed_total",
            "legendFormat": "Threats"
          }
        ]
      },
      {
        "title": "Processing Latency",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, ultra_siem_processing_duration_seconds_bucket)",
            "legendFormat": "95th Percentile"
          }
        ]
      }
    ]
  }
}
EOF

    print_success "Monitoring configuration created."
}

# Function to create systemd service
create_systemd_service() {
    print_status "Creating systemd service..."
    
    sudo tee /etc/systemd/system/ultra-siem-bridge.service > /dev/null << EOF
[Unit]
Description=Ultra SIEM Bridge
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$(pwd)
ExecStart=/usr/bin/docker-compose -f docker-compose.bridge.yml up -d
ExecStop=/usr/bin/docker-compose -f docker-compose.bridge.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable ultra-siem-bridge.service
    
    print_success "Systemd service created and enabled."
}

# Function to create log rotation
configure_log_rotation() {
    print_status "Configuring log rotation..."
    
    sudo tee /etc/logrotate.d/ultra-siem-bridge > /dev/null << EOF
${LOG_DIR}/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $USER $USER
    postrotate
        docker exec ${BRIDGE_NAME} kill -HUP 1
    endscript
}
EOF

    print_success "Log rotation configured."
}

# Function to create backup script
create_backup_script() {
    print_status "Creating backup script..."
    
    cat > backup-bridge.sh << 'EOF'
#!/bin/bash

# Ultra SIEM Bridge Backup Script

BACKUP_DIR="/var/backups/ultra-siem"
DATE=$(date +%Y%m%d_%H%M%S)
BRIDGE_NAME="ultra-siem-bridge"

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup configuration
tar -czf $BACKUP_DIR/bridge-config-$DATE.tar.gz \
    config.yaml \
    docker-compose.bridge.yml \
    /etc/ultra-siem/config/

# Backup logs
tar -czf $BACKUP_DIR/bridge-logs-$DATE.tar.gz \
    /var/log/ultra-siem/

# Backup data
tar -czf $BACKUP_DIR/bridge-data-$DATE.tar.gz \
    /var/lib/ultra-siem/

# Clean up old backups (keep last 7 days)
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR"
EOF

    chmod +x backup-bridge.sh
    
    # Add to crontab for daily backups
    (crontab -l 2>/dev/null; echo "0 2 * * * $(pwd)/backup-bridge.sh") | crontab -
    
    print_success "Backup script created and scheduled."
}

# Function to display deployment information
display_info() {
    print_success "Ultra SIEM Bridge deployment completed!"
    echo
    echo "Deployment Information:"
    echo "======================"
    echo "Bridge Name: $BRIDGE_NAME"
    echo "Version: $BRIDGE_VERSION"
    echo "Docker Image: $DOCKER_IMAGE"
    echo "Metrics Endpoint: http://localhost:8080/metrics"
    echo "Health Endpoint: http://localhost:8080/health"
    echo "Log Directory: $LOG_DIR"
    echo "Config Directory: /etc/ultra-siem/config"
    echo
    echo "Useful Commands:"
    echo "================"
    echo "View logs: docker logs $BRIDGE_NAME"
    echo "Restart bridge: docker-compose -f docker-compose.bridge.yml restart"
    echo "Stop bridge: docker-compose -f docker-compose.bridge.yml down"
    echo "Check status: docker ps | grep $BRIDGE_NAME"
    echo "View metrics: curl http://localhost:8080/metrics"
    echo
    echo "Monitoring:"
    echo "==========="
    echo "Prometheus config: prometheus-bridge.yml"
    echo "Grafana dashboard: grafana-bridge-dashboard.json"
    echo
    echo "Backup:"
    echo "======="
    echo "Manual backup: ./backup-bridge.sh"
    echo "Scheduled: Daily at 2:00 AM"
}

# Main deployment function
main() {
    echo "🚀 Ultra SIEM Bridge Deployment"
    echo "================================"
    echo
    
    check_root
    check_requirements
    create_directories
    generate_certificates
    build_image
    create_docker_compose
    deploy_bridge
    verify_deployment
    configure_monitoring
    create_systemd_service
    configure_log_rotation
    create_backup_script
    display_info
}

# Run main function
main "$@" 