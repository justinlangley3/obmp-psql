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
FROM alpine:3.21 AS build

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
    && mvn clean package \
    && cat /ws/dependency-reduced-pom.xml

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
        logrotate \
        openjdk17-jre \
        postgresql16-client \
        py3-click \
        py3-dnspython \
        py3-ipaddr \
        py3-netaddr \
        py3-pip \
        py3-psycopg2 \
        py3-requests \
        py3-urllib3 \
        rsync \
        rsyslog \
        unzip \
        whois \
        yq-go \
    # clean package cache
    && rm -rf /var/cache/apk/*

# Install extra Python dependencies
RUN pip3 install --break-system-packages pykafka supervisor

# Disable unneeded rsyslog modules
RUN sed -i '/module(load="imklog")/s/^/#/' /etc/rsyslog.conf
RUN sed -i '/module(load="immark")/s/^/#/' /etc/rsyslog.conf

# Ensure cron and rsyslog directories exist
RUN mkdir -p /var/spool/cron/crontabs \
    && chmod -R 600 /var/spool/cron/crontabs

RUN touch /usr/local/version-${VERSION}

# Copy build artifacts to runtime
COPY --from=build /ws/target/obmp-psql-consumer-0.1.0-SNAPSHOT.jar /usr/local/openbmp/obmp-psql-consumer.jar
COPY --from=build /ws/database/  /usr/local/openbmp/database
COPY --chmod=755 --from=build /ws/cron_scripts/gen-whois/*.py /usr/local/openbmp/
COPY --chmod=755 --from=build /ws/cron_scripts/peeringdb/*.py /usr/local/openbmp/
COPY --chmod=755 --from=build /ws/cron_scripts/rpki/*.py /usr/local/openbmp/
COPY --chmod=755 --from=build /ws/scripts/db-ip-import.sh /usr/local/openbmp/
COPY --chmod=755 --from=build /ws/scripts/geo-csv-to-psql.py /usr/local/openbmp/

# Add system configuration files
COPY --chmod=755 docker/files/etc/logrotate.conf /etc/logrotate.conf
COPY --chmod=755 docker/files/etc/supervisord.conf /etc/supervisord.conf

# Add OpenBMP service scripts
COPY --chmod=755 docker/scripts/configure /usr/local/openbmp/configure/
COPY --chmod=755 docker/scripts/health /usr/local/openbmp/servicecheck/
COPY --chmod=755 docker/scripts/jobs /usr/local/openbmp/jobs/
COPY --chmod=755 docker/scripts/upgrade /usr/local/openbmp/database/upgrade/

COPY --chmod=755 docker/scripts/docker-entrypoint.sh /docker-entrypoint.sh

# Define persistent data volumes
VOLUME ["/config"]
VOLUME ["/var/log"]

EXPOSE 9005

WORKDIR /tmp

ENTRYPOINT [ "/docker-entrypoint.sh" ]

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
