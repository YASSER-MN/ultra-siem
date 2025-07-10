# 🚀 Ultra SIEM Deployment Guide

## 📋 **Table of Contents**

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Production Deployment](#production-deployment)
4. [Cloud Deployment](#cloud-deployment)
5. [Scaling & Performance](#scaling--performance)
6. [Security Configuration](#security-configuration)
7. [Monitoring & Maintenance](#monitoring--maintenance)
8. [Troubleshooting](#troubleshooting)
9. [Upgrade Procedures](#upgrade-procedures)

---

## 🔧 **Prerequisites**

### **System Requirements**

#### **Minimum Requirements**

- **CPU**: 4 cores (2.4 GHz)
- **RAM**: 8 GB
- **Storage**: 100 GB SSD
- **OS**: Linux (Ubuntu 20.04+), Windows 10+, macOS 12+
- **Docker**: 20.10+
- **Docker Compose**: 2.0+

#### **Recommended Requirements**

- **CPU**: 8+ cores (3.0 GHz)
- **RAM**: 16+ GB
- **Storage**: 500+ GB NVMe SSD
- **Network**: 10 Gbps
- **GPU**: NVIDIA RTX 3080+ (for GPU acceleration)

### **Software Dependencies**

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y docker.io docker-compose git curl wget

# CentOS/RHEL
sudo yum install -y docker docker-compose git curl wget

# Windows
# Install Docker Desktop from https://www.docker.com/products/docker-desktop

# macOS
# Install Docker Desktop from https://www.docker.com/products/docker-desktop
```

---

## ⚡ **Quick Start**

### **1. Clone Repository**

```bash
git clone https://github.com/YASSER-MN/ultra-siem.git
cd ultra-siem
```

### **2. Start Basic Deployment**

```bash
# Start with simple configuration
docker-compose -f docker-compose.simple.yml up -d

# Verify services are running
docker-compose -f docker-compose.simple.yml ps
```

### **3. Access Dashboards**

- **Grafana**: http://localhost:3000 (admin/admin)
- **ClickHouse**: http://localhost:8123
- **NATS**: nats://localhost:4222

### **4. Start Threat Detection**

```bash
# Start Rust core engine
cd rust-core
cargo run --release

# Start Go processor (in another terminal)
cd go-services
go run main.go
```

---

## 🏭 **Production Deployment**

### **1. Production Configuration**

```bash
# Use production configuration
docker-compose -f docker-compose.ultra.yml up -d

# Or use universal configuration for maximum performance
docker-compose -f docker-compose.universal.yml up -d
```

### **2. Environment Configuration**

Create `.env` file:

```env
# Database Configuration
CLICKHOUSE_HOST=clickhouse
CLICKHOUSE_PORT=9000
CLICKHOUSE_DATABASE=ultra_siem
CLICKHOUSE_USER=admin
CLICKHOUSE_PASSWORD=your_secure_password

# NATS Configuration
NATS_URL=nats://nats:4222
NATS_PROCESSOR_PASSWORD=your_nats_password

# Security Configuration
JWT_SECRET=your_jwt_secret_key
ENCRYPTION_KEY=your_encryption_key

# Performance Configuration
RUST_LOG=info
GO_LOG_LEVEL=info
WORKER_THREADS=8
BUFFER_SIZE=10000

# Monitoring Configuration
PROMETHEUS_ENABLED=true
GRAFANA_ADMIN_PASSWORD=your_grafana_password
```

### **3. SSL/TLS Configuration**

```bash
# Generate SSL certificates
mkdir -p certs
openssl req -x509 -newkey rsa:4096 -keyout certs/key.pem -out certs/cert.pem -days 365 -nodes

# Update docker-compose with SSL configuration
# Add to docker-compose.ultra.yml:
volumes:
  - ./certs:/etc/ssl/certs
environment:
  - SSL_CERT_FILE=/etc/ssl/certs/cert.pem
  - SSL_KEY_FILE=/etc/ssl/certs/key.pem
```

### **4. Database Initialization**

```bash
# Initialize ClickHouse schema
docker exec -it ultra-siem-clickhouse-1 clickhouse-client --query "
CREATE DATABASE IF NOT EXISTS ultra_siem;
USE ultra_siem;

CREATE TABLE IF NOT EXISTS threat_events (
    timestamp UInt64,
    source_ip String,
    threat_type String,
    payload String,
    severity UInt8,
    confidence Float32,
    created_at DateTime DEFAULT now()
) ENGINE = MergeTree()
ORDER BY (timestamp, source_ip);
"
```

---

## ☁️ **Cloud Deployment**

### **AWS Deployment**

#### **EC2 Deployment**

```bash
# Launch EC2 instance
aws ec2 run-instances \
  --image-id ami-0c02fb55956c7d316 \
  --instance-type t3.xlarge \
  --key-name your-key-pair \
  --security-group-ids sg-xxxxxxxxx \
  --subnet-id subnet-xxxxxxxxx

# Connect and deploy
ssh -i your-key.pem ubuntu@your-instance-ip
git clone https://github.com/YASSER-MN/ultra-siem.git
cd ultra-siem
docker-compose -f docker-compose.ultra.yml up -d
```

#### **ECS Deployment**

```yaml
# task-definition.json
{
  "family": "ultra-siem",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "2048",
  "memory": "4096",
  "executionRoleArn": "arn:aws:iam::account:role/ecsTaskExecutionRole",
  "containerDefinitions":
    [
      {
        "name": "ultra-siem-core",
        "image": "ultra-siem/rust-core:latest",
        "portMappings": [{ "containerPort": 8080, "protocol": "tcp" }],
      },
    ],
}
```

### **Azure Deployment**

#### **Azure Container Instances**

```bash
# Deploy to ACI
az container create \
  --resource-group your-rg \
  --name ultra-siem \
  --image ultra-siem/rust-core:latest \
  --dns-name-label ultra-siem \
  --ports 8080 \
  --cpu 2 \
  --memory 4
```

### **Google Cloud Deployment**

#### **GKE Deployment**

```yaml
# ultra-siem-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ultra-siem
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ultra-siem
  template:
    metadata:
      labels:
        app: ultra-siem
    spec:
      containers:
        - name: ultra-siem-core
          image: ultra-siem/rust-core:latest
          ports:
            - containerPort: 8080
          resources:
            requests:
              memory: "2Gi"
              cpu: "1000m"
            limits:
              memory: "4Gi"
              cpu: "2000m"
```

---

## 📈 **Scaling & Performance**

### **Horizontal Scaling**

#### **Load Balancer Configuration**

```yaml
# nginx.conf
upstream ultra_siem_backend {
least_conn;
server ultra-siem-1:8080;
server ultra-siem-2:8080;
server ultra-siem-3:8080;
}

server {
listen 80;
server_name ultra-siem.yourdomain.com;

location / {
proxy_pass http://ultra_siem_backend;
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
}
}
```

#### **Database Scaling**

```bash
# ClickHouse cluster configuration
# config.xml
<clickhouse>
    <remote_servers>
        <ultra_siem_cluster>
            <shard>
                <replica>
                    <host>clickhouse-1</host>
                    <port>9000</port>
                </replica>
            </shard>
            <shard>
                <replica>
                    <host>clickhouse-2</host>
                    <port>9000</port>
                </replica>
            </shard>
        </ultra_siem_cluster>
    </remote_servers>
</clickhouse>
```

### **Performance Optimization**

#### **Rust Core Optimization**

```toml
# Cargo.toml
[profile.release]
opt-level = 3
lto = true
codegen-units = 1
panic = "abort"

[features]
default = ["cpu-only"]
gpu-acceleration = ["cuda", "nvml"]
full-acceleration = ["gpu-acceleration", "vulkan-support", "ml-inference"]
```

#### **Go Processor Optimization**

```go
// main.go
const (
    WORKER_THREADS = runtime.NumCPU()
    BUFFER_SIZE    = 100000
    BATCH_SIZE     = 1000
)

// Enable profiling
import _ "net/http/pprof"

func main() {
    go func() {
        log.Println(http.ListenAndServe("localhost:6060", nil))
    }()
}
```

---

## 🔒 **Security Configuration**

### **Authentication & Authorization**

#### **JWT Configuration**

```rust
// rust-core/src/auth.rs
use jsonwebtoken::{encode, decode, Header, Algorithm, Validation, EncodingKey, DecodingKey};

pub struct AuthConfig {
    pub jwt_secret: String,
    pub jwt_expiration: u64,
    pub refresh_token_expiration: u64,
}

impl AuthConfig {
    pub fn new() -> Self {
        Self {
            jwt_secret: std::env::var("JWT_SECRET").unwrap_or_else(|_| "default_secret".to_string()),
            jwt_expiration: 3600, // 1 hour
            refresh_token_expiration: 86400, // 24 hours
        }
    }
}
```

#### **Role-Based Access Control**

```rust
#[derive(Debug, Clone, PartialEq)]
pub enum UserRole {
    Admin,
    Analyst,
    Viewer,
    ReadOnly,
}

impl UserRole {
    pub fn can_read(&self) -> bool {
        matches!(self, UserRole::Admin | UserRole::Analyst | UserRole::Viewer | UserRole::ReadOnly)
    }

    pub fn can_write(&self) -> bool {
        matches!(self, UserRole::Admin | UserRole::Analyst)
    }

    pub fn can_delete(&self) -> bool {
        matches!(self, UserRole::Admin)
    }
}
```

### **Network Security**

#### **Firewall Configuration**

```bash
# UFW configuration
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3000/tcp  # Grafana
sudo ufw allow 8123/tcp  # ClickHouse HTTP
sudo ufw allow 9000/tcp  # ClickHouse native
sudo ufw allow 4222/tcp  # NATS
sudo ufw deny 22/tcp     # Deny SSH if using key-based auth
```

#### **VPN Configuration**

```bash
# WireGuard VPN setup
sudo apt install wireguard

# Generate keys
wg genkey | sudo tee /etc/wireguard/private.key
sudo cat /etc/wireguard/private.key | wg pubkey | sudo tee /etc/wireguard/public.key

# Configure WireGuard
sudo nano /etc/wireguard/wg0.conf
```

---

## 📊 **Monitoring & Maintenance**

### **Health Monitoring**

#### **Health Check Script**

```bash
#!/bin/bash
# health_check.sh

# Check services
services=("clickhouse" "grafana" "nats" "rust-core" "go-processor")

for service in "${services[@]}"; do
    if ! docker ps | grep -q "$service"; then
        echo "ERROR: $service is not running"
        exit 1
    fi
done

# Check endpoints
curl -f http://localhost:8123/ping || exit 1
curl -f http://localhost:3000/api/health || exit 1

# Check performance metrics
curl -s http://localhost:8080/metrics | grep -q "events_processed_total" || exit 1

echo "All services healthy"
```

#### **Prometheus Configuration**

```yaml
# prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "ultra-siem"
    static_configs:
      - targets: ["localhost:8080"]
    metrics_path: "/metrics"

  - job_name: "clickhouse"
    static_configs:
      - targets: ["localhost:8123"]
    metrics_path: "/metrics"

  - job_name: "grafana"
    static_configs:
      - targets: ["localhost:3000"]
    metrics_path: "/metrics"
```

### **Backup & Recovery**

#### **Database Backup**

```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/backups/clickhouse"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup ClickHouse data
docker exec ultra-siem-clickhouse-1 clickhouse-client --query "
BACKUP TABLE ultra_siem.threat_events TO '/backups/ultra_siem_backup_$DATE'
"

# Compress backup
tar -czf "$BACKUP_DIR/ultra_siem_backup_$DATE.tar.gz" -C /tmp ultra_siem_backup_$DATE

# Cleanup old backups (keep last 7 days)
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: ultra_siem_backup_$DATE.tar.gz"
```

#### **Configuration Backup**

```bash
#!/bin/bash
# config_backup.sh

CONFIG_DIR="/etc/ultra-siem"
BACKUP_DIR="/backups/config"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup configuration files
tar -czf "$BACKUP_DIR/config_backup_$DATE.tar.gz" \
    -C /etc ultra-siem \
    -C /opt ultra-siem

echo "Configuration backup completed: config_backup_$DATE.tar.gz"
```

---

## 🔧 **Troubleshooting**

### **Common Issues**

#### **Service Won't Start**

```bash
# Check logs
docker-compose logs [service-name]

# Check resource usage
docker stats

# Check disk space
df -h

# Check memory
free -h

# Restart services
docker-compose restart [service-name]
```

#### **Performance Issues**

```bash
# Check CPU usage
top -p $(pgrep -d',' -f ultra-siem)

# Check memory usage
ps aux | grep ultra-siem

# Check network
netstat -tulpn | grep ultra-siem

# Profile Rust application
cargo install flamegraph
cargo flamegraph

# Profile Go application
go tool pprof http://localhost:6060/debug/pprof/profile
```

#### **Database Issues**

```bash
# Check ClickHouse status
docker exec ultra-siem-clickhouse-1 clickhouse-client --query "SELECT 1"

# Check table sizes
docker exec ultra-siem-clickhouse-1 clickhouse-client --query "
SELECT
    table,
    formatReadableSize(sum(bytes)) as size,
    sum(rows) as rows
FROM system.parts
WHERE active
GROUP BY table
ORDER BY sum(bytes) DESC;
"

# Optimize tables
docker exec ultra-siem-clickhouse-1 clickhouse-client --query "
OPTIMIZE TABLE ultra_siem.threat_events FINAL;
"
```

### **Log Analysis**

#### **Log Aggregation**

```bash
# Collect logs
docker-compose logs --tail=1000 > ultra-siem-logs.txt

# Search for errors
grep -i error ultra-siem-logs.txt

# Search for warnings
grep -i warning ultra-siem-logs.txt

# Monitor logs in real-time
docker-compose logs -f
```

---

## 🔄 **Upgrade Procedures**

### **Version Upgrade**

#### **Backup Before Upgrade**

```bash
# Stop services
docker-compose down

# Create backup
./backup.sh

# Update code
git pull origin main

# Rebuild images
docker-compose build --no-cache

# Start services
docker-compose up -d

# Verify upgrade
./health_check.sh
```

#### **Rollback Procedure**

```bash
# Stop services
docker-compose down

# Restore backup
tar -xzf /backups/ultra_siem_backup_YYYYMMDD_HHMMSS.tar.gz -C /tmp

# Restore database
docker exec ultra-siem-clickhouse-1 clickhouse-client --query "
RESTORE TABLE ultra_siem.threat_events FROM '/tmp/ultra_siem_backup_YYYYMMDD_HHMMSS'
"

# Restart with previous version
git checkout v1.0.0
docker-compose up -d
```

### **Schema Migrations**

```bash
# Run migrations
docker exec ultra-siem-clickhouse-1 clickhouse-client --query "
-- Add new column
ALTER TABLE ultra_siem.threat_events ADD COLUMN IF NOT EXISTS user_agent String;

-- Update existing data
UPDATE ultra_siem.threat_events SET user_agent = '' WHERE user_agent = '';

-- Verify migration
SELECT count() FROM ultra_siem.threat_events WHERE user_agent != '';
"
```

---

## 📞 **Support & Resources**

### **Getting Help**

- **Documentation**: [Complete Documentation](https://github.com/YASSER-MN/ultra-siem/docs)
- **Issues**: [GitHub Issues](https://github.com/YASSER-MN/ultra-siem/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YASSER-MN/ultra-siem/discussions)
- **Email**: yassermn238@gmail.com

### **Useful Commands**

```bash
# Quick status check
docker-compose ps

# View logs
docker-compose logs -f [service]

# Restart specific service
docker-compose restart [service]

# Scale services
docker-compose up -d --scale rust-core=3

# Update images
docker-compose pull && docker-compose up -d

# Clean up
docker-compose down -v
docker system prune -f
```

---

_Ultra SIEM Deployment Guide - For production-ready enterprise security_ 🛡️
