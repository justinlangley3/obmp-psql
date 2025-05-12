#!/bin/bash
set -e

: "${KAFKA_STARTUP_TIMEOUT:=60}"
INTERVAL=5
elapsed=0

echo "===> Waiting up to ${KAFKA_STARTUP_TIMEOUT}s for Kafka to start ..."

KAFKA_OPTS="-X security.protocol=$KAFKA_SECURITY_PROTOCOL"
if [[ "$KAFKA_SSL" == "true" ]]; then
    [[ -n "$KAFKA_SSL_CERTIFICATE_LOCATION" ]] && KAFKA_OPTS+=" -X ssl.certificate.location=$KAFKA_SSL_CERTIFICATE_LOCATION"
    [[ -n "$KAFKA_SSL_KEY_LOCATION" ]] && KAFKA_OPTS+=" -X ssl.key.location=$KAFKA_SSL_KEY_LOCATION"
    [[ -n "$KAFKA_SSL_CA_LOCATION" ]] && KAFKA_OPTS+=" -X ssl.ca.location=$KAFKA_SSL_CA_LOCATION"
fi


while ! kcat $KAFKA_OPTS -u -b "$KAFKA_BROKERS" -L | grep -q broker; do
    (( elapsed >= KAFKA_STARTUP_TIMEOUT )) && {
        echo "$(cat <<EOF
ERROR: Kafka did not start within ${KAFKA_STARTUP_TIMEOUT}s.
       Ensure Kafka is reachable at ${KAFKA_BROKERS}, and
       if using SSL, enable KAFKA_SSL and set KAFKA_SSL_CA to a
       valid CA certificate path.
       Check the Kafka logs for more detailed information.
EOF
)"
        exit 1
    }
    echo "     Kafka is not ready ... (${elapsed}s elapsed)"
    sleep $INTERVAL
    (( elapsed += INTERVAL ))
done

echo "     Kafka is up."

echo "===> Testing Kafka producer"
echo "test" | timeout 5 kcat $KAFKA_OPTS -b "$KAFKA_BROKERS" -P -t openbmp.parsed.test || {
    echo "ERROR: Kafka producer test failed"
    exit 1
}

echo "===> Testing Kafka consumer"
timeout 5 kcat $KAFKA_OPTS -u -b "$KAFKA_BROKERS" -C -c 1 -o beginning -t openbmp.parsed.test > /dev/null || {
    echo "ERROR: Kafka consumer test failed"
    exit 1
}

echo "===> Kafka is operational."
