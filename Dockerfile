FROM confluentinc/cp-kafka-rest:7.5.0 AS kafka-rest-base
FROM confluentinc/cp-kafka:7.5.0 AS kafka-base
FROM confluentinc/cp-schema-registry:7.5.0 AS schema-registry-base

FROM ubuntu:22.04

ENV API=kafka-rest
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

RUN mkdir -p /api /infrastructure /results /api/classes /var/lib/kafka/data /etc/kafka /etc/schema-registry

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y install \
        openjdk-17-jdk \
        curl \
        wget \
        netcat \
        python3 \
        python3-pip \
        unzip && \
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN pip3 install mitmproxy

COPY apis/infrastructure/ /infrastructure/

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

COPY apis/kafka-rest/specifications /api/specifications
COPY apis/kafka-rest/start-kafka-stack.sh /usr/local/bin/start-kafka-stack.sh
COPY apis/kafka-rest/server.properties /etc/kafka/kraft/server.properties
COPY apis/kafka-rest/kafka-rest.properties /etc/kafka-rest/kafka-rest.properties
COPY apis/kafka-rest/schema-registry.properties /etc/schema-registry/schema-registry.properties

RUN chmod +x /usr/local/bin/start-kafka-stack.sh

RUN cd /api/classes && \
    unzip -q /usr/share/java/kafka-rest-lib/kafka-rest-*.jar 'io/confluent/**/*.class' 2>/dev/null || true

WORKDIR /var/lib/kafka

EXPOSE 8082 9090 12345 9092 8081

HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=5 \
    CMD curl -f http://localhost:8082/v3/clusters || exit 1

CMD mkdir -p /results/$API/$TOOL/$RUN/code-coverage && \
    cp -r /api/specifications /results/$API/$TOOL/$RUN/ && \
    /usr/local/bin/start-kafka-stack.sh
