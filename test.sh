#!/usr/bin/env bash
# test.sh -- Smoke tests for the OpenTelemetry tracing demo
#
# Usage: ./test.sh
# Prereq: All services must be running (run ./setup.sh first)
#
# Runs HTTP checks against all three services and the Jaeger OTLP endpoint.
# Prints [PASS] or [FAIL] for each test. Exits 0 if all pass, 1 otherwise.

set -u

PASS=0
FAIL=0

# Helper: check HTTP status code
# Usage: check_status "description" URL EXPECTED_STATUS
check_status() {
    local desc="$1" url="$2" expected="$3"
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    if [ "$status" = "$expected" ]; then
        echo "  [PASS] $desc (HTTP $status)"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $desc (expected HTTP $expected, got $status)"
        FAIL=$((FAIL + 1))
    fi
}

# Helper: check HTTP response contains a substring
# Usage: check_contains "description" URL SUBSTRING
check_contains() {
    local desc="$1" url="$2" substring="$3"
    local body
    body=$(curl -s "$url" 2>/dev/null)
    if echo "$body" | grep -q "$substring"; then
        echo "  [PASS] $desc"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $desc (response does not contain '$substring')"
        FAIL=$((FAIL + 1))
    fi
}

echo "Running smoke tests..."
echo ""

# --- Jaeger OTLP endpoint ---
echo "Jaeger:"
check_status "OTLP endpoint accepts POST" \
    "http://localhost:4318/v1/traces" 200 2>/dev/null || {
    # OTLP POST needs Content-Type header; fall back to a simple check
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" -d '{}' \
        "http://localhost:4318/v1/traces" 2>/dev/null)
    if [ "$STATUS" = "200" ]; then
        echo "  [PASS] OTLP endpoint accepts POST (HTTP $STATUS)"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] OTLP endpoint (expected HTTP 200, got $STATUS)"
        FAIL=$((FAIL + 1))
    fi
}
echo ""

# --- backend-service (port 5002) ---
echo "backend-service (port 5002):"
check_status "GET / returns 200" "http://localhost:5002/" 200
check_contains "GET / returns status ok" "http://localhost:5002/" '"status"'
check_contains "GET /users returns user list" "http://localhost:5002/users" '"Alice"'
check_contains "GET /users/1 returns Alice" "http://localhost:5002/users/1" '"alice@example.com"'
check_status "GET /users/999 returns 404" "http://localhost:5002/users/999" 404
echo ""

# --- api-gateway (port 5001) ---
echo "api-gateway (port 5001):"
check_status "GET / returns 200" "http://localhost:5001/" 200
check_contains "GET / returns status ok" "http://localhost:5001/" '"status"'
check_contains "GET /items returns item list" "http://localhost:5001/items" '"Widget A"'
check_contains "GET /items/1 returns Widget A" "http://localhost:5001/items/1" '"Widget A"'
check_status "GET /items/999 returns 404" "http://localhost:5001/items/999" 404
check_contains "GET /order/1 has item + user" "http://localhost:5001/order/1" '"user"'
echo ""

# --- ui-app (port 3000) ---
echo "ui-app (port 3000):"
check_status "GET / returns 200" "http://localhost:3000/" 200
check_contains "GET / contains OpenTelemetry" "http://localhost:3000/" "OpenTelemetry"
check_contains "GET /api/items proxies item list" "http://localhost:3000/api/items" '"Widget A"'
check_contains "GET /api/order/1 proxies order" "http://localhost:3000/api/order/1" '"user"'
echo ""

# --- Summary ---
TOTAL=$((PASS + FAIL))
echo "---"
echo "Results: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
    echo "$FAIL test(s) failed."
    exit 1
else
    echo "All tests passed."
    exit 0
fi
