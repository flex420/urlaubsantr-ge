#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$REPO_ROOT"

if [ ! -d "app/urlaubsverwaltung/.git" ] && [ ! -f "app/urlaubsverwaltung/pom.xml" ]; then
  echo "error: upstream submodule not initialised" >&2
  exit 1
fi

docker build \
  --progress=auto \
  --tag flex420/urlaubsverwaltung:verify \
  .

docker compose -f compose/docker-compose.dev.yml config >/dev/null
docker compose -f compose/docker-compose.dev.yml -f compose/docker-compose.oidc.yml config >/dev/null

echo "Verification complete"