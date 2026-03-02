FROM python:3.12-slim

WORKDIR /app

# Install uv for fast dependency management
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Copy dependency files first for layer caching
COPY pyproject.toml uv.lock* ./

# Install dependencies
RUN uv sync --no-dev --no-install-project

# Copy application code
COPY main.py otel_setup.py ./

EXPOSE 5001

CMD ["uv", "run", "flask", "--app", "main:app", "run", "--host", "0.0.0.0", "--port", "5001"]
