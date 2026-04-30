#!/usr/bin/env bash
set -euo pipefail

# Runs once on Codespace creation. Generates the per-codespace worker secret
# and warms the third-party image cache. The Semiont images (backend, worker,
# smelter) are built on first `docker compose up`.

cd "$(git rev-parse --show-toplevel)"

ENV_FILE=".devcontainer/.env"
if [[ ! -f "$ENV_FILE" ]] || ! grep -q '^SEMIONT_WORKER_SECRET=' "$ENV_FILE"; then
  echo "SEMIONT_WORKER_SECRET=$(openssl rand -hex 32)" > "$ENV_FILE"
  echo "Generated SEMIONT_WORKER_SECRET → $ENV_FILE"
fi

# Pull third-party images (neo4j, qdrant, postgres, ollama, jaeger).
# Sourcing the env file gives compose a SEMIONT_WORKER_SECRET so it'll render
# the file even though we're only pulling, not running.
set -a
# shellcheck source=/dev/null
. "$ENV_FILE"
set +a

docker compose \
  -f .semiont/compose/backend.yml \
  -f .devcontainer/docker-compose.codespaces.yml \
  --profile observe \
  pull

# Build the three Semiont images now (rather than on first `up`) so the user
# sees a ready stack on first shell.
docker compose \
  -f .semiont/compose/backend.yml \
  -f .devcontainer/docker-compose.codespaces.yml \
  build
