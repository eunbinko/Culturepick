#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
require_restore_project
verify_backup "$@"
gzip -t -- "$1"
gzip -dc -- "$1" | compose exec -T mariadb sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb --user=root'
echo 'MariaDB restored into the isolated project. Reapply permissions and run quality checks.'
