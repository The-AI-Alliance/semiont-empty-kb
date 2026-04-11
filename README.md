# Semiont Template Knowledge Base

A template repository for creating new [Semiont](https://github.com/The-AI-Alliance/semiont) knowledge bases.

## Quick Start

```bash
git clone https://github.com/The-AI-Alliance/semiont-template-kb.git my-kb
cd my-kb
```

Start the backend with one of the available inference configurations:

```bash
# Fully local with Ollama (default, no API key needed)
.semiont/scripts/local_backend.sh --email admin@example.com --password password
```

On first run, the default config (`ollama-gemma`) pulls `gemma4:26b` (17 GB), `gemma4:e2b` (7.2 GB), and `nomic-embed-text` (274 MB) from Ollama — roughly 24 GB total. This is a one-time download.

```bash
# Anthropic cloud inference
export ANTHROPIC_API_KEY=<your-api-key>
.semiont/scripts/local_backend.sh --config anthropic --email admin@example.com --password password
```

```bash
# See available configs
.semiont/scripts/local_backend.sh --list-configs
```

In a second terminal, build and run the frontend (`container` can be replaced with `docker` or `podman`):

```bash
cd my-kb
container build --tag semiont-frontend --file .semiont/containers/Dockerfile.frontend .
container run --publish 3000:3000 -it semiont-frontend
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

## Inference Configuration

Inference configs live in `.semiont/containers/semiontconfig/` and are selected with the `--config` flag. The included configs are:

- `ollama-gemma` (default) — fully local inference via Ollama with Gemma 4 models
- `anthropic` — cloud inference via the Anthropic API

To create your own, add a `.toml` file to the same directory. See the [Configuration Guide](https://github.com/The-AI-Alliance/semiont/blob/main/docs/administration/CONFIGURATION.md) for the full reference.

## Documentation

See the [Semiont repository](https://github.com/The-AI-Alliance/semiont) for full documentation:

- [Configuration Guide](https://github.com/The-AI-Alliance/semiont/blob/main/docs/administration/CONFIGURATION.md) — inference providers, vector search, graph database settings
- [Project Layout](https://github.com/The-AI-Alliance/semiont/blob/main/docs/PROJECT-LAYOUT.md) — how `.semiont/` and resource files are organized
- [Local Semiont](https://github.com/The-AI-Alliance/semiont/blob/main/docs/LOCAL-SEMIONT.md) — alternative setup paths including the Semiont CLI

## License

Apache 2.0 — See [LICENSE](LICENSE) for details.
