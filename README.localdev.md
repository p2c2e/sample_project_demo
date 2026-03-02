# Local Development Simulation

This document covers strategies for running services locally, simulating cloud environments, and when to use each approach.

## This Repo's Approach

This demo supports two modes:

**Docker mode** (default): All services run in containers via `docker compose up -d --build`.

**Local mode** (`./setup.sh --local`): Application services run as bare-metal processes on the host, only Jaeger in Docker.

```
# Docker mode (default):
Docker:
  - Jaeger all-in-one (ports 16686, 4317, 4318)
  - backend-service (Flask, port 5002)
  - api-gateway (Flask, port 5001)
  - ui-app (Express, port 3000)

# Local mode (--local):
Host machine:
  - backend-service (Flask, port 5002)
  - api-gateway (Flask, port 5001)
  - ui-app (Express, port 3000)
Docker:
  - Jaeger all-in-one (ports 16686, 4317, 4318)
```

### Why local mode is useful for development

- Fast iteration: edit a file, restart the service, see changes immediately
- Easy debugging: attach a debugger directly to the process
- Low resource usage: no Docker overhead for app services
- Simple setup: `./setup.sh --local` starts everything

### When to move beyond this approach

- You need to test Docker images or Dockerfiles
- You need service discovery (DNS-based, not localhost)
- You need to test against cloud services (S3, SQS, DynamoDB)
- You need Kubernetes manifests or Helm charts

## Docker Compose

This repo includes a `docker-compose.yml` that defines all four services (Jaeger + 3 apps):

```bash
# Start everything (build + run)
docker compose up -d --build

# Start only Jaeger (for local dev mode)
docker compose up -d jaeger

# Stop everything
docker compose down

# View logs
docker compose logs -f
```

The `setup.sh` script uses `docker compose` by default. Use `./setup.sh --local` for bare-metal mode.

### How the services are already containerized

Each service has its own `Dockerfile` in its subdirectory:

- `api-gateway/Dockerfile` -- Python 3.12-slim, uses `uv` for dependency management
- `backend-service/Dockerfile` -- Python 3.12-slim, uses `uv` for dependency management
- `ui-app/Dockerfile` -- Node 18-alpine, uses `npm ci` for production dependencies

The `docker-compose.yml` wires them together with Docker Compose networking:

- Service names (`jaeger`, `backend-service`, `api-gateway`) replace `localhost` in URLs
- Environment variables like `BACKEND_SERVICE_URL=http://backend-service:5002` configure inter-service communication
- Docker Compose provides automatic DNS resolution between containers on the same network
- Host ports are still mapped so `test.sh` and browsers can reach services from `localhost`

## Docker Networking

The `setup-jaeger.sh` script in this repo demonstrates Docker networking:

```bash
docker network create otel-net
docker run --network otel-net --name jaeger ...
```

### When you need a Docker network

- **Services in containers talking to each other**: containers on the same network can reach each other by container name (e.g., `http://jaeger:4318`)
- **Isolating environments**: multiple projects can each have their own network without port conflicts

### When you do NOT need it

- **Services on host, infra in Docker**: use port mapping to `localhost` (this repo's `--local` approach)
- **Single container**: just map the ports

## LocalStack for AWS Simulation

[LocalStack](https://localstack.cloud/) provides local emulations of AWS services. It lets you develop and test against S3, SQS, DynamoDB, Lambda, and 50+ other AWS services without an AWS account or internet connection.

### When to use LocalStack

- Your application reads/writes to S3 buckets
- Your application publishes to SQS/SNS
- Your application uses DynamoDB tables
- You want to test AWS Lambda functions locally
- You need to run integration tests against AWS services in CI

### This repo does not use LocalStack

This demo has no AWS dependencies. However, if you added an S3-backed storage service, you would add LocalStack to `docker-compose.yml`:

```yaml
services:
  localstack:
    image: localstack/localstack:latest
    ports:
      - "4566:4566"    # LocalStack gateway
    environment:
      - SERVICES=s3,sqs,dynamodb
      - DEBUG=1
    volumes:
      - ./localstack-init:/etc/localstack/init/ready.d  # Init scripts
```

Then configure your AWS SDK to point to `http://localhost:4566` instead of the real AWS endpoints:

```python
import boto3
s3 = boto3.client("s3", endpoint_url="http://localhost:4566")
s3.create_bucket(Bucket="my-bucket")
```

LocalStack docs: https://docs.localstack.cloud/

## Kubernetes Alternatives

For projects that need Kubernetes locally:

### minikube

Single-node k8s cluster in a VM or container. The most mature option.

```bash
minikube start
kubectl apply -f k8s/
minikube service ui-app
```

https://minikube.sigs.k8s.io/

### kind (Kubernetes in Docker)

Runs k8s nodes as Docker containers. Fast to create and destroy.

```bash
kind create cluster
kubectl apply -f k8s/
```

https://kind.sigs.k8s.io/

### k3d

k3s (lightweight k8s) in Docker. Very fast, low resource usage.

```bash
k3d cluster create demo
kubectl apply -f k8s/
```

https://k3d.io/

### Dev loop tools

- **Tilt** (https://tilt.dev/) -- watches code, rebuilds images, and updates k8s on save
- **Skaffold** (https://skaffold.dev/) -- similar to Tilt, from Google

## When to Use What

| Scenario | Recommended Approach |
|----------|---------------------|
| 1-3 services, no cloud dependencies | Bare-metal processes + Docker for infra (this repo) |
| Need to test Dockerfiles | Docker Compose for all services |
| Need AWS services (S3, SQS, etc.) | Add LocalStack to Docker Compose |
| Need k8s manifests/Helm charts | kind or k3d for local cluster |
| Full production-like environment | Docker Compose or k8s with all services containerized |
| Fast iteration during development | Bare-metal processes (always the fastest) |

### Progression path

Most projects follow this progression as they grow:

```
1. Bare-metal + Docker infra     (this repo)
   |
2. Docker Compose for everything  (add Dockerfiles)
   |
3. Local k8s with kind/k3d       (add k8s manifests)
   |
4. Remote dev/staging k8s        (deploy to cloud)
```

Start simple. Add complexity only when you need it.
