#!/bin/bash

PROFILE_SCRIPT="/usr/local/openbmp/pg_profile"
LOG_FILE="/var/log/openbmp/cron-update_global_ip_rib.log"
LOCK_FILE="/tmp/lock/global_ip_rib.lock"


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
    echo "[CRON] $timestamp INFO: Starting update_global_ip_rib..."
    if output=$(psql -c "SELECT update_global_ip_rib();" 2>&1); then
        echo "[CRON] $timestamp INFO: update_global_ip_rib completed."
        echo "$output"
    else
        echo "[CRON] $timestamp ERROR: update_global_ip_rib failed."
        echo "$output"
    fi
} >> "$LOG_FILE" 2>&1
