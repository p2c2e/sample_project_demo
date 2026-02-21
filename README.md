# Flask + OpenTelemetry Cross-Service Tracing Demo

Two Flask services and a Node.js UI app with OpenTelemetry instrumentation, using Jaeger to visualize distributed traces across service boundaries.

## Architecture

```
Browser  -->  ui-app (Express :3000)  -->  api-gateway (Flask :5001)  -->  backend-service (Flask :5002)
                /api/order/:id               /order/<id>                      /users/<id>
                        \                          \                              \
                         `--- OTLP HTTP (:4318) --> Jaeger UI (:16686) <----------'
```

## Prerequisites

- Python 3.12+
- [uv](https://docs.astral.sh/uv/) package manager
- Node.js 18+
- Docker (for Jaeger)

## Setup

Install Python dependencies:

```bash
uv sync
```

Install Node.js dependencies:

```bash
cd ui-app && npm install
```

## Running

### Step 1: Start Jaeger

Run the Jaeger all-in-one container (provides a UI + OTLP collector):

```bash
docker run --rm \
  -p 16686:16686 \
  -p 4317:4317 \
  -p 4318:4318 \
  jaegertracing/all-in-one:latest
```

### Step 2: Start the backend service (terminal 1)

```bash
uv run flask --app backend_service:app run --port 5002
```

### Step 3: Start the API gateway (terminal 2)

```bash
uv run flask --app main:app run --port 5001
```

Telemetry is configured programmatically via `otel_setup.py` -- each service calls `init_telemetry()` at import time, which sets up the OTLP exporter and instruments Flask + requests.

### Step 4: Start the UI app (terminal 3)

```bash
cd ui-app && npm start
```

### Step 5: Generate traces via the UI

Open http://localhost:3000 in your browser. Click buttons to invoke each endpoint. Each request flows through ui-app -> api-gateway (-> backend-service for `/order` endpoints).

Alternatively, you can still use curl directly:

```bash
curl http://localhost:5001/items
curl http://localhost:5001/items/1
curl http://localhost:5001/order/1
```

### Step 6: View traces in Jaeger

Open http://localhost:16686 in your browser.

1. Select service **ui-app** (or **api-gateway**) from the dropdown
2. Click **Find Traces**
3. Click on the `/order/1` trace to see spans from all three services in one waterfall

## Endpoints

### ui-app (ui-app/app.js, port 3000)

| Endpoint | Proxies To |
|---|---|
| `GET /api/health` | api-gateway `GET /` |
| `GET /api/items` | api-gateway `GET /items` |
| `GET /api/items/:id` | api-gateway `GET /items/:id` |
| `GET /api/order/:item_id` | api-gateway `GET /order/:item_id` |

### api-gateway (main.py, port 5001)

| Endpoint | Description |
|---|---|
| `GET /` | Health check |
| `GET /items` | Returns all items (simulates slow DB query) |
| `GET /items/<id>` | Returns one item with a custom "process-item" span |
| `GET /order/<item_id>` | Fetches user from backend-service, combines with local item data |

### backend-service (backend_service.py, port 5002)

| Endpoint | Description |
|---|---|
| `GET /` | Health check |
| `GET /users` | Returns all users (simulates slow DB query) |
| `GET /users/<id>` | Returns one user with a custom "enrich-user" span |

## What to look for in Jaeger

- **`GET /items`** -- single-service trace with one Flask handler span
- **`GET /items/<id>`** -- single-service trace with a child **process-item** span (manual instrumentation)
- **`GET /order/<id>`** (via ui-app) -- three-service trace showing:
  1. `ui-app`: Express handler span for `/api/order/:item_id`
  2. `ui-app`: outgoing HTTP request span to `api-gateway`
  3. `api-gateway`: Flask handler span for `/order/<id>`
  4. `api-gateway`: outgoing HTTP request span to `backend-service`
  5. `backend-service`: Flask handler span for `/users/<id>`
  6. `backend-service`: child **enrich-user** span
  7. `api-gateway`: child **build-order** span

All spans appear in a single trace, connected by automatically propagated W3C trace context.

## How it works

### ui-app (Node.js)

The `ui-app/tracing.js` module is loaded via `--require` before `app.js` to ensure HTTP/Express modules are patched before use. It configures `@opentelemetry/sdk-node` with an OTLP HTTP exporter and auto-instrumentations for `http` and `express`. When `app.js` makes `http.get` calls to the api-gateway, the HTTP instrumentation automatically injects `traceparent` headers.

### Python services

The `otel_setup.py` module:
1. Creates a `TracerProvider` with the service name as a resource attribute
2. Adds a `BatchSpanProcessor` with an `OTLPSpanExporter` pointing to Jaeger (port 4318)
3. Instruments Flask via `FlaskInstrumentor().instrument_app(app)` for incoming request spans
4. Instruments `requests` via `RequestsInstrumentor().instrument()` for outgoing HTTP spans with W3C trace context propagation

The manual spans (`process-item`, `enrich-user`, `build-order`) show how to add custom instrumentation when you need finer-grained visibility beyond automatic HTTP spans.

## Alternative: Zero-Code Instrumentation (no programmatic setup)

Instead of the `otel_setup.py` approach, you can use the `opentelemetry-instrument` CLI wrapper.
This requires **no OTel code in your app at all** -- the wrapper patches Flask and requests at startup.

To use this approach, comment out the `otel_setup` lines in `main.py` and `backend_service.py`:

```python
# from otel_setup import init_telemetry
# init_telemetry("api-gateway", app)
```

Then start each service with the `opentelemetry-instrument` wrapper:

Backend (terminal 1):

```bash
OTEL_SERVICE_NAME=backend-service \
OTEL_TRACES_EXPORTER=otlp \
OTEL_METRICS_EXPORTER=none \
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318 \
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf \
uv run opentelemetry-instrument \
    flask --app backend_service:app run --port 5002
```

API gateway (terminal 2):

```bash
OTEL_SERVICE_NAME=api-gateway \
OTEL_TRACES_EXPORTER=otlp \
OTEL_METRICS_EXPORTER=none \
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318 \
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf \
uv run opentelemetry-instrument \
    flask --app main:app run --port 5001
```

All configuration is via environment variables -- no Python code changes needed.
Manual spans (like `process-item`, `enrich-user`, `build-order`) still work because
they use the `opentelemetry.trace` API, which the CLI wrapper also sets up.

### Programmatic vs Zero-Code comparison

| | Programmatic (`otel_setup.py`) | Zero-Code (`opentelemetry-instrument`) |
|---|---|---|
| Code changes needed | 2 lines per service file | None (comment out otel_setup lines) |
| Configuration | In Python code + env vars | Entirely via env vars |
| Run command | `uv run flask --app ...` | `uv run opentelemetry-instrument flask --app ...` |
| Custom spans | Yes (works with both) | Yes (works with both) |
| Best for | Production apps, fine-grained control | Quick prototyping, minimal setup |

## Configuration

The OTLP endpoint defaults to `http://localhost:4318` but can be overridden via the `OTEL_EXPORTER_OTLP_ENDPOINT` environment variable.

## Troubleshooting

If traces don't appear in Jaeger:
- Ensure `OTEL_SDK_DISABLED` is NOT set to `true` in your environment
- Verify Jaeger is running: `curl http://localhost:4318/v1/traces -X POST -H "Content-Type: application/json" -d '{}'` should return `{"partialSuccess":{}}`
- Refresh the Jaeger UI page after generating traces (the service list loads on page load)

## Beyond Flask: opentelemetry-instrument is framework-agnostic

The `opentelemetry-instrument` CLI wrapper is not Flask-specific. It auto-detects **any** installed
`opentelemetry-instrumentation-*` packages and patches the corresponding libraries at startup.

Supported libraries include:

- **Web frameworks**: Django, FastAPI, Starlette, Tornado, Falcon, aiohttp
- **DB clients**: psycopg2, SQLAlchemy, pymysql, pymongo, redis
- **HTTP clients**: requests, urllib3, httpx, aiohttp-client
- **Messaging**: celery, kafka-python, pika (RabbitMQ)
- **gRPC**: grpcio
- **Others**: boto3 (AWS SDK), elasticsearch, jinja2, logging

The pattern is always the same:

```bash
# 1. Install the instrumentation package for your library
uv add opentelemetry-instrumentation-django   # or fastapi, sqlalchemy, etc.

# 2. Run your app with the wrapper
OTEL_SERVICE_NAME=my-service \
OTEL_TRACES_EXPORTER=otlp \
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318 \
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf \
uv run opentelemetry-instrument python my_app.py
```

To discover which instrumentations are available for your currently installed packages:

```bash
uv run opentelemetry-bootstrap --action=requirements
```
