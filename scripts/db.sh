#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec docker compose --project-directory "$root" --env-file "${ENV_FILE:-$root/infra/db/.env}" -f "$root/infra/db/compose.yaml" "$@"
