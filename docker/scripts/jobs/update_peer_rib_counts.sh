#!/bin/bash

PROFILE_SCRIPT="/usr/local/openbmp/pg_profile"
LOG_FILE="/var/log/openbmp/cron-update_peer_rib_counts.log"
LOCK_FILE="/tmp/lock/update_peer_rib_counts.lock"

timestamp=$(date '+%Y-%m-%d %H:%M:%S')

mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$LOCK_FILE")"


if [ -f "$PROFILE_SCRIPT" ]; then
    . "$PROFILE_SCRIPT"
else
    echo "[CRON] $timestamp ERROR: Profile script not found: $PROFILE_SCRIPT" >> "$LOG_FILE"
    exit 1
fi


exec 200>"$LOCK_FILE"
flock -n 200 || {
    echo "[CRON] $timestamp ERROR: Failed to acquire lock on $LOCK_FILE. Another instance may be running." >> "$LOG_FILE"
    exit 1
}
{
    echo "[CRON] $timestamp INFO: Starting update_peer_rib_counts..."
    if output=$(psql -c "SELECT update_peer_rib_counts();" 2>&1); then
        echo "$output"
        echo "[CRON] $timestamp INFO: update_peer_rib_counts completed."
    else
        echo "$output"
        echo "[CRON] $timestamp ERROR: update_peer_rib_counts failed."
    fi
} >> "$LOG_FILE" 2>&1
