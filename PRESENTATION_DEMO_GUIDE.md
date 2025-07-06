# 🚀 Ultra SIEM - Complete Presentation Demo Guide

## 📋 **Pre-Demo Checklist**

### **Required Software:**

- ✅ Docker Desktop (running)
- ✅ PowerShell 7+
- ✅ Rust (cargo)
- ✅ Go (go command)
- ✅ Web browser

### **System Requirements:**

- ✅ 8GB+ RAM available
- ✅ 4+ CPU cores
- ✅ 10GB+ free disk space
- ✅ Windows 10/11

---

## 🎯 **Step-by-Step Demo Setup**

### **Step 1: Start Infrastructure (5 minutes)**

**Open PowerShell as Administrator and run:**

```powershell
# Navigate to SIEM directory
cd C:\Users\yasse\Desktop\Workspace\siem

# Start Docker infrastructure
docker-compose -f docker-compose.simple.yml up -d

# Wait for services to be healthy
Start-Sleep -Seconds 30

# Verify all services are running
docker ps
```

**Expected Output:**

```
CONTAINER ID   IMAGE                    STATUS                    PORTS
xxx           clickhouse/clickhouse     Up 30s (healthy)         0.0.0.0:8123->8123/tcp
xxx           nats:alpine              Up 30s (healthy)         0.0.0.0:4222->4222/tcp
xxx           grafana/grafana-oss      Up 30s (healthy)         0.0.0.0:3000->3000/tcp
```

### **Step 2: Start Detection Engines (3 minutes)**

**In a NEW PowerShell window (Terminal 1):**

```powershell
cd C:\Users\yasse\Desktop\Workspace\siem

# Start Rust detection engine
cd rust-core
cargo run
```

**Expected Output:**

```
🚀 Ultra SIEM - REAL Threat Detection Engine Starting...
🔍 CONFIGURED FOR 100% REAL DETECTION - NO SIMULATED DATA
📡 REAL DATA SOURCES: Windows Events, Network Traffic, File System, Processes
⚡ REAL THREAT PROCESSING: Live analysis of actual system activity
✅ Connected to NATS at nats://127.0.0.1:4222
🚀 Starting REAL threat detection engines...
🔍 REAL DETECTION MODE: Monitoring actual Windows events, network traffic, file system, and processes
🔍 Monitoring REAL Windows Security Events...
📁 Monitoring REAL File System...
🌐 Monitoring REAL Network Traffic...
⚙️ Monitoring REAL Processes...
```

**In a NEW PowerShell window (Terminal 2):**

```powershell
cd C:\Users\yasse\Desktop\Workspace\siem

# Start Go data processor
cd go-services/bridge
go run main.go
```

**Expected Output:**

```
🚀 Go Data Processor Starting...
✅ Connected to NATS
📡 Listening for threat events...
```

### **Step 3: Start Monitoring Dashboard (2 minutes)**

**In a NEW PowerShell window (Terminal 3):**

```powershell
cd C:\Users\yasse\Desktop\Workspace\siem

# Start SIEM monitor
.\siem_monitor_simple.ps1
```

**Expected Output:**

```
📊 Ultra SIEM - Real-Time Threat Monitor
=========================================

🔍 Monitoring: siem.threats table
📡 NATS: http://localhost:8222/varz
📊 Grafana: http://localhost:3000 (admin/admin)

📈 Threat Statistics
===================
   🎯 Total threats (1 hour): 0
   ⚡ Recent threats (1 minute): 0
   📊 Average confidence: 0.00

🔧 System Status
===============
   ✅ ClickHouse: Online
   ✅ NATS: Online
   ✅ Grafana: Online
   ✅ Rust Engine: Running
   ✅ Go Processor: Running

🎮 Controls
==========
   Press 'R' to refresh
   Press 'Q' to quit
   Press 'A' to open attack control center
   Press 'D' to open dashboard
```

### **Step 4: Start Attack Control Center (2 minutes)**

**In a NEW PowerShell window (Terminal 4):**

```powershell
cd C:\Users\yasse\Desktop\Workspace\siem

# Start attack control center
.\attack_control_center.ps1
```

**Expected Output:**

```
🎯 Ultra SIEM - Attack Control Center
=====================================

🔧 Available Attack Types:
   1. Failed Login Attempts
   2. PowerShell Malware
   3. Command Injection
   4. File System Attacks
   5. Network Reconnaissance
   6. Process Injection
   7. Multi-Vector Attack
   8. Rapid Fire Attack
   9. Random Attack Sequence
   0. Exit

Enter your choice (0-9):
```

---

## 🎬 **Presentation Demo Script**

### **Opening (2 minutes):**

"Welcome to Ultra SIEM - an enterprise-grade Security Information and Event Management system built with modern technologies. Today I'll demonstrate real-time threat detection using actual system monitoring."

### **System Overview (3 minutes):**

"Ultra SIEM features:

- **Rust Core Engine**: High-performance threat detection
- **Go Data Processor**: Real-time event processing
- **ClickHouse Database**: Sub-second query performance
- **Grafana Dashboards**: Real-time visualizations
- **NATS Messaging**: Zero-latency event streaming"

### **Live Demo Flow (10 minutes):**

#### **1. Show Infrastructure Status (1 minute):**

- Open Grafana: http://localhost:3000 (admin/admin)
- Show ClickHouse: http://localhost:8123 (admin/admin)
- Point out all services are healthy

#### **2. Demonstrate Real-Time Monitoring (2 minutes):**

- Show the SIEM monitor (Terminal 3)
- Point out all engines are running
- Show zero threats initially

#### **3. Launch Attack Simulation (5 minutes):**

- In Attack Control Center (Terminal 4), choose option 1: "Failed Login Attempts"
- Watch real-time detection in monitor
- Show threat appearing in database
- Repeat with option 2: "PowerShell Malware"
- Show confidence scores and threat types

#### **4. Show Dashboard Analytics (2 minutes):**

- Refresh Grafana dashboard
- Show threat visualizations
- Point out real-time updates

### **Closing (2 minutes):**

"Ultra SIEM successfully detected multiple threat types in real-time, demonstrating enterprise-grade security monitoring capabilities with sub-second response times."

---

## 🔧 **Troubleshooting Guide**

### **If Services Don't Start:**

**Docker Issues:**

```powershell
# Restart Docker Desktop
# Then run:
docker-compose -f docker-compose.simple.yml down
docker-compose -f docker-compose.simple.yml up -d
```

**Rust Engine Issues:**

```powershell
cd rust-core
cargo clean
cargo build
cargo run
```

**Go Processor Issues:**

```powershell
cd go-services/bridge
go mod tidy
go run main.go
```

### **If No Threats Detected:**

1. Wait 30 seconds for engines to fully initialize
2. Try manual attacks:

   ```powershell
   # Failed login simulation
   net user invaliduser invalidpass

   # Suspicious file creation
   New-Item -Path "C:\temp\malware.exe" -ItemType File

   # Network scan
   netstat -an
   ```

### **Port Conflicts:**

- **8123**: ClickHouse - ensure no other database is using this port
- **4222**: NATS - ensure no other messaging service is using this port
- **3000**: Grafana - ensure no other web service is using this port

---

## 📊 **Demo Success Metrics**

### **Expected Results:**

- ✅ All 4 terminals showing active processes
- ✅ Grafana dashboard accessible and responsive
- ✅ ClickHouse database accepting queries
- ✅ Real-time threat detection within 5 seconds
- ✅ Confidence scores > 0.8 for detected threats
- ✅ Multiple threat types detected

### **Performance Benchmarks:**

- **Detection Latency**: < 5 seconds
- **Database Query Time**: < 1 second
- **Dashboard Refresh**: < 2 seconds
- **Threat Coverage**: 100% of simulated attacks

---

## 🎯 **Presentation Tips**

### **Before Demo:**

1. **Test everything 30 minutes before**
2. **Have backup screenshots ready**
3. **Prepare 2-3 attack scenarios**
4. **Know your system specs**

### **During Demo:**

1. **Speak clearly and confidently**
2. **Point to specific metrics**
3. **Explain the technology stack**
4. **Show real-time updates**
5. **Handle any issues gracefully**

### **After Demo:**

1. **Answer questions about architecture**
2. **Discuss scalability and performance**
3. **Show additional features if time permits**
4. **Provide contact information**

---

## 🚀 **Quick Start Commands**

**For experienced users - run these in sequence:**

```powershell
# 1. Start infrastructure
docker-compose -f docker-compose.simple.yml up -d

# 2. Start Rust engine (Terminal 1)
cd rust-core && cargo run

# 3. Start Go processor (Terminal 2)
cd go-services/bridge && go run main.go

# 4. Start monitor (Terminal 3)
.\siem_monitor_simple.ps1

# 5. Start attack center (Terminal 4)
.\attack_control_center.ps1
```

**Total setup time: 12 minutes**
**Demo duration: 20 minutes**

---

_🎉 You're now ready for a perfect Ultra SIEM presentation demo!_
