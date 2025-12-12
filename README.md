# Portainer Backup Docker Container

This repository contains a minimal Docker image to automate Portainer configuration backups using a shell script. The container supports environment-based configuration, UID/GID assignment, and secure storage of API credentials.

---

## Features

- Backup multiple Portainer hosts using API keys  
- Exports configuration as `.tar.gz` backups  
- Configurable backup directory and retention period  
- Automatic pruning of old backups  
- Runs as non-root user with configurable UID/GID  
- Lightweight Alpine base image  
- Optional dry-run mode for testing  

---

## Environment Variables

| Variable          | Default                | Description |
|-------------------|------------------------|-------------|
| SERVERS_FILE      | `/config/servers`      | Path to file or secret containing Portainer credentials (`HOST:API_KEY`) |
| PROTO             | `https`                | Protocol to use when contacting Portainer (`http`/`https`) |
| DEBUG             | `false`                | If `true`, keep container running forever for debug purposes |
| BACKUP_DEST       | `/backup`              | Directory where backup output is stored |
| LOG_FILE          | `/var/log/backup.log`  | Persistent log file |
| EMAIL_ON_SUCCESS  | `false`                | Enable sending email when backup succeeds (`true`/`false`) |
| EMAIL_ON_FAILURE  | `false`                | Enable sending email when backup fails (`true`/`false`) |
| EMAIL_TO          | `admin@example.com`    | Recipient of status notifications |
| EMAIL_FROM        | `backup@example.com`   | Sender of status notifications |
| APP_NAME          | `Portainer`            | Application name used in logs or notifications |
| APP_BACKUP        | `/default.sh`          | Path to backup script executed by the container |
| KEEP_DAYS         | `30`                   | Number of days to retain backups |
| USER_UID          | `3000`                 | UID of backup user |
| USER_GID          | `3000`                 | GID of backup user |
| DRY_RUN           | `false`                | If `true`, backup logic logs actions but does not backup or prune anything |
| TZ                | `America/Chicago`      | Timezone used for timestamps |

---

## Servers File Format

The servers file should contain lines in the following format:
```
hostname_or_ip:API_KEY
```
Example:
```
portainer.example.com:abc123secretkey
192.168.1.50:def456apikey
```

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

---

### Usage

1. Create the Swarm secret:
```bash
docker secret create backup-portainer ./servers
```
2. Deploy the stack:
```bash
docker stack deploy -c docker-compose.yml backup-portainer_stack
```

---

## Local Testing

For testing without Swarm, you can mount the servers file and run the container directly:
```bash
docker run -it --rm \
  -v /backup:/backup \
  -v ./servers:/config/servers \
  -e SCRIPT_NAME=backup-portainer.sh \
  your-dockerhub-username/backup-portainer:latest
```

---

## Logging

- Each backup logs start time, end time, and backup file path  
- Pruned backups are also logged  
- Errors are logged to `stderr`  

---

## Notes

- Ensure your API keys have proper permissions to retrieve backups.  
- The container defaults to `/backup` as the backup directory.  
- Modify `KEEP_DAYS` to retain backups for a longer period if needed.  
- Dry-run mode can be used to verify configuration without creating backups.

