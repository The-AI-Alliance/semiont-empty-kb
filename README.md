# Semiont Template Knowledge Base

A template repository for creating new [Semiont](https://github.com/The-AI-Alliance/semiont) knowledge bases.

## Quick Start

```bash
git clone https://github.com/The-AI-Alliance/semiont-template-kb.git my-kb
cd my-kb
export ANTHROPIC_API_KEY=<your-api-key>
.semiont/scripts/local_backend.sh --email admin@example.com --password password
```

In a second terminal:

```bash
cd my-kb
.semiont/scripts/local_frontend.sh
```

Open **http://localhost:3000** and enter **http://localhost:4000** as the knowledge base URL.

## Prerequisites

- A container runtime: [Apple Container](https://github.com/apple/container), [Docker](https://www.docker.com/), or [Podman](https://podman.io/)
- An inference provider: `ANTHROPIC_API_KEY` or [Ollama](https://ollama.com/) for fully local inference

No npm or Node.js installation required — everything runs in containers.

## What's Inside

The `.semiont/` directory contains the infrastructure to run a Semiont backend and frontend locally:

```
.semiont/
├── config                        # Project name and settings
├── compose/                      # Docker Compose files
├── containers/                   # Dockerfiles for backend and frontend
└── scripts/                      # Convenience scripts for local development
```

Add your documents anywhere in the project root. They become resources in the knowledge base when you upload them through the UI or CLI.

## Documentation

See the [Semiont repository](https://github.com/The-AI-Alliance/semiont) for full documentation:

- [Configuration Guide](https://github.com/The-AI-Alliance/semiont/blob/main/docs/administration/CONFIGURATION.md) — inference providers, vector search, graph database settings
- [Project Layout](https://github.com/The-AI-Alliance/semiont/blob/main/docs/PROJECT-LAYOUT.md) — how `.semiont/` and resource files are organized
- [Local Semiont](https://github.com/The-AI-Alliance/semiont/blob/main/docs/LOCAL-SEMIONT.md) — alternative setup paths including the Semiont CLI

## License

Apache 2.0 — See [LICENSE](LICENSE) for details.
