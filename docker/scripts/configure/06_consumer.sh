#!/bin/bash
set -e

echo "===> Configuring consumer"

if [[ ! -f /config/obmp-psql.yml ]]; then
    unzip -o /usr/local/openbmp/obmp-psql-consumer.jar obmp-psql.yml -d /config
fi

sed -i -e "s/\([ ]*bootstrap.servers:\).*/\1 \"${KAFKA_BROKERS}\"/" \
       -e "s/\([ ]*host[ ]*:\).*/\1 \"${POSTGRES_HOST}:${POSTGRES_PORT}\"/" \
       -e "s/\([ ]*username[ ]*:\).*/\1 \"${POSTGRES_USER}\"/" \
       -e "s/\([ ]*password[ ]*:\).*/\1 \"${POSTGRES_PASSWORD}\"/" \
       -e "s/\([ ]*db_name[ ]*:\).*/\1 \"${POSTGRES_DB}\"/" \
       -e "s/\([ ]*ssl_enable[ ]*:\).*/\1 \"${POSTGRES_SSL}\"/" \
       -e "s/\([ ]*ssl_mode[ ]*:\).*/\1 \"${POSTGRES_SSL_MODE}\"/" \
       /config/obmp-psql.yml
