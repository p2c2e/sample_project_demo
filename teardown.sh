#!/usr/bin/env bash
# teardown.sh -- Stop all services started by setup.sh
#
# Usage:
#   ./teardown.sh          # Docker Compose mode (default)
#   ./teardown.sh --local  # Bare-metal mode

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODE="docker"

if [ "${1:-}" = "--local" ]; then
    MODE="local"
fi

if [ "$MODE" = "docker" ]; then
    echo "Stopping OpenTelemetry tracing demo (Docker Compose)..."
    docker compose -f "$SCRIPT_DIR/docker-compose.yml" down
    echo ""
    echo "All services stopped."
    exit 0
fi

# --- Local mode teardown ---
PID_DIR="$SCRIPT_DIR/.pids"
LOG_DIR="$SCRIPT_DIR/.logs"

echo "Stopping OpenTelemetry tracing demo (local mode)..."

# --- Stop UI app ---
if [ -f "$PID_DIR/ui.pid" ]; then
    PID=$(cat "$PID_DIR/ui.pid")
    if kill -0 "$PID" 2>/dev/null; then
        echo "  Stopping ui-app (PID $PID)..."
        kill "$PID" 2>/dev/null
    fi
    rm -f "$PID_DIR/ui.pid"
else
    echo "  ui-app: not running"
fi

# --- Stop API gateway ---
if [ -f "$PID_DIR/gateway.pid" ]; then
    PID=$(cat "$PID_DIR/gateway.pid")
    if kill -0 "$PID" 2>/dev/null; then
        echo "  Stopping api-gateway (PID $PID)..."
        kill "$PID" 2>/dev/null
    fi
    rm -f "$PID_DIR/gateway.pid"
else
    echo "  api-gateway: not running"
fi

# --- Stop Backend service ---
if [ -f "$PID_DIR/backend.pid" ]; then
    PID=$(cat "$PID_DIR/backend.pid")
    if kill -0 "$PID" 2>/dev/null; then
        echo "  Stopping backend-service (PID $PID)..."
        kill "$PID" 2>/dev/null
    fi
    rm -f "$PID_DIR/backend.pid"
else
    echo "  backend-service: not running"
fi

# --- Stop Jaeger ---
if [ -f "$PID_DIR/jaeger.pid" ] || docker ps -q --filter name=otel-demo-jaeger 2>/dev/null | grep -q .; then
    echo "  Stopping Jaeger container..."
    docker compose -f "$SCRIPT_DIR/docker-compose.yml" stop jaeger 2>/dev/null || true
    docker compose -f "$SCRIPT_DIR/docker-compose.yml" rm -f jaeger 2>/dev/null || true
    rm -f "$PID_DIR/jaeger.pid"
else
    echo "  Jaeger: not running"
fi

# Clean up pid directory
rmdir "$PID_DIR" 2>/dev/null || true

echo ""
echo "All services stopped."
echo "Logs are preserved in $LOG_DIR/"
