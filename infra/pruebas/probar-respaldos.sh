#!/usr/bin/env bash
# =============================================================================
# ATLAS — prueba de atlas-respaldo (paso 13 de atlas-srv01) contra un MySQL 8.0 real.
#
# Levanta un MySQL descartable con los mismos scripts que producción (init.sql,
# 02-usuarios.sh y el binlog de docker-compose.yml) y una carpeta /srv/atlas de prueba, y
# comprueba: respaldo completo verificado, incremental con los binlog nuevos, copia de la
# configuración con retención de N versiones, anotación en registro_respaldos con
# atlas_backup, verificación diaria (incluida la detección de un archivo alterado) y la
# prueba de restauración en una base aparte.
#
# Uso: sudo infra/pruebas/probar-respaldos.sh        (necesita Docker)
# Las contraseñas son de PRUEBA y el contenedor se borra al terminar.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/../.."
RAIZ_REPO=$PWD
IMAGEN=${ATLAS_TEST_MYSQL_IMAGE:-mysql:8.0}
CONT=atlas-db-respaldo
TMP=$(mktemp -d)
PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); echo "  PASS  $1"; }
mal() { FAIL=$((FAIL + 1)); echo "  FAIL  $1${2:+  →  $2}"; }
limpiar() { docker rm -f "$CONT" >/dev/null 2>&1 || true; rm -rf "${TMP:?}"; }
trap limpiar EXIT

echo "== MySQL descartable ($IMAGEN) con binlog, como atlas-db"
mkdir -p "$TMP/datos" "$TMP/raiz/web" "$TMP/raiz/config" "$TMP/raiz/logs"
chmod 777 "$TMP/datos"
echo "ATLAS_DB_HOST=atlas-db" > "$TMP/raiz/config/atlas.conf"
echo "<?php // app de prueba" > "$TMP/raiz/web/index.php"
docker run -d --name "$CONT" \
  -e MYSQL_ROOT_PASSWORD=root-resp-solo-local -e ATLAS_DB_APP_PASSWORD=app-resp -e ATLAS_DB_READ_PASSWORD=read-resp \
  -e ATLAS_DB_ANALYSIS_PASSWORD=ana-resp -e ATLAS_DB_BACKUP_PASSWORD=bkp-resp -e ATLAS_DB_ADMIN_PASSWORD=adm-resp \
  -v "$RAIZ_REPO/atlas/database:/atlas/database:ro" \
  -v "$RAIZ_REPO/atlas/docker/mysql/init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro" \
  -v "$RAIZ_REPO/atlas/docker/mysql/02-usuarios.sh:/docker-entrypoint-initdb.d/02-usuarios.sh:ro" \
  -v "$TMP/datos:/var/lib/mysql" \
  "$IMAGEN" --character-set-server=utf8mb4 --collation-server=utf8mb4_0900_ai_ci --default-time-zone=+00:00 \
  --log-bin=atlas-bin --binlog-expire-logs-seconds=691200 --server-id=1 >/dev/null
for _ in $(seq 1 100); do
  docker logs "$CONT" 2>&1 | grep -q 'init process done' && docker exec "$CONT" mysqladmin -uroot -proot-resp-solo-local ping >/dev/null 2>&1 && break
  sleep 2
done
sql() { docker exec "$CONT" mysql -uroot -proot-resp-solo-local -N -B atlas_db -e "$1" 2>/dev/null; }

export ATLAS_RAIZ="$TMP/raiz" ATLAS_DATOS="$TMP/datos" ATLAS_DB_CONTENEDOR="$CONT" ATLAS_RESPALDO_CRED="$TMP/sin-credencial" RET_CONFIG_VERSIONES=3
R=(bash "$RAIZ_REPO/infra/linux/archivos/atlas-respaldo")
B="$TMP/raiz/backups"

echo
echo "[completo]"
SALIDA=$("${R[@]}" completo 2>&1); echo "$SALIDA" | sed 's/^/    /' | grep -v Windows
ls "$B"/completo/atlas_*.sql.gz >/dev/null 2>&1 && ok "volcado de la base creado" || mal "volcado de la base creado"
zcat "$B"/completo/atlas_*.sql.gz | tail -1 | grep -q -- '-- Dump completed' && ok "el volcado está completo (-- Dump completed)" || mal "el volcado está completo"
zcat "$B"/completo/atlas_*.sql.gz | grep -q 'CREATE TABLE `resultados`' && ok "el volcado tiene el esquema (resultados)" || mal "el volcado tiene el esquema"
ls "$B"/completo/atlas_*.archivos.tar.gz "$B"/completo/atlas_*.permisos.txt.gz >/dev/null 2>&1 && ok "archivos (con ACL) y permisos respaldados" || mal "archivos y permisos respaldados"
[ "$(find "$B" -name '*.gz' -perm 600 | wc -l)" -eq "$(find "$B" -name '*.gz' | wc -l)" ] && ok "los respaldos quedan con modo 600" || mal "los respaldos quedan con modo 600"
[ "$(sql "SELECT COUNT(*) FROM registro_respaldos WHERE tipo='COMPLETO' AND destino='LOCAL' AND resultado='OK' AND verificado")" = 3 ] \
  && ok "registro_respaldos: 3 archivos del completo anotados por atlas_backup, verificados" || mal "registro_respaldos del completo"
sql "SELECT sha256 FROM registro_respaldos WHERE archivo LIKE '%.sql.gz'" | grep -q "$(cut -d' ' -f1 "$B"/completo/atlas_*.sql.gz.sha256)" \
  && ok "la huella anotada coincide con la del archivo" || mal "la huella anotada coincide con la del archivo"

echo
echo "[incremental: se crean datos nuevos y se respaldan los binlog]"
sql "INSERT INTO instituciones (nombre, activa) VALUES ('Institucion creada despues del completo (prueba)', TRUE)"
SALIDA=$("${R[@]}" incremental 2>&1); echo "$SALIDA" | sed 's/^/    /' | grep -v Windows
INC=$(ls -1t "$B"/incremental/atlas_*.binlog.tar.gz 2>/dev/null | head -1)
[ -n "$INC" ] && tar -tzf "$INC" | grep -q 'atlas-bin\.' && ok "el incremental contiene binlog" || mal "el incremental contiene binlog"
mkdir -p "$TMP/bl" && tar -xzf "$INC" -C "$TMP/bl" 2>/dev/null
grep -aq 'creada despues del completo' "$TMP"/bl/atlas-bin.* 2>/dev/null && ok "el dato nuevo está en el binlog respaldado" || mal "el dato nuevo está en el binlog respaldado"
[ "$(sql "SELECT COUNT(*) FROM registro_respaldos WHERE tipo='INCREMENTAL' AND resultado='OK'")" = 2 ] && ok "registro_respaldos: incremental anotado" || mal "registro_respaldos: incremental anotado"

echo
echo "[configuración: cada cambio es una versión; se guardan las últimas 3]"
for i in 1 2 3 4 5; do echo "CAMBIO=$i" >> "$TMP/raiz/config/atlas.conf"; "${R[@]}" config >/dev/null 2>&1; sleep 1; done
[ "$(ls "$B"/config/atlas_config_*.tar.gz 2>/dev/null | wc -l)" = 3 ] && ok "retención: quedan 3 versiones de 5" || mal "retención de la configuración" "$(ls "$B"/config | wc -l) archivos"
tar -xzOf "$(ls -1t "$B"/config/atlas_config_*.tar.gz | head -1)" 2>/dev/null | grep -q 'CAMBIO=5' && ok "la última versión tiene el último cambio" || mal "la última versión tiene el último cambio"

echo
echo "[verificación diaria]"
"${R[@]}" verificar >/dev/null 2>&1 && ok "verificar: huellas y frecuencia OK" || mal "verificar: huellas y frecuencia OK"
printf 'x' >> "$INC"
"${R[@]}" verificar >/dev/null 2>&1 && mal "verificar detecta un archivo alterado" || ok "verificar detecta un archivo alterado"

echo
echo "[prueba de restauración en una base aparte]"
SALIDA=$("${R[@]}" probar-restauracion 2>&1); echo "$SALIDA" | sed 's/^/    /'
grep -q 'Tablas: 32' <<<"$SALIDA" && ok "la base restaurada tiene las 32 tablas" || mal "la base restaurada tiene las 32 tablas"
grep -q 'Resultado: 11 de 11' <<<"$SALIDA" && ok "las filas coinciden con las del momento del respaldo" || mal "las filas coinciden"
[ -z "$(sql "SHOW DATABASES LIKE 'atlas_restore_prueba'")" ] && ok "la base de prueba se borra al terminar" || mal "la base de prueba se borra al terminar"

echo
echo "Resultado: $PASS PASS · $FAIL FAIL"
[ "$FAIL" -eq 0 ]
