# ⬆️ Ultra SIEM Upgrade Guide

## 📋 Table of Contents
1. [Upgrade Checklist](#upgrade-checklist)
2. [Backup Procedures](#backup-procedures)
3. [Version Upgrade Steps](#version-upgrade-steps)
4. [Schema Migration](#schema-migration)
5. [Rollback Procedures](#rollback-procedures)
6. [Post-Upgrade Validation](#post-upgrade-validation)
7. [Best Practices](#best-practices)
8. [FAQ](#faq)

---

## 1. Upgrade Checklist
- [ ] Review release notes and breaking changes
- [ ] Notify users of planned downtime
- [ ] Backup database and configuration
- [ ] Stop all services
- [ ] Pull latest code
- [ ] Rebuild Docker images
- [ ] Run schema migrations
- [ ] Start services and validate

## 2. Backup Procedures
- **Database:**
  - Run `./backup.sh` (see deployment guide)
- **Configuration:**
  - Run `./config_backup.sh`
- **Dashboards:**
  - Export Grafana dashboards as JSON

## 3. Version Upgrade Steps
```bash
# Stop services
docker-compose down

# Backup data
./backup.sh

# Pull latest code
git pull origin main

# Rebuild images
docker-compose build --no-cache

# Start services
docker-compose up -d
```

## 4. Schema Migration
- Review migration scripts in `scripts/` or `docs/`
- Run ClickHouse migration commands as needed:
```bash
docker exec ultra-siem-clickhouse-1 clickhouse-client --query "ALTER TABLE ultra_siem.threat_events ADD COLUMN IF NOT EXISTS user_agent String;"
```
- Validate schema with test queries

## 5. Rollback Procedures
```bash
# Stop services
docker-compose down

# Restore previous backup
tar -xzf /backups/ultra_siem_backup_YYYYMMDD_HHMMSS.tar.gz -C /tmp

docker exec ultra-siem-clickhouse-1 clickhouse-client --query "RESTORE TABLE ultra_siem.threat_events FROM '/tmp/ultra_siem_backup_YYYYMMDD_HHMMSS'"

# Checkout previous version
git checkout v1.0.0

docker-compose up -d
```

## 6. Post-Upgrade Validation
- Run health checks: `./health_check.sh`
- Validate data integrity with test queries
- Check logs for errors or warnings
- Verify dashboards and alerts

## 7. Best Practices
- Always test upgrades in staging first
- Keep at least 7 days of backups
- Document all changes and migrations
- Monitor system closely after upgrade

## 8. FAQ
- **Q: Can I skip versions?**
  - A: Not recommended. Upgrade sequentially for major releases.
- **Q: What if migration fails?**
  - A: Rollback and contact support.
- **Q: How do I migrate custom dashboards?**
  - A: Export/import JSON via Grafana UI.

---

_Ultra SIEM Upgrade Guide - For safe, reliable upgrades_ 🛡️ 