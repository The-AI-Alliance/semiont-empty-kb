#!/usr/bin/env bash
set -euo pipefail

# Start a local Semiont backend with all services in containers.

cd "$(git rev-parse --show-toplevel)"

# --- Colors & output helpers ---

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

QUIET=false

log()     { $QUIET || echo -e "${CYAN}▸${RESET} $1"; }
ok()      { $QUIET || echo -e "${GREEN}✓${RESET} $1"; }
warn()    { echo -e "${YELLOW}⚠️${RESET}  $1"; }
fail()    { echo -e "${RED}✗${RESET} $1" >&2; }
banner()  { $QUIET || echo -e "\n${BOLD}$1${RESET}"; }
run_cmd() { $QUIET || echo -e "  ${DIM}\$ $*${RESET}"; "$@"; }

# --- Parse arguments ---

CONFIG_NAME="ollama-gemma"
CONFIG_DIR=".semiont/containers/semiontconfig"
CACHE_FLAG=""
ADMIN_EMAIL=""
ADMIN_PASSWORD=""
CLEAN_OLLAMA=false
LIST_CONFIGS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG_NAME="$2"; shift 2 ;;
    --list-configs) LIST_CONFIGS=true; shift ;;
    --no-cache) CACHE_FLAG="--no-cache"; shift ;;
    --email) ADMIN_EMAIL="$2"; shift 2 ;;
    --password) ADMIN_PASSWORD="$2"; shift 2 ;;
    --clean-ollama) CLEAN_OLLAMA=true; shift ;;
    --quiet|-q) QUIET=true; shift ;;
    --help|-h)
      echo "Usage: start.sh [options]"
      echo ""
      echo "Start a local Semiont backend with Neo4j, Qdrant, Ollama, PostgreSQL,"
      echo "and the Semiont API server — all in containers."
      echo ""
      echo "Options:"
      echo "  --config <name>       Semiontconfig to use (default: ollama-gemma)"
      echo "  --list-configs        List available configs and exit"
      echo "  --no-cache            Force a fresh backend container build"
      echo "  --email <email>       Admin user email (requires --password)"
      echo "  --password <pass>     Admin user password (requires --email)"
      echo "  --clean-ollama        Remove the Ollama model cache volume and exit"
      echo "  --quiet, -q           Suppress informational output"
      echo "  --help, -h            Show this help"
      echo ""
      echo "Examples:"
      echo "  # Fully local with Ollama (default, no API key needed)"
      echo "  start.sh --email admin@example.com --password password"
      echo ""
      echo "  # Anthropic cloud inference"
      echo "  export ANTHROPIC_API_KEY=<your-key>"
      echo "  start.sh --config anthropic --email admin@example.com --password password"
      echo ""
      echo "  # See available configs"
      echo "  start.sh --list-configs"
      exit 0
      ;;
    *) fail "Unknown argument: $1"; exit 1 ;;
  esac
done

# --- List or validate config ---

if [[ "${LIST_CONFIGS}" == "true" ]]; then
  echo "Available configs:"
  for f in "${CONFIG_DIR}"/*.toml; do
    echo "  $(basename "${f}" .toml)"
  done
  exit 0
fi

CONFIG_FILE="${CONFIG_DIR}/${CONFIG_NAME}.toml"
if [[ ! -f "${CONFIG_FILE}" ]]; then
  fail "Config not found: ${CONFIG_FILE}"
  echo "Available configs:"
  for f in "${CONFIG_DIR}"/*.toml; do
    echo "  $(basename "${f}" .toml)"
  done
  exit 1
fi

# --- Detect container runtime ---

for rt in container docker podman; do
  if command -v "$rt" > /dev/null 2>&1; then
    RT="$rt"
    break
  fi
done
if [[ -z "${RT:-}" ]]; then
  fail "No container runtime found. Install Apple Container, Docker, or Podman."
  exit 1
fi

# Handle --clean-ollama
if [[ "${CLEAN_OLLAMA}" == "true" ]]; then
  log "Removing Ollama model cache volume..."
  run_cmd "${RT}" volume rm semiont-ollama-models 2>/dev/null && ok "Removed." || warn "Volume not found."
  exit 0
fi

NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmjs.org}"

banner "Semiont Local Backend"
log "Container runtime: ${BOLD}${RT}${RESET}"
log "Config: ${BOLD}${CONFIG_NAME}${RESET}"
log "npm registry: ${DIM}${NPM_REGISTRY}${RESET}"

# --- Check required env vars ---

if grep -q 'ANTHROPIC_API_KEY' "${CONFIG_FILE}"; then
  if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    fail "Config '${CONFIG_NAME}' requires ANTHROPIC_API_KEY but it is not set."
    exit 1
  fi
fi

# --- Resolve host address for container networking ---

HOST_ADDR=$($RT run --rm node:22-alpine sh -c "ip route | awk '/default/{print \$3}'" 2>/dev/null)
log "Host address: ${DIM}${HOST_ADDR}${RESET}"

# --- Neo4j ---

NEO4J_NAME="semiont-neo4j"
banner "Neo4j"
run_cmd $RT stop "$NEO4J_NAME" 2>/dev/null || true
sleep 1
PID_ON_PORT=$(lsof -ti :7687 2>/dev/null || echo "")
if [[ -n "$PID_ON_PORT" ]]; then
  log "Killing existing process on port 7687 (PID ${PID_ON_PORT})"
  kill $PID_ON_PORT 2>/dev/null || true
  sleep 1
fi

run_cmd $RT run -d --rm \
  --name "$NEO4J_NAME" \
  -p 7474:7474 \
  -p 7687:7687 \
  -e NEO4J_AUTH=neo4j/localpass \
  -e NEO4J_ACCEPT_LICENSE_AGREEMENT=yes \
  neo4j:5-community > /dev/null

for i in $(seq 1 30); do
  if curl -sf http://localhost:7474 > /dev/null 2>&1; then break; fi
  sleep 1
done
ok "Neo4j on bolt://localhost:7687 (browser: http://localhost:7474)"

# --- Qdrant ---

QDRANT_NAME="semiont-qdrant"
banner "Qdrant"
run_cmd $RT stop "$QDRANT_NAME" 2>/dev/null || true
sleep 1
PID_ON_PORT=$(lsof -ti :6333 2>/dev/null || echo "")
if [[ -n "$PID_ON_PORT" ]]; then
  log "Killing existing process on port 6333 (PID ${PID_ON_PORT})"
  kill $PID_ON_PORT 2>/dev/null || true
  sleep 1
fi

run_cmd $RT run -d --rm \
  --name "$QDRANT_NAME" \
  -p 6333:6333 \
  qdrant/qdrant > /dev/null

for i in $(seq 1 15); do
  if curl -sf http://localhost:6333/healthz > /dev/null 2>&1; then break; fi
  sleep 1
done
ok "Qdrant on http://localhost:6333"

# --- Ollama ---

OLLAMA_NAME="semiont-ollama"
banner "Ollama"

if curl -sf http://localhost:11434/api/version > /dev/null 2>&1; then
  # Host Ollama detected — verify it's reachable from containers
  if "${RT}" run --rm node:22-alpine sh -c "wget -q -O- http://${HOST_ADDR}:11434/api/version" > /dev/null 2>&1; then
    ok "Using host Ollama at http://localhost:11434"
  else
    echo ""
    warn "Ollama is running on the host but not reachable from containers."
    echo "   The backend runs in a container and needs Ollama at ${HOST_ADDR}:11434."
    echo ""
    echo "   Fix: configure Ollama to listen on all interfaces:"
    echo "     ${BOLD}launchctl setenv OLLAMA_HOST 0.0.0.0${RESET}"
    echo "   Then restart Ollama Desktop and re-run this script."
    echo ""
    exit 1
  fi
else
  log "No host Ollama detected — starting container..."
  run_cmd "${RT}" stop "${OLLAMA_NAME}" 2>/dev/null || true
  sleep 1

  OLLAMA_VOLUME=""
  if [ -d "${HOME}/.ollama" ]; then
    printf "  Found local Ollama model cache at %s. Share it? [Y/n] (auto-yes in 10s) " "${HOME}/.ollama"
    read -r -t 10 answer || answer=""
    if [ "${answer}" != "n" ] && [ "${answer}" != "N" ]; then
      OLLAMA_VOLUME="${HOME}/.ollama:/root/.ollama"
      log "Using host model cache."
    fi
  fi
  if [ -z "${OLLAMA_VOLUME}" ]; then
    OLLAMA_VOLUME="semiont-ollama-models:/root/.ollama"
    log "Using named volume semiont-ollama-models for model cache."
  fi

  run_cmd "${RT}" run -d --rm \
    --name "${OLLAMA_NAME}" \
    -p 11434:11434 \
    -m 24G \
    -v "${OLLAMA_VOLUME}" \
    ollama/ollama > /dev/null

  for i in $(seq 1 30); do
    if curl -sf http://localhost:11434/api/version > /dev/null 2>&1; then break; fi
    sleep 1
  done
  ok "Ollama container on http://localhost:11434 (24 GB memory)"
fi

# --- PostgreSQL ---

POSTGRES_NAME="semiont-postgres"
banner "PostgreSQL"
run_cmd $RT stop "$POSTGRES_NAME" 2>/dev/null || true
sleep 1
PID_ON_PORT=$(lsof -ti :5432 2>/dev/null || echo "")
if [[ -n "$PID_ON_PORT" ]]; then
  log "Killing existing process on port 5432 (PID ${PID_ON_PORT})"
  kill $PID_ON_PORT 2>/dev/null || true
  sleep 1
fi

run_cmd $RT run -d --rm \
  --name "$POSTGRES_NAME" \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=localpass \
  -e POSTGRES_DB=semiont \
  postgres:15-alpine > /dev/null

for i in $(seq 1 20); do
  if $RT run --rm postgres:15-alpine pg_isready -h "$HOST_ADDR" -p 5432 > /dev/null 2>&1; then break; fi
  sleep 0.5
done
ok "PostgreSQL on port 5432"

# --- Build backend ---

banner "Backend"
log "Building backend image..."
run_cmd $RT build $CACHE_FLAG --tag semiont-backend \
  --build-arg NPM_REGISTRY="$NPM_REGISTRY" \
  --build-arg SEMIONT_CONFIG="$CONFIG_FILE" \
  --file .semiont/containers/Dockerfile .

ok "Backend image built"

# --- Run backend ---

banner "Starting Backend"
log "http://localhost:4000"

ADMIN_ARGS=()
if [[ -n "$ADMIN_EMAIL" && -n "$ADMIN_PASSWORD" ]]; then
  ADMIN_ARGS=(--env ADMIN_EMAIL="$ADMIN_EMAIL" --env ADMIN_PASSWORD="$ADMIN_PASSWORD")
  log "Admin user: ${BOLD}${ADMIN_EMAIL}${RESET}"
fi

ANTHROPIC_ARGS=()
if grep -q 'ANTHROPIC_API_KEY' "${CONFIG_FILE}"; then
  ANTHROPIC_ARGS=(--env ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY")
fi

run_cmd $RT run --publish 4000:4000 \
  --memory 8G \
  --volume "$(pwd)":/kb \
  ${ANTHROPIC_ARGS[@]+"${ANTHROPIC_ARGS[@]}"} \
  --env POSTGRES_HOST="$HOST_ADDR" \
  --env NEO4J_HOST="$HOST_ADDR" \
  --env QDRANT_HOST="${HOST_ADDR}" \
  --env OLLAMA_HOST="${HOST_ADDR}" \
  ${ADMIN_ARGS[@]+"${ADMIN_ARGS[@]}"} \
  -it semiont-backend
