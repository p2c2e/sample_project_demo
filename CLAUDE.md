# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OpenTelemetry distributed tracing demo with three services that produce end-to-end traces viewable in Jaeger:

- **ui-app** (Node.js/Express, port 3000) - Browser UI that proxies requests to the api-gateway. Entry point: `ui-app/app.js`
- **api-gateway** (Python/Flask, port 5001) - Entry point: `api-gateway/main.py`, serves items and creates orders
- **backend-service** (Python/Flask, port 5002) - Entry point: `backend-service/backend_service.py`, serves user data

Request flow: `ui-app -> api-gateway -> backend-service`

## Architecture

Each service lives in its own subdirectory with its own dependencies and Dockerfile:

- `api-gateway/otel_setup.py` - OpenTelemetry init for the api-gateway (OTLP HTTP exporter, Flask + Requests auto-instrumentation)
- `backend-service/otel_setup.py` - OpenTelemetry init for the backend-service (identical copy -- keep in sync)
- `ui-app/tracing.js` - OTel init for the Node service (must be loaded before Express/http). Uses HTTP + Express auto-instrumentation
- `ui-app/app.js` - Express server that proxies `/api/*` routes to the api-gateway via `http.request`
- Trace context propagates automatically across services via W3C `traceparent` headers

## Running the Demo

```bash
# Docker Compose mode (default) -- builds and runs all containers:
./setup.sh

# Bare-metal mode -- processes on host, only Jaeger in Docker:
./setup.sh --local

# Stop everything:
./teardown.sh          # Docker mode
./teardown.sh --local  # Local mode
```

Services individually:
```bash
# Python services (from their subdirectories):
cd api-gateway && uv sync && uv run flask --app main:app run --port 5001
cd backend-service && uv sync && uv run flask --app backend_service:app run --port 5002

# Node UI:
cd ui-app && npm install && npm start
```

Requires: Docker (for Jaeger and/or all services), Python 3.12+, Node.js 18+, `uv` for Python package management.

## Key URLs When Running

- UI: http://localhost:3000
- API Gateway: http://localhost:5001
- Backend Service: http://localhost:5002
- Jaeger UI: http://localhost:16686
- OTLP endpoint: http://localhost:4318

## Dependencies

- Python (api-gateway): managed via `api-gateway/pyproject.toml` + `api-gateway/uv.lock`. Install with `cd api-gateway && uv sync`
- Python (backend-service): managed via `backend-service/pyproject.toml` + `backend-service/uv.lock`. Install with `cd backend-service && uv sync`
- Node: managed via `ui-app/package.json`. Install with `cd ui-app && npm install`

## Environment Variables

| Variable | Default | Used By |
|----------|---------|---------|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://localhost:4318` | All services |
| `OTEL_SERVICE_NAME` | `ui-app` | Node service only |
| `API_GATEWAY_URL` | `http://localhost:5001` | Node service only |
| `UI_APP_PORT` | `3000` | Node service only |
| `BACKEND_SERVICE_URL` | `http://localhost:5002` | api-gateway only (Docker sets to `http://backend-service:5002`) |
