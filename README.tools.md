# Developer Tooling Guide

This document explains the tools and conventions used in this project and why they matter for a consistent development workflow.

## Python: uv

[uv](https://docs.astral.sh/uv/) is a fast Python package manager and project tool. This project uses it instead of pip/pipenv/poetry.

### Why uv

- 10-100x faster than pip for dependency resolution and installation
- Manages virtual environments automatically
- Respects `.python-version` for Python version selection
- Single tool for dependencies, virtual environments, and script running

### Key commands

```bash
uv sync              # Install all dependencies from pyproject.toml + uv.lock
uv add flask         # Add a new dependency
uv run flask ...     # Run a command inside the project's virtual environment
uv lock              # Regenerate uv.lock after changing pyproject.toml
```

### How this project uses it

- Each Python service has its own `pyproject.toml` (in `api-gateway/` and `backend-service/`)
- Each has a `uv.lock` pinning exact versions for reproducibility
- `setup.sh --local` runs services via `cd api-gateway && uv run flask ...`

Install uv: https://docs.astral.sh/uv/getting-started/installation/

## Python: pyenv and .python-version

[pyenv](https://github.com/pyenv/pyenv) manages multiple Python versions on your system.

### The .python-version file

This repo includes a `.python-version` file containing `3.12`. When you `cd` into this directory:
- pyenv automatically switches to Python 3.12
- uv reads this file to know which Python to use for the virtual environment

### Setup

```bash
# Install pyenv (macOS)
brew install pyenv

# Install the required Python version
pyenv install 3.12

# Verify
python --version   # Should show 3.12.x when in this directory
```

## Java/JVM: sdkman and .sdkmanrc

[SDKMAN](https://sdkman.io/) manages JVM-related tools (Java, Gradle, Maven, Kotlin, etc.).

### The .sdkmanrc convention

This repo includes a `.sdkmanrc` file (commented out, since the project does not use Java). The convention is:

```
# .sdkmanrc
java=21.0.2-tem
gradle=8.5
```

When a developer runs `sdk env`, SDKMAN switches to the specified versions. With `sdkman_auto_env=true` in SDKMAN config, this happens automatically on `cd`.

### Why include it

Even if your project does not use Java today, the `.sdkmanrc` file:
- Documents the convention for any future JVM services
- Signals to developers that version management is intentional
- Takes up one file and costs nothing

Install SDKMAN: https://sdkman.io/install

## Node.js: nvm and .nvmrc

[nvm](https://github.com/nvm-sh/nvm) manages Node.js versions, similar to pyenv for Python.

### Convention

A `.nvmrc` file at the repo root specifies the Node version:

```
18
```

This repo does not include a `.nvmrc` because it does not pin a specific Node version beyond "18+". If you need strict version control, add one.

### Setup

```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash

# Install and use the required version
nvm install 18
nvm use 18
```

## Docker

Docker runs Jaeger (the trace collector/UI) in this project.

### Why Docker for Jaeger

Jaeger is a Go binary with a web UI. Running it in Docker means:
- No local installation or compilation
- Clean isolation from your system
- One command to start, one to stop
- Consistent across macOS, Linux, and Windows

### docker-compose.yml

This repo includes a `docker-compose.yml` for declarative Jaeger management:

```bash
docker compose up -d     # Start Jaeger in background
docker compose down       # Stop and remove container
docker compose logs -f    # Tail Jaeger logs
```

The `setup.sh` script uses `docker compose` when available, falling back to `docker run` otherwise.

### Port mapping

| Host Port | Container Port | Purpose |
|-----------|---------------|---------|
| 16686 | 16686 | Jaeger web UI |
| 4317 | 4317 | OTLP gRPC receiver |
| 4318 | 4318 | OTLP HTTP receiver |

### Docker networking

The `setup-jaeger.sh` script demonstrates Docker networking with `--network otel-net`. This is needed when services run inside Docker containers and need to communicate by container name instead of `localhost`. For this demo (services on host, only Jaeger in Docker), port mapping to `localhost` is sufficient.

## VSCode Configuration

### Line endings

Add this to your workspace or user settings:

```json
{
  "files.eol": "\n"
}
```

This ensures new files use Unix line endings (LF), matching the `.gitattributes` configuration.

### Recommended extensions

- **Python** (ms-python.python) -- Python language support
- **Pylance** (ms-python.vscode-pylance) -- Python type checking
- **ESLint** (dbaeumer.vscode-eslint) -- JavaScript linting

### .gitattributes rationale

This repo uses:

```
* text=auto eol=lf
```

What this does:
- `text=auto` -- Git auto-detects text vs binary files
- `eol=lf` -- All text files use Unix line endings (LF) in the working directory

Why:
- Shell scripts (`.sh`) break with Windows line endings (CRLF)
- Docker and CI environments expect LF
- Prevents "no changes but everything shows as modified" issues when developers switch between macOS/Linux and Windows
- One rule for all files is simpler than file-by-file configuration

## Claude Code

This project includes a `CLAUDE.md` file that provides context to Claude Code (the AI coding assistant). See [README.claude.md](README.claude.md) for details on using Claude Code effectively with this project.

## Windows Users

If you are developing on Windows, see [README.windows.md](README.windows.md) for a complete setup guide covering WSL, Rancher Desktop, VSCode with WSL integration, Docker CLI, Python, Node.js, and all other tooling. All development happens inside WSL -- the Windows guide walks you through everything from scratch.

## Summary: Convention Files

| File | Tool | Purpose |
|------|------|---------|
| `.python-version` | pyenv / uv | Pin Python version (3.12) |
| `.sdkmanrc` | SDKMAN | Pin JVM tool versions (convention example) |
| `.nvmrc` | nvm | Pin Node.js version (not included in this repo) |
| `.gitattributes` | Git | Enforce LF line endings |
| `api-gateway/pyproject.toml` | uv / pip | API gateway Python dependencies |
| `backend-service/pyproject.toml` | uv / pip | Backend service Python dependencies |
| `*/uv.lock` | uv | Locked Python dependency versions (per service) |
| `ui-app/package.json` | npm | Node.js project metadata and dependencies |
| `ui-app/package-lock.json` | npm | Locked Node dependency versions |
| `docker-compose.yml` | Docker Compose | All services + infrastructure definitions |
| `*/Dockerfile` | Docker | Container image build instructions (per service) |
| `CLAUDE.md` | Claude Code | AI assistant project context |
