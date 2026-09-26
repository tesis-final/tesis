#!/usr/bin/env bash
# =============================================================================
# Ejecuta los tests de la Fase 5 contra un MySQL 8.0 real y efímero.
# Uso: atlas/tests/Database/run.sh [ruta_de_evidencia]
# Credenciales de PRUEBA local (nunca se usan en el servidor).
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."

IMAGEN="${ATLAS_TEST_MYSQL_IMAGE:-mysql:8.0}"
RED=atlas_back_test
CONT=atlas-db-test
export ATLAS_TEST_ROOT_PASSWORD=root-test-solo-local
export ATLAS_DB_APP_PASSWORD=app-test ATLAS_DB_READ_PASSWORD=read-test ATLAS_DB_ANALYSIS_PASSWORD=ana-test
export ATLAS_DB_BACKUP_PASSWORD=bkp-test ATLAS_DB_ADMIN_PASSWORD=adm-test
export ATLAS_TEST_DB_HOST=192.168.250.20

docker rm -f "$CONT" >/dev/null 2>&1 || true
docker network rm "$RED" >/dev/null 2>&1 || true
# Misma subred que atlas_back (CT-07): así se prueban los usuarios restringidos por origen.
docker network create --subnet 192.168.250.16/28 --gateway 192.168.250.17 "$RED" >/dev/null
docker run -d --name "$CONT" --network "$RED" --ip "$ATLAS_TEST_DB_HOST" \
  -e MYSQL_ROOT_PASSWORD="$ATLAS_TEST_ROOT_PASSWORD" \
  -e ATLAS_DB_APP_PASSWORD -e ATLAS_DB_READ_PASSWORD -e ATLAS_DB_ANALYSIS_PASSWORD \
  -e ATLAS_DB_BACKUP_PASSWORD -e ATLAS_DB_ADMIN_PASSWORD \
  -v "$PWD/database:/atlas/database:ro" \
  -v "$PWD/docker/mysql/init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro" \
  -v "$PWD/docker/mysql/02-usuarios.sh:/docker-entrypoint-initdb.d/02-usuarios.sh:ro" \
  "$IMAGEN" >/dev/null

echo "Esperando a MySQL..."
for _ in $(seq 1 80); do
  if docker logs "$CONT" 2>&1 | grep -q 'init process done' \
     && docker exec "$CONT" mysqladmin -uroot -p"$ATLAS_TEST_ROOT_PASSWORD" ping >/dev/null 2>&1; then
    break
  fi
  sleep 3
done

SALIDA="${1:-}"
set +e
{
  echo "# Ejecución: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# Servidor: $(docker exec "$CONT" mysql -uroot -p"$ATLAS_TEST_ROOT_PASSWORD" -N -e 'SELECT VERSION()' 2>/dev/null)"
  echo "# Imagen: $IMAGEN"
  vendor/bin/phpunit --testsuite "${ATLAS_TEST_SUITES:-database}" --colors=never
} 2>&1 | if [ -n "$SALIDA" ]; then tee "$SALIDA"; else cat; fi
RC=${PIPESTATUS[0]}

docker rm -f "$CONT" >/dev/null
docker network rm "$RED" >/dev/null
exit "$RC"
