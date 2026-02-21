# ui-app -- OpenTelemetry Demo UI

A simple Node.js/Express web app that provides a browser UI for invoking the api-gateway endpoints. The app is instrumented with OpenTelemetry so traces flow through all three services: **ui-app -> api-gateway -> backend-service**.

## How to Run

```bash
cd ui-app
npm install
npm start
```

Then open http://localhost:3000 in your browser.

## Prerequisites

- Node.js 18+
- api-gateway running on port 5001
- backend-service running on port 5002
- Jaeger running with OTLP HTTP on port 4318

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OTEL_SERVICE_NAME` | `ui-app` | Service name shown in Jaeger |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://localhost:4318` | Jaeger OTLP HTTP endpoint |
| `API_GATEWAY_URL` | `http://localhost:5001` | URL of the api-gateway service |
| `UI_APP_PORT` | `3000` | Port the UI app listens on |

## Routes

| UI App Route | Proxies To (api-gateway) |
|-------------|--------------------------|
| `GET /api/health` | `GET /` |
| `GET /api/items` | `GET /items` |
| `GET /api/items/:id` | `GET /items/:id` |
| `GET /api/order/:item_id` | `GET /order/:item_id` |

## How Tracing Works

The app uses `@opentelemetry/sdk-node` with HTTP and Express auto-instrumentation. The `tracing.js` file is loaded before `app.js` via `--require` to ensure the `http` module is patched before Express imports it. When `app.js` makes HTTP calls to the api-gateway using Node's `http.get`, the instrumentation automatically injects W3C `traceparent` headers, creating a distributed trace across all three services.
