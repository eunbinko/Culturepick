#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
require_restore_project
verify_backup "$@"
compose exec -T mongodb sh -c '
  umask 077
  cfg=$(mktemp)
  trap '\''rm -f -- "$cfg"'\'' EXIT
  escaped=$(printf %s "$MONGO_INITDB_ROOT_PASSWORD" | sed "s/'\''/'\'''\''/g")
  printf "password: '\''%s'\''\n" "$escaped" > "$cfg"
  mongorestore --config="$cfg" --username="$MONGO_INITDB_ROOT_USERNAME" --authenticationDatabase=admin --archive --gzip --nsInclude="culturepick_events.*" --drop --stopOnError
' < "$1"
echo 'MongoDB restored into the isolated project. Reconcile event_id and outbox before resuming writes.'
