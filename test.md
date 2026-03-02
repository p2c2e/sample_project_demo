# test.sh -- Smoke Test Script

## What it does

Runs HTTP-based smoke tests against all three services and the Jaeger OTLP endpoint. Checks that each endpoint returns the expected HTTP status code and/or response content.

## Prerequisites

- All services must be running (run `./setup.sh` first)
- `curl` must be available (installed by default on macOS and most Linux distributions)

## Usage

```bash
./test.sh
```

No arguments. No configuration needed.

## What it tests

| Service | Test | Check |
|---------|------|-------|
| Jaeger | OTLP POST endpoint | HTTP 200 |
| backend-service | GET / | HTTP 200, contains "status" |
| backend-service | GET /users | Contains "Alice" |
| backend-service | GET /users/1 | Contains "alice@example.com" |
| backend-service | GET /users/999 | HTTP 404 |
| api-gateway | GET / | HTTP 200, contains "status" |
| api-gateway | GET /items | Contains "Widget A" |
| api-gateway | GET /items/1 | Contains "Widget A" |
| api-gateway | GET /items/999 | HTTP 404 |
| api-gateway | GET /order/1 | Contains "user" (cross-service call) |
| ui-app | GET / | HTTP 200, contains "OpenTelemetry" |
| ui-app | GET /api/items | Contains "Widget A" (proxy test) |
| ui-app | GET /api/order/1 | Contains "user" (proxy + cross-service) |

## Output format

```
Running smoke tests...

Jaeger:
  [PASS] OTLP endpoint accepts POST (HTTP 200)

backend-service (port 5002):
  [PASS] GET / returns 200 (HTTP 200)
  [PASS] GET / returns status ok
  ...

---
Results: 14/14 passed
All tests passed.
```

## Exit codes

- `0` -- All tests passed
- `1` -- One or more tests failed
