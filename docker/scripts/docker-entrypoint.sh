#!/bin/bash

# Postgres Backend: Run script
#
# Copyright (c) 2021-2022 Cisco Systems, Inc. and others.  All rights reserved.
#
# Original Author: Tim Evens <tim@evensweb.com>
#
set -e

echo "===> Ensuring directories exist"
mkdir -p /tmp/lock
mkdir -p /var/log/openbmp
mkdir -p /var/log/supervisor

echo "===> Removing stale lock files"
rm -f /tmp/lock/*

echo "===> Removing stale PID files"
rm -f /var/run/supervisord.pid
rm -f /var/run/rsyslogd.pid
rm -f /var/run/cron.pid

# configure environment variables
source /usr/local/openbmp/configure/01_environment.sh
source /usr/local/openbmp/configure/02_pg_profile.sh
source /usr/local/openbmp/pg_profile

# ensure required services are running
/usr/local/openbmp/servicecheck/postgres.sh
/usr/local/openbmp/servicecheck/kafka.sh

# configure database, cron jobs, and consumer
/usr/local/openbmp/configure/03_db_import.sh
/usr/local/openbmp/configure/04_db_upgrade.sh
/usr/local/openbmp/configure/05_cron.sh
/usr/local/openbmp/configure/06_consumer.sh

# Handle optional services
if [[ "${ENABLE_RPKI}" == "1" ]]; then
    /usr/local/openbmp/jobs/enable_rpki.sh &
    echo "===> Enabling RPKI ($!) in the background"
else
    echo "===> ENABLE_RPKI=${ENABLE_RPKI} - skipped RPKI job"
fi

if [[ "${ENABLE_DBIP}" == "1" ]]; then
    /usr/local/openbmp/jobs/enable_dbip.sh &
    echo "===> Enabling DBIP ($!) in the background"
else
    echo "===> ENABLE_DBIP=${ENABLE_DBIP} - skipped DBIP job"
fi

if [[ "${ENABLE_IRR}"  == "1" ]]; then
    /usr/local/openbmp/jobs/enable_irr.sh &
    echo "===> Enabling IRR ($!) in the background"
else
    echo "===> ENABLE_IRR=${ENABLE_IRR} - skipped IRR job"
fi

echo "===> Starting supervisord, and handing over control"

if [[ $# -eq 0 ]]; then
  echo "ERROR: No CMD to execute. Exiting."
  exit 1
fi

exec "$@"
