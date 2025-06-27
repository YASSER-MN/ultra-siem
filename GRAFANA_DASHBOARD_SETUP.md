# 🖥️ GRAFANA SIEM DASHBOARD SETUP GUIDE

## ✅ **ClickHouse Plugin Installed Successfully!**

I've installed the ClickHouse plugin in your Grafana. Now let's create your SIEM dashboard step by step.

---

## 🚀 **Step 1: Access Grafana**

1. Open your browser and go to: **http://localhost:3000**
2. Login with:
   - **Username**: `admin`
   - **Password**: `admin`

---

## 🔌 **Step 2: Add ClickHouse Data Source**

1. **Click the menu** (☰) in the top-left corner
2. Go to **"Administration"** → **"Data sources"**
3. Click **"Add new data source"**
4. **Search for "ClickHouse"** and select it (you should now see it!)

### **Configure the ClickHouse Data Source:**

```
Name: SIEM-ClickHouse
URL: http://host.docker.internal:8123
Database: siem
Username: admin
Password: admin123
```

**Advanced Settings:**

- **Protocol**: HTTP
- **Port**: 8123
- **Default Table**: threats

5. Click **"Save & test"** - you should see a green ✅ "Data source is working"

---

## 📊 **Step 3: Create Your First SIEM Dashboard**

### **Create a New Dashboard:**

1. Click **"+"** → **"Dashboard"**
2. Click **"Add visualization"**
3. Select your **"SIEM-ClickHouse"** data source

### **Panel 1: Threat Types Distribution (Pie Chart)**

1. **Query**:

```sql
SELECT threat_type, count() as value
FROM threats
GROUP BY threat_type
```

2. **Visualization**: Change to **"Pie chart"**
3. **Panel Title**: "🛡️ Threat Types Distribution"
4. Click **"Apply"**

### **Panel 2: Threats by Severity (Bar Chart)**

1. Click **"Add panel"** → **"Add visualization"**
2. **Query**:

```sql
SELECT severity, count() as count
FROM threats
GROUP BY severity
ORDER BY count DESC
```

3. **Visualization**: **"Bar chart"**
4. **Panel Title**: "⚠️ Threats by Severity"
5. Click **"Apply"**

### **Panel 3: Geographic Threat Sources (Table)**

1. Click **"Add panel"** → **"Add visualization"**
2. **Query**:

```sql
SELECT
    geo_country as Country,
    count() as Threats,
    avg(confidence_score) as Avg_Confidence
FROM threats
GROUP BY geo_country
ORDER BY Threats DESC
```

3. **Visualization**: **"Table"**
4. **Panel Title**: "🌍 Geographic Threat Sources"
5. Click **"Apply"**

### **Panel 4: Recent High-Severity Threats (Table)**

1. Click **"Add panel"** → **"Add visualization"**
2. **Query**:

```sql
SELECT
    event_time,
    source_ip,
    threat_type,
    severity,
    message,
    confidence_score
FROM threats
WHERE severity IN ('HIGH', 'CRITICAL')
ORDER BY event_time DESC
LIMIT 10
```

3. **Visualization**: **"Table"**
4. **Panel Title**: "🚨 Recent Critical & High Threats"
5. Click **"Apply"**

### **Save Your Dashboard:**

1. Click the **"Save"** icon (💾) at the top
2. **Dashboard name**: "Ultra SIEM - Threat Monitor"
3. Click **"Save"**

---

## 🎯 **Step 4: Test Your Dashboard**

Your dashboard should now show:

- **4 Threat Types**: SQL_INJECTION, BRUTE_FORCE, MALWARE, XSS_ATTACK
- **3 Severity Levels**: CRITICAL (1), HIGH (2), MEDIUM (1)
- **4 Countries**: US, CN, RU, KP
- **All Recent Threats** with timestamps and details

---

## 📈 **Step 5: Advanced Features (Optional)**

### **Add Real-Time Refresh:**

1. Click the **refresh** dropdown (🔄) at the top-right
2. Set to **"30s"** for real-time monitoring

### **Add Filters:**

1. Click **"Dashboard settings"** (⚙️)
2. Go to **"Variables"** → **"Add variable"**
3. Create variables for:
   - **Country**: `SELECT DISTINCT geo_country FROM threats`
   - **Severity**: `SELECT DISTINCT severity FROM threats`

### **Set Time Range:**

1. Click the **time picker** at top-right
2. Set to **"Last 24 hours"** or **"Last 7 days"**

---

## 🎨 **Step 6: Customize Your Dashboard**

### **Change Colors:**

- **Critical**: Red (#FF0000)
- **High**: Orange (#FF8C00)
- **Medium**: Yellow (#FFD700)
- **Low**: Green (#32CD32)

### **Add Thresholds:**

1. Edit any panel
2. Go to **"Field"** → **"Thresholds"**
3. Set alert levels for threat counts

---

## 🔄 **Troubleshooting**

### **If ClickHouse data source doesn't work:**

```bash
# Check ClickHouse is running
docker logs siem-clickhouse

# Test connection manually
curl "http://localhost:8123/?query=SELECT 1"
```

### **If queries fail:**

- Make sure you're using the `threats` table (not `siem.threats`)
- Check the **Database** field is set to `siem`
- Verify your ClickHouse credentials: `admin` / `admin123`

### **If no data shows:**

```sql
-- Run this query to verify data exists:
SELECT COUNT(*) FROM threats;
-- Should return: 4
```

---

## 🎉 **Success!**

You now have a **fully functional SIEM dashboard** with:

- ✅ Real-time threat monitoring
- ✅ Geographic threat intelligence
- ✅ Severity-based analytics
- ✅ Interactive visualizations
- ✅ Zero licensing costs!

**Your enterprise SIEM dashboard is ready for production use!** 🛡️

---

## 🚀 **Next Steps**

1. **Add more data** by connecting your log sources to NATS
2. **Create alerts** for critical threats
3. **Share dashboards** with your security team
4. **Extend analytics** with custom queries

**Need help with any step? Just let me know!**
