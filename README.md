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
| `specifications/kafka-rest-proxy-openapi.json` | The specification given to the tools (OpenAPI 3.0.0). |
| `specifications/kafka-rest-proxy.yaml` | The specification given to the tools (OpenAPI 3.0.0). |
| `specifications/openapi-original.yaml` | The original specification (OpenAPI 3.0.0) of the version packaged (7.5.0), unchanged. |
| `Dockerfile` | The Docker image of the API, built by RESTgym (`./restgym.sh b`). |
| `entrypoint.sh` | Starts the API (and the services it needs) in the container. |
| `restgym-api-manifest.yaml` | Metadata of the API for RESTgym. |

## How RESTgym runs it

The image starts from the base image of RESTgym for Java 17 (`restgym/api-base:java17`), which contains the proxy and the collection of code coverage. The image copies the REST Proxy, the Kafka broker and Schema Registry from the official Confluent images (`confluentinc/cp-kafka-rest`, `cp-kafka` and `cp-schema-registry`, version 7.5.0) onto the base image of RESTgym. `entrypoint.sh` starts Kafka (KRaft mode, a single node) and Schema Registry, then the REST Proxy on port 8082, with the default configuration files of the Confluent packages (see [Configuration](#configuration)). The REST Proxy logs (e.g., the errors behind its 5XX responses) are in the output of the container (`logs/kafka-rest-proxy-stdout.log` in the results of a run); those of Kafka and Schema Registry are in `/tmp/kafka.log` and `/tmp/schema-registry.log` in the container. The classes for code coverage (the `io.confluent` classes of the REST Proxy and of the REST utilities of Confluent) are extracted from their jars when the image is built, so this repository has no `classes/`. The tools reach the API through the proxy of RESTgym, on port 9090.

### Configuration

The services read the default configuration files copied from the Confluent images, unchanged. The Confluent images generate these files from `KAFKA_*` (and `KAFKA_REST_*`, `SCHEMA_REGISTRY_*`) variables when they start, with their own startup scripts (`/etc/confluent/docker`), which this image does not copy nor run: the only variable used is `KAFKA_CLUSTER_ID`, with which `entrypoint.sh` formats the storage of the broker.

| Service | File | Main settings |
|---|---|---|
| Kafka broker | `/etc/kafka/kraft/server.properties` | Broker and controller in one node (`node.id=1`), listeners `localhost:9092` (clients) and `localhost:9093` (controller), data in `/tmp/kraft-combined-logs`; replication factor 1, `num.partitions=1`, `auto.create.topics.enable` and `delete.topic.enable` true (defaults) |
| Schema Registry | `/etc/schema-registry/schema-registry.properties` | Listener `http://0.0.0.0:8081`, schemas in the topic `_schemas` of the broker, compatibility `backward` (default) |
| REST Proxy | `/etc/kafka-rest/kafka-rest.properties` | Only `bootstrap.servers=localhost:9092`; the rest is default: listener `http://0.0.0.0:8082`, Schema Registry at `http://localhost:8081` (records with AVRO, JSON Schema or Protobuf schemas are registered there) |

With a single broker, a replication factor above 1 (e.g., `replication_factor` in `POST /v3/clusters/{cluster_id}/topics`) fails, as in any cluster of one broker. The id of the cluster that the API answers (`MkU3OEVBNTcwNTJENDM2Qg`) differs in its last character from `KAFKA_CLUSTER_ID` (`MkU3OEVBNTcwNTJENDM2Qk`): both encode the same 16 bytes, and Kafka answers the canonical encoding.

## Changes made by RESTgym

### API

None: the official Confluent images, unchanged. The image copies their programs and libraries, also `/usr/share/java/kafka-rest-bin`, which the REST Proxy needs to log (it has the binding of SLF4J to log4j: without it, the REST Proxy logged nothing until 2026-10-13, so the runs before have no log of the REST Proxy).

### Specification

The original specification is `openapi-original.yaml` (OpenAPI 3.0.0): `api/v3/openapi.yaml` at the `v7.5.0` tag of the original repository (commit `534aabb`), the version of the API packaged, unchanged. `kafka-rest-proxy-openapi.json` and `kafka-rest-proxy.yaml`, given to the tools, have the same content, and differ from it in:

1. **Specification of a newer version of the API.** They are the specification of kafka-rest **8.0** (`api/v3/openapi.yaml` of commits `ace1de9`, 2025-03-13, and `dbbe753`, 2025-07-16, in v8.0.0 and v8.0.1), not of 7.5.0, with one fix: `type: int64` (not a type of OpenAPI) is `type: integer, format: int64` in `PartitionWithOffsetsData`. Compared with 7.5.0, they add the operation `GET /v3/clusters/{cluster_id}/topics/{topic_name}/partitions/{partition_id}/offset` and its schema `PartitionWithOffsetsData` and parameter `offset_type`, the schema `ConsumerGroupType` and the properties `type` and `is_mixed_consumer_group` of consumer groups, the responses 400, 413 and 415 of `POST .../records` and 400 and 415 of `POST .../records:batch`, and other descriptions and examples. **The API (7.5.0) does not implement the added operation**: in the runs of October 2026 (in `results/`), it answered 404 to all of its 3,390 requests (and 400 or 414 to malformed ones).
2. **Base path moved into the paths.** The base path `/v3` is in each path (e.g., `/v3/clusters`), and the server URL is `http://localhost:9090` (since 2025-12-29), instead of the three server URLs of the original (`{protocol}://{address}:{port}/v3`, `{protocol}://{address}:{port}/kafka/v3`, and that of Confluent Cloud).

## Endpoints that may interfere with authentication

RESTgym handles the authentication of the requests, and the tools are not aware of it: an endpoint that ends or changes the session of RESTgym (e.g., logout, login as another user, change or deletion of the user of the proxy, of its password or of its roles) may make the tools fail for the rest of the run. Such endpoints may be removed from the specifications given to the tools.

None: RESTgym does not authenticate the requests to this API (it needs no authentication), so no endpoint can end or change a session of RESTgym.

## To verify

- Why the specification given to the tools is that of kafka-rest 8.0, while the API is 7.5.0 (one of its operations does not exist in 7.5.0), and why the base path was moved into the paths.
