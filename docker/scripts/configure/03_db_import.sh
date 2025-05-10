#!/bin/bash
set -e

if [[ ! -f /config/do_not_init_db ]]; then
    echo "===> Initializing the database"

    until psql -c "select 1;" &>/dev/null; do
        echo "    Waiting for Postgres..."
        sleep 5
    done

    echo "===> Loading schemas"
    for file in /usr/local/openbmp/database/*.sql; do
        echo "Loading: $file"
        psql < "$file"
    done

    touch /config/do_not_init_db
fi
