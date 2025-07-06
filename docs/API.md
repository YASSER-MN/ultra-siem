# 🔌 **Ultra SIEM API Reference**

## **📋 Table of Contents**

- [🌐 Overview](#-overview)
- [🔐 Authentication](#-authentication)
- [📊 Events API](#-events-api)
- [🔍 Query API](#-query-api)
- [🛡️ Threats API](#-threats-api)
- [📈 Metrics API](#-metrics-api)
- [⚙️ Configuration API](#️-configuration-api)
- [🚨 Error Handling](#-error-handling)
- [📝 Examples](#-examples)

---

## 🌐 **Overview**

The Ultra SIEM REST API provides programmatic access to all SIEM functionality including:

- **Event ingestion and querying**
- **Threat detection and analysis**
- **Real-time metrics and monitoring**
- **Configuration management**
- **User management and RBAC**

### **Base URL**

```
Production:  https://api.ultra-siem.com/v1
Development: http://localhost:8080/api/v1
```

### **Content Types**

- **Request**: `application/json`
- **Response**: `application/json`
- **Bulk uploads**: `application/x-ndjson`

### **Rate Limits**

| Endpoint Type   | Limit      | Window   |
| --------------- | ---------- | -------- |
| Event Ingestion | 10,000/min | 1 minute |
| Queries         | 1,000/min  | 1 minute |
| Management      | 100/min    | 1 minute |

---

## 🔐 **Authentication**

Ultra SIEM uses **Bearer Token** authentication with **JWT tokens**.

### **Obtain Access Token**

```http
POST /auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "secure_password"
}
```

**Response:**

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "scope": ["read:events", "write:events", "admin"]
}
```

### **Using the Token**

Include the token in the `Authorization` header:

```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### **Token Refresh**

```http
POST /auth/refresh
Content-Type: application/json

{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

---

## 📊 **Events API**

### **Ingest Single Event**

```http
POST /events
Authorization: Bearer {token}
Content-Type: application/json

{
  "timestamp": "2024-01-20T10:30:00Z",
  "source": "nginx",
  "level": "info",
  "message": "GET /api/health 200",
  "metadata": {
    "ip": "192.168.1.100",
    "user_agent": "Mozilla/5.0...",
    "response_time": 45
  }
}
```

**Response:**

```json
{
  "event_id": "evt_1234567890abcdef",
  "status": "accepted",
  "timestamp": "2024-01-20T10:30:00Z",
  "processing_time_ms": 12
}
```

### **Bulk Event Ingestion**

```http
POST /events/bulk
Authorization: Bearer {token}
Content-Type: application/x-ndjson

{"timestamp": "2024-01-20T10:30:00Z", "source": "nginx", "level": "info", "message": "Event 1"}
{"timestamp": "2024-01-20T10:30:01Z", "source": "auth", "level": "warning", "message": "Event 2"}
{"timestamp": "2024-01-20T10:30:02Z", "source": "firewall", "level": "error", "message": "Event 3"}
```

**Response:**

```json
{
  "total_events": 3,
  "accepted": 3,
  "rejected": 0,
  "processing_time_ms": 45,
  "errors": []
}
```

### **Get Events**

```http
GET /events?limit=100&offset=0&from=2024-01-20T00:00:00Z&to=2024-01-20T23:59:59Z&source=nginx&level=error
Authorization: Bearer {token}
```

**Parameters:**

| Parameter | Type    | Default | Description                    |
| --------- | ------- | ------- | ------------------------------ |
| `limit`   | integer | 100     | Max events to return (1-10000) |
| `offset`  | integer | 0       | Pagination offset              |
| `from`    | ISO8601 | 24h ago | Start timestamp                |
| `to`      | ISO8601 | now     | End timestamp                  |
| `source`  | string  | -       | Filter by event source         |
| `level`   | string  | -       | Filter by log level            |
| `search`  | string  | -       | Full-text search               |

**Response:**

```json
{
  "events": [
    {
      "event_id": "evt_1234567890abcdef",
      "timestamp": "2024-01-20T10:30:00Z",
      "source": "nginx",
      "level": "info",
      "message": "GET /api/health 200",
      "metadata": {
        "ip": "192.168.1.100",
        "user_agent": "Mozilla/5.0..."
      }
    }
  ],
  "total": 1,
  "limit": 100,
  "offset": 0
}
```

---

## 🔍 **Query API**

### **Execute SQL Query**

```http
POST /query
Authorization: Bearer {token}
Content-Type: application/json

{
  "query": "SELECT source, COUNT(*) as count FROM events WHERE timestamp > now() - INTERVAL 1 HOUR GROUP BY source ORDER BY count DESC",
  "format": "json",
  "limit": 1000
}
```

**Response:**

```json
{
  "query_id": "qry_abcdef1234567890",
  "execution_time_ms": 234,
  "rows": 5,
  "data": [
    { "source": "nginx", "count": 15234 },
    { "source": "auth", "count": 8761 },
    { "source": "firewall", "count": 3421 }
  ],
  "meta": [
    { "name": "source", "type": "String" },
    { "name": "count", "type": "UInt64" }
  ]
}
```

### **Saved Queries**

#### **Create Saved Query**

```http
POST /queries
Authorization: Bearer {token}
Content-Type: application/json

{
  "name": "Top Error Sources",
  "description": "Shows sources with most errors in last hour",
  "query": "SELECT source, COUNT(*) as errors FROM events WHERE level='error' AND timestamp > now() - INTERVAL 1 HOUR GROUP BY source ORDER BY errors DESC LIMIT 10",
  "tags": ["errors", "monitoring"]
}
```

#### **Execute Saved Query**

```http
POST /queries/{query_id}/execute
Authorization: Bearer {token}
```

---

## 🛡️ **Threats API**

### **Get Detected Threats**

```http
GET /threats?limit=50&severity=high&status=active
Authorization: Bearer {token}
```

**Parameters:**

| Parameter    | Type   | Description                           |
| ------------ | ------ | ------------------------------------- |
| `severity`   | string | low, medium, high, critical           |
| `status`     | string | active, resolved, investigating       |
| `category`   | string | malware, intrusion, data_breach, etc. |
| `confidence` | float  | Minimum confidence (0.0-1.0)          |

**Response:**

```json
{
  "threats": [
    {
      "threat_id": "thr_9876543210fedcba",
      "timestamp": "2024-01-20T10:30:00Z",
      "severity": "high",
      "confidence": 0.92,
      "category": "intrusion",
      "title": "SQL Injection Attempt Detected",
      "description": "Multiple SQL injection patterns detected from IP 10.0.0.50",
      "indicators": [
        {
          "type": "ip",
          "value": "10.0.0.50",
          "confidence": 0.95
        },
        {
          "type": "pattern",
          "value": "' OR 1=1--",
          "confidence": 0.88
        }
      ],
      "events": ["evt_abc123", "evt_def456"],
      "status": "active",
      "mitigation": "Block IP address at firewall level"
    }
  ],
  "total": 1
}
```

### **Update Threat Status**

```http
PATCH /threats/{threat_id}
Authorization: Bearer {token}
Content-Type: application/json

{
  "status": "investigating",
  "analyst": "john.doe@company.com",
  "notes": "Investigating source IP for false positive"
}
```

### **Create Custom Threat Rule**

```http
POST /threats/rules
Authorization: Bearer {token}
Content-Type: application/json

{
  "name": "Suspicious Admin Access",
  "description": "Detects multiple failed admin login attempts",
  "rule": {
    "conditions": [
      {
        "field": "message",
        "operator": "contains",
        "value": "failed login"
      },
      {
        "field": "metadata.username",
        "operator": "equals",
        "value": "admin"
      }
    ],
    "time_window": "5m",
    "threshold": 3
  },
  "severity": "medium",
  "enabled": true
}
```

---

## 📈 **Metrics API**

### **System Metrics**

```http
GET /metrics/system
Authorization: Bearer {token}
```

**Response:**

```json
{
  "timestamp": "2024-01-20T10:30:00Z",
  "metrics": {
    "events_per_second": 12500,
    "query_latency_p95_ms": 45,
    "memory_usage_mb": 3456,
    "cpu_usage_percent": 23.5,
    "disk_usage_percent": 67.2,
    "active_connections": 234
  }
}
```

### **Event Statistics**

```http
GET /metrics/events?from=2024-01-20T00:00:00Z&to=2024-01-20T23:59:59Z&interval=1h
Authorization: Bearer {token}
```

**Response:**

```json
{
  "interval": "1h",
  "data": [
    {
      "timestamp": "2024-01-20T00:00:00Z",
      "total_events": 45123,
      "by_level": {
        "info": 38901,
        "warning": 5432,
        "error": 678,
        "critical": 112
      },
      "by_source": {
        "nginx": 23456,
        "auth": 12345,
        "firewall": 9322
      }
    }
  ]
}
```

### **Performance Metrics**

```http
GET /metrics/performance
Authorization: Bearer {token}
```

**Response:**

```json
{
  "ingestion": {
    "events_per_second": 12500,
    "avg_processing_time_ms": 2.3,
    "queue_depth": 156
  },
  "queries": {
    "queries_per_second": 45,
    "avg_latency_ms": 67,
    "p95_latency_ms": 234,
    "cache_hit_rate": 0.78
  },
  "storage": {
    "total_events": 15678234567,
    "storage_used_gb": 234.5,
    "compression_ratio": 0.12
  }
}
```

---

## ⚙️ **Configuration API**

### **Get Configuration**

```http
GET /config
Authorization: Bearer {token}
```

### **Update Configuration**

```http
PUT /config
Authorization: Bearer {token}
Content-Type: application/json

{
  "retention_days": 90,
  "max_events_per_second": 50000,
  "threat_detection": {
    "enabled": true,
    "confidence_threshold": 0.7
  },
  "alerting": {
    "email_enabled": true,
    "webhook_url": "https://hooks.slack.com/...",
    "notification_levels": ["high", "critical"]
  }
}
```

---

## 🚨 **Error Handling**

### **Error Response Format**

```json
{
  "error": {
    "code": "INVALID_REQUEST",
    "message": "Invalid timestamp format",
    "details": {
      "field": "timestamp",
      "expected": "ISO8601 format",
      "received": "2024-01-20"
    },
    "request_id": "req_1234567890abcdef"
  }
}
```

### **HTTP Status Codes**

| Code | Description           | When Used                |
| ---- | --------------------- | ------------------------ |
| 200  | OK                    | Successful request       |
| 201  | Created               | Resource created         |
| 400  | Bad Request           | Invalid request data     |
| 401  | Unauthorized          | Missing/invalid auth     |
| 403  | Forbidden             | Insufficient permissions |
| 404  | Not Found             | Resource not found       |
| 429  | Too Many Requests     | Rate limit exceeded      |
| 500  | Internal Server Error | Server error             |
| 503  | Service Unavailable   | System overloaded        |

### **Common Error Codes**

| Code                       | Description                      |
| -------------------------- | -------------------------------- |
| `INVALID_REQUEST`          | Request validation failed        |
| `AUTHENTICATION_FAILED`    | Invalid credentials              |
| `INSUFFICIENT_PERMISSIONS` | Missing required permissions     |
| `RATE_LIMIT_EXCEEDED`      | Too many requests                |
| `RESOURCE_NOT_FOUND`       | Requested resource doesn't exist |
| `VALIDATION_ERROR`         | Data validation failed           |
| `PROCESSING_ERROR`         | Internal processing error        |

---

## 📝 **Examples**

### **JavaScript/Node.js**

```javascript
const SIEM_API = "http://localhost:8080/api/v1";
const token = "your-jwt-token";

// Ingest an event
async function ingestEvent(event) {
  const response = await fetch(`${SIEM_API}/events`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(event),
  });

  return response.json();
}

// Query events
async function queryEvents(query) {
  const response = await fetch(`${SIEM_API}/query`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ query, format: "json" }),
  });

  return response.json();
}

// Get threats
async function getThreats(filters = {}) {
  const params = new URLSearchParams(filters);
  const response = await fetch(`${SIEM_API}/threats?${params}`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  return response.json();
}
```

### **Python**

```python
import requests
import json

class UltraSIEMClient:
    def __init__(self, base_url, token):
        self.base_url = base_url
        self.headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }

    def ingest_event(self, event):
        response = requests.post(
            f'{self.base_url}/events',
            headers=self.headers,
            json=event
        )
        return response.json()

    def query(self, sql_query):
        response = requests.post(
            f'{self.base_url}/query',
            headers=self.headers,
            json={'query': sql_query, 'format': 'json'}
        )
        return response.json()

    def get_threats(self, **filters):
        response = requests.get(
            f'{self.base_url}/threats',
            headers=self.headers,
            params=filters
        )
        return response.json()

# Usage
client = UltraSIEMClient('http://localhost:8080/api/v1', 'your-token')

# Ingest event
event = {
    'timestamp': '2024-01-20T10:30:00Z',
    'source': 'nginx',
    'level': 'info',
    'message': 'GET /api/health 200'
}
result = client.ingest_event(event)
print(f"Event ingested: {result['event_id']}")

# Query data
threats = client.get_threats(severity='high', status='active')
print(f"Found {len(threats['threats'])} active high-severity threats")
```

### **curl Examples**

```bash
# Login and get token
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password"}' \
  | jq -r '.access_token')

# Ingest event
curl -X POST http://localhost:8080/api/v1/events \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "timestamp": "2024-01-20T10:30:00Z",
    "source": "nginx",
    "level": "info",
    "message": "GET /api/health 200"
  }'

# Query events
curl -X POST http://localhost:8080/api/v1/query \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "SELECT COUNT(*) FROM events WHERE level='\''error'\''",
    "format": "json"
  }'

# Get threats
curl -X GET "http://localhost:8080/api/v1/threats?severity=high&limit=10" \
  -H "Authorization: Bearer $TOKEN"
```

---

## 📚 **Additional Resources**

- **[OpenAPI Specification](api-spec.yaml)** - Complete API specification
- **[Postman Collection](postman-collection.json)** - Ready-to-use API collection
- **[SDK Downloads](https://github.com/ultra-siem/sdks)** - Official SDKs for various languages
- **[Rate Limiting Guide](rate-limiting.md)** - Understanding API limits
- **[Webhook Documentation](webhooks.md)** - Setting up real-time notifications

---

## 🆘 **Support**

- **📧 API Support**: api-support@ultra-siem.com
- **📖 Documentation**: https://docs.ultra-siem.com/api
- **💬 Community**: https://discord.gg/ultra-siem
- **🐛 Issues**: https://github.com/ultra-siem/ultra-siem/issues
