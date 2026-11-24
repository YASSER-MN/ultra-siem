# Ultra SIEM

A SIEM (security information and event management) prototype written in Rust and Go.
It collects security logs, stores them, runs detection rules on them and shows the results in dashboards.

I built this project during my 3-month internship at CHU Hassan II (university hospital, Fès, Morocco), from May to July 2025, and tested it on the hospital's logs.

## Architecture

```
collectors -> Rust core -> NATS -> Go bridge -> ClickHouse -> Grafana
```

| Part | Technology | Role |
|---|---|---|
| `rust-core/` | Rust | Log ingestion, parsing and detection |
| `go-services/` | Go | Bridge that reads events from NATS and writes them to ClickHouse |
| `clickhouse/` | ClickHouse | Storage and queries on events |
| `grafana/` | Grafana | Dashboards and alerts |
| `collectors/` | Scripts | Log collection from the sources |
| `zig-query/` | Zig | Experimental query module |

## Detection

The Rust core applies four layers of detection:

1. **Signatures**: pattern matching on known attack strings.
2. **Threat indicators**: comparison with lists of known malicious IP addresses and domains.
3. **Correlation**: links between related events in a 5-minute window.
4. **Statistical anomalies**: events that deviate from the usual activity.

## Run it locally

Requirements: Docker, Rust and Go.

```bash
# 1. Start NATS, ClickHouse and Grafana
docker compose -f docker-compose.simple.yml up -d

# 2. Start the Rust core
cd rust-core && cargo run --release --bin ultra-siem-core

# 3. Start the Go bridge (in a second terminal)
cd go-services && go run .
```

Grafana is then available at http://localhost:3000 and ClickHouse at http://localhost:8123.

The Docker Compose files use default passwords. They are for local development only. Change them before you deploy anything.

## Status

This is an internship prototype, not a product. It has no published benchmark and it is not ready for production use.

## License

See [LICENSE](LICENSE).
