#!/bin/bash

PROFILE_SCRIPT="/usr/local/openbmp/pg_profile"
LOG_FILE="/var/log/openbmp/cron-chg_stats_l3vpn_update.log"
LOCK_FILE="/tmp/lock/chg_stats_l3vpn_update.lock"

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$LOCK_FILE")"


if [ -f "$PROFILE_SCRIPT" ]; then
    . "$PROFILE_SCRIPT"
else
    echo "[CRON] $(timestamp) ERROR: Profile script not found: $PROFILE_SCRIPT" >> "$LOG_FILE"
    exit 1
fi


exec 200>"$LOCK_FILE"
flock -n 200 || {
    echo "[CRON] $(timestamp) ERROR: Failed to acquire lock on $LOCK_FILE. Another instance may be running." >> "$LOG_FILE"
    exit 1
}
{
    echo "[CRON] $(timestamp) INFO: Starting update_l3vpn_chg_stats..."
    if output=$(psql -c "SELECT update_l3vpn_chg_stats('5 minute');" 2>&1); then
        echo "[CRON] $(timestamp) INFO: $output"
        echo "[CRON] $(timestamp) INFO: update_l3vpn_chg_stats completed."
    else
        echo "[CRON] $(timestamp) INFO: $output"
        echo "[CRON] $(timestamp) ERROR: update_l3vpn_chg_stats failed."
    fi
} >> "$LOG_FILE" 2>&1
