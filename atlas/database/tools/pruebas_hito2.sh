#!/usr/bin/env bash
# =============================================================================
# ATLAS — tools/pruebas_hito2.sh  (Hito 2, Base de Datos)
#
# Prueba de punta a punta sobre un MySQL 8.0 REAL y DESCARTABLE (Docker):
#   1. Instalación desde cero (mismos scripts que producción) y conteo de objetos.
#   2. Carga de datos representativos (datos_representativos.sql) con su tiempo.
#   3. Consultas de prueba: resultado, tiempo promedio (3 corridas) y EXPLAIN ANALYZE.
#   4. Consistencia de la única desnormalización (resultados.puntaje) y prueba de
#      rendimiento contra el cálculo sin desnormalizar (devolución de BD).
#   5. Ejercicio de restauración real: respaldo completo + incremental (binlog),
#      trabajo posterior al respaldo, pérdida total de la base, restauración,
#      tiempos (RTO), datos perdidos (RPO) e integridad comparada.
#
# Uso:  atlas/database/tools/pruebas_hito2.sh [carpeta_de_salida]
# Deja dos archivos: E-BD-005-restauracion-rpo-rto.txt y E-BD-006-datos-y-consultas.txt
# Las contraseñas son de PRUEBA local y el contenedor se borra al terminar.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/../.."                     # carpeta atlas/
SALIDA=$(realpath -m "${1:-../docs/evidencias/G}")
mkdir -p "$SALIDA"
IMAGEN=${ATLAS_TEST_MYSQL_IMAGE:-mysql:8.0}
AUX=${ATLAS_MYSQLBINLOG_IMAGE:-mysql:8.0-debian}   # solo para leer los binlog
CONT=atlas-db-hito2
PW=root-hito2-solo-local
BKP=bkp-hito2-solo-local
CONSULTAS="$SALIDA/E-BD-006-datos-y-consultas.txt"
RESTAURA="$SALIDA/E-BD-005-restauracion-rpo-rto.txt"

ms()  { date +%s%3N; }
m()   { docker exec -i -e MYSQL_PWD="$PW" "$CONT" mysql -uroot --default-character-set=utf8mb4 "$@"; }
mq()  { m -N -B atlas_db -e "$1"; }
tabla() { m -t atlas_db -e "$1"; }

docker rm -f "$CONT" >/dev/null 2>&1 || true
trap 'docker rm -f "$CONT" >/dev/null 2>&1 || true' EXIT

# --------------------------------------------------------------------------- 1
T0=$(ms)
docker run -d --name "$CONT" \
  -e MYSQL_ROOT_PASSWORD="$PW" \
  -e ATLAS_DB_APP_PASSWORD=app-hito2 -e ATLAS_DB_READ_PASSWORD=read-hito2 \
  -e ATLAS_DB_ANALYSIS_PASSWORD=ana-hito2 -e ATLAS_DB_BACKUP_PASSWORD="$BKP" \
  -e ATLAS_DB_ADMIN_PASSWORD=adm-hito2 \
  -v "$PWD/database:/atlas/database:ro" \
  -v "$PWD/docker/mysql/init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro" \
  -v "$PWD/docker/mysql/02-usuarios.sh:/docker-entrypoint-initdb.d/02-usuarios.sh:ro" \
  "$IMAGEN" --character-set-server=utf8mb4 --collation-server=utf8mb4_0900_ai_ci \
  --default-time-zone=+00:00 --log-bin=atlas-bin --server-id=1 >/dev/null
for _ in $(seq 1 100); do
  if docker logs "$CONT" 2>&1 | grep -q 'init process done' && m -e 'SELECT 1' >/dev/null 2>&1; then break; fi
  sleep 2
done
T_INST=$(( $(ms) - T0 ))

{
  echo "ATLAS — Evidencia E-BD-006: instalación, datos representativos y consultas de prueba"
  echo "Fecha (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Motor: MySQL $(mq 'SELECT VERSION()') (imagen $IMAGEN, contenedor descartable)"
  echo "Entorno: entorno de desarrollo (Docker). No es atlas-srv01."
  echo
  echo "== 1. Instalación desde cero (init.sql + 02-usuarios.sh, los mismos de producción)"
  echo "Tiempo hasta base lista: $((T_INST / 1000)) s (incluye el arranque de MySQL)"
  tabla "SELECT
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='atlas_db' AND table_type='BASE TABLE') AS tablas,
    (SELECT COUNT(*) FROM information_schema.views  WHERE table_schema='atlas_db') AS vistas,
    (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='atlas_db') AS triggers,
    (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema='atlas_db') AS rutinas,
    (SELECT COUNT(*) FROM information_schema.table_constraints WHERE table_schema='atlas_db' AND constraint_type='FOREIGN KEY') AS claves_foraneas,
    (SELECT COUNT(*) FROM information_schema.check_constraints WHERE constraint_schema='atlas_db') AS checks,
    (SELECT COUNT(DISTINCT table_name, index_name) FROM information_schema.statistics WHERE table_schema='atlas_db') AS indices"

  # ------------------------------------------------------------------------- 2
  echo
  echo "== 2. Datos representativos (database/tools/datos_representativos.sql)"
  T=$(ms); m -t atlas_db < database/tools/datos_representativos.sql; echo "Tiempo de carga: $(( ($(ms) - T) / 1000 )) s"
  m -e "ANALYZE TABLE atlas_db.intentos, atlas_db.respuestas, atlas_db.resultados, atlas_db.interacciones, atlas_db.pregunta_habilidad" >/dev/null

  # ------------------------------------------------------------------------- 3
  echo
  echo "== 3. Consultas de prueba (el dato que vale es el tiempo en el servidor; el del cliente suma el costo de docker exec)"
} > "$CONSULTAS"

consulta() {   # consulta <id> <título> <sql>
  local id=$1 titulo=$2 sql=$3 t total=0 srv
  for _ in 1 2 3; do t=$(ms); mq "$sql" >/dev/null; total=$(( total + $(ms) - t )); done
  # Tiempo en el servidor: SHOW PROFILES de 3 ejecuciones en la misma sesión (promedio).
  srv=$(mq "SET profiling = 1; $sql; $sql; $sql; SELECT '@@PERFILES@@'; SHOW PROFILES;" \
        | awk -F'\t' 'p && NF>=3 && $1 ~ /^[0-9]+$/ && $3 !~ /@@PERFILES@@|^SET / {s+=$2; n++} $0=="@@PERFILES@@" {p=1} END {if (n) printf "%.1f", s/n*1000}')
  {
    echo
    echo "--- $id · $titulo"
    echo "Tiempo en el servidor (SHOW PROFILES, promedio de 3): $srv ms"
    echo "Tiempo desde el cliente (promedio de 3, incluye ~80 ms de docker exec): $(( total / 3 )) ms"
    echo "SQL: $sql"
    tabla "$sql" | head -14
    echo "Plan real (EXPLAIN ANALYZE, recortado):"
    mq "EXPLAIN ANALYZE $sql" | head -c 1800 | sed 's/\\n/\n/g' | head -14
  } >> "$CONSULTAS"
}

G="(SELECT id FROM grupos_clase WHERE nombre='S03' AND anio_lectivo=2026 ORDER BY id DESC LIMIT 1)"

consulta Q1 "Promedio por estudiante de un grupo, usando el puntaje guardado (desnormalizado)" \
"SELECT i.usuario_id, COUNT(*) AS intentos, ROUND(AVG(r.puntaje),2) AS promedio
   FROM resultados r JOIN intentos i ON i.id = r.intento_id
   JOIN usuario_grupo ug ON ug.usuario_id = i.usuario_id AND ug.grupo_id = $G
  GROUP BY i.usuario_id ORDER BY promedio LIMIT 10"

consulta Q1b "Lo mismo calculado desde respuestas y opciones (sin desnormalizar)" \
"SELECT x.usuario_id, COUNT(*) AS intentos, ROUND(AVG(x.p),2) AS promedio
   FROM (SELECT i.id, i.usuario_id, 100 * SUM(o.es_correcta) / (SELECT COUNT(*) FROM preguntas p WHERE p.actividad_id = i.actividad_id) AS p
           FROM intentos i
           JOIN usuario_grupo ug ON ug.usuario_id = i.usuario_id AND ug.grupo_id = $G
           JOIN respuestas re ON re.intento_id = i.id
           JOIN opciones o ON o.id = re.opcion_id
          WHERE i.estado = 'FINALIZADO' GROUP BY i.id) x
  GROUP BY x.usuario_id ORDER BY promedio LIMIT 10"

consulta Q2 "Desempeño del grupo por habilidad (lo nuevo del Hito 2)" \
"SELECT h.nombre AS habilidad, COUNT(*) AS respuestas, ROUND(100 * AVG(o.es_correcta), 1) AS pct_aciertos
   FROM respuestas re
   JOIN intentos i ON i.id = re.intento_id
   JOIN usuario_grupo ug ON ug.usuario_id = i.usuario_id AND ug.grupo_id = $G
   JOIN opciones o ON o.id = re.opcion_id
   JOIN pregunta_habilidad ph ON ph.pregunta_id = re.pregunta_id
   JOIN habilidades h ON h.id = ph.habilidad_id
  GROUP BY h.nombre ORDER BY pct_aciertos"

consulta Q3 "Habilidad más débil de cada estudiante del grupo" \
"SELECT usuario_id, habilidad, pct FROM (
   SELECT i.usuario_id, h.nombre AS habilidad, ROUND(100 * AVG(o.es_correcta), 1) AS pct,
          ROW_NUMBER() OVER (PARTITION BY i.usuario_id ORDER BY AVG(o.es_correcta), h.nombre) AS n
     FROM respuestas re JOIN intentos i ON i.id = re.intento_id
     JOIN usuario_grupo ug ON ug.usuario_id = i.usuario_id AND ug.grupo_id = $G
     JOIN opciones o ON o.id = re.opcion_id
     JOIN pregunta_habilidad ph ON ph.pregunta_id = re.pregunta_id
     JOIN habilidades h ON h.id = ph.habilidad_id
    GROUP BY i.usuario_id, h.nombre) t
  WHERE n = 1 ORDER BY pct LIMIT 10"

consulta Q4 "Requieren atención: promedio de sus últimas 3 actividades por debajo del promedio del grupo" \
"WITH ult AS (
   SELECT i.usuario_id, r.puntaje, ROW_NUMBER() OVER (PARTITION BY i.usuario_id ORDER BY i.iniciado_en DESC) AS n
     FROM resultados r JOIN intentos i ON i.id = r.intento_id
     JOIN usuario_grupo ug ON ug.usuario_id = i.usuario_id AND ug.grupo_id = $G),
 est AS (SELECT usuario_id, AVG(puntaje) AS prom3 FROM ult WHERE n <= 3 GROUP BY usuario_id),
 grp AS (SELECT AVG(prom3) AS prom_grupo FROM est)
 SELECT e.usuario_id, ROUND(e.prom3, 2) AS ultimas3, ROUND(g.prom_grupo, 2) AS grupo
   FROM est e CROSS JOIN grp g WHERE e.prom3 < g.prom_grupo ORDER BY e.prom3 LIMIT 10"

consulta Q5 "Preguntas con más errores de un grupo (vista v_preguntas_error, filtrada como la usa la app)" \
"SELECT actividad_id, orden, respuestas, errores, proporcion_error FROM v_preguntas_error
  WHERE grupo_id = $G ORDER BY proporcion_error DESC LIMIT 10"

consulta Q5b "Lo mismo sin la vista: consulta parametrizada que arranca por el grupo" \
"SELECT p.actividad_id, p.orden, COUNT(*) AS respuestas, SUM(o.es_correcta = FALSE) AS errores,
        ROUND(SUM(o.es_correcta = FALSE) / COUNT(*), 4) AS proporcion_error
   FROM usuario_grupo ug
   JOIN intentos i ON i.usuario_id = ug.usuario_id AND i.estado = 'FINALIZADO'
   JOIN respuestas res ON res.intento_id = i.id
   JOIN preguntas p ON p.id = res.pregunta_id
   JOIN actividad_grupo ag ON ag.actividad_id = p.actividad_id AND ag.grupo_id = ug.grupo_id
   JOIN opciones o ON o.id = res.opcion_id
  WHERE ug.grupo_id = $G AND ug.activo
  GROUP BY p.actividad_id, p.id, p.orden ORDER BY proporcion_error DESC LIMIT 10"

consulta Q6 "Historial de un estudiante (usa el índice ix_intentos_usuario_actividad)" \
"SELECT i.actividad_id, i.numero_intento, i.estado, r.puntaje, i.duracion_seg
   FROM intentos i LEFT JOIN resultados r ON r.intento_id = i.id
  WHERE i.usuario_id = (SELECT MIN(id) FROM usuarios WHERE correo LIKE 'est%@sintetico.atlas.local')
  ORDER BY i.iniciado_en"

{
  echo
  echo "== 4. Consistencia de la desnormalización resultados.puntaje (excepción a la 3FN)"
  echo "Cada fila de resultados se compara con el cálculo hecho desde respuestas y opciones."
  tabla "SELECT
    (SELECT COUNT(*) FROM resultados) AS resultados_revisados,
    (SELECT COUNT(*) FROM resultados r JOIN intentos i ON i.id = r.intento_id
       LEFT JOIN (SELECT re.intento_id, SUM(o.es_correcta) AS c FROM respuestas re JOIN opciones o ON o.id = re.opcion_id GROUP BY re.intento_id) x
              ON x.intento_id = r.intento_id
      WHERE r.correctas <> COALESCE(x.c, 0)
         OR r.total_preguntas <> (SELECT COUNT(*) FROM preguntas p WHERE p.actividad_id = i.actividad_id)
         OR r.puntaje <> ROUND(100 * COALESCE(x.c, 0) / NULLIF(r.total_preguntas, 0), 2)) AS inconsistentes,
    (SELECT COUNT(*) FROM intentos i LEFT JOIN resultados r ON r.intento_id = i.id WHERE i.estado='FINALIZADO' AND r.id IS NULL) AS finalizados_sin_resultado,
    (SELECT COUNT(*) FROM intentos i JOIN resultados r ON r.intento_id = i.id WHERE i.estado='ABANDONADO') AS abandonados_con_resultado"
  echo "Esperado: inconsistentes = 0, finalizados_sin_resultado = 0, abandonados_con_resultado = 0."
  echo "Por qué no puede divergir: el puntaje se escribe una sola vez al finalizar; un intento cerrado no"
  echo "se reabre ni acepta respuestas nuevas (triggers) y atlas_app no tiene UPDATE sobre resultados."
} >> "$CONSULTAS"

# --------------------------------------------------------------------------- 5
{
  echo "ATLAS — Evidencia E-BD-005: ejercicio de restauración real (RPO y RTO)"
  echo "Fecha (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Motor: MySQL $(mq 'SELECT VERSION()') · Entorno: Docker de desarrollo (no es atlas-srv01)"
  echo "Objetivos documentados (Hito 1): RPO 24 h · RTO 4 h"
  echo "Estrategia probada: respaldo completo con mysqldump (usuario atlas_backup, solo lectura)"
  echo "+ incremental con el registro binario (binlog) de MySQL."
  echo
} > "$RESTAURA"

m -e "FLUSH BINARY LOGS"
BINLOG_DESDE=$(m -N -B -e "SHOW MASTER STATUS" | cut -f1)
T=$(ms)
docker exec -e MYSQL_PWD="$BKP" "$CONT" sh -c \
  'mysqldump -u atlas_backup --single-transaction --routines --triggers --no-tablespaces atlas_db > /tmp/completo.sql'
T_RESP=$(( $(ms) - T ))
TAM=$(docker exec "$CONT" sh -c 'wc -c < /tmp/completo.sql')
SHA=$(docker exec "$CONT" sh -c 'sha256sum /tmp/completo.sql | cut -c1-16')
INT_RESP=$(mq "SELECT COUNT(*) FROM intentos")

# Trabajo posterior al respaldo: 50 estudiantes hacen un segundo intento.
mq "INSERT INTO intentos (usuario_id, actividad_id, numero_intento, estado)
    SELECT usuario_id, actividad_id, 2, 'EN_CURSO' FROM intentos
     WHERE numero_intento = 1 AND estado = 'FINALIZADO' ORDER BY id LIMIT 50"
mq "INSERT INTO respuestas (intento_id, pregunta_id, opcion_id, tiempo_seg)
    SELECT i.id, p.id, o.id, 30 FROM intentos i
      JOIN preguntas p ON p.actividad_id = i.actividad_id
      JOIN opciones o ON o.pregunta_id = p.id AND o.es_correcta
     WHERE i.numero_intento = 2"
mq "UPDATE intentos SET estado = 'FINALIZADO', finalizado_en = NOW(3), duracion_seg = 600 WHERE numero_intento = 2"
INT_ANTES=$(mq "SELECT COUNT(*) FROM intentos")

# Foto de integridad antes del desastre: filas y CHECKSUM de cada tabla.
LISTA=$(mq "SELECT GROUP_CONCAT(table_name ORDER BY table_name) FROM information_schema.tables WHERE table_schema='atlas_db' AND table_type='BASE TABLE'")
foto() { m -N -B atlas_db -e "CHECKSUM TABLE $(echo "$LISTA" | sed 's/,/, /g')" | awk '{print $1, $2}'; }
OBJ="SELECT CONCAT((SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='atlas_db'), ' triggers, ',
                   (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema='atlas_db'), ' rutinas, ',
                   (SELECT COUNT(*) FROM information_schema.views WHERE table_schema='atlas_db'), ' vistas')"
foto > /tmp/atlas-foto-antes.txt
OBJ_ANTES=$(mq "$OBJ")

m -e "FLUSH BINARY LOGS"
BINLOG_HASTA=$(m -N -B -e "SHOW MASTER STATUS" | cut -f1)
INCREMENTAL=$(m -N -B -e "SHOW BINARY LOGS" | cut -f1 | awk -v d="$BINLOG_DESDE" -v h="$BINLOG_HASTA" '$1 >= d && $1 < h' | tr '\n' ' ')
# La imagen oficial mysql:8.0 no trae mysqlbinlog: se copian los binlog afuera y se
# leen con la misma versión de MySQL en su variante Debian (herramienta auxiliar).
BINDIR=$(mktemp -d)
for f in $INCREMENTAL; do docker cp -q "$CONT:/var/lib/mysql/$f" "$BINDIR/$f"; done

# Desastre: se pierde la base entera.
m -e "DROP DATABASE atlas_db"
T_DESASTRE=$(ms)

# Restauración: base vacía + completo + incremental (sin volver a escribir el binlog).
m -e "CREATE DATABASE atlas_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci"
T=$(ms)
docker exec -e MYSQL_PWD="$PW" "$CONT" sh -c 'set -e; mysql -uroot --init-command="SET sql_log_bin=0" atlas_db < /tmp/completo.sql'
T_COMPLETO=$(( $(ms) - T ))
INT_SOLO_COMPLETO=$(mq "SELECT COUNT(*) FROM intentos")
T=$(ms)
docker run --rm -v "$BINDIR:/b:ro" -w /b --entrypoint mysqlbinlog "$AUX" $INCREMENTAL > "$BINDIR/incremental.sql"
docker exec -i -e MYSQL_PWD="$PW" "$CONT" mysql -uroot --init-command='SET sql_log_bin=0' < "$BINDIR/incremental.sql"
rm -rf "$BINDIR"
T_INCR=$(( $(ms) - T ))
T_RTO=$(( $(ms) - T_DESASTRE ))
INT_DESPUES=$(mq "SELECT COUNT(*) FROM intentos")
foto > /tmp/atlas-foto-despues.txt
OBJ_DESPUES=$(mq "$OBJ")
DIFS=$(diff /tmp/atlas-foto-antes.txt /tmp/atlas-foto-despues.txt | grep -c '^[<>]' || true)
HUERF=$(mq "SELECT (SELECT COUNT(*) FROM respuestas r LEFT JOIN intentos i ON i.id = r.intento_id WHERE i.id IS NULL)
             + (SELECT COUNT(*) FROM resultados r LEFT JOIN intentos i ON i.id = r.intento_id WHERE i.id IS NULL)
             + (SELECT COUNT(*) FROM interacciones x LEFT JOIN intentos i ON i.id = x.intento_id WHERE i.id IS NULL)
             + (SELECT COUNT(*) FROM pregunta_habilidad ph LEFT JOIN preguntas p ON p.id = ph.pregunta_id WHERE p.id IS NULL)")
PRIV=$(docker exec -e MYSQL_PWD="$BKP" "$CONT" mysql -u atlas_backup -N -B -e "SELECT COUNT(*) FROM atlas_db.habilidades" 2>&1 | tail -1)

{
  echo "== Paso a paso y tiempos"
  echo "| Paso | Resultado |"
  echo "| --- | --- |"
  echo "| Respaldo completo (mysqldump, atlas_backup) | $T_RESP ms · $TAM bytes · sha256 $SHA… |"
  echo "| Inicio del incremental (binlog) | $BINLOG_DESDE |"
  echo "| Intentos en el respaldo completo | $INT_RESP |"
  echo "| Trabajo posterior al respaldo | 50 intentos nuevos con respuestas y resultados |"
  echo "| Intentos justo antes del desastre | $INT_ANTES |"
  echo "| Desastre simulado | DROP DATABASE atlas_db |"
  echo "| Restauración del completo | $T_COMPLETO ms → $INT_SOLO_COMPLETO intentos (faltan $((INT_ANTES - INT_SOLO_COMPLETO))) |"
  echo "| Aplicación del incremental ($INCREMENTAL) | $T_INCR ms → $INT_DESPUES intentos |"
  echo "| **RTO medido** (del desastre a la base completa) | **$T_RTO ms** (objetivo: 4 h) |"
  echo "| **RPO medido** (datos perdidos) | **$((INT_ANTES - INT_DESPUES)) intentos perdidos** con completo + incremental; con solo el completo se habrían perdido $((INT_ANTES - INT_SOLO_COMPLETO)) (todo lo posterior al respaldo) |"
  echo
  echo "== Integridad de los datos recuperados"
  echo "| Control | Resultado | Esperado |"
  echo "| --- | --- | --- |"
  echo "| CHECKSUM TABLE de las $(echo "$LISTA" | tr ',' '\n' | wc -l) tablas, antes contra después | $DIFS diferencias | 0 |"
  echo "| Triggers, rutinas y vistas | antes: $OBJ_ANTES · después: $OBJ_DESPUES | iguales |"
  echo "| Filas huérfanas (respuestas, resultados, interacciones, vínculos de habilidad) | $HUERF | 0 |"
  echo "| Privilegios después de restaurar (atlas_backup lee habilidades) | $PRIV filas | 4 |"
  echo
  echo "Notas honestas:"
  echo "- Es una base de prueba de $TAM bytes en Docker, no la de producción en atlas-srv01."
  echo "  El procedimiento es el mismo; en el servidor los tiempos pueden ser mayores y hay que repetirlo ahí."
  echo "- El RPO real depende de cada cuánto se copian los binlog fuera del servidor (Tabla 29): si el"
  echo "  servidor se pierde entero, se pierde lo que no se haya copiado todavía."
} >> "$RESTAURA"

echo "Listo:"
echo "  $CONSULTAS"
echo "  $RESTAURA"
