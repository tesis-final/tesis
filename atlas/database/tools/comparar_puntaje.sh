#!/usr/bin/env bash
# =============================================================================
# ATLAS — tools/comparar_puntaje.sh  (Hito 3, devolución de Base de Datos)
#
# Pedido: «elijan un reporte docente y comparen dos consultas sobre los mismos datos de
# desarrollo. Una leerá el puntaje guardado y la otra lo calculará a partir de las
# respuestas. Verifiquen que ambas devuelvan los mismos valores y registren sus tiempos en
# varias ejecuciones. Con la cuenta atlas_app, intenten además modificar el puntaje de
# prueba una vez cerrado el intento y conserven el mensaje de rechazo.»
#
# Reporte elegido: Reportes → «Resumen por actividad» (promedio de puntaje e intentos por
# actividad de un grupo). Corre sobre un MySQL 8.0 REAL y DESCARTABLE con los datos
# representativos (datos_representativos.sql) y los mismos scripts que producción.
#
# Uso:  atlas/database/tools/comparar_puntaje.sh [archivo_salida] [repeticiones]
# Las contraseñas son de PRUEBA local y el contenedor se borra al terminar.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."                     # carpeta atlas/
SALIDA=$(realpath -m "${1:-../docs/evidencias/G/E-BD-017-puntaje-guardado-vs-calculado.txt}")
N=${2:-20}
mkdir -p "$(dirname "$SALIDA")"
IMAGEN=${ATLAS_TEST_MYSQL_IMAGE:-mysql:8.0}
RED=atlas_back_puntaje
CONT=atlas-db-puntaje
# Red propia de la prueba (no choca con una pila de ATLAS levantada en la misma PC). Los
# usuarios de MySQL se crean restringidos a esta red, igual que en producción a atlas_back.
PREFIJO=${ATLAS_PRUEBA_RED:-192.168.251}
SERVIDOR_IP=$PREFIJO.20
CLIENTE_IP=$PREFIJO.21                         # dentro de $PREFIJO.16/28, como atlas-php
PW=root-puntaje-solo-local
APP=app-puntaje-solo-local

ms() { date +%s%3N; }
m()  { docker exec -i -e MYSQL_PWD="$PW" "$CONT" mysql -uroot --default-character-set=utf8mb4 "$@"; }
mq() { m -N -B atlas_db -e "$1"; }
tabla() { m -t atlas_db -e "$1"; }
# Cliente que se conecta como atlas_app desde la red de la aplicación (192.168.250.16/28).
como_app() {
  docker run --rm -i --network "$RED" --ip "$CLIENTE_IP" -e MYSQL_PWD="$APP" --entrypoint mysql "$IMAGEN" \
    -h "$SERVIDOR_IP" -uatlas_app --default-character-set=utf8mb4 atlas_db -e "$1" 2>&1 | grep -v 'Using a password' || true
}

limpiar() { docker rm -f "$CONT" >/dev/null 2>&1 || true; docker network rm "$RED" >/dev/null 2>&1 || true; }
limpiar
trap limpiar EXIT
docker network create --subnet "$PREFIJO.16/28" --gateway "$PREFIJO.17" "$RED" >/dev/null
docker run -d --name "$CONT" --network "$RED" --ip "$SERVIDOR_IP" \
  -e MYSQL_ROOT_PASSWORD="$PW" -e ATLAS_DB_ALLOWED_HOST="$PREFIJO.16/255.255.255.240" \
  -e ATLAS_DB_APP_PASSWORD="$APP" -e ATLAS_DB_READ_PASSWORD=read-puntaje \
  -e ATLAS_DB_ANALYSIS_PASSWORD=ana-puntaje -e ATLAS_DB_BACKUP_PASSWORD=bkp-puntaje -e ATLAS_DB_ADMIN_PASSWORD=adm-puntaje \
  -v "$PWD/database:/atlas/database:ro" \
  -v "$PWD/docker/mysql/init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro" \
  -v "$PWD/docker/mysql/02-usuarios.sh:/docker-entrypoint-initdb.d/02-usuarios.sh:ro" \
  "$IMAGEN" --character-set-server=utf8mb4 --collation-server=utf8mb4_0900_ai_ci --default-time-zone=+00:00 >/dev/null
for _ in $(seq 1 100); do
  if docker logs "$CONT" 2>&1 | grep -q 'init process done' && m -e 'SELECT 1' >/dev/null 2>&1; then break; fi
  sleep 2
done
m atlas_db < database/tools/datos_representativos.sql >/dev/null
m -e "ANALYZE TABLE atlas_db.intentos, atlas_db.respuestas, atlas_db.resultados, atlas_db.opciones, atlas_db.preguntas" >/dev/null

G="(SELECT id FROM grupos_clase WHERE nombre='S03' AND anio_lectivo=2026 ORDER BY id DESC LIMIT 1)"
GUARDADO="SELECT i.actividad_id, COUNT(*) AS intentos, ROUND(AVG(r.puntaje), 2) AS promedio
  FROM resultados r
  JOIN intentos i         ON i.id = r.intento_id
  JOIN actividad_grupo ag ON ag.actividad_id = i.actividad_id AND ag.grupo_id = $G
  JOIN usuario_grupo ug   ON ug.usuario_id = i.usuario_id AND ug.grupo_id = ag.grupo_id
 GROUP BY i.actividad_id ORDER BY i.actividad_id"
# Sin el puntaje guardado: correctas / total de preguntas de la actividad × 100. Una pregunta
# sin responder cuenta como incorrecta (LEFT JOIN), igual que Indicadores::puntaje en PHP.
CALCULADO="SELECT x.actividad_id, COUNT(*) AS intentos, ROUND(AVG(x.p), 2) AS promedio
  FROM (SELECT i.id, i.actividad_id,
               100 * COALESCE(SUM(o.es_correcta), 0) / (SELECT COUNT(*) FROM preguntas p WHERE p.actividad_id = i.actividad_id) AS p
          FROM intentos i
          JOIN actividad_grupo ag ON ag.actividad_id = i.actividad_id AND ag.grupo_id = $G
          JOIN usuario_grupo ug   ON ug.usuario_id = i.usuario_id AND ug.grupo_id = ag.grupo_id
          LEFT JOIN respuestas re ON re.intento_id = i.id
          LEFT JOIN opciones o    ON o.id = re.opcion_id
         WHERE i.estado = 'FINALIZADO'
         GROUP BY i.id, i.actividad_id) x
 GROUP BY x.actividad_id ORDER BY x.actividad_id"

# Tiempo en el servidor de N ejecuciones (SHOW PROFILES, en una misma sesión).
tiempos() {
  local sql=$1 lote="" i
  for i in $(seq 1 "$N"); do lote+="$sql; "; done
  mq "SET profiling = 1; SET profiling_history_size = 100; $lote SELECT '@@P@@'; SHOW PROFILES;" \
    | awk -F'\t' 'p && NF>=3 && $1 ~ /^[0-9]+$/ && $3 !~ /@@P@@|^SET / {print $2*1000} $0=="@@P@@" {p=1}' | sort -n
}
resumen() {   # min · mediana · p95 · máx en ms
  awk '{v[NR]=$1} END {printf "mín %.2f ms · mediana %.2f ms · p95 %.2f ms · máx %.2f ms (n=%d)", v[1], v[int((NR+1)/2)], v[int(NR*0.95+0.999)], v[NR], NR}'
}

{
  echo "ATLAS — Evidencia E-BD-017: puntaje guardado contra puntaje calculado, y rechazo de atlas_app"
  echo "Fecha (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Motor: MySQL $(mq 'SELECT VERSION()') (imagen $IMAGEN, contenedor descartable)"
  echo "Entorno: desarrollo (Docker) con datos representativos. No es atlas-srv01."
  echo "Datos: $(mq 'SELECT COUNT(*) FROM intentos') intentos, $(mq 'SELECT COUNT(*) FROM resultados') resultados, $(mq 'SELECT COUNT(*) FROM respuestas') respuestas"
  echo "Reporte elegido: Reportes → «Resumen por actividad» del grupo S03 (promedio e intentos por actividad)."
  echo
  echo "== 1. Consulta A: lee el puntaje guardado (resultados.puntaje)"
  echo "$GUARDADO"
  tabla "$GUARDADO"
  echo
  echo "== 2. Consulta B: calcula el puntaje desde respuestas y opciones"
  echo "$CALCULADO"
  tabla "$CALCULADO"
  echo
  echo "== 3. ¿Devuelven lo mismo?"
  DIF=$(mq "SELECT COUNT(*) FROM ($GUARDADO) a LEFT JOIN ($CALCULADO) b ON b.actividad_id = a.actividad_id
             WHERE b.actividad_id IS NULL OR a.intentos <> b.intentos OR a.promedio <> b.promedio")
  FILAS=$(mq "SELECT COUNT(*) FROM ($GUARDADO) a")
  echo "Actividades del reporte: $FILAS · filas con alguna diferencia entre A y B: $DIF"
  # Además del reporte, intento por intento en toda la base.
  DIF_INT=$(mq "SELECT COUNT(*) FROM resultados r JOIN (
                  SELECT i.id, ROUND(100 * COALESCE(SUM(o.es_correcta), 0) / (SELECT COUNT(*) FROM preguntas p WHERE p.actividad_id = i.actividad_id), 2) AS p
                    FROM intentos i LEFT JOIN respuestas re ON re.intento_id = i.id LEFT JOIN opciones o ON o.id = re.opcion_id
                   WHERE i.estado = 'FINALIZADO' GROUP BY i.id, i.actividad_id) c ON c.id = r.intento_id
                 WHERE c.p <> r.puntaje")
  SIN=$(mq "SELECT COUNT(*) FROM intentos i LEFT JOIN resultados r ON r.intento_id = i.id WHERE i.estado = 'FINALIZADO' AND r.id IS NULL")
  echo "Intento por intento, en toda la base: $(mq 'SELECT COUNT(*) FROM resultados') resultados comparados · diferencias: $DIF_INT · finalizados sin resultado: $SIN"
  echo
  echo "== 4. Tiempos en el servidor ($N ejecuciones de cada una, SHOW PROFILES)"
  TA=$(tiempos "$GUARDADO" | resumen); TB=$(tiempos "$CALCULADO" | resumen)
  echo "A · puntaje guardado:   $TA"
  echo "B · puntaje calculado:  $TB"
  echo
  echo "== 5. atlas_app intenta modificar el puntaje de un intento cerrado"
  X=$(mq "SELECT r.intento_id FROM resultados r JOIN intentos i ON i.id = r.intento_id WHERE i.estado = 'FINALIZADO' ORDER BY r.intento_id LIMIT 1")
  ANTES=$(mq "SELECT puntaje FROM resultados WHERE intento_id = $X")
  echo "Intento de prueba: $X (FINALIZADO), puntaje guardado: $ANTES"
  echo "Conexión: atlas_app desde $CLIENTE_IP (red de la prueba, equivalente a atlas_back), sin permisos de DDL."
  echo
  echo "-- a) UPDATE resultados SET puntaje = 100 WHERE intento_id = $X;"
  como_app "UPDATE resultados SET puntaje = 100 WHERE intento_id = $X;"
  echo "-- b) DELETE FROM resultados WHERE intento_id = $X;"
  como_app "DELETE FROM resultados WHERE intento_id = $X;"
  echo "-- c) INSERT de un segundo resultado para el mismo intento"
  como_app "INSERT INTO resultados (intento_id, correctas, total_preguntas, puntaje) VALUES ($X, 4, 4, 100);"
  echo "-- d) Cambiar la respuesta de una pregunta del intento cerrado"
  RESP=$(mq "SELECT re.id FROM respuestas re WHERE re.intento_id = $X LIMIT 1")
  OTRA=$(mq "SELECT o.id FROM respuestas re JOIN opciones o ON o.pregunta_id = re.pregunta_id AND o.id <> re.opcion_id WHERE re.id = $RESP LIMIT 1")
  como_app "UPDATE respuestas SET opcion_id = $OTRA WHERE id = $RESP;"
  echo "-- e) Reabrir el intento cerrado"
  como_app "UPDATE intentos SET estado = 'EN_CURSO', finalizado_en = NULL WHERE id = $X;"
  DESPUES=$(mq "SELECT puntaje FROM resultados WHERE intento_id = $X")
  CANT=$(mq "SELECT COUNT(*) FROM resultados WHERE intento_id = $X")
  echo
  echo "Puntaje después de los cinco intentos: $DESPUES (antes: $ANTES) · resultados del intento: $CANT"
  echo
  echo "== 6. Conclusión"
  if [ "$DIF" = 0 ] && [ "$DIF_INT" = 0 ] && [ "$SIN" = 0 ] && [ "$ANTES" = "$DESPUES" ] && [ "$CANT" = 1 ]; then
    echo "Aprobada: las dos consultas devuelven los mismos valores, el puntaje guardado no se pudo alterar y sigue habiendo un único resultado."
  else
    echo "Fallada: revisar las diferencias de arriba."
  fi
  echo "Lectura de los tiempos: la consulta A lee una fila por intento; la B tiene que juntar todas las respuestas"
  echo "con sus opciones y contar las preguntas de cada actividad. La diferencia crece con la cantidad de respuestas."
} | tee "$SALIDA"
