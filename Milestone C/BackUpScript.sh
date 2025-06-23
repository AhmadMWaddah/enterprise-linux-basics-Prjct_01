#!/bin/bash

# Variables
BACKUP_DIR="/backups"
DATE=$(date +%F)
BACKUP_FILE="$BACKUP_DIR/etc-backup-$DATE.tar.gz"

# Create backup
tar -czf "$BACKUP_FILE" /etc

# Log result
if [ $? -eq 0 ]; then
  echo "$(date) Backup successful: $BACKUP_FILE" >> /var/log/backup.log
else
  echo "$(date) Backup failed!" >> /var/log/backup.log
fi


find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +60 -exec rm -f {} \;

