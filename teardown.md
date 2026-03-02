# teardown.sh -- Stop All Services

## What it does

Stops all services started by `setup.sh`. Supports two modes matching `setup.sh`:

- **Docker mode** (default) -- `docker compose down` stops and removes all containers
- **Local mode** (`--local`) -- kills host processes and stops the Jaeger container

## Usage

```bash
# Docker Compose mode (default)
./teardown.sh

# Bare-metal mode
./teardown.sh --local
```

## Cleanup behavior

### Docker mode

| What | Action |
|------|--------|
| All containers | Stopped and removed via `docker compose down` |
| Docker networks | Removed by `docker compose down` |
| Docker images | Preserved (not removed) |

### Local mode

| What | Action |
|------|--------|
| Application processes | Sent SIGTERM via `kill` |
| Jaeger container | Stopped via `docker compose stop/rm` |
| `.pids/` directory | PID files removed, directory deleted if empty |
| `.logs/` directory | **Preserved** -- logs are kept for debugging |

## Log preservation (local mode)

Log files in `.logs/` are intentionally kept after teardown so you can inspect service output:

```bash
cat .logs/gateway.log    # Check api-gateway output
cat .logs/backend.log    # Check backend-service output
cat .logs/ui.log         # Check ui-app output
cat .logs/jaeger.log     # Check Jaeger startup output
```

To remove logs manually:

```bash
rm -rf .logs/
```

## Handling stale state

If `teardown.sh --local` cannot find PID files but Jaeger is still running, it falls back to stopping the container by name (`otel-demo-jaeger`).
