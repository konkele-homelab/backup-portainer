#!/bin/sh
set -eu

# ----------------------
# Default variables
# ----------------------
: "${APP_NAME:=Portainer}"
: "${BACKUP_DEST:=/backup}"
: "${KEEP_DAYS:=30}"
: "${DRY_RUN:=false}"
: "${TZ:=America/Chicago}"
: "${TIMESTAMP:=$(date '+%Y-%m-%d_%H-%M-%S')}"

: "${SERVERS_FILE:=/config/servers}"
: "${PROTO:=https}"

export APP_NAME
# ----------------------
# Portainer Backup
# ----------------------
portainer_backup() {
    host="$1"
    apiKey="$2"

    # Ensure backup destination exists
    mkdir -p "$BACKUP_DEST"
    serverURL="${PROTO}://${host}"

    # Build backup filename
    backup="${BACKUP_DEST}/${host}-${TIMESTAMP}.tar.gz"

    log "Starting backup for ${host}"

    # Dry run
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would perform backup for ${host}, saving to ${backup}"
        return 0
    fi

    # Request configuration backup
    if ! curl -sk -X POST \
        -H "X-API-Key: ${apiKey}" \
        -H "Content-Type: application/json; charset=utf-8" \
        -d '{ "password": "" }' \
        "${serverURL}/api/backup" \
        -o "$backup"
    then
        log_error "${host}: Backup failed (API error)"
        rm -f "$backup"
        return 1
    fi

    # Validate output file.
    if [ ! -s "$backup" ]; then
        log_error "${host}: Backup file is missing or empty"
        rm -f "$backup"
        return 1
    fi

    # Secure file
    chmod 600 "$backup"

    log "Backup saved: ${backup}"
}

# ----------------------
# Backup Execution
# ----------------------
if [ ! -f "$SERVERS_FILE" ]; then
    log_error "Servers file not found: ${SERVERS_FILE}"
    exit 1
fi

# Read server list line by line
while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines
    [ -z "$line" ] && continue

    # Split host and API key using POSIX tools
    host=$(echo "$line" | awk -F: '{print $1}')
    api=$(echo "$line" | awk -F: '{print $2}')

    if [ -z "$host" ] || [ -z "$api" ]; then
        log_error "Invalid entry in servers file: ${line}"
        continue
    fi

    # Run backup
    portainer_backup "$host" "$api"

    # Prune old backups
    prune_by_timestamp "${host}-*" "$KEEP_DAYS" "$BACKUP_DEST"

done < "$SERVERS_FILE"

# ----------------------
# Debug: keep container running
# ----------------------
if [ "${DEBUG:-false}" = "true" ]; then
    log "DEBUG mode enabled — container will remain running."
    tail -f /dev/null
fi
