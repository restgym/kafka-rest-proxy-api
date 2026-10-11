FROM confluentinc/cp-kafka-rest:7.5.0 AS kafka-rest-base
FROM confluentinc/cp-kafka:7.5.0 AS kafka-base
FROM confluentinc/cp-schema-registry:7.5.0 AS schema-registry-base

FROM ubuntu:22.04

ENV API=kafka-rest-proxy
ENV TOOL=${TOOL:-manual}
ENV RUN=${RUN:-1}
ENV DEBIAN_FRONTEND=noninteractive
ENV KAFKA_CLUSTER_ID=MkU3OEVBNTcwNTJENDM2Qk
ENV KAFKA_NODE_ID=1
ENV KAFKA_PROCESS_ROLES=broker,controller
ENV KAFKA_LISTENERS=PLAINTEXT://localhost:9092,CONTROLLER://localhost:9093
ENV KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092
ENV KAFKA_CONTROLLER_QUORUM_VOTERS=1@localhost:9093
ENV KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER
ENV KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
ENV KAFKA_INTER_BROKER_LISTENER_NAME=PLAINTEXT
ENV KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1
ENV KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1
ENV KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1
ENV KAFKA_AUTO_CREATE_TOPICS_ENABLE=true
ENV KAFKA_LOG_DIRS=/var/lib/kafka/data
ENV KAFKA_REST_HOST_NAME=localhost
ENV KAFKA_REST_LISTENERS=http://0.0.0.0:8082
ENV KAFKA_REST_BOOTSTRAP_SERVERS=localhost:9092
ENV KAFKA_REST_SCHEMA_REGISTRY_URL=http://localhost:8081

RUN mkdir -p /api /infrastructure /results /var/lib/kafka/data

RUN apt-get update && \
    apt-get -y install openjdk-17-jdk mitmproxy curl wget python3 unzip procps && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY ./infrastructure/ /infrastructure/

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
COPY --from=kafka-rest-base /etc/kafka-rest /etc/kafka-rest
COPY --from=kafka-rest-base /usr/bin/kafka-rest-* /usr/bin/

RUN mkdir -p /api/classes

RUN cd /api/classes && \
    unzip -q /usr/share/java/kafka-rest-lib/kafka-rest-*.jar 'io/confluent/**/*.class' || true

RUN cd /api/classes && \
    unzip -q /usr/share/java/rest-utils/rest-utils-*.jar 'io/confluent/**/*.class' || true

RUN chmod -R 755 /api/classes

COPY ./apis/kafka-rest-proxy/ /api/

EXPOSE 9090 12345

# Startup script: starts the API, the collection of code coverage and the proxy (see infrastructure/api/restgym-api.sh)
COPY ./apis/kafka-rest-proxy/entrypoint.sh /entrypoint.sh

ENTRYPOINT ["bash", "/entrypoint.sh"]
