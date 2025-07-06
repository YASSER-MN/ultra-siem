# 🎯 **Ultra SIEM - Attack Testing Guide**

## 🚀 **Quick Start: Test Your SIEM Real-Time Detection**

### **Step 1: Start the SIEM Monitor**

Open **Terminal 1** and run:

```powershell
.\siem_monitor_simple.ps1
```

This will show you:

- Real-time threat statistics
- Recent threat detections
- System status (ClickHouse, NATS, Grafana, detection engines)
- Live threat distribution

### **Step 2: Launch Attack Control Center**

Open **Terminal 2** and run:

```powershell
.\attack_control_center.ps1
```

This gives you a menu to choose different attack types:

- 🔐 Failed Login Attacks
- 🦠 PowerShell Malware
- 💉 Command Injection
- 📁 File System Attacks
- 🌐 Network Reconnaissance
- ⚙️ Process Injection
- 🔥 Multi-Vector Attack
- ⚡ Rapid Fire Attack
- 🎲 Random Attack Sequence

---

## 🎮 **How to Test as the Attacker**

### **Option 1: Use the Attack Control Center**

1. **Start the monitor** in Terminal 1
2. **Start the attack center** in Terminal 2
3. **Choose attack types** from the menu
4. **Watch real-time detection** in Terminal 1

### **Option 2: Manual Attack Commands**

While the monitor is running, execute these in a new terminal:

#### **🔴 PowerShell Malware Detection**

```powershell
powershell.exe -enc SGVsbG8gV29ybGQ=
powershell.exe -windowstyle hidden -enc SGVsbG8gV29ybGQ=
```

#### **🔴 Command Injection Detection**

```powershell
cmd.exe /c whoami
cmd.exe /c net user
cmd.exe /c dir
```

#### **🔴 File System Attacks**

```powershell
New-Item -Path "$env:TEMP\malware.exe" -ItemType File
New-Item -Path "$env:TEMP\payload.dll" -ItemType File
```

#### **🔴 Network Reconnaissance**

```powershell
netstat -an
netstat -an | findstr :80
```

#### **🔴 Process Injection**

```powershell
Start-Process notepad.exe
tasklist
```

---

## 📊 **What You Should See**

### **In the Monitor (Terminal 1)**

```
📈 Threat Statistics
===================
   🎯 Total threats (1 hour): 15
   ⚡ Recent threats (1 minute): 3
   📊 Average confidence: 0.92

📊 Threat Distribution (1 hour)
=============================
   🔴 POWERSHELL_MALWARE: 8 threats
   🔴 COMMAND_INJECTION: 4 threats
   🔴 FILE_SYSTEM: 3 threats

🚨 Recent Threats (Last 5 minutes)
=================================
   ⏰ 2024-01-15 14:30:25 | POWERSHELL_MALWARE | 192.168.1.100 | HIGH | 0.95
   ⏰ 2024-01-15 14:30:20 | COMMAND_INJECTION | 192.168.1.100 | MEDIUM | 0.87
   ⏰ 2024-01-15 14:30:15 | FILE_SYSTEM | 192.168.1.100 | LOW | 0.78
```

### **In Grafana Dashboard**

- Real-time threat timeline
- Threat type distribution charts
- Confidence score metrics
- Geographic threat distribution

---

## 🎯 **Attack Types and Expected Detections**

### **1. Failed Login Attacks**

- **What to do:** Try logging in with wrong password
- **Expected detection:** Windows Event ID 4625
- **Detection time:** 5-10 seconds

### **2. PowerShell Malware**

- **What to do:** Run encoded PowerShell commands
- **Expected detection:** POWERSHELL_MALWARE
- **Confidence:** 0.9-0.95

### **3. Command Injection**

- **What to do:** Execute suspicious commands
- **Expected detection:** COMMAND_INJECTION
- **Confidence:** 0.8-0.9

### **4. File System Attacks**

- **What to do:** Create suspicious files
- **Expected detection:** FILE_SYSTEM
- **Confidence:** 0.7-0.85

### **5. Network Reconnaissance**

- **What to do:** Run network scanning commands
- **Expected detection:** NETWORK_SCAN
- **Confidence:** 0.8-0.9

### **6. Process Injection**

- **What to do:** Start suspicious processes
- **Expected detection:** PROCESS_INJECTION
- **Confidence:** 0.7-0.8

---

## 🔧 **Troubleshooting**

### **No Threats Detected?**

1. **Check system status** in the monitor
2. **Verify detection engines are running:**
   ```powershell
   Get-Process | Where-Object {$_.ProcessName -like "*cargo*" -or $_.ProcessName -like "*go*"}
   ```
3. **Restart detection engines:**

   ```powershell
   # Stop existing processes
   Get-Process | Where-Object {$_.ProcessName -like "*cargo*" -or $_.ProcessName -like "*go*"} | Stop-Process

   # Start Rust engine
   Start-Process -FilePath "cargo" -ArgumentList "run" -WorkingDirectory "rust-core" -WindowStyle Hidden

   # Start Go processor
   Start-Process -FilePath "go" -ArgumentList "run", "real_processor.go" -WorkingDirectory "go-services/bridge" -WindowStyle Hidden
   ```

### **Database Connection Issues?**

1. **Check ClickHouse:**
   ```powershell
   curl -u admin:admin http://localhost:8123/ping
   ```
2. **Check table exists:**
   ```powershell
   curl -u admin:admin -d "SHOW TABLES FROM siem" http://localhost:8123/
   ```

### **Low Detection Rate?**

1. **Increase attack volume** - Run more attacks
2. **Try different attack types** - Use the attack control center
3. **Check confidence thresholds** - Some attacks might have lower confidence

---

## 🎮 **Advanced Testing Scenarios**

### **Scenario 1: Multi-Vector Attack**

1. Start monitor
2. Choose "Multi-Vector Attack" from attack center
3. Watch for multiple threat types detected simultaneously

### **Scenario 2: Rapid Fire Attack**

1. Start monitor
2. Choose "Rapid Fire Attack" from attack center
3. Watch for high-volume threat detection

### **Scenario 3: Random Attack Sequence**

1. Start monitor
2. Choose "Random Attack Sequence" from attack center
3. Watch for unpredictable threat patterns

### **Scenario 4: Manual Attack Chain**

1. Start monitor
2. Execute attacks manually in sequence:

   ```powershell
   # Attack 1: PowerShell malware
   powershell.exe -enc SGVsbG8gV29ybGQ=

   # Attack 2: Network scan
   netstat -an

   # Attack 3: File creation
   New-Item -Path "$env:TEMP\attack.exe" -ItemType File

   # Attack 4: Process injection
   Start-Process notepad.exe

   # Attack 5: Command injection
   cmd.exe /c whoami
   ```

---

## 📈 **Performance Expectations**

### **Detection Performance**

- **Latency:** <5-10 seconds detection time
- **Accuracy:** >90% detection rate for known patterns
- **Throughput:** 1M+ events/sec processing capability
- **False Positives:** <5% for normal activities

### **Real-Time Monitoring**

- **Update frequency:** Every 5 seconds
- **Dashboard refresh:** Real-time
- **Alert notifications:** Immediate
- **Data retention:** Configurable (default 1 hour for stats)

---

## 🎉 **Success Criteria**

Your SIEM is working correctly if you see:

1. ✅ **Real-time threat detection** within 5-10 seconds
2. ✅ **Multiple threat types** detected (PowerShell, Network, File, etc.)
3. ✅ **High confidence scores** (0.8-0.95) for known attacks
4. ✅ **Dashboard updates** showing threat progression
5. ✅ **System status** showing all components online
6. ✅ **Threat distribution** charts updating in real-time

---

## 🚀 **Next Steps**

Once you've confirmed detection is working:

1. **Test with real attack tools** (if you have them)
2. **Configure custom detection rules**
3. **Set up alerting and notifications**
4. **Deploy to production environment**
5. **Monitor performance and tune thresholds**

---

**🎯 Ready to test? Start with the monitor and attack control center!**
