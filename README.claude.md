# Using Claude Code Effectively

This document explains how to use [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (Anthropic's CLI-based AI coding assistant) effectively, using this project as an example.

## What is CLAUDE.md

The `CLAUDE.md` file at the project root is a machine-readable context file that Claude Code reads automatically when you start a session in this directory. It tells Claude:

- What the project does
- How the services are structured
- How to run and test things
- Key file paths and their roles
- Environment variables and configuration

Think of it as a README for the AI, not for humans (though humans can read it too).

### What belongs in CLAUDE.md

- Project architecture overview
- How to build, run, and test
- Key file paths and entry points
- Environment variables and their defaults
- Dependency management commands
- Conventions the AI should follow

### What does NOT belong in CLAUDE.md

- Detailed code explanations (that is what README.code.md is for)
- Setup instructions for humans (that is README.md)
- Business requirements or design docs

## Starting with /init

When you start Claude Code in a new project, run:

```
/init
```

This generates a starter `CLAUDE.md` by scanning the project structure, package files, and existing documentation. It gives Claude a baseline understanding of the project.

For this repo, the `/init` command would detect:
- Python project with `pyproject.toml` (Flask, OTel dependencies)
- Node.js sub-project in `ui-app/`
- Shell scripts (`setup.sh`, `teardown.sh`)
- Existing `README.md`

Then refine the generated `CLAUDE.md` with project-specific details that `/init` might miss.

## Updating Memory

Claude Code maintains memory across sessions. As you work, you can tell Claude things like:

- "Remember that we always use uv for Python package management"
- "Remember that tracing.js must be loaded before express"
- "Remember that the backend-service runs on port 5002"

These get stored in Claude's memory directory and are available in future sessions. This is useful for:
- Personal preferences ("always use single quotes in JS")
- Project-specific gotchas ("the OTLP endpoint must include /v1/traces")
- Workflow patterns ("run test.sh after making changes")

### Memory vs CLAUDE.md

| CLAUDE.md | Memory |
|-----------|--------|
| Checked into the repo | Local to your machine |
| Shared with the team | Personal |
| Project-level context | Cross-project preferences |
| Read by anyone using Claude Code on this repo | Read only by your Claude Code sessions |

Use CLAUDE.md for things the whole team should know. Use memory for personal preferences.

## Planning Before Coding

For non-trivial changes, ask Claude to plan before writing code:

```
Plan how to add a new inventory-service following the same pattern as backend-service/backend_service.py
```

Claude will enter plan mode and:
1. Explore the existing code to understand patterns
2. Identify files that need to change
3. Design an approach
4. Present the plan for your approval before writing any code

This prevents wasted effort on the wrong approach. It is especially valuable when:
- The change touches multiple files
- There are multiple valid approaches
- You are unfamiliar with the codebase
- The change has architectural implications

## Effective Prompting Patterns

### Be specific about the pattern to follow

```
Add a new inventory-service on port 5003 following the same pattern as backend-service/.
Copy otel_setup.py for telemetry. Add an in-memory INVENTORY list similar to ITEMS and USERS.
Create a Dockerfile and add it to docker-compose.yml.
```

### Reference existing code

```
Update api-gateway/otel_setup.py to also set up metrics collection using MeterProvider,
similar to how TracerProvider is set up on line 19. Then sync the change to backend-service/otel_setup.py.
```

### Ask for exploration before changes

```
Read through api-gateway/main.py and explain how the /order endpoint propagates trace context
to the backend-service. Do not make any changes yet.
```

### Request specific testing

```
After making changes, run test.sh and verify all tests pass.
If any fail, fix the issue before moving on.
```

### Scope your requests

Instead of:
```
Make the project production-ready
```

Be specific:
```
Add error handling to the /order endpoint in main.py so it returns a proper
error response if the backend-service call times out after 5 seconds.
```

## CLAUDE.md Maintenance

Keep `CLAUDE.md` updated as the project evolves:

- **Add new services**: When you add a service, add its entry point, port, and role
- **Update dependencies**: When you add major dependencies, mention them
- **Document new scripts**: When you add scripts like `test.sh`, add them to the running section
- **Remove stale info**: If a service is removed or renamed, update CLAUDE.md

A stale CLAUDE.md is worse than no CLAUDE.md -- it leads Claude to make incorrect assumptions.

## Global vs Project CLAUDE.md

Claude Code supports two levels:

- `~/.claude/CLAUDE.md` -- Global rules for all projects (e.g., "always use uv", "never auto-commit")
- `<project>/CLAUDE.md` -- Project-specific context (e.g., "this is a Flask + Node demo with 3 services")

Global rules override project rules when they conflict. Use global rules for your personal coding standards and project rules for project-specific knowledge.
