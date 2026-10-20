#!/usr/bin/env bash
# =============================================================================
# ATLAS — tools/actualizar_a_003.sh  (Hito 2)
# Aplica la migración 003 (habilidades y aprobación configurable) a una base
# YA INSTALADA, sin borrar datos. En una instalación nueva no hace falta:
# init.sql ya la incluye.
#
# Uso (en el servidor, con el usuario de consola que puede usar docker):
#   sudo atlas/database/tools/actualizar_a_003.sh [contenedor]     (por defecto atlas-db)
# Hacer antes un respaldo. La contraseña de root la toma del propio contenedor.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."                      # carpeta atlas/database
CONT=${1:-atlas-db}
sql() { docker exec -i "$CONT" sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot --default-character-set=utf8mb4 atlas_db'; }

sql < migrations/003_habilidades_aprobacion.sql
sql < seeds/002_habilidades.sql
docker exec -i "$CONT" sh -c '
  H="${ATLAS_DB_ALLOWED_HOST:-192.168.250.16/255.255.255.240}"
  MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -e "
    GRANT SELECT, INSERT, UPDATE ON atlas_db.habilidades        TO '"'"'atlas_app'"'"'@'"'"'$H'"'"';
    GRANT SELECT, INSERT, DELETE ON atlas_db.pregunta_habilidad TO '"'"'atlas_app'"'"'@'"'"'$H'"'"';"'
echo "Migración 003 aplicada:"
docker exec "$CONT" sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -t -e "
  SELECT COUNT(*) AS habilidades FROM atlas_db.habilidades;
  SELECT COUNT(*) AS columna_requiere_aprobacion FROM information_schema.columns
   WHERE table_schema=\"atlas_db\" AND table_name=\"instituciones\" AND column_name=\"requiere_aprobacion\";"'
