#!/bin/bash
# Nightly copies, run by the backup container (compose.yml): at 02:00 UTC the database (pg_dump) and the files
# (the storage volume) go to /backups, which is /opt/collarbell/backups on the server. Copies older than 14 days
# are deleted. A failed copy is logged and tried again the next night.
set -u

while :; do
  now=$(date -u +%s)
  next=$(date -u -d "$(date -u +%F) 02:00" +%s)
  if [ "$next" -le "$now" ]; then
    next=$((next + 86400))
  fi
  sleep $((next - now))

  day=$(date -u +%F)
  if pg_dump --format=custom --file="/backups/db-$day.dump.part" && mv "/backups/db-$day.dump.part" "/backups/db-$day.dump"; then
    echo "$(date -u -Is) database copied: db-$day.dump"
  else
    echo "$(date -u -Is) database copy FAILED" >&2
    rm -f "/backups/db-$day.dump.part"
  fi

  # tar exits with 1 when a file changed while it was read: the storage keeps working during the copy.
  tar -czf "/backups/files-$day.tar.gz.part" -C /storage .
  if [ $? -le 1 ] && mv "/backups/files-$day.tar.gz.part" "/backups/files-$day.tar.gz"; then
    echo "$(date -u -Is) files copied: files-$day.tar.gz"
  else
    echo "$(date -u -Is) files copy FAILED" >&2
    rm -f "/backups/files-$day.tar.gz.part"
  fi

  find /backups -maxdepth 1 \( -name 'db-*.dump' -o -name 'files-*.tar.gz' \) -mtime +13 -delete
done
