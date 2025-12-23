#!/bin/bash
set -e

echo $API
ls api/specifications

mkdir -p /results/$API/$TOOL/$RUN

echo "=== Starting Kafka Embedded Stack for $API ==="


kafka-storage format -t $KAFKA_CLUSTER_ID -c /etc/kafka/kraft/server.properties || true
kafka-server-start /etc/kafka/kraft/server.properties > /tmp/kafka.log 2>&1 &


for i in {1..60}; do
    if kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1; then
        echo "Kafka ready"
        break
    fi
    sleep 2
done

schema-registry-start /etc/schema-registry/schema-registry.properties > /tmp/schema-registry.log 2>&1 &

for i in {1..30}; do
    if curl -sf http://localhost:8081/ > /dev/null 2>&1; then
        echo "Schema Registry ready"
        break
    fi
    sleep 2
done


echo "Starting restgym infrastructure..."


sh /infrastructure/jacoco/collect-coverage-interval.sh &

mitmdump -p 9090 --mode reverse:http://localhost:8082/ -s /infrastructure/mitmproxy/store-interactions.py &

echo "Starting Kafka REST Proxy with JaCoCo..."

export KAFKAREST_OPTS="-javaagent:/infrastructure/jacoco/org.jacoco.agent-0.8.7-runtime.jar=includes=io.confluent.*,output=tcpserver,port=12345,address=* -Dfile.encoding=UTF-8"

exec kafka-rest-start /etc/kafka-rest/kafka-rest.properties