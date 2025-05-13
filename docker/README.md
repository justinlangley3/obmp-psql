# OpenBMP Postgres Application Container
This container is the main application container for OpenBMP and PostgreSQL. 

It provides:

* Alpine Base Image
* OpenBMP Consumer (Java application) - Handles writes to PostgreSQL
* Runtime (e.g. Java, supervisord, core libraries, etc.)
* Command-line tools (e.g. bash, kcat, psql, yq, etc.)
* RPKI validator import/sync 
* IRR and peering DB import/sync
* Schedules and runs the metric DB functions
* Schedules and runs the DB timescale DB chunk drops
* A generator for the configuration file
* A (generated) configuration file

## Building
See the [Dockerfile](Dockerfile) notes for build instructions.

## Running

### Entrypoint

The entrypoint for this container, [docker-entrypoint.sh](scripts/docker-entrypoint.sh), completes several tasks during startup:
1. Creates required directories
2. Removes stale PID and lock files
3. Ensures postgres is reachable
4. Ensures Kafka is reachable and runs Kafka validation tests
5. Creates the OpenBMP database and tables if they do not exist
6. Upgrades the database if required
7. Configures cron jobs
8. Configures the psql-app consumer
9. Executes the container CMD

> :bulb: The default CMD is `["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]`

### Supervisord

The container uses [supervisord](http://supervisord.org/) to manage the OpenBMP consumer processes.
The supervisord configuration file is [supervisord.conf](files/etc/supervisord.conf) and installs to the `/etc` directory.

Services:
* `crond` - Runs the OpenBMP cron jobs
* `rsyslogd` - Runs the rsyslog daemon
* `consumer` - Runs the OpenBMP psql-app consumer process (Java application)

### Kafka Validation Testing
The Kafka setup can be tricky due to docker networking between containers and remote systems.  
Kafka clustering involves brokers advertising available listeners as ```hostname:port``` that consumers & producers will use.  
Each consumer & producer will connect to the brokers using these **advertised** hostnames and ports.  
The Kafka setting to change advertised broker names is ```advertised.listeners```. 

The postgres container (**this container**) uses **KAFKA_BROKERS**, following the syntax ```<HOSTNAME or IP:PORT>```.  
This will work with an IP or hostname. When using a hostname, the hostname *MUST* resolve within the container.  
While this may work for bootstrapping a connection, the advertised hostnames need to also resolve in the container.  

**Kafka Validation is a 3 step process** 

1. Successfully connect to the broker(s) and retrieve metadata (e.g.  broker hostname:port)
2. Successfully produce a test message to ```openbmp.parsed.test``` topic
3. Successfully consume a test message from ```openbmp.parsed.test``` topic

> :bulb:
> If using your own Kafka install, make sure you allow producing and consuming on **openbmp.parsed.test** 
> for the consumer validation. 

### Hostnames in Container

To enable communication to services like Postgres or Kafka **hosted externally**, you can map their hostnames to IP
addresses inside the container. This can be used to make them appear local to the container.

Modifying the `/etc/hosts` file directly in the container is not possible because it is mounted **read-only** by Docker.
However, custom host entries can still be added through one of the methods below.

> :warning: When TLS/SSL is enabled, the hostname used to connect to the service must match the certificate used by the service.
> Make sure to add subject alternative names (SAN) to the certificate for all hostnames used to connect to the service.

#### 1) Docker Run Command

Passing the following option to the **docker run** command will add an entry to the container's `/etc/hosts` file.
```
--add-host <HOSTNAME:IP>
```

> :bulb: Setting custom host entries this way is ephemeral and will not persist after the container is stopped, but it is useful for temporary testing.


#### 2) Docker Compose
If you are using docker-compose, you can add the following to your docker-compose.yml file:

```yaml
services:
  consumer:
    image: openbmp/psql-app:2.2.2
    container_name: obmp-consumer
    extra_hosts:
      - "kafka:<IP>"
      - "postgres:<IP>"
```
> :bulb: This is a better approach to maintaining custom host entries throughout the container's lifecycle.
> They will persist through container restarts until entries are changed in the `docker-compose.yml` file.

### VM Specifications

#### Storage

You will need to dedicate space for the postgres instance.  Normally two partitions are used.  A good
starting size for postgres main is 500GB and postgres ts (timescaleDB) is 1TB.  Both disks
should be fast SSD. ZFS can be used on either of them to add compression. The size you need will depend
on the number of NLRI's and updates per second.

#### Memory & CPU

The size of memory will depend on the type of queries and number of NLRI's.   A good starting point for
memory is a server with more than 48GB RAM. You can run on as little as 4GB RAM but that will only
scale to about 10,000,000 NLRI's.  64BG of RAM should scale to 150,000,000 NLRI's. 

The number of vCPU's also varies by the number of concurrent connections and how many threads you use for
the postgres consumer.  A good starting point is at least 8 vCPU's.   


### 1) Install docker
Follow the [Docker Instructions](https://docs.docker.com/install) to install docker CE.  

### 2) Add persistent volumes

Persistent volumes make it possible for upgrades without loosing any data. 


#### a) Bind Mounts

File or directory bind mounts can be use to persist configuration files. 
```bash
docker run -v /var/openbmp/config:/config
``` 

#### b) Persistent Volumes
Create a persistent volume using `docker volume create`.

Files can be preloaded into a persistent volume using any temporary container.
We use a `busybox` container, but it could be `alpine`, or any other container
with a shell and required command-line tools.
```bash
# create a persistent volume
docker volume create openbmp-config

# copy files from the current directory into the persistent volume
docker run --rm \
  -v openbmp-config:/mnt \
  -v $(pwd):/data \
  busybox sh -c "cp -r /data/* /mnt"

# mount when running the container
docker run -v openbmp-config:/config \
  ...
  openbmp/psql-app:build-50
```

### Container Configuration

The [obmp-psql.yml](https://github.com/OpenBMP/obmp-postgres/blob/master/src/main/resources/obmp-psql.yml) file is
an example configuration file for the OpenBMP consumer (Java application). Configuration is generated when the
container starts, so this file now serves only as a reference config.

> :warning: You should not need to modify the config directly -- use the environment variables instead.

#### Environment Variables

Tables below list all of the environment variables that can be used.

Variables can be set using the `-e` flag in the `docker run` command.
or in the docker-compose.yml file under the `environment` section.

> :warning: The `environment` section must be passed strictly as a list or as a
> map. The map format is recommended for multiline YAML values.

##### Key prefixes

All **OpenBMP** specific parameters are prefixed: **OPENBMP_**  
All **Postgres** specific parameters extend the prefix: **OPENBMP_POSTGRES_**  
All **Kafka** specific parameters extend the prefix: **OPENBMP_KAFKA_**

##### Generation

The configuration generator is layered in this order:
| Precedence | Type | Source | Details |
| :--------- | :--: | :----- | :------ |
| Lowest | Default Layer | [01_generate_config](scripts/configure/01_generate_config) | Sane base values for all required settings |
| - | Environment | `OPENBMP_CONFIG` | Merged into the default settings<br/>This could potentially be the entire config, or<br />just a few desired values in the relevant sections |
| - | Environment | `OPENBMP_KAFKA_CONSUMER_CONFIG` | Merged into the kafka settings after `OPENBMP_CONFIG`<br />Useful for setting all Kafka consumer values at once, or<br/>settings that do not have an environment variable yet |
| Highest | Environment | All other environment variables | Merged into the final configuration |

##### Multiline YAML

The following variables require passing as multiline YAML strings.
- `OPENBMP_CONFIG`
- `OPENBMP_KAFKA_CONSUMER_CONFIG`
- `OPENBMP_KAFKA_SUBSCRIBE_TOPIC_PATTERNS`

> :bulb: Multiline YAML strings are passed using the `|-` or `>` syntax. The `|` character indicates a block literal, and the `>` character would indicate a block folded into spaces. The `-` character would indicate to chomp the trailing newline at the end of the block, if desired.

```yaml
environment:
  OPENBMP_CONFIG: |
    # This is a comment
    # This is another comment
  OPENBMP_KAFKA_CONSUMER_CONFIG: |
    bootstrap.servers=kafka1:9092,kafka2:9092,kafka3:9092
  OPENBMP_KAFKA_SUBSCRIBE_TOPIC_PATTERNS: |
    # This is also a comment
```

###### Java (JVM Runtime) Options

The OpenBMP Consumer is a Java application.   
JVM options can be passed when it is started by setting the following environment variables:

| Variable | Datatype | Details |
| :------- | :------: | :------ |
| `OPENBMP_JAVA_XMX` | String | Maximum heap size for the Java process.<br />Default is **512m**. |
| `OPENBMP_JAVA_XMS` | String | Initial heap size for the Java process.<br />Default is **512m**. |
| `OPENBMP_JAVA_EXTRA_OPTS` | String | Additional JVM options for the Java process.<br />See below for defaults. |

These options are combined into a single **JAVA_OPTS** variable, and `supervisord` will pass them to the Java process when it starts.

> :bulb: JVM extra options should be passed as a single line of space-separated values.
> This demonstrates a YAML feature using the `>-` syntax. The `>` character indicates a block folded into spaces,
> and the `-` character indicates to chomp the trailing newline at the end of the block.

Default extra JVM options:
```yaml
environment:
  OPENBMP_JAVA_EXTRA_OPTS: >-
    -XX:+UseG1GC
    -XX:+UnlockExperimentalVMOptions
    -XX:InitiatingHeapOccupancyPercent=30
    -XX:G1MixedGCLiveThresholdPercent=30
    -XX:MaxGCPauseMillis=200
    -XX:ParallelGCThreads=20
    -XX:ConcGCThreads=5
    -XX:+ExitOnOutOfMemoryError
    -Duser.timezone=UTC
```

##### Optional Services

These auxiliary import services are optional and can be enabled or disabled using the environment variables below.

| Variable | Datatype | Details |
| :------- | :------: | :------ |
| `OPENBMP_DBIP_ENABLED` | Boolean | Enables the (optional) DB-IP importer as a cron service.<br />Default is **0**. |
| `OPENBMP_IRR_ENABLED` | Boolean | Enables the (optional) IRR importer as a cron service.<br />Default is **0**. |
| `OPENBMP_RPKI_ENABLED` | Boolean | Enables the (optional) RPKI importer as a cron service.<br />Default is **0**. |
| `OPENBMP_RPKI_URL` | String | URL for the RPKI repository.<br />Default is **https://rpki.cloudflare.com/rpki.json**. |
| `OPENBMP_RPKI_USERNAME` | String | Username for the RPKI repository.<br />Default is **None**. |
| `OPENBMP_RPKI_PASSWORD` | String | Password for the RPKI repository.<br />Default is **None**. |

##### Base Configuration

| Variable | Datatype | Details |
| :------- | :------: | :------ |
| `OPENBMP_STATS_INTERVAL` | Integer | Interval consumer stats are printed or logged.<br />Default is **60** seconds. |
| `OPENBMP_CONSUMMER_THREADS` | Integer | Number of consumer threads.<br />Default is **8**. |
| `OPENBMP_HEARTBEAT_MAX_AGE` | Integer | The maximum age between collector heartbeats, in minutes, before it is considered down.<br />Default is **5** minutes. |
| `OPENBMP_WRITER_MAX_THREADS_PER_TYPE` | Integer | The maximum number of writer threads per processing type: (default, base attributes).<br />Default is **1**. |
| `OPENBMP_WRITER_ALLOWED_OVER_QUEUE_TIMES` | Integer | The number of times the writer queue can be over the high threshold mark before a new thread is added for the writer type.<br />Default is **8**. |
| `OPENBMP_WRITER_SECONDS_THREAD_SCALE_BACK` | Integer | The number of seconds the writer needs to sustain below the low queue threshold mark in order to trigger scaling back the number of threads in use.<br />Default is **4800** seconds. |
| `OPENBMP_WRITER_REBALANCE_SECONDS` | Integer | The number of seconds between rebalancing of writer threads.<br />Default is **900** seconds. |
| `OPENBMP_WRITER_QUEUE_SIZE` | Integer | Maximum input size of the writer queue.<br />Default is **4000**. |
| `OPENBMP_CONSUMER_QUEUE_SIZE` | Integer | Maximum input size of the consumer queue. A good starting point is twice that of `OPENBMP_WRITER_QUEUE_SIZE`<br />Default is **10000**. |

##### Postgres Configuration

| Variable | Datatype | Details |
| :------- | :------: | :------ |
| `OPENBMP_POSTGRES_STARTUP_TIMEOUT` | Integer | Determines how long, in seconds, to wait for Postgres startup before failing.<br />Default is **60** seconds. |
| `OPENBMP_POSTGRES_DB` | String | Name of postgres database.<br />Default is **openbmp**. |
| `OPENBMP_POSTGRES_HOST` | String | Hostname or IP address of the postgres server.<br />Default is **localhost**. |
| `OPENBMP_POSTGRES_PORT` | Integer | Port number of the postgres server.<br />Default is **5432**. |
| `OPENBMP_POSTGRES_USERNAME` | String | Postgres username.<br/>Default is **openbmp**. |
| `OPENBMP_POSTGRES_PASSWORD` | String | Postgres password.<br />Default is **openbmp**. |
| `OPENBMP_POSTGRES_SSL_ENABLED` | Boolean | Enable SSL for postgres connection. Default is **false**. |
| `OPENBMP_POSTGRES_SSL_MODE` | String | SSL mode for postgres connection. Default is **require**.<br />Other options are **verify-ca** and **verify-full**. |
| `OPENBMP_POSTGRES_BATCH_RECORDS` | Integer | Number of statements to batch in a bulk update/insert/delate.<br />Default is **3000**. |
| `OPENBMP_POSTGRES_BATCH_TIME_MILLIS` | Integer | Number of milliseconds to wait before flushing the batch.<br />Default is **300**. |
| `OPENBMP_POSTGRES_RETRIES` | Integer | Number of time to retry a failed statement.<br />Default is **6**. |

##### Kafka Configuration

| Variable | Datatype | Details |
| :------- | :------: | :------ |
| `OPENBMP_KAFKA_STARTUP_TIMEOUT` | Integer | Determines how long, in seconds, to wait for Kafka startup before failing.<br />Default is **60** seconds. |
| `OPENBMP_KAFKA_BROKERS` | String | One or more Kafka broker host as `<hostname:port>`, passed to the `bootstrap.servers` setting. Hostnames can be IP addresses.<br />Default is **localhost:9092**. |
| `OPENBMP_KAFKA_GROUP_ID` | String | Kafka consumer group ID.<br />Default is **openbmp-consumer**. |
| `OPENBMP_KAFKA_CLIENT_ID` | String | Kafka client ID.<br/>Default is **openbmp-consumer**. |
| `OPENBMP_KAFKA_SESSION_TIMEOUT_MS` | Integer | Kafka session timeout in milliseconds.<br />Default is **15000**. |
| `OPENBMP_KAFKA_HEARTBEAT_INTERVAL_MS` | Integer | Kafka heartbeat interval in milliseconds.<br />Default is **5000**. |
| `OPENBMP_KAFKA_MAX_POLL_INTERVAL_MS` | Integer | Kafka max poll interval in milliseconds.<br />Default is **300000**. |
| `OPENBMP_KAFKA_AUTO_OFFSET_RESET` | String | Kafka auto offset reset policy.<br />Default is **earliest**. Other options are **latest** and **none**. |
| `OPENBMP_KAFKA_MAX_PARTITION_FETCH_BYTES` | Integer | Kafka max partition fetch bytes.<br />Default is **2000000**. |
| `OPENBMP_KAFKA_MAX_POLL_RECORDS` | Integer | Kafka max poll records.<br />Default is **1000**. |
| `OPENBMP_KAFKA_SECURITY_PROTOCOL` | String | Security protocol for Kafka connection. Default is **PLAINTEXT**.<br />Other options are **SSL** and **SASL_SSL**. |
| `OPENBMP_KAFKA_SSL_ENABLED` | Boolean | Sets `security.protocol` to `SSL`, enabling SSL for Kafka connection.<br />Default is **false**. |
| `OPENBMP_KAFKA_SSL_TRUSTSTORE_LOCATION` | String | Path to the Kafka truststore file.<br />Default is **/config/kafka.truststore.jks**. |
| `OPENBMP_KAFKA_SSL_TRUSTSTORE_PASSWORD` | String | Password for the Kafka truststore file.<br />Default is **changeit**. |
| `OPENBMP_KAFKA_SSL_KEYSTORE_LOCATION` | String | Path to the Kafka keystore file.<br />Default is **/config/kafka.keystore.jks**. |
| `OPENBMP_KAFKA_SSL_KEYSTORE_PASSWORD` | String | Password for the Kafka keystore file.<br />Default is **changeit**. |
| `OPENBMP_KAFKA_TOPIC_SUBSCRIBE_DELAY_MILLIS` | Integer | Delay in milliseconds before subscribing to Kafka topics.<br />Default is **1000**. |
| `OPENBMP_KAFKA_SUBSCRIBE_TOPIC_PATTERNS` | List | List of Kafka topic patterns to subscribe to.<br/>See below for defaults

> :warning: If SSL is enabled, you are required to pass additional SSL variables.

###### Kafkacat SSL

These will be used by `kcat` (formerly kafkacat) to validate Kafka during startup. Kafkacat uses librdkafka, hence Java Keystore files are not supported in Kafkacat.
Enabling ssl requires setting the following variables:

| Variable | Datatype | Details | Condition |
| :------- | :------: | :------ | :--------: |
| `OPENBMP_KAFKA_SSL_CA_LOCATION` | String | Path to the CA certificate file.<br />Default is **empty**. | `OPENBMP_KAFKA_SSL_ENABLED=true` |
| `OPENBMP_KAFKA_SSL_CERTIFICATE_LOCATION` | String | Path to the client certificate file.<br />Default is **empty**. | If Kafka is configured for mTLS |
| `OPENBMP_KAFKA_SSL_KEY_LOCATION` | String | Path to the client key file.<br />Default is **empty**. | If Kafka is configured for mTLS |
| `OPENBMP_KAFKA_SSL_KEY_PASSWORD` | String | Password for the client key file.<br />Default is **empty**. | If the client key is encrypted |

> :bulb: Generating the `ca.key`, `ca.pem`, `client.key`, and `client.pem`, then deriving the kafka keystore 
> and truststore files is outside the scope of this document. These files can be loaded into a docker volume
> and mounted read-only into the container at an appropriate location e.g. `/etc/openbmp/pki/`.

###### Default Kafka Topic Patterns
```yaml
environment:
  OPENBMP_KAFKA_SUBSCRIBE_TOPIC_PATTERNS: |
    - "openbmp[.]parsed[.]collector"
    - "openbmp[.]parsed[.]router"
    - "openbmp[.]parsed[.]peer"
    - "openbmp[.]parsed[.]ls.*"
    #- "openbmp[.]parsed[.]bmp_stat"
    - "openbmp[.]parsed[.]base_attribute"
    - "openbmp[.]parsed[.]l3vpn"
    - "openbmp[.]parsed[.]unicast_prefix"
```

### Docker Run Example

Docker compose is recommended for running a production deployment of OpenBMP, but using the `docker run` command still works. 
```bash
docker run --rm -d --name obmp-consumer \
	-h obmp-consumer \
	-e OPENBMP_ENABLE_DBIP=1 \
	-e OPENBMP_ENABLE_RPKI=1 \
	-e OPENBMP_ENABLE_IRR=1 \
	-e OPENBMP_KAFKA_BROKERS=kafka1:9092 \
	-e OPENBMP_JAVA_XMX=3g \
	-e OPENBMP_JAVA_XMS=3g \
	-e OPENBMP_JAVA_EXTRA_OPTS="-XX:+UseG1GC -XX:+UnlockExperimentalVMOptions -XX:InitiatingHeapOccupancyPercent=30 -XX:G1MixedGCLiveThresholdPercent=30 -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=20 -XX:ConcGCThreads=5 -XX:+ExitOnOutOfMemoryError -Duser.timezone=UTC" \
	-v $OBMP_CONFIG:/config \
	-p 9005:9005 \
	openbmp/psql-app:build-50
```

Editing the entrypoint will prevent supervisord from starting.  
Useful if you don't want to load the environment, or start the consumer.
```bash
  --entrypoint /bin/bash
```

### Monitoring/Troubleshooting

Useful commands:
```bash
docker logs obmp-consumer
docker exec obmp-consumer tail -f /var/log/supervisord.log
docker exec obmp-consumer tail -f /var/log/openbmp/obmp-psql.log
docker exec -it obmp-consumer /bin/bash
```
