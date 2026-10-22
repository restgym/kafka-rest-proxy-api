# Specifications of Confluent REST Proxy for Kafka

## Original specification

`original/kafka-rest-proxy-openapi.yaml` (OpenAPI 3.0.0, YAML), unchanged.

- **Made by**: written by hand by Confluent Kafka REST developers.
- **Source**: https://github.com/confluentinc/kafka-rest/blob/534aabbfba81cd74b747dad8cce44280d718a50d/api/v3/openapi.yaml

It is the specification of the version packaged (`v7.5.0` tag of the original repository, commit `534aabb`).

## Standardized specification

`standardized/kafka-rest-proxy-openapi.yaml`: the original with the change below. `standardized/kafka-rest-proxy-openapi.json` is the same specification in JSON, converted with yq 4.44.3 (the same content and order of properties, checked; see §6.4 of `docs/API-INTEGRATION-PROTOCOL.md` in RESTgym). The 5 comments of the YAML file (e.g., `# Error responses`) are not in the JSON version, which cannot have comments. The Swagger 2.0 version is converted from it (see below).

Changes from the original:

- **One server, and base path `/v3` in the paths**: `servers: [{url: "http://localhost:8082"}]` instead of the three servers of the original, and each path starts with `/v3` (e.g., `/v3/clusters` instead of `/clusters`; all 38 paths).
  - The original has three servers: `{protocol}://{address}:{port}/v3` (Kafka REST Proxy, the one that RESTgym runs; its variables default to `http://localhost:8082/v3`), `{protocol}://{address}:{port}/kafka/v3` (Kafka REST as part of Confluent Server, port 8090 by default) and `https://pkc-00000.region.provider.confluent.cloud/kafka/v3` (Confluent Cloud). The standardized specification keeps only the first, with its default values (`http://localhost:8082`, the port of the API in its RESTgym container, `entrypoint.sh`), its description and its `x-audience`, and without variables. The other two servers are not the API in RESTgym, and have a different base path (`/kafka/v3`).
  - So the URLs of the operations are those of the first server of the original, with its default values (e.g., `http://localhost:8082/v3/clusters`), the ones that the API answers (`/v3/clusters` was used in the runtime checks of 2026-10). The base path is in each path for the tools that do not handle base paths.

**Swagger 2.0 version** (`standardized/kafka-rest-proxy-swagger.json`, and `standardized/kafka-rest-proxy-swagger.yaml`, the same in YAML): converted from `standardized/kafka-rest-proxy-openapi.json` with hidi 3.10.2, the command-line tool of Microsoft's OpenAPI.NET (`mcr.microsoft.com/openapi/hidi:3.10.2.202608213`, `hidi transform -v 2.0 -f json`); its output is only formatted with yq 4.44.3, and its YAML version is converted with yq (see §6.4 of `docs/API-INTEGRATION-PROTOCOL.md` in RESTgym). Checked against the OpenAPI 3 version: the same 49 operations, with the same parameters (name, location, required), request bodies and response codes, and the same 62 schemas, in the same order; it passes the official validation. What the conversion changes: the server becomes `host: localhost:8082` and `schemes: [http]` (no `basePath`, which means `/`); the schemas become `definitions`; the request bodies become `body` (or form) parameters, and the media types of the request bodies and responses become `consumes` and `produces`. `nullable: true` becomes `x-nullable: true` (33 properties), except the schema `AnyValue`, which is only `{nullable: true}` and becomes `{}` (any value: Swagger 2.0 cannot express `null`). The responses `5XX` of the 49 operations are kept as `5XX`: Swagger 2.0 defines only exact codes and `default`, but the official validator accepts them, and `default` would change their meaning.

The official validation passes: `standardized/validation.json` (2026-10, swagger-validator-v2 2.1.9) has no messages.

## Corrected specification

`corrected/kafka-rest-proxy-openapi.yaml`: the standardized specification (`standardized/kafka-rest-proxy-openapi.yaml`), with the changes below, which make it match the implementation of the version packaged (7.5.0). The two files are identical except these changes: so the corrected specification also has the single server `http://localhost:8082` and the base path `/v3` in each path, as the standardized one. `corrected/kafka-rest-proxy-openapi.json` is the same specification in JSON, converted with yq 4.44.3 (the same content and order of properties, checked; see §6.4 of `docs/API-INTEGRATION-PROTOCOL.md` in RESTgym). The 5 comments of the YAML file (e.g., `# Error responses`) are not in the JSON version, which cannot have comments. The Swagger 2.0 version is converted from it (see below).

Changes from the standardized specification:

- **Property `consumer` of `ConsumerGroupData` renamed `consumers`** (the relationship to the consumers of a consumer group). The API writes `consumers` (`ConsumerGroupData` in the code of 7.5.0, tag `v7.5.0`), and the original itself requires `consumers` (in the `required` of `ConsumerGroupData`) while declaring `consumer`: so the original contradicts itself, and a response of the API has a required property that the original does not describe.
- **Response `415` added to `POST /v3/clusters/{cluster_id}/topics/{topic_name}/records` and `POST /v3/clusters/{cluster_id}/topics/{topic_name}/records:batch`**, with the component `UnsupportedMediaTypeErrorResponse` (in `components/responses`). Both operations accept only `application/json` (`@Consumes(MediaType.APPLICATION_JSON)` in `ProduceAction` and `ProduceBatchAction`): verified at runtime (2026-10, in its RESTgym container, through the proxy), with a body of type `text/plain`, both answer HTTP 415 `{"error_code":415,"message":"HTTP 415 Unsupported Media Type"}`.

**Swagger 2.0 version** (`corrected/kafka-rest-proxy-swagger.json`, and `corrected/kafka-rest-proxy-swagger.yaml`, the same in YAML): converted from `corrected/kafka-rest-proxy-openapi.json` with hidi 3.10.2, the command-line tool of Microsoft's OpenAPI.NET (`mcr.microsoft.com/openapi/hidi:3.10.2.202608213`, `hidi transform -v 2.0 -f json`); its output is only formatted with yq 4.44.3, and its YAML version is converted with yq (see §6.4 of `docs/API-INTEGRATION-PROTOCOL.md` in RESTgym). Checked against the OpenAPI 3 version: the same 49 operations, with the same parameters (name, location, required), request bodies and response codes, and the same 62 schemas, in the same order; it passes the official validation. What the conversion changes: the server becomes `host: localhost:8082` and `schemes: [http]` (no `basePath`, which means `/`); the schemas become `definitions`; the request bodies become `body` (or form) parameters, and the media types of the request bodies and responses become `consumes` and `produces`. `nullable: true` becomes `x-nullable: true` (33 properties), except the schema `AnyValue`, which is only `{nullable: true}` and becomes `{}` (any value: Swagger 2.0 cannot express `null`). The responses `5XX` of the 49 operations are kept as `5XX`: Swagger 2.0 defines only exact codes and `default`, but the official validator accepts them, and `default` would change their meaning.

The official validation passes: `corrected/validation.json` (2026-10, swagger-validator-v2 2.1.9) has no messages.

## Endpoints of the original that may interfere with authentication

RESTgym does not authenticate the requests to this API (it needs no authentication). None: the API has no users or credentials. The ACL endpoints (`/clusters/{cluster_id}/acls`, `/acls:batch`) manage the ACLs of Kafka: RESTgym enables the authorizer of Kafka so that they work, with every client of the broker as a super user, so the ACLs never restrict a request (see "Authorizer" in the README of the API).
