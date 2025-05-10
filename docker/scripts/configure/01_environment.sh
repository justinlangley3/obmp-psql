#!/bin/bash
set -e

export SYS_NUM_CPU=$(grep processor /proc/cpuinfo | wc -l)

# JVM defaults
export JAVA_XMX=${JAVA_XMX:-512m}
export JAVA_XMS=${JAVA_XMS:-512m}
export JAVA_EXTRA_OPTS=${JAVA_EXTRA_OPTS:-"\
    -XX:+UseG1GC \
    -XX:+UnlockExperimentalVMOptions \
    -XX:InitiatingHeapOccupancyPercent=30 \
    -XX:G1MixedGCLiveThresholdPercent=30 \
    -XX:MaxGCPauseMillis=200 \
    -XX:ParallelGCThreads=20 \
    -XX:ConcGCThreads=5 \
    -XX:+ExitOnOutOfMemoryError \
    -Duser.timezone=UTC"}

export JAVA_OPTS="-Xmx${JAVA_XMX} -Xms${JAVA_XMS} ${JAVA_EXTRA_OPTS}"

# Postgres
export POSTGRES_DB=${POSTGRES_DB:-"openbmp"}
export POSTGRES_HOST=${POSTGRES_HOST:-"127.0.0.1"}
export POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-"openbmp"}
export POSTGRES_PORT=${POSTGRES_PORT:-"5432"}
export POSTGRES_SSL=${POSTGRES_SSL:-"false"}
export POSTGRES_SSL_MODE=${POSTGRES_SSL_MODE:-"require"}
export POSTGRES_USER=${POSTGRES_USER:-"openbmp"}

# Kafka
export KAFKA_BROKERS="${KAFKA_BROKERS:-${KAFKA_BOOTSTRAP_SERVERS:-kafka:9092}}"
export KAFKA_SSL=${KAFKA_SSL:-"false"}
export KAFKA_SSL_CA=${KAFKA_SSL_CA:-"/etc/openbmp/pki/openbmp_ca.pem"}

if [[ "$KAFKA_SSL" == "true" && ! -f $KAFKA_SSL_CA ]]; then
    echo "ERROR: Kafka SSL is enabled, but CA file is missing or empty: $KAFKA_SSL_CA"
    exit 1
fi

if [[ -z "$KAFKA_BROKERS" ]]; then
    echo "ERROR: KAFKA_BROKERS is not set"
    exit 1
fi
