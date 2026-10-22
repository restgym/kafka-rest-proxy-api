#!/usr/bin/env bash
# Starts Kafka REST Proxy in RESTgym: see /infrastructure/api/restgym-api.sh

source /infrastructure/api/restgym-api.sh

# Kafka broker (KRaft mode) and Schema Registry
# The authorizer of Kafka (StandardAuthorizer), so that the ACL operations of the API work (without it, they always
# answer 400 "No Authorizer is configured"). Every client of the broker is User:ANONYMOUS (listeners without
# authentication), a super user: the ACLs are stored and listed, but never restrict a request (see the README)
kafka-storage format -t "$KAFKA_CLUSTER_ID" -c /etc/kafka/kraft/server.properties
restgym_start_service Kafka sh -c 'exec kafka-server-start /etc/kafka/kraft/server.properties \
    --override authorizer.class.name=org.apache.kafka.metadata.authorizer.StandardAuthorizer \
    --override super.users=User:ANONYMOUS > /tmp/kafka.log 2>&1'
restgym_wait_until Kafka kafka-broker-api-versions --bootstrap-server localhost:9092
restgym_start_service "Schema Registry" \
    sh -c 'exec schema-registry-start /etc/schema-registry/schema-registry.properties > /tmp/schema-registry.log 2>&1'
restgym_wait_until "Schema Registry" curl -sf http://localhost:8081/

export KAFKAREST_OPTS="-javaagent:/infrastructure/jacoco/org.jacoco.agent-0.8.12-runtime.jar=includes=io.confluent.*,output=tcpserver,port=12345,address=* -Dfile.encoding=UTF-8"
restgym_run_api 8082 kafka-rest-start /etc/kafka-rest/kafka-rest.properties
