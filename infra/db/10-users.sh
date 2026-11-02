#!/usr/bin/env bash
# Sourced by the MariaDB official entrypoint, using its docker_process_sql helper.
set -eu
docker_process_sql <<'SQL'
CREATE DATABASE IF NOT EXISTS culturepick_analytics CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
SQL
for spec in migration:MARIADB_MIGRATION_PASSWORD app:MARIADB_APP_PASSWORD collector:MARIADB_COLLECTOR_PASSWORD dispatcher:MARIADB_DISPATCHER_PASSWORD analytics:MARIADB_ANALYTICS_PASSWORD backup:MARIADB_BACKUP_PASSWORD; do
  user="${spec%%:*}_user"
  variable="${spec#*:}"
  password="${!variable:?Missing DB account password}"
  case "$password" in replace-*|'') echo "Generate private values for $variable" >&2; exit 1;; esac
  # Hex literal + QUOTE prevents passwords from becoming executable SQL.
  hex="$(printf '%s' "$password" | od -An -v -tx1 | tr -d ' \n')"
  docker_process_sql <<SQL
SET @pw=CONVERT(0x${hex} USING utf8mb4);
SET @ddl=CONCAT('CREATE USER IF NOT EXISTS ''${user}''@''%'' IDENTIFIED BY ',QUOTE(@pw));
PREPARE cp_create_user FROM @ddl;
EXECUTE cp_create_user;
DEALLOCATE PREPARE cp_create_user;
SQL
done
docker_process_sql <<'SQL'
GRANT ALL PRIVILEGES ON culturepick.* TO 'migration_user'@'%';
GRANT ALL PRIVILEGES ON culturepick_analytics.* TO 'migration_user'@'%';
SQL
# Table-scoped application roles are applied after migrations, via permissions.sql.
