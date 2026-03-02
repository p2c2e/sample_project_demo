# Code Walkthrough

This document explains the key code patterns in this repo, focusing on OpenTelemetry instrumentation and how the services are wired together.

## Python OTel Setup (api-gateway/otel_setup.py, backend-service/otel_setup.py)

Each Python service has its own copy of `otel_setup.py` in its directory. Both copies are identical and initialize tracing for that service. Here is what each section does:

### 1. Safety guard (line 12)

```python
os.environ.pop("OTEL_SDK_DISABLED", None)
```

Removes the `OTEL_SDK_DISABLED` environment variable if present. Some environments set this accidentally, which would silently disable all tracing.

### 2. Resource creation (line 17)

```python
resource = Resource.create(attributes={SERVICE_NAME: service_name})
```

Creates an OTel Resource that tags all spans from this service with its name. This is how Jaeger knows which service produced which spans.

### 3. TracerProvider and exporter (lines 18-23)

```python
provider = TracerProvider(resource=resource)
otlp_endpoint = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4318")
provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint=otlp_endpoint + "/v1/traces"))
)
trace.set_tracer_provider(provider)
```

- `TracerProvider` is the central object that manages span creation
- `BatchSpanProcessor` batches spans before sending (more efficient than sending one at a time)
- `OTLPSpanExporter` sends spans to Jaeger via the OTLP HTTP protocol on port 4318
- `trace.set_tracer_provider(provider)` registers this as the global provider

### 4. Auto-instrumentation (lines 27-28)

```python
FlaskInstrumentor().instrument_app(flask_app)
RequestsInstrumentor().instrument()
```

- `FlaskInstrumentor` patches Flask to create spans for every incoming HTTP request. You get spans like `GET /items` without writing any tracing code in your route handlers.
- `RequestsInstrumentor` patches the `requests` library to create spans for outgoing HTTP calls AND inject the `traceparent` header automatically. This is how trace context propagates to downstream services.

## Node.js OTel Setup (ui-app/tracing.js)

### Why it must be loaded first

```javascript
// app.js line 3:
require('./tracing.js');
```

The tracing module must be `require()`d before `express` and `http` because the OTel instrumentations work by monkey-patching those modules. If Express is loaded first, the patches cannot intercept its method calls.

### Key initialization (tracing.js lines 29-37)

```javascript
var provider = new sdkTraceNode.NodeTracerProvider({
  resource: resource,
  spanProcessors: [
    new sdkTraceBase.BatchSpanProcessor(otlpExporter),
  ],
});
provider.register();
```

Mirrors the Python setup: creates a provider with a resource and batch span processor, then registers it globally.

### Instrumentations (lines 40-45)

```javascript
registerInstrumentations({
  instrumentations: [
    new HttpInstrumentation(),
    new ExpressInstrumentation(),
  ],
});
```

- `HttpInstrumentation` patches Node's `http` module. This creates spans for outgoing `http.request()` calls and injects `traceparent` headers.
- `ExpressInstrumentation` creates spans for incoming Express route handlers.

### Graceful shutdown (lines 51-65)

```javascript
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
```

Ensures that buffered spans are flushed to Jaeger before the process exits. Without this, the last batch of spans could be lost.

## Manual Spans

Auto-instrumentation gives you HTTP-level spans. Manual spans add business-level visibility.

### process-item (api-gateway/main.py lines 46-49)

```python
with tracer.start_as_current_span("process-item") as span:
    span.set_attribute("item.id", item_id)
    span.set_attribute("item.name", item["name"])
    time.sleep(random.uniform(0.01, 0.05))
```

Creates a child span under the Flask handler span. The `with` block defines the span's lifetime. Attributes are searchable in Jaeger.

### enrich-user (backend-service/backend_service.py lines 43-46)

```python
with tracer.start_as_current_span("enrich-user") as span:
    span.set_attribute("user.id", user_id)
    span.set_attribute("user.name", user["name"])
    time.sleep(random.uniform(0.01, 0.05))
```

Same pattern. In a real app, this might represent a cache lookup, external API call, or data transformation.

### build-order (api-gateway/main.py lines 71-79)

```python
with tracer.start_as_current_span("build-order") as span:
    span.set_attribute("order.item_id", item_id)
    span.set_attribute("order.user_id", 1)
    time.sleep(random.uniform(0.01, 0.03))
    order = {
        "item": item,
        "user": user_resp.json(),
        "total": item["price"],
    }
```

This span wraps the order assembly logic. It runs after the backend-service call returns, so it appears as a sibling span to the outgoing HTTP span in the Jaeger waterfall.

## Proxy Pattern in ui-app (app.js)

```javascript
function proxyGet(gatewayPath, res) {
  var options = {
    hostname: gatewayUrl.hostname,
    port: gatewayUrl.port,
    path: gatewayPath,
    method: 'GET',
  };
  var proxyReq = http.request(options, function (apiRes) {
    // ...
  });
  proxyReq.end();
}
```

The ui-app uses Node's built-in `http.request()` instead of a library like `axios` or `node-fetch`. This is deliberate: the `HttpInstrumentation` patches `http.request()` to automatically create spans and inject `traceparent` headers. Using a third-party HTTP client would require its own instrumentation package.

## Programmatic vs Zero-Code Instrumentation

This repo defaults to the **programmatic** approach (calling `init_telemetry()` in each service). The alternative is **zero-code** using the `opentelemetry-instrument` CLI wrapper.

| Aspect | Programmatic | Zero-Code |
|--------|-------------|-----------|
| Setup location | `otel_setup.py` in each service dir, called in app code | CLI wrapper, no app code changes |
| Configuration | Code + env vars | Env vars only |
| Run command | `uv run flask --app main:app run` | `uv run opentelemetry-instrument flask --app main:app run` |
| Manual spans | Work with both | Work with both |
| Control level | Fine-grained | Convention-based |

See [README.md](README.md) for full zero-code usage instructions.

## Key Patterns to Notice

1. **Per-service otel_setup.py** -- Each Python service has its own copy of `otel_setup.py` in its directory (`api-gateway/otel_setup.py` and `backend-service/otel_setup.py`). The copies are identical and should be kept in sync when making changes to OTel configuration.

2. **tracing.js as first require** -- The `require('./tracing.js')` call on line 3 of `app.js` is critical. Moving it below `require('express')` would break instrumentation.

3. **dotenv for Node config** -- The ui-app uses `dotenv` to load `.env` variables. The Python services rely on `os.environ.get()` with defaults.

4. **Simulated latency** -- `time.sleep(random.uniform(...))` calls create variable-duration spans, making the Jaeger waterfall more realistic and easier to understand visually.

5. **In-memory data** -- No database means no setup friction. The focus is on tracing, not data persistence.

6. **W3C propagation is automatic** -- No code manually sets or reads `traceparent` headers. The instrumentors handle it.
