#!/usr/bin/env bash
# docker compose wrapper: enables the "cservice" profile when api/web sources exist.
#
# Respects an explicit COMPOSE_PROFILES from the environment or .env.
# Usage: ./scripts/compose.sh up -d
#        ./scripts/compose.sh --profile cservice up -d   # force
set -euo pipefail

cd "$(dirname "$0")/.."

# Load .env the same way compose does (simple KEY=VAL, ignore comments/exports)
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

api_src=${CSERVICE_API_SRC:-./cservice-api}
web_src=${CSERVICE_WEB_SRC:-./cservice-web}

has_api() { [[ -f "$api_src/go.mod" ]]; }
has_web() { [[ -d "$web_src/php_includes" || -f "$web_src/composer.json" ]]; }

# If the user already set profiles (env or .env), leave them alone.
if [[ -z "${COMPOSE_PROFILES:-}" ]]; then
  if has_api && has_web; then
    export COMPOSE_PROFILES=cservice
    echo "Enabling profile: cservice (api + web sources found)"
  elif has_api || has_web; then
    echo "Warning: only one of api/web sources found; not enabling cservice profile." >&2
    echo "  api: $api_src ($(has_api && echo ok || echo missing))" >&2
    echo "  web: $web_src ($(has_web && echo ok || echo missing))" >&2
    echo "  Set COMPOSE_PROFILES=cservice in .env to force, or init both submodules." >&2
  else
    echo "Skipping cservice profile (no api/web sources). Core stack only: hub leaf db gnuworld"
  fi
fi

exec docker compose "$@"
