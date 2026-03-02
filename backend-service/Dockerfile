FROM python:3.12-slim

WORKDIR /app

# Install uv for fast dependency management
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Copy dependency files first for layer caching
COPY pyproject.toml uv.lock* ./

# Install dependencies
RUN uv sync --no-dev --no-install-project

# Copy application code
COPY backend_service.py otel_setup.py ./

EXPOSE 5002

CMD ["uv", "run", "flask", "--app", "backend_service:app", "run", "--host", "0.0.0.0", "--port", "5002"]
