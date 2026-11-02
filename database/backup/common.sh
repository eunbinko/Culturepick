#!/usr/bin/env bash
set -euo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
compose() {
  if [[ -n "${RESTORE_PROJECT:-}" ]]; then
    bash "$ROOT/scripts/db.sh" --project-name "$RESTORE_PROJECT" "$@"
  else
    bash "$ROOT/scripts/db.sh" "$@"
  fi
}
require_restore_project() {
  case "${RESTORE_PROJECT:-}" in culturepick-restore-?*) ;; *) echo 'Set RESTORE_PROJECT=culturepick-restore-<unique-name> for an isolated restore target' >&2; exit 1;; esac
  [[ "${RESTORE_CONFIRM:-}" == "$RESTORE_PROJECT" ]] || { echo 'RESTORE_CONFIRM must equal RESTORE_PROJECT' >&2; exit 1; }
}
begin_backup() {
  local kind="$1"
  mkdir -p -- "${BACKUP_DIR:-$ROOT/backups}"
  dest="${BACKUP_DIR:-$ROOT/backups}/${kind}-$(date -u +%Y%m%dT%H%M%SZ)-$$.$2"
  tmp="${dest}.partial"
  trap 'rm -f -- "$tmp"' EXIT
}
finish_backup() {
  [[ -s "$tmp" ]] || { echo 'Empty backup rejected' >&2; exit 1; }
  mv -- "$tmp" "$dest"
  (cd -- "$(dirname -- "$dest")" && sha256sum -- "$(basename -- "$dest")" > "$(basename -- "$dest").sha256")
  printf 'UTC backup completed: %s\n' "$dest"
}
verify_backup() {
  [[ $# == 1 && -s "$1" && -f "$1.sha256" ]] || { echo 'Provide an existing backup and adjacent .sha256' >&2; exit 1; }
  (cd -- "$(dirname -- "$1")" && sha256sum -c -- "$(basename -- "$1").sha256")
}
