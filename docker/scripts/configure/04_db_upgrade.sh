#!/bin/bash
set -e

if [[ -f /config/do_not_init_db ]]; then
    for ver in 2.1.0 2.2.0 2.2.1 2.2.2; do
        if [[ ! -f "/config/psql-app-upgraded.$ver" ]]; then
            echo "===> Running upgrade for version $ver"
            /tmp/upgrade/upgrade_$ver.sh
            touch "/config/psql-app-upgraded.$ver"
        fi
    done
fi
