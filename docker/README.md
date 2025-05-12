# OpenBMP Postgres Application Container
This container is the main application container for OpenBMP and PostgreSQL. 

It provides:

* PostgreSQL consumer 
* RPKI validator improt/sync 
* IRR and peering DB import/sync
* Schedules and runs the metric DB functions
* Schedules and runs the DB timescale DB chunk drops

## Building
See the [Dockerfile](Dockerfile) notes for build instructions.

## Running

### Kafka Validation Testing
The Kafka setup can be tricky due to docker networking between containers and remote systems. Kafka clustering
makes use of a bootstrap server which will advertise each broker ```hostname:port``` that the consumer/producer
will use.  Each consumer/producer will connect to the brokers using these **advertised** hostnames and ports.  The
setting in Kafka to configure the broker hostname is ```advertised.listeners```. 

The postgres container (**this container**) uses the **KAFKA_FQDN** as the bootstrap server,
syntax is ```<HOSTNAME or IP:PORT>```.  This will work with an
IP or hostname. When using a hostname, the hostname *MUST* resolve within the container.  While this may work for
bootstrap server conection, the advertised hostnames need to also resolve in the container.  

**Kafka Validation is a 3 step process** 

1. Successfully connect to the bootstrap server and retrieve metadata (e.g.  broker hostname:port)
2. Successfully produce a test message to ```openbmp.parsed.test``` topic
3. Successfully consume a test message from ```openbmp.parsed.test``` topic

> **IMPORTANT**
> If using your own Kafka install, make sure you allow producing/consuming to/from **openbmp.parsed.test** 
> for the consumer validation. 

### Hostnames in Container
You can map Postgres and/or Kafka instances to IP addresses using the following methods:  

#### 1) Docker Run Command

Passing the following option to the **docker run** command will add an entry to the container's `/etc/hosts` file.
```
--add-host <HOSTNAME:IP>
```

> **NOTE:**
> This is ephemeral and will not persist after the container is stopped, but it is useful for temporary testing.


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
> **NOTE:**
> This is a more ideal method of maintaining `/etc/hosts` entries throughout the container's lifecycle, and will persist through container restarts until entries are change in the `docker-compose.yml` file.

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

#### (a) Create persistent config location

    mkdir -p /var/openbmp/config
    chmod 777 /var/openbmp/config

##### config
You can add custom host entries so that the collector will reverse lookup IP addresses
using a persistent hosts file.

File bind mounts can be used with persistent config files. 
```bash
docker run -v /var/openbmp/config:/config
``` 

Or, create a persistent volume using `docker volume create`. Files can be preloaded into a persistent volume from nearly any image.
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

> Running the docker container for the first time will download the container image. 

#### Environment Variables
Below table lists the environment variables that can be used with ``docker run -e <name=value>``

NAME | Value | Details
:---- | ----- |:-------
ENABLE_DBIP | 1 | Set to 1 to enable DBIP. DBIP is disabled by default
ENABLE_RPKI | 1 | Set to 1 to eanble RPKI. RPKI is disabled by default
ENABLE_IRR | 1 | Set to 1 to enable IRR. IRR is disabled by default
JAVA_XMX | memory_spec | Java heap memory size. Defaults is `512m`, but can be set to `1g`, `2g`, etc. This is the max heap size.
JAVA_XMS | memory_spec | Java initial heap memory size. Defaults is `512m`, but can be set to `1g`, `2g`, etc. This is the initial heap size. Generally, this should be set to the same value as `JAVA_XMX`.
JAVA_EXTRA_OPTS | options | Extra Java options to pass to the JVM, and combined with the `JAVA_XMX` and `JAVA_XMS` options. `JAVA_EXTRA_OPTS` is a space-separated list of options, but can be passed as a multiline folded YAML block. See below for an example.<br/>These options are passed to the JVM as-is, so you can use any valid Java option here. For example, `-XX:+UseG1GC` to enable G1 garbage collector.<br/>
POSTGRES_USERNAME | username | Postgres username, default is **openbmp**
POSTGRES_PASSWORD | password | Postgres password, default is **openbmp**
POSTGRES_DB | database | Name of postgres database, default is **openbmp**
POSTGRES_HOST | hostname or IP | Hostname or IP address of the postgres server. Default is **localhost**.
POSTGRES_PORT | port | Port number of the postgres server. Default is **5432**.
POSTGRES_SSL | true/false | Enable SSL for postgres connection. Default is **false**.
POSTGRES_SSL_MODE | require | SSL mode for postgres connection. Default is **require**. Other options are **verify-ca** and **verify-full**.
KAFKA\_BROKERS | hostname or IP | One or more Kafka broker `<hostname:port>`.  Hostnames can be IP addresses.
KAFKA\_SSL | true/false | Enable SSL for Kafka connection. Default is **false**.
KAFKA\_SECURITY\_PROTOCOL | plaintext | Security protocol for Kafka connection. Default is **plaintext**. Other options are **SSL** and **SASL_SSL**.
KAFKA\_KEYSTORE\_LOCATION | path to keystore | Path to keystore for Kafka SSL connection. Default is **/config/kafka-keystore.jks**.
KAFKA\_KEYSTORE\_PASSWORD | password | Password for Kafka keystore. Default is **changeit**.
KAFKA\_TRUSTSTORE\_LOCATION | path to truststore | Path to truststore for Kafka SSL connection. Default is **/config/kafka-truststore.jks**.
KAFKA\_TRUSTSTORE\_PASSWORD | password | Password for Kafka truststore. Default is **changeit**.
KAFKA\_SSL\_CA\_LOCATION | path to CA cert | Path to CA certificate for Kafka SSL connection. Default is **/config/kafka-ca.crt**. This is only used by `kafkacat` during startup kafka checks and validation tests.
KAFKA\_SSL_CERTIFICATE_LOCATION | path to cert | Path to client certificate for Kafka SSL connection. Default is **/config/kafka-client.crt**. This is only used by `kafkacat` during startup kafka checks and validation tests.
KAFKA\_SSL\_KEY\_LOCATION | path to key | Path to client key for Kafka SSL connection. Default is **/config/kafka-client.key**. This is only used by `kafkacat` during startup kafka checks and validation tests.


##### Example JAVA_EXTRA_OPTS
The following will collapse to a single line with a single space between each option when passed.
```yaml
JAVA_EXTRA_OPTS: >-
  -XX:+UseG1GC
  -XX:MaxGCPauseMillis=200
  -XX:+UnlockExperimentalVMOptions
  -XX:+UseCGroupMemoryLimitForHeap
```

This is a YAML feature.  The `>` character is used to indicate that the following lines are folded into a single line. The `-` character indicates that the following lines are part of a block.



#### Docker Run obmp-consumer
> **NOTE:**
> If the container fails to start, it's likely due to the configuration. Check using
> ```docker logs obmp-consumer```

```
docker run --rm -d --name obmp-consumer \
	-h obmp-consumer \
	-e ENABLE_RPKI=1 \
	-e ENABLE_IRR=1 \
	-e KAFKA_BROKERS=kafka:9092 \
	-e JAVA_XMX=16 \
	-e JAVA_XMS=16 \
	-e JAVA_EXTRA_OPTS="-XX:+UseG1GC -XX:+UnlockExperimentalVMOptions -XX:InitiatingHeapOccupancyPercent=30 -XX:G1MixedGCLiveThresholdPercent=30 -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=20 -XX:ConcGCThreads=5 -XX:+ExitOnOutOfMemoryError -Duser.timezone=UTC" \
	-v /var/openbmp/config:/config \
	-p 9005:9005 -p 8080:8080 \
	openbmp/psql-app:build-50
```

### Monitoring/Troubleshooting

Useful commands:

- docker logs obmp-consumer
- docker exec obmp-consumer tail -f /var/log/obmp-psql.log
- docker exec obmp-consumer tail -f /var/log/postgresql/postgresql-10-main.log 
- docker exec -it obmp-consumer bash

