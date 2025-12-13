#!/bin/sh
set -eu

# ----------------------
# Default variables
# ----------------------
: "${APP_NAME:=Portainer}"
: "${SERVERS_FILE:=/config/servers}"
: "${PROTO:=https}"
: "${SNAPSHOT_DIR:?SNAPSHOT_DIR not set by wrapper}"

export APP_NAME
# ----------------------
# Portainer Backup
# ----------------------
portainer_backup() {
    (
        host="$1"
        apiKey="$2"

        serverURL="${PROTO}://${host}"

        backup_file="${SNAPSHOT_DIR}/${host}.tar.gz"

        [ "$DRY_RUN" != "true" ] && mkdir -p "$SNAPSHOT_DIR"

        log "Starting TrueNAS backup for $host -> $backup_file"

        if [ "$DRY_RUN" = "true" ]; then
            log "[DRY RUN] Would download backup for $host to $backup_file"
            return 0
        fi

        # Download backup
        curl -sk -X POST \
            -H "X-API-Key: ${apiKey}" \
            -H "Content-Type: application/json; charset=utf-8" \
            -d '{ "password": "" }' \
            "${serverURL}/api/backup" \
            -o "$backup_file" || {
                log_error "${host}: Backup download failed"
                rm -f "$backup_file"
                return 1
            }

        # Validate file is not empty
        [ -s "$backup_file" ] || {
            log_error "$host: Backup file empty"
            rm -f "$backup_file"
            return 1
        }

        chmod 600 "$backup_file"
        log "Backup completed for $host: $backup_file"
    )
}

# ----------------------
# Backup Execution
# ----------------------
[ -f "$SERVERS_FILE" ] || { log_error "Servers file missing: $SERVERS_FILE"; exit 1; }

while IFS=: read -r host apiKey || [ -n "$host" ]; do
    [ -z "$host" ] && continue
    [ -n "$apiKey" ] || { log_error "$host: Missing API key"; continue; }

    portainer_backup "$host" "$apiKey"
done < "$SERVERS_FILE"

# ----------------------
# Debug: keep container running
# ----------------------
if [ "${DEBUG:-false}" = "true" ]; then
    log "DEBUG mode enabled — container will remain running."
    tail -f /dev/null
fi
