# Confluent REST Proxy for Kafka for RESTgym

This repository is the RESTgym integration of Confluent REST Proxy for Kafka. It is meant to be used as a Git submodule of [RESTgym](https://github.com/restgym/restgym) (in `apis/kafka-rest-proxy/`), which builds its Docker image and runs it with the testing tools: it does not work on its own.

## The API

| | |
|---|---|
| Name | Confluent REST Proxy for Kafka |
| Version | 7.5.0 |
| Description | RESTful interface to an Apache Kafka cluster (REST Admin API v3). |
| Domain | Messaging |
| License | LicenseRef-Confluent-Community-1.0 |
| Original repository | https://github.com/confluentinc/kafka-rest |
| Technology | Java 17, Confluent Platform 7.5.0 (REST Proxy, Kafka broker in KRaft mode, Schema Registry) |
| Original specification | OpenAPI 3.0, YAML, written by Confluent Kafka REST developers (`api/v3/openapi.yaml` in the original repository) |
| Operations tested | 50 |
| Authentication | None |
| External services | None |

More details (e.g., how 5XX responses are grouped into unique failures) are in the manifest, `restgym-api-manifest.yaml`.

## Contents

| File | Content |
|---|---|
| `specifications/original/kafka-rest-proxy-openapi.yaml` | The original specification (OpenAPI 3.0.0) of the version packaged (7.5.0), unchanged. |
| `specifications/standardized/kafka-rest-proxy-openapi.yaml` | The specification given to the tools (OpenAPI 3.0.0): the original with one server and the base path in the paths. |
| `specifications/standardized/kafka-rest-proxy-openapi.json` | The same specification in JSON (converted with yq). |
| `specifications/standardized/kafka-rest-proxy-swagger.json` | The same specification in Swagger 2.0 (converted with hidi). |
| `specifications/standardized/kafka-rest-proxy-swagger.yaml` | The Swagger 2.0 version in YAML (converted with yq). |
| `specifications/corrected/kafka-rest-proxy-openapi.yaml` | The standardized specification with two fixes that make it match the implementation of 7.5.0. |
| `specifications/corrected/kafka-rest-proxy-openapi.json` | The same specification in JSON (converted with yq). |
| `specifications/corrected/kafka-rest-proxy-swagger.json` | The same specification in Swagger 2.0 (converted with hidi). |
| `specifications/corrected/kafka-rest-proxy-swagger.yaml` | The Swagger 2.0 version in YAML (converted with yq). |
| `specifications/README.md` | Every difference between these specifications. |
| `Dockerfile` | The Docker image of the API, built by RESTgym (`./restgym.sh b`). |
| `entrypoint.sh` | Starts the API (and the services it needs) in the container. |
| `restgym-api-manifest.yaml` | Metadata of the API for RESTgym. |

## How RESTgym runs it

The image starts from the base image of RESTgym for Java 17 (`restgym/api-base:java17`), which contains the proxy and the collection of code coverage. The image copies the REST Proxy, the Kafka broker and Schema Registry from the official Confluent images (`confluentinc/cp-kafka-rest`, `cp-kafka` and `cp-schema-registry`, version 7.5.0) onto the base image of RESTgym. `entrypoint.sh` starts Kafka (KRaft mode, a single node) and Schema Registry, then the REST Proxy on port 8082, with the default configuration files of the Confluent packages (see [Configuration](#configuration)). The REST Proxy logs (e.g., the errors behind its 5XX responses) are in the output of the container (`logs/kafka-rest-proxy-stdout.log` in the results of a run); those of Kafka and Schema Registry are in `/tmp/kafka.log` and `/tmp/schema-registry.log` in the container. The classes for code coverage (the `io.confluent` classes of the REST Proxy and of the REST utilities of Confluent) are extracted from their jars when the image is built, so this repository has no `classes/`. The tools reach the API through the proxy of RESTgym, on port 9090.

### Configuration

The services read the default configuration files copied from the Confluent images, unchanged (the broker with two more settings, given by `entrypoint.sh`: see "Authorizer" below). The Confluent images generate these files from `KAFKA_*` (and `KAFKA_REST_*`, `SCHEMA_REGISTRY_*`) variables when they start, with their own startup scripts (`/etc/confluent/docker`), which this image does not copy nor run: the only variable used is `KAFKA_CLUSTER_ID`, with which `entrypoint.sh` formats the storage of the broker.

| Service | File | Main settings |
|---|---|---|
| Kafka broker | `/etc/kafka/kraft/server.properties` | Broker and controller in one node (`node.id=1`), listeners `localhost:9092` (clients) and `localhost:9093` (controller), data in `/tmp/kraft-combined-logs`; replication factor 1, `num.partitions=1`, `auto.create.topics.enable` and `delete.topic.enable` true (defaults) |
| Schema Registry | `/etc/schema-registry/schema-registry.properties` | Listener `http://0.0.0.0:8081`, schemas in the topic `_schemas` of the broker, compatibility `backward` (default) |
| REST Proxy | `/etc/kafka-rest/kafka-rest.properties` | Only `bootstrap.servers=localhost:9092`; the rest is default: listener `http://0.0.0.0:8082`, Schema Registry at `http://localhost:8081` (records with AVRO, JSON Schema or Protobuf schemas are registered there) |

**Authorizer.** `entrypoint.sh` starts the broker with the authorizer of Kafka, `authorizer.class.name=org.apache.kafka.metadata.authorizer.StandardAuthorizer` (in `kafka-metadata-7.5.0-ccs.jar`, part of the image), and `super.users=User:ANONYMOUS`. The authorizer decides, for each request of a client of the broker, whether its principal may perform the operation on the resource, according to the ACLs, which the 4 ACL operations of the API manage (`GET`, `POST` and `DELETE /v3/clusters/{cluster_id}/acls`, `POST .../acls:batch`). Without an authorizer (the default configuration), these 4 operations always answer 400 `No Authorizer is configured` (error 40002), so the tools could not use them. The listeners of the broker have no authentication, so every client (the REST Proxy, Schema Registry, the controller) is `User:ANONYMOUS`, a super user, whose requests the authorizer allows without reading the ACLs: the ACLs are created, listed and deleted for real, but never restrict a request, so a tool cannot block the API with an ACL (e.g., one that denies everything to `User:ANONYMOUS`). Verified at runtime (2026-10, on the image with and without the authorizer, with the same requests): the 4 ACL operations answer 200, 201 and 204 instead of 400, and all the other requests (clusters, topics, records in JSON and AVRO, configurations, partitions, brokers, consumer groups) answer the same, with the same bodies, also `authorized_operations` with `include_authorized_operations=true` (the broker reports all the operations both without an authorizer and for a super user); the only other difference is the list of the configurations of the broker, which has `super.users` too.

With a single broker, a replication factor above 1 (e.g., `replication_factor` in `POST /v3/clusters/{cluster_id}/topics`) fails, as in any cluster of one broker. The id of the cluster that the API answers (`MkU3OEVBNTcwNTJENDM2Qg`) differs in its last character from `KAFKA_CLUSTER_ID` (`MkU3OEVBNTcwNTJENDM2Qk`): both encode the same 16 bytes, and Kafka answers the canonical encoding.

## Changes made by RESTgym

### API

None: the official Confluent images, unchanged. The image copies their programs and libraries, also `/usr/share/java/kafka-rest-bin`, which the REST Proxy needs to log (it has the binding of SLF4J to log4j: without it, the REST Proxy logged nothing until 2026-10, so the runs before have no log of the REST Proxy).

### Specification

The original specification is `original/kafka-rest-proxy-openapi.yaml` (OpenAPI 3.0.0): `api/v3/openapi.yaml` at the `v7.5.0` tag of the original repository (commit `534aabb`), the version of the API packaged, unchanged.

The standardized specification, `standardized/kafka-rest-proxy-openapi.yaml`, given to the tools, differs from it only in the server and the base path: it has the single server `http://localhost:8082`, instead of the three server URLs of the original (`{protocol}://{address}:{port}/v3`, `{protocol}://{address}:{port}/kafka/v3`, and that of Confluent Cloud), and the base path `/v3` is in each path (e.g., `/v3/clusters`).

The corrected specification, `corrected/kafka-rest-proxy-openapi.yaml`, is the standardized one with two fixes where the original does not match the implementation of 7.5.0: the property `consumers` of consumer groups (`consumer` in the original), and the response 415 of the operations that produce records. Details in `specifications/README.md`.

## External services (verified 2026-10)

None. The REST Proxy uses only the Kafka broker and Schema Registry of its container:

- **Configuration:** the three services connect only to `localhost` (the broker at `localhost:9092`, its controller at `localhost:9093`, Schema Registry at `localhost:8081`), and no client request can point them elsewhere: the API v3 takes no URL of another cluster or registry. No configuration file enables a metrics reporter or the telemetry of Confluent (the jars of `confluent-telemetry` are in the image, on the classpath of Schema Registry, but unused): the REST Proxy starts its clients with `metric.reporters = []`.
- **Runtime**, on the image built from the current files of this repository, with a capture of all the traffic of the container except the requests to the proxy and the loopback: the container runs only the proxy, Kafka, Schema Registry and the REST Proxy; no packet during the startup and 150 seconds idle, nor while creating a topic and producing records (JSON, and AVRO, whose schema the REST Proxy registered in Schema Registry), nor during requests to all the 49 operations of the standardized specification with the id of the cluster, of the broker and of that topic (27 successful).

## Endpoints that may interfere with authentication

RESTgym handles the authentication of the requests, and the tools are not aware of it: an endpoint that ends or changes the session of RESTgym (e.g., logout, login as another user, change or deletion of the user of the proxy, of its password or of its roles) may make the tools fail for the rest of the run. The proxy blocks the requests that would end its session (`471 Blocked by RESTgym`), instead of removing the endpoints from the specifications given to the tools.

None: RESTgym does not authenticate the requests to this API (it needs no authentication), so no endpoint can end or change a session of RESTgym.
