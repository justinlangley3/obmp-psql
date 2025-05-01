# Postgres Backend: openbmp/psql-app
#
# Copyright (c) 2021-2022 Cisco Systems, Inc. and others.  All rights reserved.
#
# Original Author: Tim Evens <tim@openbmp.org>
#
#   Use buildkit - either via export DOCKER_BUILDKIT=1 or by using buildx cli
#
#   Run the following from the obmp-psql project root:
#
#   docker buildx build \
#     --platform linux/amd64 \
#     --progress=plain \
#     --build-arg VERSION=2.2.2 \
#     -f docker/Dockerfile \
#     -t openbmp/psql-app:2.2.2 \
#     .

# -----------------------------------------------
# stage: Build
# -----------------------------------------------
FROM alpine:3.20 AS build

ARG VERSION=0.0.0

# Proxy servers
#ENV http_proxy http://proxy:80
#ENV https_proxy http://proxy:80
#ENV no_proxy "domain.com"

WORKDIR /ws
COPY . .

# Install build dependencies (Java JDK and Maven)
RUN apk update \
    && apk add --no-cache \
         openjdk17-jdk maven git

# Build the Java application and dependencies
RUN mv obmp-java-api-message /tmp/obmp-java-api-message \
    && cd /tmp/obmp-java-api-message \
    && mvn clean install \
    && cd /ws/ \
    && mvn clean package

# Clean up packages and build cache
RUN apk del openjdk17-jdk maven git \
    && rm -rf /var/cache/apk/* /ws/obmp-java-api-message

# -----------------------------------------------
# stage: Final container
# -----------------------------------------------
FROM alpine:3.21

# Install runtime dependencies
RUN apk update \
    && apk add --no-cache \
        bash \
        cronie \
        curl \
        kafkacat \
        openjdk17-jre \
        py3-dnspython \
        py3-click \
        py3-ipaddr \
        py3-netaddr \
        py3-pip \
        py3-psycopg2 \
        py3-requests \
        py3-urllib3 \
        postgresql16-client \
        rsync \
        rsyslog \
        whois \
        unzip \
    # clean package cache
    && rm -rf /var/cache/apk/*

# Install extra Python dependencies
RUN pip3 install --break-system-packages pykafka

# Disable this rsyslog module -- containers have no /dev/log device
RUN sed -i '/module(load="imklog")/s/^/#/' /etc/rsyslog.conf

# Ensure cron and rsyslog directories exist
RUN mkdir -p /var/spool/cron/crontabs \
    && chmod -R 600 /var/spool/cron/crontabs \
    && mkdir -p /var/log/ \
    && touch /var/log/cron.log /var/log/syslog /var/log/openbmpd.log

# Copy build artifacts to runtime
COPY --from=build /ws/target/obmp-psql-consumer-0.1.0-SNAPSHOT.jar /usr/local/openbmp/obmp-psql-consumer.jar
COPY --from=build /ws/database/  /usr/local/openbmp/database
COPY --chmod=755 --from=build /ws/cron_scripts/gen-whois/*.py /usr/local/openbmp/
COPY --chmod=755 --from=build /ws/cron_scripts/peeringdb/*.py /usr/local/openbmp/
COPY --chmod=755 --from=build /ws/cron_scripts/rpki/*.py /usr/local/openbmp/
COPY --chmod=755 --from=build /ws/scripts/geo-csv-to-psql.py /usr/local/openbmp/
COPY --chmod=755 --from=build /ws/scripts/db-ip-import.sh /usr/local/openbmp/

RUN touch /usr/local/version-${VERSION}

# Add runtime scripts
COPY --chmod=755 docker/scripts/run /usr/local/bin
COPY --chmod=755 docker/upgrade /tmp/upgrade

# Define persistent data volumes
VOLUME ["/config"]

EXPOSE 9005

WORKDIR /tmp

CMD ["/usr/local/bin/run"]
