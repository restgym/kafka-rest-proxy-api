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
| Original specification | OpenAPI 3.0, YAML, written by Confluent Kafka REST developers |
| Operations tested | 50 |
| Authentication | None |
| External services | None |

More details (e.g., how 5XX responses are grouped into unique failures) are in the manifest, `restgym-api-manifest.yaml`.

## Contents

| File | Content |
|---|---|
| `specifications/kafka-rest-proxy-openapi.json` | The specification given to the tools (OpenAPI 3.0.0). |
| `specifications/kafka-rest-proxy.yaml` | The specification given to the tools (OpenAPI 3.0.0). |
| `Dockerfile` | The Docker image of the API, built by RESTgym (`./restgym.sh b`). |
| `entrypoint.sh` | Starts the API (and the services it needs) in the container. |
| `restgym-api-manifest.yaml` | Metadata of the API for RESTgym. |

## How RESTgym runs it

The image starts from the base image of RESTgym for Java 17 (`restgym/api-base:java17`), which contains the proxy and the collection of code coverage. The image copies the REST Proxy, the Kafka broker and Schema Registry from the official Confluent images (`confluentinc/cp-kafka-rest`, `cp-kafka` and `cp-schema-registry`, version 7.5.0) onto the base image of RESTgym. `entrypoint.sh` starts Kafka (KRaft mode, a single node) and Schema Registry with the default configuration files of the Confluent images, then the REST Proxy on port 8082. The classes for code coverage (the `io.confluent` classes of the REST Proxy and of the REST utilities of Confluent) are extracted from their jars when the image is built, so this repository has no `classes/`. The tools reach the API through the proxy of RESTgym, on port 9090.

## Changes made by RESTgym

### API

None: the official Confluent images, unchanged.

### Specification

**Base path moved into the paths.** The base path `/v3` is in each path (e.g., `/v3/clusters`) instead of the server URL (`http://localhost:9090`), since 2025-12-29. `kafka-rest-proxy.yaml` is the YAML version of `kafka-rest-proxy-openapi.json`, added by RESTgym. The original specification (`api/v3/openapi.yaml` in the original repository) is not kept.

## To verify

- Why the base path was moved into the paths, and whether the specification differs from the original in other points.
