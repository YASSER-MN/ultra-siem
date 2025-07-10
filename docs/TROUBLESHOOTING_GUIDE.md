# 🛠️ Ultra SIEM Troubleshooting Guide

## 📋 Table of Contents
1. [General Diagnostics](#general-diagnostics)
2. [Service Startup Issues](#service-startup-issues)
3. [Rust Core Engine Issues](#rust-core-engine-issues)
4. [Go Data Processor Issues](#go-data-processor-issues)
5. [Zig Query Engine Issues](#zig-query-engine-issues)
6. [ClickHouse Database Issues](#clickhouse-database-issues)
7. [NATS Messaging Issues](#nats-messaging-issues)
8. [Grafana Dashboard Issues](#grafana-dashboard-issues)
9. [Docker & Compose Issues](#docker--compose-issues)
10. [Upgrade & Migration Issues](#upgrade--migration-issues)
11. [Performance Issues](#performance-issues)
12. [Security & Access Issues](#security--access-issues)
13. [Contact & Support](#contact--support)

---

## 1. General Diagnostics
- Check service status: `docker-compose ps`
- View logs: `docker-compose logs -f [service]`
- Check resource usage: `docker stats`
- Check disk space: `df -h`
- Check memory: `free -h`

## 2. Service Startup Issues
- **Service not starting:**
  - Check logs for errors
  - Ensure ports are not in use
  - Verify Docker/Compose version
  - Check `.env` configuration
- **Container exits immediately:**
  - Run with `docker-compose up` (no `-d`) to see errors
  - Check for missing dependencies

## 3. Rust Core Engine Issues
- **Build errors:**
  - Run `cargo clean && cargo build --release`
  - Ensure Rust toolchain is up to date
- **Runtime errors:**
  - Check `rust-core/logs/` for error logs
  - Run with `RUST_LOG=debug` for verbose output
- **Performance issues:**
  - Profile with `cargo flamegraph`
  - Tune thread count in `.env`

## 4. Go Data Processor Issues
- **Build errors:**
  - Run `go mod tidy`
  - Ensure Go version is 1.21 or newer
- **Runtime errors:**
  - Check logs for panics or nil pointer errors
  - Run with `GO_LOG_LEVEL=debug`
- **NATS/ClickHouse connection errors:**
  - Verify NATS/ClickHouse are running and accessible
  - Check credentials in `.env`

## 5. Zig Query Engine Issues
- **Build errors:**
  - Run `zig build clean && zig build`
  - Ensure Zig version is 0.11.0 or newer
- **Runtime errors:**
  - Check for segmentation faults (usually memory issues)
  - Run with debug flags: `zig build -Drelease-safe=false`

## 6. ClickHouse Database Issues
- **Cannot connect:**
  - Check `clickhouse/config.xml` and `users.xml`
  - Ensure port 9000/8123 is open
- **Table not found:**
  - Run schema init script (see deployment guide)
- **Slow queries:**
  - Run `OPTIMIZE TABLE` and check indexes

## 7. NATS Messaging Issues
- **Cannot connect:**
  - Check `config/nats.conf`
  - Ensure port 4222 is open
- **Auth errors:**
  - Verify NATS credentials in `.env`
- **Message loss:**
  - Check NATS JetStream configuration

## 8. Grafana Dashboard Issues
- **Cannot login:**
  - Reset admin password in `.env`
- **No data:**
  - Check ClickHouse datasource config
  - Ensure data is being ingested
- **Dashboard errors:**
  - Check JSON provisioning files for syntax

## 9. Docker & Compose Issues
- **Image build fails:**
  - Run `docker system prune -f`
  - Check Dockerfile paths and permissions
- **Network issues:**
  - Check `docker network ls` and `docker network inspect`
- **Volume issues:**
  - Ensure correct volume mounts in `docker-compose.yml`

## 10. Upgrade & Migration Issues
- **Upgrade fails:**
  - Backup before upgrade
  - Run `docker-compose down` before `git pull`
  - Rebuild images: `docker-compose build --no-cache`
- **Schema migration errors:**
  - Run migration scripts manually (see deployment guide)

## 11. Performance Issues
- **High CPU/memory:**
  - Check for memory leaks (see monitoring guide)
  - Tune buffer/thread settings in `.env`
- **Slow ingestion/queries:**
  - Scale out services
  - Optimize ClickHouse tables

## 12. Security & Access Issues
- **Auth failures:**
  - Check JWT secret and user roles
- **TLS/SSL errors:**
  - Verify certificate paths and permissions
- **Firewall blocks:**
  - Check UFW/iptables rules

## 13. Contact & Support
- **GitHub Issues:** https://github.com/YASSER-MN/ultra-siem/issues
- **Discussions:** https://github.com/YASSER-MN/ultra-siem/discussions
- **Email:** yassermn238@gmail.com

---

_Ultra SIEM Troubleshooting Guide - For enterprise reliability_ 🛡️ 