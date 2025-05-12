#!/bin/bash
set -e

echo "===> Configuring OpenBMP Environment"
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
export POSTGRES_PORT=${POSTGRES_PORT:-"5432"}
export POSTGRES_USERNAME=${POSTGRES_USERNAME:-"openbmp"}
export POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-"openbmp"}
export POSTGRES_SSL=${POSTGRES_SSL:-"false"}
export POSTGRES_SSL_MODE=${POSTGRES_SSL_MODE:-"require"}

# Kafka
export KAFKA_BROKERS="${KAFKA_BROKERS:-${KAFKA_BOOTSTRAP_SERVERS:-kafka1:9092}}"

# Kafka - Java SSL options
export KAFKA_SSL=${KAFKA_SSL:-"false"}
export KAFKA_SECURITY_PROTOCOL=${KAFKA_SECURITY_PROTOCOL:-"PLAINTEXT"}
export KAFKA_SSL_KEYSTORE_LOCATION=${KAFKA_SSL_KEYSTORE_LOCATION:-}
export KAFKA_SSL_KEYSTORE_PASSWORD=${KAFKA_SSL_KEYSTORE_PASSWORD:-}
export KAFKA_SSL_TRUSTSTORE_LOCATION=${KAFKA_SSL_TRUSTSTORE_LOCATION:-}
export KAFKA_SSL_TRUSTSTORE_PASSWORD=${KAFKA_SSL_TRUSTSTORE_PASSWORD:-}

# Kafka - librdkafka SSL options for kcat (formerly kafkacat)
export KAFKA_SSL_CA_LOCATION=${KAFKA_SSL_CA_LOCATION:-}
export KAFKA_SSL_CERTIFICATE_LOCATION=${KAFKA_SSL_CERTIFICATE_LOCATION:-}
export KAFKA_SSL_KEY_LOCATION=${KAFKA_SSL_KEY_LOCATION:-}


if [[ "$KAFKA_SSL" == "true" ]]; then
    export KAFKA_SECURITY_PROTOCOL="SSL"
fi

if [[ "$KAFKA_SSL" == "true" && ! -f $KAFKA_SSL_CA_LOCATION ]]; then
    echo "ERROR: Kafka SSL is enabled, but KAFKA_SSL_CA_LOCATION file is missing or empty: $KAFKA_SSL_CACERT"
    exit 1
fi

if [[ -z "$KAFKA_BROKERS" ]]; then
    echo "ERROR: KAFKA_BROKERS is not set"
    exit 1
fi
