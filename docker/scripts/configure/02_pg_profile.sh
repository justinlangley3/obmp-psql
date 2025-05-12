#!/bin/bash
set -e

echo "===> Configuring PostgreSQL Shell Profile"
cat <<EOF > /usr/local/openbmp/pg_profile
export PGDATABASE=$POSTGRES_DB
export PGHOST=$POSTGRES_HOST
export PGPORT=$POSTGRES_PORT
export PGUSER=$POSTGRES_USERNAME
export PGPASSWORD=$POSTGRES_PASSWORD
EOF
