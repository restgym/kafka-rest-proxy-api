# Kafka REST Proxy 7.5.0, with the Kafka broker (KRaft mode) and Schema Registry of Confluent Platform 7.5.0 in the same container
# (the images of Confluent are pinned to a digest, since a tag can be moved to a rebuilt image)
FROM confluentinc/cp-kafka-rest:7.5.0@sha256:161d9e268f7e6c4e4f6af90ab91b8bf54d7bd35a5a27072a6ec26f323c22d439 AS kafka-rest-base
FROM confluentinc/cp-kafka:7.5.0@sha256:fbbb6fa11b258a88b83f54d4f0bddfcffbf2279f99d66a843486e3da7bdfbf41 AS kafka-base
FROM confluentinc/cp-schema-registry:7.5.0@sha256:e51684b472a2481f065f44616d3d8ad2182029a7011f949a612d35b54566a1f6 AS schema-registry-base

# Base image: Ubuntu 22.04, Java 17 (headless JRE), mitmproxy and the RESTgym infrastructure (see infrastructure/api/Dockerfile)
FROM restgym/api-base:java17

# Id of the Kafka cluster, used by entrypoint.sh to format the storage of the broker. The services are configured by the
# default configuration files of Confluent (/etc/kafka/kraft/server.properties, /etc/schema-registry/schema-registry.properties
# and /etc/kafka-rest/kafka-rest.properties, see the README): the images of Confluent turn KAFKA_* variables into these
# files when they start, but this image does not run their startup scripts
ENV KAFKA_CLUSTER_ID=MkU3OEVBNTcwNTJENDM2Qk

# ps (used by the scripts of Kafka), curl (used by entrypoint.sh) and unzip (to extract the classes for code coverage)
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl procps unzip \
    && rm -rf /var/lib/apt/lists/*

# Kafka, Schema Registry and Kafka REST Proxy, from the images of Confluent
COPY --from=kafka-base /usr/bin/kafka-* /usr/bin/
COPY --from=kafka-base /etc/kafka /etc/kafka
COPY --from=kafka-base /usr/share/java/kafka /usr/share/java/kafka
COPY --from=kafka-base /usr/share/java/cp-base-new /usr/share/java/cp-base-new
COPY --from=schema-registry-base /usr/share/java/schema-registry /usr/share/java/schema-registry
COPY --from=schema-registry-base /usr/share/java/confluent-common /usr/share/java/confluent-common
COPY --from=schema-registry-base /usr/share/java/confluent-telemetry /usr/share/java/confluent-telemetry
COPY --from=schema-registry-base /usr/share/java/rest-utils /usr/share/java/rest-utils
COPY --from=schema-registry-base /usr/share/java/kafka-serde-tools /usr/share/java/kafka-serde-tools
COPY --from=schema-registry-base /etc/schema-registry /etc/schema-registry
COPY --from=schema-registry-base /usr/bin/schema-registry-* /usr/bin/
COPY --from=kafka-rest-base /usr/share/java/kafka-rest-lib /usr/share/java/kafka-rest-lib
# kafka-rest-bin: on the classpath of kafka-rest-start, it has the binding of SLF4J to log4j (without it, the REST Proxy logs nothing)
COPY --from=kafka-rest-base /usr/share/java/kafka-rest-bin /usr/share/java/kafka-rest-bin
COPY --from=kafka-rest-base /etc/kafka-rest /etc/kafka-rest
COPY --from=kafka-rest-base /usr/bin/kafka-rest-* /usr/bin/

# Classes for code coverage: the io.confluent classes of Kafka REST Proxy and of the REST utilities of Confluent
RUN mkdir -p /api/classes \
    && cd /api/classes \
    && (unzip -q /usr/share/java/kafka-rest-lib/kafka-rest-*.jar 'io/confluent/**/*.class' || true) \
    && (unzip -q /usr/share/java/rest-utils/rest-utils-*.jar 'io/confluent/**/*.class' || true) \
    && chmod -R 755 /api/classes

# The API: its specifications and scripts
COPY ./apis/kafka-rest-proxy/ /api/

# Startup script (in /api): starts the API, the collection of code coverage and the proxy (see infrastructure/api/restgym-api.sh)
ENTRYPOINT ["bash", "/api/entrypoint.sh"]
