# setup.sh -- Start All Services

## What it does

Starts all four components of the OpenTelemetry tracing demo. Supports two modes:

- **Docker mode** (default) -- builds Docker images and runs all services in containers via `docker compose`
- **Local mode** (`--local`) -- runs application processes on the host, only Jaeger in Docker

## Prerequisites

### Docker mode (default)

- **Docker** with `docker compose` support

### Local mode (`--local`)

- **Docker** -- for running Jaeger
- **uv** -- for running Python services
- **Node.js** -- for running the ui-app (`node app.js`)
- Python dependencies installed (`cd api-gateway && uv sync`, `cd backend-service && uv sync`)
- Node dependencies installed (`cd ui-app && npm install`)

## Usage

```bash
# Docker Compose mode (default) -- builds and runs all containers
./setup.sh

# Bare-metal mode -- processes on host, only Jaeger in Docker
./setup.sh --local
```

## What gets created

### Docker mode

Four containers managed by Docker Compose:

| Container | Service | Port |
|-----------|---------|------|
| otel-demo-jaeger | Jaeger | 16686, 4317, 4318 |
| otel-demo-backend | backend-service | 5002 |
| otel-demo-gateway | api-gateway | 5001 |
| otel-demo-ui | ui-app | 3000 |

### Local mode

| Service | Port | Process |
|---------|------|---------|
| Jaeger | 16686, 4317, 4318 | Docker container `otel-demo-jaeger` |
| backend-service | 5002 | `cd backend-service && uv run flask ...` |
| api-gateway | 5001 | `cd api-gateway && uv run flask ...` |
| ui-app | 3000 | `cd ui-app && node app.js` |

PID files stored in `.pids/`, logs in `.logs/`.

## Error handling

- **Docker mode**: `docker compose up -d --build` handles everything. If containers are already running, they are recreated.
- **Local mode**: If any `.pids/*.pid` files exist, the script refuses to start. Run `./teardown.sh --local` first.
- If the OTLP endpoint does not become ready within 15 seconds (local mode), the script prints a timeout warning but continues.

## Stopping

```bash
./teardown.sh          # Docker mode
./teardown.sh --local  # Local mode
```

See [teardown.md](teardown.md).
