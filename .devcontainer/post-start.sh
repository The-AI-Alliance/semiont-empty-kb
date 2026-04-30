#!/usr/bin/env bash
set -euo pipefail

# Runs on every Codespace start (creation and resume). Brings up the backend
# stack via backend.yml + the Codespace overrides + the observe profile.

cd "$(git rev-parse --show-toplevel)"

ENV_FILE=".devcontainer/.env"
ADMIN_FILE=".devcontainer/admin.json"
if [[ ! -f "$ENV_FILE" || ! -f "$ADMIN_FILE" ]]; then
  echo "ERROR: $ENV_FILE or $ADMIN_FILE missing — re-run .devcontainer/post-create.sh"
  exit 1
fi

set -a
# shellcheck source=/dev/null
. "$ENV_FILE"
ADMIN_EMAIL=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["email"])' "$ADMIN_FILE")
ADMIN_PASSWORD=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["password"])' "$ADMIN_FILE")
set +a

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "WARNING: ANTHROPIC_API_KEY is not set."
  echo "  Add it as a Codespaces user secret at:"
  echo "    https://github.com/settings/codespaces"
  echo "  Then rebuild the container (Codespaces: Rebuild Container)."
fi

docker compose \
  -f .semiont/compose/backend.yml \
  -f .devcontainer/docker-compose.codespaces.yml \
  --profile observe \
  up -d --wait

# nomic-embed-text (~270MB) is required by the embedding layer in the
# anthropic config. Idempotent — exits fast if already pulled.
docker compose -f .semiont/compose/backend.yml exec -T ollama \
  ollama pull nomic-embed-text || true

cat <<EOF

Semiont stack is up.
  Backend API    → port 4000  (forwarded by Codespaces)
  Jaeger UI      → port 16686
  Neo4j Browser  → port 7474   (login: neo4j / localpass)

Admin credentials (from $ADMIN_FILE):
  email:    $ADMIN_EMAIL
  password: $ADMIN_PASSWORD

Bring down with:  docker compose -f .semiont/compose/backend.yml --profile observe down
EOF
