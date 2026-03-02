# Architecture

This document describes the architecture of the OpenTelemetry tracing demo, including service boundaries, data flow, and trace propagation.

## Service Diagram

```
+------------------------+    +--------------------------+    +----------------------------------+
|    ui-app/             |    |    api-gateway/           |    |   backend-service/               |
|  (Express :3000)       |--->|   (Flask :5001)           |--->|    (Flask :5002)                 |
|                        |    |                           |    |                                  |
|  ui-app/tracing.js     |    |  api-gateway/otel_setup.py|    |  backend-service/otel_setup.py   |
|  ui-app/app.js         |    |  api-gateway/main.py      |    |  backend-service/backend_service.py|
|  ui-app/public/        |    |  api-gateway/Dockerfile   |    |  backend-service/Dockerfile      |
|    index.html          |    |                           |    |                                  |
+------------------------+    +--------------------------+    +----------------------------------+
        |                            |                            |
        |        OTLP/HTTP (port 4318)                            |
        +------------v---------------v----------------------------+
                     |                                            |
              +------+--------------------------------------------+------+
              |              Jaeger All-in-One (Docker)                  |
              |   UI: http://localhost:16686                             |
              |   OTLP HTTP: http://localhost:4318                      |
              |   OTLP gRPC: http://localhost:4317                      |
              +----------------------------------------------------------+
```

## Request Flow: GET /api/order/1

This is the most interesting trace because it crosses all three services.

```
Step 1: Browser sends GET /api/order/1 to ui-app (:3000)
        |
Step 2: ui-app Express handler matches /api/order/:item_id
        |-- HTTP instrumentation creates a span for the incoming request
        |
Step 3: ui-app calls http.request() to api-gateway at GET /order/1 (:5001)
        |-- HTTP instrumentation auto-injects traceparent header
        |-- A new child span is created for the outgoing HTTP call
        |
Step 4: api-gateway Flask receives GET /order/1
        |-- FlaskInstrumentor auto-extracts traceparent header
        |-- A new span is created, parented to the ui-app span
        |
Step 5: api-gateway looks up item locally (in-memory ITEMS list)
        |-- Returns 404 if item not found
        |
Step 6: api-gateway calls requests.get("http://127.0.0.1:5002/users/1")
        |-- RequestsInstrumentor auto-injects traceparent header
        |-- A new child span is created for the outgoing HTTP call
        |
Step 7: backend-service Flask receives GET /users/1
        |-- FlaskInstrumentor auto-extracts traceparent header
        |-- A new span is created, parented to the api-gateway span
        |
Step 8: backend-service creates manual "enrich-user" span
        |-- Sets span attributes: user.id, user.name
        |-- Simulates processing delay
        |
Step 9: backend-service returns user JSON to api-gateway
        |
Step 10: api-gateway creates manual "build-order" span
         |-- Sets span attributes: order.item_id, order.user_id
         |-- Combines item data + user data into order response
         |
Step 11: api-gateway returns order JSON to ui-app
         |
Step 12: ui-app forwards JSON response to the browser
```

## W3C Trace Context Propagation

Trace context flows across service boundaries via the `traceparent` HTTP header. The format is:

```
traceparent: {version}-{trace-id}-{parent-span-id}-{trace-flags}

Example:
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
              |  |                                |                  |
              |  32-char trace ID (shared)        16-char span ID    sampled
              version (always 00)
```

How it works in this demo:

```
ui-app                          api-gateway                     backend-service
  |                                |                                |
  |-- GET /order/1 ------------->  |                                |
  |   traceparent: 00-AAAA-1111-01 |                                |
  |                                |                                |
  |                                |-- GET /users/1 ------------->  |
  |                                |   traceparent: 00-AAAA-2222-01 |
  |                                |                                |
  |                                |   (same trace ID AAAA,         |
  |                                |    new span ID 2222)           |
  |                                |                                |
  |                                |  <-- 200 OK ------------------|
  |  <-- 200 OK -------------------|                                |
```

Key points:
- The **trace ID** (AAAA above) stays the same across all services
- Each service gets its own **span ID** (1111, 2222 above)
- The `traceparent` header is injected/extracted automatically by the OTel instrumentors
- No manual code is needed for propagation

## Service Boundaries

| Service | Tech Stack | Port | Entry Point | OTel Setup | Role |
|---------|-----------|------|-------------|------------|------|
| ui-app | Node.js / Express | 3000 | ui-app/app.js | ui-app/tracing.js | Browser UI, proxies API calls |
| api-gateway | Python / Flask | 5001 | api-gateway/main.py | api-gateway/otel_setup.py | Serves items, creates orders |
| backend-service | Python / Flask | 5002 | backend-service/backend_service.py | backend-service/otel_setup.py | Serves user data |
| Jaeger | Docker | 16686, 4318 | N/A | N/A | Collects and visualizes traces |

## Data Model

Both services use simple in-memory arrays (no database).

**api-gateway -- ITEMS** (in api-gateway/main.py):

```
ID  Name       Price
1   Widget A   9.99
2   Widget B   19.99
3   Widget C   29.99
```

**backend-service -- USERS** (in backend-service/backend_service.py):

```
ID  Name     Email
1   Alice    alice@example.com
2   Bob      bob@example.com
3   Charlie  charlie@example.com
```

The `/order/<item_id>` endpoint combines one item with user ID 1 (Alice) to create an order response.

## File Map

```
sample_project/
  setup.sh               Start all services (Jaeger + Flask + Node)
  teardown.sh            Stop all services
  test.sh                Smoke tests for all endpoints
  docker-compose.yml     Declarative Jaeger setup (alternative to docker run)
  setup-jaeger.sh        Jaeger setup with Docker networking
  CLAUDE.md              Machine-readable project context for Claude Code
  README.md              Quick start and endpoint reference
  README.arch.md         This file -- architecture documentation
  README.code.md         Code walkthrough and patterns
  README.observability.md  Observability concepts and OTEL deep dive
  README.tools.md        Developer tooling guide
  README.claude.md       Guide to using Claude Code effectively
  README.localdev.md     Local development simulation guide
  .gitattributes         Line ending configuration (LF everywhere)
  .gitignore             Git ignore rules
  .python-version        Python version for pyenv (3.12)
  .sdkmanrc              SDKMAN configuration (convention example)
  api-gateway/
    main.py              API gateway Flask app (items + orders)
    otel_setup.py        OTel initialization for the api-gateway service
    pyproject.toml       Python dependencies for api-gateway
    Dockerfile           Container build for api-gateway
    .dockerignore        Docker build exclusions for api-gateway
  backend-service/
    backend_service.py   Backend service Flask app (users)
    otel_setup.py        OTel initialization for the backend-service
    pyproject.toml       Python dependencies for backend-service
    Dockerfile           Container build for backend-service
    .dockerignore        Docker build exclusions for backend-service
  ui-app/
    app.js               Express server, proxies /api/* to api-gateway
    tracing.js           OTel initialization for Node (loaded before app.js)
    package.json         Node dependencies (Express, OTel packages)
    package-lock.json    Locked Node dependency versions
    .env                 Environment variables for ui-app
    ui-app.md            Documentation for the ui-app service
    public/
      index.html         Single-page browser UI for testing endpoints
```
