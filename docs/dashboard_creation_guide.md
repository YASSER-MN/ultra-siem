# 📊 **4 Pivotal SIEM Dashboards Creation Guide**

## 🎯 **Overview**

This guide will help you create 4 essential SIEM dashboards in Grafana that provide comprehensive security monitoring capabilities:

1. **🏢 Executive Security Overview** - High-level KPIs for leadership
2. **🔍 SOC Operations Center** - Real-time monitoring for analysts
3. **🌐 Network Security Analysis** - Network-focused threat intelligence
4. **⚡ SIEM Performance & Health** - System monitoring and performance

---

## 📋 **Prerequisites**

✅ **Grafana running**: http://localhost:3000  
✅ **ClickHouse datasource configured**: `ClickHouse-SIEM`  
✅ **Sample data loaded**: 25+ threat records  
✅ **Authentication working**: admin/admin credentials

---

## 🚀 **Dashboard Creation Process**

### **Method 1: JSON Import (Recommended)**

#### **Step 1: Access Dashboard Import**

1. **Go to Grafana**: http://localhost:3000
2. **Login**: admin/admin
3. **Click "+" icon** in left sidebar
4. **Select "Import"**

#### **Step 2: Import Each Dashboard**

For each dashboard, follow these steps:

1. **Copy the JSON** from the respective file
2. **Paste into "Import via panel json"** textbox
3. **Click "Load"**
4. **Configure import options**:
   - **Name**: Keep default or customize
   - **Folder**: Select "General" or create new
   - **UID**: Leave as generated
5. **Select datasource**: Choose "ClickHouse-SIEM"
6. **Click "Import"**

---

## 📊 **Dashboard 1: Executive Security Overview**

### **Purpose**: C-level executives and security leadership

### **Refresh Rate**: 5 minutes

### **Time Range**: Last 24 hours

#### **Key Metrics**:

- 🛡️ **Security Score**: Overall security posture (0-100%)
- 📊 **Threat Trend**: Current vs previous 24h comparison
- 🚨 **Critical Alerts**: Number of critical threats
- 🌍 **Global Threat Map**: Geographic distribution
- 📈 **Threat Timeline**: Hourly trends by severity
- 🎯 **Top Attack Types**: Most common threat vectors

#### **Import Instructions**:

```json
Copy content from: grafana/executive_dashboard.json
```

#### **Business Value**:

- **Risk Assessment**: Quick security posture overview
- **Trend Analysis**: Identify security improvements/degradation
- **Geographic Intelligence**: Understand threat origins
- **Executive Reporting**: High-level metrics for leadership

---

## 🔍 **Dashboard 2: SOC Operations Center**

### **Purpose**: Security analysts and SOC teams

### **Refresh Rate**: 30 seconds

### **Time Range**: Last 6 hours

#### **Key Features**:

- 🚨 **Live Threat Feed**: Real-time security events
- ⚡ **Events per Second**: Processing rate monitoring
- 🎯 **High Priority Queue**: Critical/High severity alerts
- 📊 **Severity Distribution**: Current threat breakdown
- 🌐 **Top Source IPs**: Most active attackers
- 📈 **Attack Patterns**: Minute-by-minute trends
- 🔥 **Critical Incidents**: Detailed incident table

#### **Import Instructions**:

```json
Copy content from: grafana/soc_operations_dashboard.json
```

#### **Operational Value**:

- **Real-time Monitoring**: Live security event stream
- **Incident Response**: Quick identification of critical threats
- **Pattern Recognition**: Identify attack campaigns
- **Workload Management**: Prioritize analyst efforts

---

## 🌐 **Dashboard 3: Network Security Analysis**

### **Purpose**: Network security teams and threat hunters

### **Refresh Rate**: 2 minutes

### **Time Range**: Last 12 hours

#### **Key Insights**:

- 🗺️ **Global Attack Heat Map**: Country-based threat analysis
- 🎯 **Most Dangerous IPs**: High-risk IP addresses
- 📊 **Attack Types by Country**: Geographic threat patterns
- ⏱️ **Attack Timeline**: Severity-based time series
- 🔍 **IP Reputation Score**: Network trust metric
- 🌍 **Country Risk Assessment**: Geographic risk analysis

#### **Import Instructions**:

```json
Copy content from: grafana/network_security_dashboard.json
```

#### **Network Intelligence**:

- **Threat Geography**: Understand attack origins
- **IP Reputation**: Identify persistent threats
- **Attack Correlation**: Link related network activities
- **Risk Assessment**: Evaluate geographic threat levels

---

## ⚡ **Dashboard 4: Performance & Health**

### **Purpose**: System administrators and DevOps teams

### **Refresh Rate**: 15 seconds

### **Time Range**: Last 3 hours

#### **System Metrics**:

- 📊 **Processing Rate**: Events processed per second
- 🗄️ **Database Size**: Total threat records stored
- ⏱️ **Query Performance**: Average query response time
- 🔄 **System Uptime**: SIEM operational time
- 📈 **Data Ingestion Rate**: Real-time data flow
- 💾 **Storage Utilization**: Database storage usage
- 🎯 **Detection Accuracy**: ML confidence scores
- 📊 **Processing Pipeline Health**: Component status
- ⚙️ **System Resources**: CPU, Memory, Disk, Network
- 📡 **Alert Response Time**: Time-to-detection metrics

#### **Import Instructions**:

```json
Copy content from: grafana/performance_dashboard.json
```

#### **Technical Value**:

- **Performance Monitoring**: System health tracking
- **Capacity Planning**: Resource utilization analysis
- **Quality Assurance**: Detection accuracy monitoring
- **Operational Efficiency**: Processing pipeline optimization

---

## 🛠️ **Custom Dashboard Creation**

### **Step-by-Step Manual Creation**

If you prefer to build dashboards from scratch:

#### **1. Create New Dashboard**

```
Grafana → "+" → Create → Dashboard
```

#### **2. Add Panel**

```
Click "Add visualization"
Select "ClickHouse-SIEM" datasource
```

#### **3. Configure Query**

```sql
-- Example threat count query
SELECT count() as threat_count
FROM siem.threats
WHERE event_time >= now() - INTERVAL 1 HOUR
```

#### **4. Choose Visualization**

- **Stat**: Single metrics
- **Gauge**: Progress/percentage indicators
- **Time Series**: Trends over time
- **Table**: Detailed data views
- **Pie Chart**: Category distributions
- **Bar Chart**: Comparisons

#### **5. Configure Display**

- **Title**: Descriptive panel name
- **Units**: Appropriate data units
- **Thresholds**: Color-coded alerts
- **Refresh**: Auto-update interval

---

## 🎨 **Dashboard Customization**

### **Visual Enhancements**

#### **Color Schemes**:

```
🟢 Green: Normal/Safe (0-70)
🟡 Yellow: Warning (70-90)
🔴 Red: Critical (90-100)
```

#### **Emoji Usage**:

- **🛡️**: Security/Protection
- **🚨**: Alerts/Critical
- **📊**: Statistics/Analytics
- **🌍**: Geographic/Global
- **⚡**: Performance/Speed
- **🔍**: Investigation/Analysis

#### **Panel Sizing**:

```
Full Width: 24 units (w=24)
Half Width: 12 units (w=12)
Quarter Width: 6 units (w=6)
Standard Height: 8 units (h=8)
```

---

## 📈 **Advanced Query Examples**

### **Threat Trending**

```sql
SELECT
  toStartOfHour(event_time) as time,
  countIf(severity = 'CRITICAL') as critical,
  countIf(severity = 'HIGH') as high,
  countIf(severity = 'MEDIUM') as medium
FROM siem.threats
WHERE event_time >= now() - INTERVAL 24 HOUR
GROUP BY time
ORDER BY time
```

### **Geographic Analysis**

```sql
SELECT
  geo_country,
  count() as attacks,
  uniq(source_ip) as unique_ips,
  round(avg(confidence_score), 2) as avg_confidence
FROM siem.threats
WHERE event_time >= now() - INTERVAL 12 HOUR
  AND geo_country != 'Unknown'
GROUP BY geo_country
ORDER BY attacks DESC
LIMIT 10
```

### **Performance Metrics**

```sql
SELECT
  count() / 3600 as events_per_second,
  round(avg(confidence_score) * 100, 1) as accuracy_percent,
  uniq(source_ip) as unique_attackers
FROM siem.threats
WHERE event_time >= now() - INTERVAL 1 HOUR
```

---

## 🚀 **Quick Import Commands**

### **Import All Dashboards via CLI**

If you have Grafana CLI access:

```bash
# Dashboard 1: Executive Overview
grafana-cli dashboards import grafana/executive_dashboard.json

# Dashboard 2: SOC Operations
grafana-cli dashboards import grafana/soc_operations_dashboard.json

# Dashboard 3: Network Security
grafana-cli dashboards import grafana/network_security_dashboard.json

# Dashboard 4: Performance Health
grafana-cli dashboards import grafana/performance_dashboard.json
```

---

## 🔧 **Troubleshooting**

### **Common Issues**

#### **"No data" panels**:

```sql
-- Test basic connectivity
SELECT count() FROM siem.threats;

-- Check recent data
SELECT max(event_time) FROM siem.threats;
```

#### **Query errors**:

- ✅ Verify datasource name: `ClickHouse-SIEM`
- ✅ Check database name: `siem`
- ✅ Confirm table name: `threats`
- ✅ Validate column names in schema

#### **Performance issues**:

```sql
-- Optimize with time filters
WHERE event_time >= now() - INTERVAL 24 HOUR

-- Use appropriate aggregations
GROUP BY toStartOfHour(event_time)
```

---

## 📚 **Next Steps**

### **Dashboard Management**

1. **Organize in folders**: Create folder structure
2. **Set permissions**: Control dashboard access
3. **Configure alerts**: Set up notification rules
4. **Create playlists**: Auto-cycle through dashboards
5. **Export/backup**: Save dashboard configurations

### **Advanced Features**

1. **Variables**: Dynamic filtering
2. **Annotations**: Mark significant events
3. **Links**: Connect related dashboards
4. **Templates**: Reusable dashboard patterns

---

## 🎯 **Success Metrics**

After implementing these dashboards, you should have:

✅ **Executive visibility** into security posture  
✅ **Real-time SOC operations** monitoring  
✅ **Network threat intelligence** capabilities  
✅ **System performance** tracking  
✅ **Comprehensive SIEM** monitoring coverage

---

**🛡️ Your Ultra SIEM dashboards are now ready for enterprise-grade security monitoring! 🚀**
