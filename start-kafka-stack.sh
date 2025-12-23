#!/bin/bash
set -e

echo "=== Starting Kafka Embedded Stack ==="

# Format Kafka storage for KRaft mode
kafka-storage format -t $KAFKA_CLUSTER_ID -c /etc/kafka/kraft/server.properties || true
kafka-server-start /etc/kafka/kraft/server.properties > /tmp/kafka.log 2>&1 &
KAFKA_PID=$!


echo "Waiting for Kafka to start..."
for i in {1..60}; do
    if kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1; then
        echo "ready!"
        break
    fi
    sleep 2
done

# Start Schema Registry (background)
echo "Starting Schema Registry..."
schema-registry-start /etc/schema-registry/schema-registry.properties > /tmp/schema-registry.log 2>&1 &
SCHEMA_REGISTRY_PID=$!

# Wait for Schema Registry
echo "Waiting for Schema Registry..."
for i in {1..30}; do
    if curl -sf http://localhost:8081/ > /dev/null 2>&1; then
        echo "Schema Registry is ready!"
        break
    fi
    sleep 2
done

# Create test topic for API testing
echo "Creating test topics..."
kafka-topics --create --if-not-exists --topic restgym-test --partitions 1 --replication-factor 1 --bootstrap-server localhost:9092 || true
kafka-topics --create --if-not-exists --topic jsontest --partitions 1 --replication-factor 1 --bootstrap-server localhost:9092 || true

echo "=== Kafka Stack Ready ==="

# Start JaCoCo coverage collector
sh /infrastructure/jacoco/collect-coverage-interval.sh &

# Start mitmproxy for HTTP interception
mitmdump -p 9090 --mode reverse:http://localhost:8082/ -s /infrastructure/mitmproxy/store-interactions.py &

# Start Kafka REST Proxy with JaCoCo (foreground)
echo "Starting Kafka REST Proxy..."
export KAFKAREST_OPTS="-javaagent:/infrastructure/jacoco/org.jacoco.agent-0.8.12-runtime.jar=includes=io.confluent.*,output=tcpserver,port=12345,address=*"
exec kafka-rest-start /etc/kafka-rest/kafka-rest.properties
