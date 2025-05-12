#!/bin/bash
set -e

echo "===> Configuring consumer"

if [[ ! -f /config/obmp-psql.yml ]]; then
    unzip -o /usr/local/openbmp/obmp-psql-consumer.jar obmp-psql.yml -d /config
fi

escape() {
    echo "$1" | sed -e 's/[\/&]/\\&/g'
}

# replacement variables need to be escaped
POSTGRES_PASSWORD_ESCAPED="$(escape "${POSTGRES_PASSWORD}")"
KAFKA_SSL_KEYSTORE_LOCATION_ESCAPED="$(escape "${KAFKA_SSL_KEYSTORE_LOCATION}")"
KAFKA_SSL_KEYSTORE_PASSWORD_ESCAPED="$(escape "${KAFKA_SSL_KEYSTORE_PASSWORD}")"
KAFKA_SSL_TRUSTSTORE_PASSWORD_ESCAPED="$(escape "${KAFKA_SSL_TRUSTSTORE_PASSWORD}")"
KAFKA_SSL_TRUSTSTORE_LOCATION_ESCAPED="$(escape "${KAFKA_SSL_TRUSTSTORE_LOCATION}")"

sed -i -e "s/\([ ]*host[ ]*:\).*/\1 \"${POSTGRES_HOST}:${POSTGRES_PORT}\"/" \
       -e "s/\([ ]*username[ ]*:\).*/\1 \"${POSTGRES_USERNAME}\"/" \
       -e "s/\([ ]*password[ ]*:\).*/\1 \"${POSTGRES_PASSWORD_ESCAPED}\"/" \
       -e "s/\([ ]*db_name[ ]*:\).*/\1 \"${POSTGRES_DB}\"/" \
       -e "s/\([ ]*ssl_enable[ ]*:\).*/\1 \"${POSTGRES_SSL}\"/" \
       -e "s/\([ ]*ssl_mode[ ]*:\).*/\1 \"${POSTGRES_SSL_MODE}\"/" \
       -e "s/\([ ]*bootstrap\.servers:\).*/\1 \"${KAFKA_BROKERS}\"/" \
       -e "s/\([ ]*security\.protocol[ ]*:\).*/\1 \"${KAFKA_SECURITY_PROTOCOL}\"/" \
       -e "s/\([ ]*ssl\.keystore\.location[ ]*:\).*/\1 \"${KAFKA_SSL_KEYSTORE_LOCATION_ESCAPED}\"/" \
       -e "s/\([ ]*ssl\.keystore\.password[ ]*:\).*/\1 \"${KAFKA_SSL_KEYSTORE_PASSWORD_ESCAPED}\"/" \
       -e "s/\([ ]*ssl\.truststore\.password[ ]*:\).*/\1 \"${KAFKA_SSL_TRUSTSTORE_PASSWORD_ESCAPED}\"/" \
       -e "s/\([ ]*ssl\.truststore\.location[ ]*:\).*/\1 \"${KAFKA_SSL_TRUSTSTORE_LOCATION_ESCAPED}\"/" \
       /config/obmp-psql.yml
