# Portainer Backup Docker Container

This repository contains a minimal Docker image to automate **Portainer configuration backups** using a shell-based backup system. The container supports environment-based configuration, UID/GID assignment, snapshot retention policies, Swarm secrets, and email notifications.

The design follows a **wrapper + application script** model, making it easy to reuse common backup logic across multiple platforms.

---

## Features

- Backup multiple Portainer hosts using API keys
- Creates a **single timestamped snapshot directory per run** containing all host backups.
- Exports configuration as `.tar.gz` backups
- Swarm secret support for storing credentials.
- Pluggable backup retention policies: **GFS**, **FIFO**, **Calendar**.
- Automatic creation of daily, weekly, and monthly snapshots (for GFS).
- Runs as non-root user with configurable UID/GID.
- Lightweight Alpine base image.
- Email notifications on success and/or failure.
- **DRY-RUN mode** for safe testing without modifying data.

---

## Retention Policies

- **GFS (Grandfather-Father-Son)**: Retain daily, weekly, and monthly snapshots.
- **FIFO (First-In-First-Out)**: Keep a fixed number of most recent snapshots.
- **Calendar**: Keep snapshots for a fixed number of days.

Retention behavior is controlled via environment variables and operates on **snapshot directories**, not individual files.

---

## Directory Layout

```
/backup/
└── daily/
    └── 2025-12-13_12-00-00/
        ├── portainer.example.com.tar.gz
        └── 192.168.1.50.tar.gz
    └── 2025-12-14_12-00-00/
        ├── portainer.example.com.tar.gz
        └── 192.168.1.50.tar.gz
└── weekly/
└── monthly/
└── latest -> daily/2025-12-14_12-00-00

```

## Environment Variables

| Variable            | Default                                | Description |
|---------------------|----------------------------------------|-------------|
| APP_NAME            | `Portainer`                            | Application name in status notification |
| APP_BACKUP          | `/usr/local/bin/backup-portainer.sh`   | Path to backup script executed by the container |
| PROTO               | `https`                                | Protocol to use when contacting Portainer (`http`/`https`) |
| SERVERS_FILE        | `/config/servers`                      | Path to file or secret containing Portainer credentials (`FQDN:API_KEY`) |
| BACKUP_DEST         | `/backup`                              | Directory where backup output is stored |
| DRY_RUN             | `false`                                | If `true`, logs actions but does not write or prune backups |
| LOG_FILE            | `/var/log/backup.log`                  | Persistent log file |
| EMAIL_ON_SUCCESS    | `false`                                | Send email when backup succeeds |
| EMAIL_ON_FAILURE    | `false`                                | Send email when backup fails |
| EMAIL_TO            | `admin@example.com`                    | Recipient of status notifications |
| EMAIL_FROM          | `backup@example.com`                   | Sender address for email notifications |
| SMTP_SERVER         | `smtp.example.com`                     | SMTP server hostname or IP |
| SMTP_PORT           | `25`                                   | SMTP server port |
| SMTP_TLS            | `off`                                  | Enable TLS (`off` / `on`) |
| SMTP_USER           | *(empty)*                              | SMTP username |
| SMTP_USER_FILE      | *(empty)*                              | File or secret containing SMTP username |
| SMTP_PASS           | *(empty)*                              | SMTP password |
| SMTP_PASS_FILE      | *(empty)*                              | File or secret containing SMTP password |
| RETENTION_POLICY    | `gfs`                                  | Retention strategy: `gfs`, `fifo`, or `calendar` |
| GFS_DAILY           | `7`                                    | Number of daily snapshots to keep (GFS) |
| GFS_WEEKLY          | `4`                                    | Number of weekly snapshots to keep (GFS) |
| GFS_MONTHLY         | `6`                                    | Number of monthly snapshots to keep (GFS) |
| FIFO_COUNT          | `14`                                   | Number of snapshots to retain (FIFO) |
| CALENDAR_DAYS       | `30`                                   | Number of days to retain snapshots (Calendar) |
| TZ                  | `America/Chicago`                      | Timezone used for timestamps |
| USER_UID            | `3000`                                 | UID of backup user |
| USER_GID            | `3000`                                 | GID of backup user |
| DEBUG               | `false`                                | If `true`, container remains running after backup |

---

## Swarm Secret Format

The servers file (typically stored as a Docker Swarm secret) must contain one host per line:

```
FQDN:API_KEY
```
Example:
```
portainer.example.com:abc123secretkey
192.168.1.50:def456apikey
```

> **Security Note**  
> The servers file contains plaintext credentials. Always store it as a Docker secret or restrict file permissions appropriately.

---

## Docker Compose Example (Swarm)

```yaml
version: "3.9"

services:
  backup-portainer:
    image: your-dockerhub-username/backup-portainer:latest
    environment:
      BACKUP_DEST: /backup
      SERVERS_FILE: /run/secrets/backup-portainer
      SECRETSEED: true
      RETENTION_POLICY: gfs
      GFS_DAILY: 7
      GFS_WEEKLY: 4
      GFS_MONTHLY: 6
      EMAIL_ON_FAILURE: "true"
      EMAIL_TO: admin@example.com
      DRY_RUN: "false"
    volumes:
      - /backup:/backup
    secrets:
      - backup-portainer
    deploy:
      mode: replicated
      replicas: 1
      restart_policy:
        condition: none

secrets:
  backup-portainer:
    external: true
```

## Local Testing

To test without Swarm:

```bash
docker run -it --rm \
  -v /backup:/backup \
  -v ./servers:/config/servers \
  -e APP_BACKUP=/usr/local/bin/backup-portainer.sh \
  -e RETENTION_POLICY=gfs \
  -e DRY_RUN=true \
  your-dockerhub-username/backup-portainer:latest
```

Change `RETENTION_POLICY` to `fifo` or `calendar` to test other modes.

---

## Failure Semantics

- If **any host backup fails**, the application script exits non-zero.
- On failure:
  - The snapshot directory is preserved for inspection.
  - Retention policies are **not applied**.
  - Failure notifications are sent if enabled.

---

## Logging

- Logs each backup start, completion, and file paths.
- Logs pruning actions according to the selected retention policy.
- Errors are written to `stderr`.

---

## Notes

- UID/GID customization ensures backup files match host filesystem ownership.
- Pluggable retention policies allow flexible backup management:
  - **GFS**: Daily/weekly/monthly snapshots with `latest` symlink.
  - **FIFO**: Keeps only the last `FIFO_COUNT` snapshots.
  - **Calendar**: Keeps all snapshots for a specified number of days.
- Use `DRY_RUN=true` to safely test backup and retention behavior without modifying files.
