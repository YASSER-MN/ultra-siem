# 🚀 Ultra SIEM Quick Start Guide

Welcome to Ultra SIEM! This guide will get you up and running in minutes.

---

## 1. Prerequisites

- **OS:** Linux (Ubuntu 20.04+), Windows 10+, or macOS 12+
- **CPU:** 4+ cores
- **RAM:** 8+ GB
- **Docker:** 20.10+
- **Docker Compose:** 2.0+
- **Git:** Latest version

---

## 2. Installation

### **Clone the Repository**

```bash
git clone https://github.com/YASSER-MN/ultra-siem.git
cd ultra-siem
```

---

## 3. Start Ultra SIEM (Simple Mode)

```bash
docker-compose -f docker-compose.simple.yml up -d
```

---

## 4. Access Dashboards & Services

- **Grafana Dashboard:** [http://localhost:3000](http://localhost:3000) (admin/admin)
- **ClickHouse DB:** [http://localhost:8123](http://localhost:8123)
- **NATS Console:** [http://localhost:8222](http://localhost:8222)

---

## 5. Start Detection Engines (Optional)

Open new terminals for each engine:

**Rust Core Engine:**

```bash
cd rust-core
cargo run --release
```

**Go Data Processor:**

```bash
cd go-services
# For bridge: cd bridge && go run main.go
# For main processor:
go run main.go
```

---

## 6. Stopping & Restarting

```bash
# Stop all services
docker-compose -f docker-compose.simple.yml down

# Restart
# (from project root)
docker-compose -f docker-compose.simple.yml up -d
```

---

## 7. Troubleshooting Basics

- Check service status: `docker-compose ps`
- View logs: `docker-compose logs -f [service]`
- For more help, see [Troubleshooting Guide](TROUBLESHOOTING_GUIDE.md)

---

## 8. Next Steps

- Explore dashboards and analytics
- Simulate attacks: `./scripts/simulate_attacks.ps1`
- Run full system test: `./test_complete_system.ps1`
- See [Deployment Guide](DEPLOYMENT_GUIDE.md) for production setup

---

**Ultra SIEM is now running!**

_Questions? See the [README](../README.md) or join our [community](https://github.com/YASSER-MN/ultra-siem/discussions)._ 🛡️
