#!/usr/bin/env bash
# =============================================================================
# ATLAS — tools/demostrar_rechazos.sh  (Hito 2, Base de Datos)
#
# Devolución de BD: "Implementar usuarios y privilegios, demostrando que las
# operaciones no autorizadas son rechazadas". Las pruebas automáticas
# (tests/Database/PrivilegiosTest) dicen PASS/FAIL; esta herramienta MUESTRA el
# intento y la respuesta real de MySQL, para presentarlo.
#
# Sobre un MySQL 8.0 REAL y DESCARTABLE, instalado con los mismos scripts que
# producción (init.sql + 02-usuarios.sh), ejecuta con cada usuario de MySQL:
#   - operaciones que NO le corresponden  → tiene que aparecer el error de MySQL;
#   - operaciones que SÍ le corresponden  → tiene que funcionar (control: no es
#     que "falla todo" por un problema de conexión);
#   - datos que violan reglas de negocio  → los rechaza una restricción o un trigger.
# Cada caso dice qué regla demuestra (docs/fase-05-base-datos/reglas-de-negocio.md).
#
# Uso:  atlas/database/tools/demostrar_rechazos.sh [archivo_de_salida]
#       (por defecto docs/evidencias/G/E-BD-011-rechazos.txt)
# Las contraseñas son de PRUEBA local y los contenedores se borran al terminar.
# =============================================================================
set -euo pipefail
export MSYS_NO_PATHCONV=1                       # Git Bash en Windows: no convertir rutas
cd "$(dirname "$0")/../.."                      # carpeta atlas/
SALIDA=${1:-../docs/evidencias/G/E-BD-011-rechazos.txt}
IMAGEN=${ATLAS_TEST_MYSQL_IMAGE:-mysql:8.0}
RED=atlas_rechazos
SRV=atlas-db-rechazos
CLI=atlas-cli-rechazos
ROOT=root-rechazos-solo-local
declare -A CLAVE=([atlas_app]=app-rechazos [atlas_read]=read-rechazos [atlas_analysis]=ana-rechazos
                  [atlas_backup]=bkp-rechazos [atlas_admin]=adm-rechazos)

limpiar() { docker rm -f "$SRV" "$CLI" >/dev/null 2>&1 || true; docker network rm "$RED" >/dev/null 2>&1 || true; }
limpiar
trap limpiar EXIT

# Misma subred que atlas_back (CT-07): los usuarios de la app solo entran desde ahí.
docker network create --subnet 192.168.250.16/28 --gateway 192.168.250.17 "$RED" >/dev/null
docker run -d --name "$SRV" --network "$RED" --ip 192.168.250.20 \
  -e MYSQL_ROOT_PASSWORD="$ROOT" \
  -e ATLAS_DB_APP_PASSWORD="${CLAVE[atlas_app]}" -e ATLAS_DB_READ_PASSWORD="${CLAVE[atlas_read]}" \
  -e ATLAS_DB_ANALYSIS_PASSWORD="${CLAVE[atlas_analysis]}" -e ATLAS_DB_BACKUP_PASSWORD="${CLAVE[atlas_backup]}" \
  -e ATLAS_DB_ADMIN_PASSWORD="${CLAVE[atlas_admin]}" \
  -v "$PWD/database:/atlas/database:ro" \
  -v "$PWD/docker/mysql/init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro" \
  -v "$PWD/docker/mysql/02-usuarios.sh:/docker-entrypoint-initdb.d/02-usuarios.sh:ro" \
  "$IMAGEN" >/dev/null
# Cliente en la misma subred, como el contenedor de la aplicación.
docker run -d --name "$CLI" --network "$RED" --ip 192.168.250.21 --entrypoint sleep "$IMAGEN" infinity >/dev/null

echo "Esperando a MySQL..." >&2
for _ in $(seq 1 100); do
  if docker logs "$SRV" 2>&1 | grep -q 'init process done' \
     && docker exec -e MYSQL_PWD="$ROOT" "$SRV" mysql -uroot -e 'SELECT 1' >/dev/null 2>&1; then break; fi
  sleep 2
done

root() { docker exec -i -e MYSQL_PWD="$ROOT" "$SRV" mysql -uroot -N -B atlas_db "$@"; }

# --- Datos mínimos (como root): un docente, un grupo, una actividad publicada
# con una pregunta, un estudiante con un intento en curso y uno cerrado.
root <<'SQL'
INSERT INTO usuarios (institucion_id, rol_id, nombre, apellido, correo, hash_contrasena)
VALUES (1, (SELECT id FROM roles WHERE codigo='DOCENTE'), 'Docente', 'Prueba', 'docente@prueba.local', 'x'),
       (1, (SELECT id FROM roles WHERE codigo='ESTUDIANTE'), 'Estudiante', 'Prueba', 'estudiante@prueba.local', 'x');
SET @doc = (SELECT id FROM usuarios WHERE correo='docente@prueba.local');
SET @est = (SELECT id FROM usuarios WHERE correo='estudiante@prueba.local');
INSERT INTO grupos_clase (institucion_id, nombre, anio_lectivo) VALUES (1, '3A', 2026);
INSERT INTO actividades (autor_id, nivel_id, categoria_id, estado_id, titulo)
VALUES (@doc, (SELECT id FROM niveles_dificultad ORDER BY orden LIMIT 1), (SELECT id FROM categorias LIMIT 1),
        (SELECT id FROM estados_actividad WHERE codigo='BORRADOR'), 'Actividad de prueba');
SET @act = LAST_INSERT_ID();
INSERT INTO preguntas (actividad_id, orden, enunciado) VALUES (@act, 1, '¿2 + 2?');
SET @pre = LAST_INSERT_ID();
INSERT INTO opciones (pregunta_id, orden, texto, es_correcta) VALUES (@pre, 1, '4', TRUE), (@pre, 2, '5', FALSE);
UPDATE actividades SET estado_id = (SELECT id FROM estados_actividad WHERE codigo='PUBLICADA') WHERE id = @act;
INSERT INTO intentos (usuario_id, actividad_id, numero_intento) VALUES (@est, @act, 1);
INSERT INTO respuestas (intento_id, pregunta_id, opcion_id, tiempo_seg)
VALUES (LAST_INSERT_ID(), @pre, (SELECT id FROM opciones WHERE pregunta_id=@pre AND orden=1), 12);
INSERT INTO intentos (usuario_id, actividad_id, numero_intento, estado, finalizado_en, duracion_seg, duracion_activa_seg)
VALUES (@est, @act, 2, 'FINALIZADO', NOW(3), 60, 50);
INSERT INTO resultados (intento_id, correctas, total_preguntas, puntaje) VALUES (LAST_INSERT_ID(), 1, 1, 100);
INSERT INTO perfiles_aprendizaje (usuario_id, periodo_inicio, periodo_fin) VALUES (@est, '2026-10-01', '2026-10-31');
SQL
ID_ACT=$(root -e "SELECT id FROM actividades LIMIT 1")
ID_PRE=$(root -e "SELECT id FROM preguntas LIMIT 1")
ID_OPC=$(root -e "SELECT id FROM opciones WHERE pregunta_id=$ID_PRE AND orden=2")
ID_EN_CURSO=$(root -e "SELECT id FROM intentos WHERE estado='EN_CURSO'")
ID_CERRADO=$(root -e "SELECT id FROM intentos WHERE estado='FINALIZADO'")
ID_EST=$(root -e "SELECT id FROM usuarios WHERE correo='estudiante@prueba.local'")

RECHAZOS=0; PERMITIDOS=0; FALLAS=0
caso() {  # caso <esperado: RECHAZA|PERMITE> <regla> <usuario> <sql>
  local esperado=$1 regla=$2 usuario=$3 sql=$4 salida rc
  if [ "$usuario" = root ]; then
    salida=$(docker exec -e MYSQL_PWD="$ROOT" "$SRV" mysql -uroot --default-character-set=utf8mb4 -N -B atlas_db -e "$sql" 2>&1) && rc=0 || rc=$?
  else
    salida=$(docker exec -e MYSQL_PWD="${CLAVE[$usuario]}" "$CLI" \
      mysql -h 192.168.250.20 -u"$usuario" --default-character-set=utf8mb4 -N -B atlas_db -e "$sql" 2>&1) && rc=0 || rc=$?
  fi
  # (grep sin líneas devuelve 1: una operación permitida puede no tener salida)
  salida=$(printf '%s' "$salida" | { grep -v 'Using a password' || true; } | tr '\n' ' ' | sed 's/  */ /g; s/ $//' | tr '`' "'")
  local obtenido; [ "$rc" -eq 0 ] && obtenido=PERMITE || obtenido=RECHAZA
  local marca="OK"; [ "$obtenido" = "$esperado" ] || { marca="NO COINCIDE"; FALLAS=$((FALLAS + 1)); }
  [ "$obtenido" = RECHAZA ] && RECHAZOS=$((RECHAZOS + 1)) || PERMITIDOS=$((PERMITIDOS + 1))
  printf '| %s | %s | `%s` | `%s` | %s → %s |\n' "$regla" "$usuario" "$sql" "${salida:-(sin salida: se ejecutó)}" \
    "$( [ "$esperado" = RECHAZA ] && echo "se esperaba rechazo" || echo "se esperaba que funcione")" "$marca"
}

{
  echo "# E-BD-011 — Rechazos demostrados: privilegios, restricciones y triggers (Hito 2)"
  echo "# Fecha (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ) · MySQL $(root -e 'SELECT VERSION()') (imagen $IMAGEN, contenedor descartable)"
  echo "# Comando: atlas/database/tools/demostrar_rechazos.sh · Entorno: Docker de desarrollo, no es atlas-srv01"
  echo "# Instalación con los mismos scripts de producción (init.sql + 02-usuarios.sh, migraciones 001-004)."
  echo "# Los usuarios de la aplicación se conectan desde 192.168.250.21, en la misma subred interna que el"
  echo "# contenedor de la aplicación. Reglas: docs/fase-05-base-datos/reglas-de-negocio.md"
  echo
  echo "## 1. Privilegios: cada usuario de MySQL solo puede lo suyo (Tabla 21)"
  echo
  echo "| Regla | Usuario | Intento | Respuesta de MySQL | Resultado |"
  echo "| --- | --- | --- | --- | --- |"
  caso PERMITE "Control" atlas_app "INSERT INTO auditoria (accion, resultado) VALUES ('demo.rechazos', 'OK')"
  caso RECHAZA "C3" atlas_app "DROP TABLE resultados"
  caso RECHAZA "C3" atlas_app "ALTER TABLE usuarios ADD COLUMN x INT"
  caso RECHAZA "U7" atlas_app "DELETE FROM usuarios WHERE id = $ID_EST"
  caso RECHAZA "P2" atlas_app "UPDATE resultados SET puntaje = 0 WHERE intento_id = $ID_CERRADO"
  caso RECHAZA "P2" atlas_app "DELETE FROM resultados WHERE intento_id = $ID_CERRADO"
  caso RECHAZA "C1" atlas_app "DELETE FROM auditoria"
  caso RECHAZA "A8" atlas_app "UPDATE transiciones_actividad SET observaciones = 'cambiada'"
  caso RECHAZA "N5" atlas_app "UPDATE decisiones_recomendacion SET decision = 'CAMBIADA'"
  caso RECHAZA "C3" atlas_app "GRANT SELECT ON atlas_db.* TO 'atlas_read'@'%'"
  caso PERMITE "Control" atlas_read "SELECT COUNT(*) FROM v_resultados_detalle"
  caso RECHAZA "C4" atlas_read "SELECT correo, hash_contrasena FROM usuarios"
  caso RECHAZA "C4" atlas_read "SELECT * FROM resultados"
  caso PERMITE "Control" atlas_analysis "SELECT COUNT(*) FROM intentos"
  caso RECHAZA "N7" atlas_analysis "SELECT nombre, correo FROM usuarios"
  caso RECHAZA "N7" atlas_analysis "UPDATE intentos SET duracion_seg = 1"
  caso PERMITE "Control" atlas_backup "SELECT COUNT(*) FROM usuarios"
  caso RECHAZA "C5" atlas_backup "UPDATE usuarios SET activo = FALSE"
  caso RECHAZA "C5" atlas_backup "DELETE FROM intentos"
  caso RECHAZA "C6" atlas_admin "SELECT 1"
  echo
  echo "## 2. Auditoría inmutable, incluso para root (RF-15)"
  echo
  echo "| Regla | Usuario | Intento | Respuesta de MySQL | Resultado |"
  echo "| --- | --- | --- | --- | --- |"
  caso RECHAZA "C1" root "UPDATE auditoria SET accion = 'alterada'"
  caso RECHAZA "C1" root "DELETE FROM auditoria"
  echo
  echo "## 3. Datos que violan reglas de negocio (restricciones y triggers; se intentan como root para"
  echo "##    mostrar que los frena la base, no los permisos)"
  echo
  echo "| Regla | Usuario | Intento | Respuesta de MySQL | Resultado |"
  echo "| --- | --- | --- | --- | --- |"
  caso RECHAZA "U1" root "INSERT INTO usuarios (institucion_id, rol_id, nombre, apellido, correo, hash_contrasena) VALUES (1, 1, 'Otro', 'Docente', 'docente@prueba.local', 'x')"
  caso RECHAZA "U2" root "INSERT INTO usuarios (institucion_id, rol_id, nombre, apellido, correo, hash_contrasena) VALUES (1, 1, '   ', 'Sin nombre', 'vacio@prueba.local', 'x')"
  caso RECHAZA "U4" root "INSERT INTO usuarios (institucion_id, rol_id, nombre, apellido, correo, hash_contrasena) VALUES (999, 1, 'Sin', 'Institucion', 'fk@prueba.local', 'x')"
  caso RECHAZA "U8" root "INSERT INTO grupos_clase (institucion_id, nombre, anio_lectivo) VALUES (1, '3A', 2026)"
  caso RECHAZA "U8" root "INSERT INTO grupos_clase (institucion_id, nombre, anio_lectivo) VALUES (1, '4B', 1999)"
  caso RECHAZA "A3" root "UPDATE actividades SET estado_id = (SELECT id FROM estados_actividad WHERE codigo='APROBADA') WHERE id = $ID_ACT"
  caso RECHAZA "A7" root "UPDATE preguntas SET enunciado = 'cambiada' WHERE id = $ID_PRE"
  caso RECHAZA "A9" root "INSERT INTO preguntas (actividad_id, orden, enunciado) VALUES ($ID_ACT, 1, 'Repite el orden')"
  caso RECHAZA "R3" root "UPDATE intentos SET estado = 'EN_CURSO', finalizado_en = NULL, duracion_seg = NULL WHERE id = $ID_CERRADO"
  caso RECHAZA "R4" root "INSERT INTO respuestas (intento_id, pregunta_id, opcion_id) VALUES ($ID_CERRADO, $ID_PRE, $ID_OPC)"
  caso RECHAZA "R6" root "INSERT INTO respuestas (intento_id, pregunta_id, opcion_id) VALUES ($ID_EN_CURSO, $ID_PRE, $ID_OPC)"
  caso RECHAZA "R8" root "UPDATE respuestas SET tiempo_seg = 90000 WHERE intento_id = $ID_EN_CURSO"
  caso RECHAZA "R9" root "UPDATE intentos SET duracion_activa_seg = 61 WHERE id = $ID_CERRADO"
  caso RECHAZA "P1" root "INSERT INTO resultados (intento_id, correctas, total_preguntas, puntaje) VALUES ($ID_CERRADO, 1, 1, 100)"
  caso RECHAZA "P1" root "UPDATE resultados SET puntaje = 101 WHERE intento_id = $ID_CERRADO"
  caso RECHAZA "N2" root "INSERT INTO perfiles_aprendizaje (usuario_id, periodo_inicio, periodo_fin) VALUES ($ID_EST, '2026-10-01', '2026-10-31')"
  caso RECHAZA "N2" root "INSERT INTO perfiles_aprendizaje (usuario_id, periodo_inicio, periodo_fin) VALUES ($ID_EST, '2026-11-30', '2026-11-01')"
  caso RECHAZA "C2" root "INSERT INTO auditoria (accion, resultado, detalle) VALUES ('demo', 'OK', 'esto no es JSON')"
  echo
  echo "Resumen: $RECHAZOS rechazos y $PERMITIDOS operaciones permitidas; casos que no dieron lo esperado: $FALLAS"
  echo "Se espera: 0 casos que no coinciden. El error 1142 es MySQL negando un privilegio; 1045, un usuario que no"
  echo "puede entrar desde ese origen; 3819, una restricción CHECK; 1062, una clave única; 1452, una clave foránea;"
  echo "1644, un trigger de ATLAS (SIGNAL 45000); 3140, un valor que no es JSON válido en una columna JSON."
} > "$SALIDA"

echo "Listo: $SALIDA" >&2
[ "$FALLAS" -eq 0 ]
