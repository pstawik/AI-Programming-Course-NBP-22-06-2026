#!/usr/bin/env bash
# run-dev.sh
# Reads .env from the repo root and starts the Spring Boot backend.
# Usage: cd app/backend && ./run-dev.sh
# Never hardcodes secrets — reads them from .env which is gitignored.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env not found at $ENV_FILE. Copy .env.example and fill in your keys." >&2
  exit 1
fi

# Export KEY=VALUE pairs (skip comments and blank lines)
while IFS='=' read -r key value; do
  [[ "$key" =~ ^[[:space:]]*# ]] && continue
  [[ -z "$key" ]] && continue
  [[ "$key" =~ ^[[:space:]]*$ ]] && continue
  export "$key"="$value"
done < <(grep -E '^[A-Z_]+=' "$ENV_FILE")

echo "Starting Spring Boot backend with env from $ENV_FILE ..."
exec "$SCRIPT_DIR/mvnw" spring-boot:run
