#!/usr/bin/env bash
# setup.sh -- Start all services for the OpenTelemetry tracing demo
# Usage: ./setup.sh
# Stops everything: ./teardown.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_DIR="$SCRIPT_DIR/.pids"
LOG_DIR="$SCRIPT_DIR/.logs"

mkdir -p "$PID_DIR" "$LOG_DIR"

# Check if already running
if [ -f "$PID_DIR/jaeger.pid" ] || [ -f "$PID_DIR/backend.pid" ] || [ -f "$PID_DIR/gateway.pid" ] || [ -f "$PID_DIR/ui.pid" ]; then
    echo "ERROR: Services appear to be already running. Run ./teardown.sh first."
    exit 1
fi

echo "Starting OpenTelemetry tracing demo..."
echo "Logs will be written to $LOG_DIR/"
echo ""

# --- 1. Jaeger ---
echo "[1/4] Starting Jaeger..."
docker run --rm -d \
    --name otel-demo-jaeger \
    -p 16686:16686 \
    -p 4317:4317 \
    -p 4318:4318 \
    jaegertracing/all-in-one:latest \
    > "$LOG_DIR/jaeger.log" 2>&1

JAEGER_CID=$(docker ps -q --filter name=otel-demo-jaeger)
echo "$JAEGER_CID" > "$PID_DIR/jaeger.pid"
echo "       Jaeger UI:    http://localhost:16686"

# Wait for Jaeger OTLP endpoint to be ready
printf "       Waiting for OTLP endpoint..."
for i in $(seq 1 15); do
    if curl -s -o /dev/null -w '' http://localhost:4318/v1/traces -X POST -H "Content-Type: application/json" -d '{}' 2>/dev/null; then
        echo " ready"
        break
    fi
    if [ "$i" -eq 15 ]; then
        echo " timeout (continuing anyway)"
    fi
    sleep 1
done

# --- 2. Backend service ---
echo "[2/4] Starting backend-service on :5002..."
cd "$SCRIPT_DIR"
uv run flask --app backend_service:app run --port 5002 \
    > "$LOG_DIR/backend.log" 2>&1 &
echo "$!" > "$PID_DIR/backend.pid"

# --- 3. API gateway ---
echo "[3/4] Starting api-gateway on :5001..."
uv run flask --app main:app run --port 5001 \
    > "$LOG_DIR/gateway.log" 2>&1 &
echo "$!" > "$PID_DIR/gateway.pid"

# --- 4. UI app ---
echo "[4/4] Starting ui-app on :3000..."
cd "$SCRIPT_DIR/ui-app"
node app.js > "$LOG_DIR/ui.log" 2>&1 &
echo "$!" > "$PID_DIR/ui.pid"

# Wait briefly for services to start
sleep 2

echo ""
echo "All services started."
echo ""
echo "  UI app:           http://localhost:3000"
echo "  API gateway:      http://localhost:5001"
echo "  Backend service:  http://localhost:5002"
echo "  Jaeger UI:        http://localhost:16686"
echo ""
echo "Run ./teardown.sh to stop all services."
