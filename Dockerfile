ARG UPSTREAM_TAG=latest
FROM registry.lab.konkel.us/backup-base:${UPSTREAM_TAG}

# Portainer Backup Script
ARG SCRIPT_FILE=backup-portainer.sh

# Install Application Specific Backup Script
ENV APP_BACKUP=/usr/local/bin/${SCRIPT_FILE}
COPY ${SCRIPT_FILE} ${APP_BACKUP}
RUN chmod +x ${APP_BACKUP}
