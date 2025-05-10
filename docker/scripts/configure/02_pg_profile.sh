#!/bin/bash
set -e

echo "===> Configuring PostgreSQL Shell Profile"
cat <<EOF > /usr/local/openbmp/pg_profile
export PGUSER=$POSTGRES_USER
export PGPASSWORD=$POSTGRES_PASSWORD
export PGHOST=$POSTGRES_HOST
export PGPORT=$POSTGRES_PORT
export PGDATABASE=$POSTGRES_DB
EOF
