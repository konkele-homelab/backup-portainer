# Default Arguments for Upstream Base Image
ARG UPSTREAM_REGISTRY=registry.example.com
ARG UPSTREAM_TAG=latest

# Use Upstream Base Image
FROM ${UPSTREAM_REGISTRY}/backup-base:${UPSTREAM_TAG}

# App Specific Backup Script
ARG SCRIPT_FILE=backup-portainer.sh

# Install Application Specific Backup Script
ENV APP_BACKUP=/usr/local/bin/${SCRIPT_FILE}
COPY ${SCRIPT_FILE} ${APP_BACKUP}
RUN chmod +x ${APP_BACKUP}
