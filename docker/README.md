# OpenBMP Postgres Application Container
This container is the main application container for OpenBMP and PostgreSQL. 

It provides:

* PostgreSQL consumer 
* RPKI validator import/sync 
* IRR and peering DB import/sync
* Schedules and runs the metric DB functions
* Schedules and runs the DB timescale DB chunk drops

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
The supervisord configuration file is located at `/etc/supervisord.conf`.

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

File or directory bind mounts can be used with persistent config files. 
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

##### config/obmp-psql.yml
If the [obmp-psql.yml](https://github.com/OpenBMP/obmp-postgres/blob/master/src/main/resources/obmp-psql.yml) file
does not exist, a default one will be created. You should update this based on your settings. This file
is inline documented.  

### 3) Run docker container

> :bulb: Tip: Running the docker container for the first time will automatically pull the container image. 

#### Environment Variables
Below table lists the environment variables that can be passed to the container with ``docker run -e <name=value>`` or docker compose.

Variable | Datatype | Details
:------- | :------: | :------
`ENABLE_DBIP` | 0 or 1 | Set to 1 to enable optional DBIP service. Default is **disabled** (0).
`ENABLE_RPKI` | 0 or 1 | Set to 1 to enable optional RPKI service. Default is **disabled** (0).
`ENABLE_IRR` | 0 or 1 | Set to 1 to enable optional IRR service. Default is **disabled** (0).
`JAVA_XMX` | memory size | Java heap memory size. Default is **`512m`**, but can be set to **`1g`**, **`2g`**, etc.<br />This setting is the **_maximum_** heap size.
`JAVA_XMS` | memory size | Java initial heap memory size. Defaults is `512m`, but can be set to `1g`, `2g`, etc.<br />This setting is the **_initial_** heap size, and generally should be the same value as `JAVA_XMX` to eliminate heap resizing.
`JAVA_EXTRA_OPTS` | options | Extra Java options to pass to the JVM, and combined with the `JAVA_XMX` and `JAVA_XMS` options. These options are passed to the JVM as-is, so you can use any valid Java option here e.g. `-XX:+UseG1GC` to enable G1 garbage collector.<br />See below for an extended example.
`POSTGRES_USERNAME` | username | Postgres username, default is **openbmp**
`POSTGRES_PASSWORD` | password | Postgres password, default is **openbmp**
`POSTGRES_DB` | database | Name of postgres database, default is **openbmp**
`POSTGRES_HOST` | host | Hostname or IP address of the postgres server. Default is **localhost**.
`POSTGRES_PORT` | port | Port number of the postgres server. Default is **5432**.
`POSTGRES_SSL` | true or false | Enable SSL for postgres connection. Default is **false**.
`POSTGRES_SSL_MODE` | require | SSL mode for postgres connection. Default is **require**.<br />Other options are **verify-ca** and **verify-full**.
`KAFKA_BROKERS` | host | One or more Kafka broker host as `<hostname:port>`.  Hostnames can be IP addresses.
`KAFKA_SSL` | true or false | Enable SSL for Kafka connection. Default is **false**.
`KAFKA_SECURITY_PROTOCOL` | protocol | Security protocol for Kafka connection. Default is **plaintext**. Other options are **SSL** and **SASL_SSL**.
`KAFKA_KEYSTORE_LOCATION` | filepath | Path to keystore for Kafka SSL connection. Default is **empty**.
`KAFKA_KEYSTORE_PASSWORD` | password | Password for Kafka keystore. Default is **empty**.
`KAFKA_TRUSTSTORE_LOCATION` | filepath | Path to truststore for Kafka SSL connection. Default is **empty**.
`KAFKA_TRUSTSTORE_PASSWORD` | password | Password for Kafka truststore. Default is **empty**.
`KAFKA_SSL_CA_LOCATION` | filepath | Path to CA certificate for Kafka SSL connection. Default is **empty**.<br />This is only used by `kafkacat` during startup kafka checks and validation tests.
`KAFKA_SSL_CERTIFICATE_LOCATION` | filepath | Path to client certificate for Kafka SSL connection. Default is **empty**.<br />This is only used by `kafkacat` during startup kafka checks and validation tests.
`KAFKA_SSL_KEY_LOCATION` | filepath | Path to client key for Kafka SSL connection. Default is **empty**.<br />This is only used by `kafkacat` during startup kafka checks and validation tests.

#### Docker Run obmp-consumer

```bash
docker run --rm -d --name obmp-consumer \
	-h obmp-consumer \
	-e ENABLE_DBIP=1 \
	-e ENABLE_RPKI=1 \
	-e ENABLE_IRR=1 \
	-e KAFKA_BROKERS=kafka1:9092 \
	-e JAVA_XMX=3g \
	-e JAVA_XMS=3g \
	-e JAVA_EXTRA_OPTS="-XX:+UseG1GC -XX:+UnlockExperimentalVMOptions -XX:InitiatingHeapOccupancyPercent=30 -XX:G1MixedGCLiveThresholdPercent=30 -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=20 -XX:ConcGCThreads=5 -XX:+ExitOnOutOfMemoryError -Duser.timezone=UTC" \
	-v $OBMP_CONFIG:/config \
	-p 9005:9005 \
	openbmp/psql-app:build-50
```
> :warning: If the container fails to start, check the container logs. You can view them with:  
> `docker logs obmp-consumer`


### Monitoring/Troubleshooting

Useful commands:
```bash
docker logs obmp-consumer
docker exec obmp-consumer tail -f /var/log/supervisord.log
docker exec obmp-consumer tail -f /var/log/openbmp/obmp-psql.log
docker exec -it obmp-consumer /bin/bash
```
