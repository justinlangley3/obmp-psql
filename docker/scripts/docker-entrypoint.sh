#!/bin/bash

# Postgres Backend: Run script
#
# Copyright (c) 2021-2022 Cisco Systems, Inc. and others.  All rights reserved.
#
# Original Author: Tim Evens <tim@evensweb.com>
#
set -e

echo "===> Ensuring directories exist"
mkdir -p /config
mkdir -p /tmp/lock
mkdir -p /var/log/openbmp
mkdir -p /var/log/supervisor

echo "===> Removing stale lock files"
rm -f /tmp/lock/*

echo "===> Removing stale PID files"
rm -f /var/run/supervisord.pid
rm -f /var/run/rsyslogd.pid
rm -f /var/run/cron.pid

# configure the OpenBMP runtime environment
source /usr/local/openbmp/configure/01_generate_config
source /usr/local/openbmp/configure/02_environment
source /usr/local/openbmp/configure/03_pg_profile
source /usr/local/openbmp/pg_profile

# ensure required services are running
source /usr/local/openbmp/servicecheck/validate-postgres
source /usr/local/openbmp/servicecheck/validate-kafka

# setup database and cron jobs
/usr/local/openbmp/configure/04_db_import
/usr/local/openbmp/configure/05_db_upgrade
/usr/local/openbmp/configure/06_cron

# Handle optional services
if [[ "${OPENBMP_RPKI_ENABLED}" == "1" ]]; then
    /usr/local/openbmp/jobs/enable_rpki.sh &
    echo "===> Enabling RPKI ($!) in the background"
else
    echo "===> OPENBMP_RPKI_ENABLED=${OPENBMP_RPKI_ENABLED} - skipped RPKI job"
fi

if [[ "${OPENBMP_DBIP_ENABLED}" == "1" ]]; then
    /usr/local/openbmp/jobs/enable_dbip.sh &
    echo "===> Enabling DBIP ($!) in the background"
else
    echo "===> OPENBMP_DBIP_ENABLED=${OPENBMP_DBIP_ENABLED} - skipped DBIP job"
fi

if [[ "${OPENBMP_IRR_ENABLED}"  == "1" ]]; then
    /usr/local/openbmp/jobs/enable_irr.sh &
    echo "===> Enabling IRR ($!) in the background"
else
    echo "===> OPENBMP_IRR_ENABLED=${OPENBMP_IRR_ENABLED} - skipped IRR job"
fi

echo "===> Starting supervisord, and handing over control"

if [[ $# -eq 0 ]]; then
  echo "ERROR: No CMD to execute. Exiting."
  exit 1
fi

exec "$@"
