#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
begin_backup mariadb sql.gz
compose exec -T mariadb sh -c 'MYSQL_PWD="$MARIADB_BACKUP_PASSWORD" exec mariadb-dump --user=backup_user --single-transaction --quick --skip-lock-tables --no-tablespaces --skip-routines --skip-events --databases culturepick culturepick_analytics' | gzip > "$tmp"
finish_backup
