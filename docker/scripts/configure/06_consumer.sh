#!/bin/bash
set -e

echo "===> Configuring consumer"

if [[ ! -f /config/obmp-psql.yml ]]; then
    unzip -o /usr/local/openbmp/obmp-psql-consumer.jar obmp-psql.yml -d /config
fi

escape() {
    echo "$1" | sed -e 's/[\/&]/\\&/g'
}

POSTGRES_HOST_ESC="$(escape "${POSTGRES_HOST}")"
POSTGRES_PORT_ESC="$(escape "${POSTGRES_PORT}")"
POSTGRES_USER_ESC="$(escape "${POSTGRES_USER}")"
POSTGRES_PASSWORD_ESC="$(escape "${POSTGRES_PASSWORD}")"
POSTGRES_DB_ESC="$(escape "${POSTGRES_DB}")"
POSTGRES_SSL_ESC="$(escape "${POSTGRES_SSL}")"
POSTGRES_SSL_MODE_ESC="$(escape "${POSTGRES_SSL_MODE}")"

KAFKA_BROKERS_ESC="$(escape "${KAFKA_BROKERS}")"
KAFKA_SECURITY_PROTOCOL_ESC="$(escape "${KAFKA_SECURITY_PROTOCOL}")"
KAFKA_SSL_KEYSTORE_LOCATION_ESC="$(escape "${KAFKA_SSL_KEYSTORE_LOCATION}")"
KAFKA_SSL_KEYSTORE_PASSWORD_ESC="$(escape "${KAFKA_SSL_KEYSTORE_PASSWORD}")"
KAFKA_SSL_TRUSTSTORE_PASSWORD_ESC="$(escape "${KAFKA_SSL_TRUSTSTORE_PASSWORD}")"
KAFKA_SSL_TRUSTSTORE_LOCATION_ESC="$(escape "${KAFKA_SSL_TRUSTSTORE_LOCATION}")"

sed -i -e "s/\([ ]*host[ ]*:\).*/\1 \"${POSTGRES_HOST_ESC}:${POSTGRES_PORT_ESC}\"/" \
       -e "s/\([ ]*username[ ]*:\).*/\1 \"${POSTGRES_USER_ESC}\"/" \
       -e "s/\([ ]*password[ ]*:\).*/\1 \"${POSTGRES_PASSWORD_ESC}\"/" \
       -e "s/\([ ]*db_name[ ]*:\).*/\1 \"${POSTGRES_DB_ESC}\"/" \
       -e "s/\([ ]*ssl_enable[ ]*:\).*/\1 \"${POSTGRES_SSL_ESC}\"/" \
       -e "s/\([ ]*ssl_mode[ ]*:\).*/\1 \"${POSTGRES_SSL_MODE_ESC}\"/" \
       -e "s/\([ ]*bootstrap.servers:\).*/\1 \"${KAFKA_BROKERS_ESC}\"/" \
       -e "s/\([ ]*security\.protocol[ ]*:\).*/\1 \"${KAFKA_SECURITY_PROTOCOL_ESC}\"/" \
       -e "s/\([ ]*ssl\.keystore\.location[ ]*:\).*/\1 \"${KAFKA_SSL_KEYSTORE_LOCATION_ESC}\"/" \
       -e "s/\([ ]*ssl\.keystore\.password[ ]*:\).*/\1 \"${KAFKA_SSL_KEYSTORE_PASSWORD_ESC}\"/" \
       -e "s/\([ ]*ssl\.truststore\.password[ ]*:\).*/\1 \"${KAFKA_SSL_TRUSTSTORE_PASSWORD_ESC}\"/" \
       -e "s/\([ ]*ssl\.truststore\.location[ ]*:\).*/\1 \"${KAFKA_SSL_TRUSTSTORE_LOCATION_ESC}\"/" \
       /config/obmp-psql.yml
