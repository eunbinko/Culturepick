#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ "${WRITES_PAUSED:-}" == yes ]] || { echo 'Pause app, dispatcher and ETL writes, then set WRITES_PAUSED=yes' >&2; exit 1; }
begin_backup mongodb archive.gz
compose exec -T mongodb sh -c '
  umask 077
  cfg=$(mktemp)
  trap '\''rm -f -- "$cfg"'\'' EXIT
  escaped=$(printf %s "$MONGO_BACKUP_PASSWORD" | sed "s/'\''/'\'''\''/g")
  printf "password: '\''%s'\''\n" "$escaped" > "$cfg"
  mongodump --config="$cfg" --username=event_backup --authenticationDatabase=culturepick_events --db=culturepick_events --archive --gzip
' > "$tmp"
finish_backup
