# Bridge (Go)

This service connects NATS to ClickHouse.

It subscribes to two NATS subjects, `security.events` and `security.alerts`, groups the messages in batches and inserts them into the ClickHouse tables `security_events` and `threat_alerts`.

## Configuration

The settings are in `config.yaml`: NATS address, ClickHouse address and database, batch size and batch timeout, number of workers and retries.

The ClickHouse user and password in `config.yaml` are defaults for local development. Change them before any deployment.

## Run

```bash
cd go-services/bridge
go run .
```

NATS and ClickHouse must be running first (see the main README).
