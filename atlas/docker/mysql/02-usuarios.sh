#!/bin/bash
# =============================================================================
# ATLAS — docker/mysql/02-usuarios.sh
# Crea los usuarios de MySQL de la Tabla 21 (+ DEC-10, CT-06, CT-13).
# Las contraseñas se leen de variables de entorno; nunca se escriben en Git.
# Origen permitido: la subred interna atlas_back (CT-07).
# El entrypoint oficial de mysql:8.0 lo *incluye* (source) desde
# /docker-entrypoint-initdb.d porque no es ejecutable; así puede usar
# docker_process_sql. Si falta una variable, el arranque se detiene.
# =============================================================================

: "${ATLAS_DB_APP_PASSWORD:?falta ATLAS_DB_APP_PASSWORD}"
: "${ATLAS_DB_READ_PASSWORD:?falta ATLAS_DB_READ_PASSWORD}"
: "${ATLAS_DB_ANALYSIS_PASSWORD:?falta ATLAS_DB_ANALYSIS_PASSWORD}"
: "${ATLAS_DB_BACKUP_PASSWORD:?falta ATLAS_DB_BACKUP_PASSWORD}"
: "${ATLAS_DB_ADMIN_PASSWORD:?falta ATLAS_DB_ADMIN_PASSWORD}"
HOST="${ATLAS_DB_ALLOWED_HOST:-192.168.250.16/255.255.255.240}"

sql_escape() { printf '%s' "$1" | sed "s/'/''/g"; }

APP=$(sql_escape "$ATLAS_DB_APP_PASSWORD")
READ=$(sql_escape "$ATLAS_DB_READ_PASSWORD")
ANA=$(sql_escape "$ATLAS_DB_ANALYSIS_PASSWORD")
BKP=$(sql_escape "$ATLAS_DB_BACKUP_PASSWORD")
ADM=$(sql_escape "$ATLAS_DB_ADMIN_PASSWORD")

# En Windows (Docker Desktop) el bind mount deja el archivo como ejecutable y el
# entrypoint lo *ejecuta* en vez de incluirlo: docker_process_sql no existe.
# Mismo efecto contra el servidor temporal de inicialización (socket local).
if ! declare -F docker_process_sql >/dev/null; then
  docker_process_sql() { MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql --protocol=socket -uroot "$@"; }
fi

docker_process_sql --database=mysql <<SQL
-- atlas_app: SELECT/INSERT/UPDATE en tablas operativas (Tabla 21).
CREATE USER 'atlas_app'@'${HOST}' IDENTIFIED BY '${APP}';
GRANT SELECT, INSERT, UPDATE ON atlas_db.instituciones        TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT, UPDATE ON atlas_db.rol_permiso          TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT, UPDATE ON atlas_db.usuarios             TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT, UPDATE ON atlas_db.grupos_clase         TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT, UPDATE ON atlas_db.usuario_grupo        TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT, UPDATE ON atlas_db.niveles_dificultad   TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT, UPDATE ON atlas_db.categorias           TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT, UPDATE ON atlas_db.actividades          TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT, UPDATE, DELETE ON atlas_db.preguntas    TO 'atlas_app'@'${HOST}';  -- CT-13
GRANT SELECT, INSERT, UPDATE, DELETE ON atlas_db.opciones     TO 'atlas_app'@'${HOST}';  -- CT-13
GRANT SELECT, INSERT, UPDATE ON atlas_db.habilidades          TO 'atlas_app'@'${HOST}';  -- Hito 2: se desactivan, no se borran
GRANT SELECT, INSERT, DELETE ON atlas_db.pregunta_habilidad   TO 'atlas_app'@'${HOST}';  -- Hito 2: se borran y crean, no se modifican
GRANT SELECT, INSERT, UPDATE ON atlas_db.actividad_grupo      TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT, UPDATE ON atlas_db.intentos             TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT, UPDATE ON atlas_db.respuestas           TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT, UPDATE ON atlas_db.interacciones        TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT, UPDATE ON atlas_db.perfiles_aprendizaje TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT, UPDATE ON atlas_db.indicadores          TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT, UPDATE ON atlas_db.reglas_analisis      TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT, UPDATE ON atlas_db.recomendaciones      TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT, UPDATE ON atlas_db.recomendacion_regla  TO 'atlas_app'@'${HOST}';
-- Solo lectura: catálogos fijos y datos que escriben otros (ML, respaldos).
GRANT SELECT ON atlas_db.roles              TO 'atlas_app'@'${HOST}';
GRANT SELECT ON atlas_db.permisos           TO 'atlas_app'@'${HOST}';
GRANT SELECT ON atlas_db.estados_actividad  TO 'atlas_app'@'${HOST}';
GRANT SELECT ON atlas_db.agrupamientos      TO 'atlas_app'@'${HOST}';
GRANT SELECT ON atlas_db.registro_respaldos TO 'atlas_app'@'${HOST}';
-- Solo agregar: registros que no se modifican (RF-15, RF-17, RF-20). Desde 004 (D-4)
-- la app calcula resultados y análisis grupal: los agrega, pero no puede alterarlos.
GRANT SELECT, INSERT ON atlas_db.auditoria              TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT ON atlas_db.transiciones_actividad TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT ON atlas_db.conversaciones         TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT ON atlas_db.resultados             TO 'atlas_app'@'${HOST}';
GRANT SELECT, INSERT ON atlas_db.analisis_grupal        TO 'atlas_app'@'${HOST}';

-- atlas_read: SELECT sobre vistas de reporte (Tabla 21).
CREATE USER 'atlas_read'@'${HOST}' IDENTIFIED BY '${READ}';
GRANT SELECT ON atlas_db.v_resultados_detalle     TO 'atlas_read'@'${HOST}';
GRANT SELECT ON atlas_db.v_evolucion_estudiante   TO 'atlas_read'@'${HOST}';
GRANT SELECT ON atlas_db.v_distribucion_puntajes  TO 'atlas_read'@'${HOST}';
GRANT SELECT ON atlas_db.v_preguntas_error        TO 'atlas_read'@'${HOST}';
GRANT SELECT ON atlas_db.v_recomendaciones_riesgo TO 'atlas_read'@'${HOST}';

-- atlas_analysis: SELECT en interacción, INSERT en análisis (Tabla 21).
-- Nunca lee nombres ni correos.
CREATE USER 'atlas_analysis'@'${HOST}' IDENTIFIED BY '${ANA}';
GRANT SELECT ON atlas_db.intentos      TO 'atlas_analysis'@'${HOST}';
GRANT SELECT ON atlas_db.respuestas    TO 'atlas_analysis'@'${HOST}';
GRANT SELECT ON atlas_db.interacciones TO 'atlas_analysis'@'${HOST}';
GRANT SELECT ON atlas_db.resultados    TO 'atlas_analysis'@'${HOST}';
GRANT SELECT (usuario_id, grupo_id, activo) ON atlas_db.usuario_grupo TO 'atlas_analysis'@'${HOST}';
GRANT SELECT (id, usuario_id, periodo_inicio, periodo_fin) ON atlas_db.perfiles_aprendizaje TO 'atlas_analysis'@'${HOST}';
GRANT INSERT ON atlas_db.agrupamientos TO 'atlas_analysis'@'${HOST}';
GRANT INSERT ON atlas_db.indicadores   TO 'atlas_analysis'@'${HOST}';

-- atlas_backup: Tabla 21 + TRIGGER y SHOW_ROUTINE (DEC-10) + registro (CT-06).
CREATE USER 'atlas_backup'@'${HOST}' IDENTIFIED BY '${BKP}';
CREATE USER 'atlas_backup'@'localhost' IDENTIFIED BY '${BKP}';
GRANT SELECT, LOCK TABLES, SHOW VIEW, TRIGGER ON atlas_db.* TO 'atlas_backup'@'${HOST}', 'atlas_backup'@'localhost';
GRANT SHOW_ROUTINE ON *.* TO 'atlas_backup'@'${HOST}', 'atlas_backup'@'localhost';
GRANT INSERT ON atlas_db.registro_respaldos TO 'atlas_backup'@'${HOST}', 'atlas_backup'@'localhost';

-- atlas_admin: todo sobre atlas_db, solo desde dentro del contenedor.
CREATE USER 'atlas_admin'@'localhost' IDENTIFIED BY '${ADM}';
GRANT ALL PRIVILEGES ON atlas_db.* TO 'atlas_admin'@'localhost';

FLUSH PRIVILEGES;
SQL
