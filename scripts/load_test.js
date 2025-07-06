import http from "k6/http";
import { check, sleep } from "k6";
import { Counter, Rate, Trend } from "k6/metrics";

// Custom metrics
const eventProcessingRate = new Rate("event_processing_rate");
const queryResponseTime = new Trend("query_response_time");
const errorCounter = new Counter("errors");

// Test configuration
export const options = {
  stages: [
    { duration: "2m", target: 10 }, // Ramp up to 10 VUs
    { duration: "5m", target: 50 }, // Stay at 50 VUs
    { duration: "2m", target: 100 }, // Ramp up to 100 VUs
    { duration: "5m", target: 100 }, // Stay at 100 VUs
    { duration: "2m", target: 0 }, // Ramp down
  ],
  thresholds: {
    http_req_duration: ["p(95)<500"], // 95% of requests under 500ms
    http_req_failed: ["rate<0.05"], // Error rate under 5%
    event_processing_rate: ["rate>0.95"], // 95% success rate
  },
};

// Test data
const testEvents = [
  {
    timestamp: new Date().toISOString(),
    source: "nginx",
    level: "info",
    message: "GET /api/health 200",
    ip: "192.168.1.100",
    user_agent: "k6-loadtest/1.0",
  },
  {
    timestamp: new Date().toISOString(),
    source: "auth",
    level: "warning",
    message: "Failed login attempt",
    ip: "10.0.0.50",
    username: "admin",
  },
  {
    timestamp: new Date().toISOString(),
    source: "firewall",
    level: "alert",
    message: "Suspicious traffic detected",
    ip: "172.16.0.25",
    protocol: "TCP",
    port: 22,
  },
];

const queries = [
  'SELECT COUNT(*) FROM events WHERE level="error"',
  "SELECT source, COUNT(*) FROM events GROUP BY source",
  "SELECT * FROM threats WHERE confidence > 0.8",
  "SELECT ip, COUNT(*) FROM events WHERE timestamp > now() - INTERVAL 1 HOUR GROUP BY ip",
];

export default function () {
  const baseUrl = "http://localhost:8123";
  const grafanaUrl = "http://localhost:3000";

  // Test 1: Health checks
  const healthCheck = http.get(`${baseUrl}/ping`);
  check(healthCheck, {
    "SIEM health check successful": (r) => r.status === 200,
  });

  const grafanaHealth = http.get(`${grafanaUrl}/api/health`);
  check(grafanaHealth, {
    "Grafana health check successful": (r) => r.status === 200,
  });

  // Test 2: Event ingestion
  const eventPayload = JSON.stringify({
    events: [testEvents[Math.floor(Math.random() * testEvents.length)]],
  });

  const eventResponse = http.post(`${baseUrl}/events`, eventPayload, {
    headers: {
      "Content-Type": "application/json",
    },
  });

  const eventProcessed = check(eventResponse, {
    "Event ingestion successful": (r) => r.status === 200 || r.status === 201,
    "Event response time OK": (r) => r.timings.duration < 100,
  });

  eventProcessingRate.add(eventProcessed);

  if (!eventProcessed) {
    errorCounter.add(1);
    console.error(
      `Event ingestion failed: ${eventResponse.status} ${eventResponse.body}`
    );
  }

  // Test 3: Query performance
  const randomQuery = queries[Math.floor(Math.random() * queries.length)];
  const queryStart = Date.now();

  const queryResponse = http.post(
    `${baseUrl}/query`,
    JSON.stringify({
      query: randomQuery,
      format: "JSON",
    }),
    {
      headers: {
        "Content-Type": "application/json",
      },
    }
  );

  const queryTime = Date.now() - queryStart;
  queryResponseTime.add(queryTime);

  check(queryResponse, {
    "Query executed successfully": (r) => r.status === 200,
    "Query response has data": (r) => r.body.length > 0,
    "Query response time acceptable": () => queryTime < 200,
  });

  // Test 4: Dashboard access
  if (__VU % 10 === 0) {
    // Every 10th VU tests dashboard
    const dashboardResponse = http.get(`${grafanaUrl}/d/ultra-siem-overview`);
    check(dashboardResponse, {
      "Dashboard loads successfully": (r) => r.status === 200,
    });
  }

  // Test 5: Threat detection API
  const threatResponse = http.get(`${baseUrl}/threats?limit=10`);
  check(threatResponse, {
    "Threats API responsive": (r) => r.status === 200,
    "Threats data available": (r) => {
      try {
        const data = JSON.parse(r.body);
        return Array.isArray(data) || Array.isArray(data.threats);
      } catch {
        return false;
      }
    },
  });

  // Simulate realistic user behavior
  sleep(Math.random() * 2 + 1); // 1-3 second delay
}

export function handleSummary(data) {
  return {
    "loadtest_summary.json": JSON.stringify(
      {
        test_duration: data.state.testRunDurationMs,
        total_requests: data.metrics.http_reqs.values.count,
        avg_response_time: data.metrics.http_req_duration.values.avg,
        p95_response_time: data.metrics.http_req_duration.values["p(95)"],
        error_rate: data.metrics.http_req_failed.values.rate,
        throughput: data.metrics.http_reqs.values.rate,
        event_processing_rate:
          data.metrics.event_processing_rate?.values?.rate || 0,
        query_avg_time: data.metrics.query_response_time?.values?.avg || 0,
      },
      null,
      2
    ),
  };
}
