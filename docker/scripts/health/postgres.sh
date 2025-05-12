#!/bin/bash
set -e

: "${POSTGRES_STARTUP_TIMEOUT:=60}"
INTERVAL=5
elapsed=0

echo "===> Waiting up to ${POSTGRES_STARTUP_TIMEOUT}s for Postgres to start ..."

while ! psql -c "SELECT 1;" &>/dev/null; do
    (( elapsed >= POSTGRES_STARTUP_TIMEOUT )) && {
        echo "$(cat <<EOF
ERROR: Postgres did not start within ${POSTGRES_STARTUP_TIMEOUT}s.
       Ensure Postgres is reachable at ${POSTGRES_HOST}:${POSTGRES_PORT},
       and that the credentials are correct.
       Check the Postgres logs for more detailed information.
EOF
)"
        exit 1
    }
    echo "     Postgres is not ready ... (${elapsed}s elapsed)"
    sleep $INTERVAL
    (( elapsed += INTERVAL ))
done

echo "     Postgres is up."
