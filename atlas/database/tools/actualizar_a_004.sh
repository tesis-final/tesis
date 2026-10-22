#!/usr/bin/env bash
# =============================================================================
# ATLAS — tools/actualizar_a_004.sh  (Hito 2)
# Aplica la migración 004 (cálculos en PHP, acta D-4) a una base YA INSTALADA,
# sin borrar datos. En una instalación nueva no hace falta: init.sql ya la incluye.
#
# Uso (en el servidor, con el usuario de consola que puede usar docker):
#   sudo atlas/database/tools/actualizar_a_004.sh [contenedor]     (por defecto atlas-db)
# Hacer antes un respaldo. La contraseña de root la toma del propio contenedor.
# La aplicación tiene que estar actualizada al mismo tiempo: desde 004 es ella la
# que guarda `resultados` y `analisis_grupal`.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."                      # carpeta atlas/database
CONT=${1:-atlas-db}
sql() { docker exec -i "$CONT" sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot --default-character-set=utf8mb4 atlas_db'; }

sql < migrations/004_calculos_en_php.sql
sql < seeds/003_permisos_hito2.sql
docker exec -i "$CONT" sh -c '
  H="${ATLAS_DB_ALLOWED_HOST:-192.168.250.16/255.255.255.240}"
  MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -e "
    GRANT SELECT, INSERT ON atlas_db.resultados               TO '"'"'atlas_app'"'"'@'"'"'$H'"'"';
    GRANT SELECT, INSERT ON atlas_db.analisis_grupal          TO '"'"'atlas_app'"'"'@'"'"'$H'"'"';
    GRANT SELECT, INSERT ON atlas_db.decisiones_recomendacion TO '"'"'atlas_app'"'"'@'"'"'$H'"'"';"'
echo "Migración 004 aplicada:"
docker exec "$CONT" sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -t -e "
  SELECT COUNT(*) AS trigger_resultados FROM information_schema.triggers
   WHERE trigger_schema=\"atlas_db\" AND trigger_name=\"trg_intentos_finalizar\";
  SELECT COUNT(*) AS procedimientos FROM information_schema.routines WHERE routine_schema=\"atlas_db\";"'
