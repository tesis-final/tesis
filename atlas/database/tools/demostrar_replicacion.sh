#!/usr/bin/env bash
# =============================================================================
# ATLAS — tools/demostrar_replicacion.sh  (Hito 2, Base de Datos)
#
# Recomendación del profesor de BD: "estudiar una alternativa de alta
# disponibilidad mediante replicación y conmutación ante fallos; explicar qué
# problemas resuelve y cómo complementa la estrategia de respaldo, considerando
# que no la sustituye". Explicación: docs/fase-05-base-datos/alta-disponibilidad.md
#
# Demostración sobre dos MySQL 8.0 REALES y DESCARTABLES (Docker):
#   1. Primario + réplica con replicación por GTID (asíncrona). Se instala ATLAS
#      en el primario con los scripts de siempre y se cargan los datos
#      representativos: todo llega a la réplica. Se comparan con CHECKSUM.
#   2. La réplica es de solo lectura: no se puede escribir en ella por error.
#   3. Un error humano (DELETE) en el primario se replica en segundos: la réplica
#      NO protege contra eso. Por eso no reemplaza al respaldo.
#   4. Caída del primario (docker kill) mientras la aplicación escribe:
#      se promueve la réplica, se mide cuánto tarda (RTO) y cuánto se perdió (RPO).
#
# Uso:  atlas/database/tools/demostrar_replicacion.sh [archivo_de_salida]
#       (por defecto docs/evidencias/G/E-BD-012-replicacion-y-conmutacion.txt)
# Las contraseñas son de PRUEBA local y los contenedores se borran al terminar.
# =============================================================================
set -euo pipefail
export MSYS_NO_PATHCONV=1                       # Git Bash en Windows: no convertir rutas
cd "$(dirname "$0")/../.."                      # carpeta atlas/
SALIDA=${1:-../docs/evidencias/G/E-BD-012-replicacion-y-conmutacion.txt}
IMAGEN=${ATLAS_TEST_MYSQL_IMAGE:-mysql:8.0}
RED=atlas_replicacion
P=atlas-db-primario
R=atlas-db-replica
PW=root-replicacion-solo-local
REPL=repl-solo-local

limpiar() { docker rm -f "$P" "$R" >/dev/null 2>&1 || true; docker network rm "$RED" >/dev/null 2>&1 || true; }
limpiar
trap limpiar EXIT

ms() { date +%s%3N; }
en() { local c=$1; shift; docker exec -i -e MYSQL_PWD="$PW" "$c" mysql -uroot --default-character-set=utf8mb4 "$@"; }
valor() { en "$1" -N -B -e "$2"; }
tabla() { en "$1" -t -e "$2"; }

ARGS=(--server-id=1 --log-bin=atlas-bin --gtid-mode=ON --enforce-gtid-consistency=ON
      --character-set-server=utf8mb4 --collation-server=utf8mb4_0900_ai_ci --default-time-zone=+00:00)
docker network create "$RED" >/dev/null
docker run -d --name "$P" --network "$RED" -e MYSQL_ROOT_PASSWORD="$PW" \
  -v "$PWD/database:/atlas/database:ro" "$IMAGEN" "${ARGS[@]}" >/dev/null
ARGS[0]=--server-id=2
# (se arranca escribible: la inicialización de la imagen crea root; después pasa a solo lectura)
docker run -d --name "$R" --network "$RED" -e MYSQL_ROOT_PASSWORD="$PW" "$IMAGEN" "${ARGS[@]}" >/dev/null

esperar() {
  for _ in $(seq 1 100); do
    docker logs "$1" 2>&1 | grep -q 'init process done' && valor "$1" 'SELECT 1' >/dev/null 2>&1 && return 0
    sleep 2
  done
  echo "MySQL $1 no arrancó" >&2; return 1
}
echo "Esperando a los dos MySQL..." >&2
esperar "$P"; esperar "$R"

# La réplica no acepta escrituras de nadie (ni root): solo lo que llega por replicación.
en "$R" -e "SET PERSIST read_only = ON; SET PERSIST super_read_only = ON;"
# Usuario de replicación (solo puede replicar) y conexión de la réplica al primario.
en "$P" -e "CREATE USER 'repl'@'%' IDENTIFIED BY '$REPL'; GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';"
en "$R" -e "CHANGE REPLICATION SOURCE TO SOURCE_HOST='$P', SOURCE_USER='repl', SOURCE_PASSWORD='$REPL',
            SOURCE_AUTO_POSITION=1, GET_SOURCE_PUBLIC_KEY=1; START REPLICA;"

replica_al_dia() {   # espera hasta que la réplica aplicó todo lo que tiene el primario
  local gtid; gtid=$(valor "$P" "SELECT @@GLOBAL.gtid_executed")
  valor "$R" "SELECT WAIT_FOR_EXECUTED_GTID_SET('$gtid', 120)" >/dev/null
}
CONTROL="SELECT
  (SELECT COUNT(*) FROM atlas_db.intentos)      AS intentos,
  (SELECT COUNT(*) FROM atlas_db.respuestas)    AS respuestas,
  (SELECT COUNT(*) FROM atlas_db.interacciones) AS interacciones,
  (SELECT COUNT(*) FROM atlas_db.resultados)    AS resultados,
  (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='atlas_db') AS triggers"
checksum() {
  valor "$1" "CHECKSUM TABLE atlas_db.usuarios, atlas_db.actividades, atlas_db.intentos, atlas_db.respuestas,
              atlas_db.interacciones, atlas_db.resultados, atlas_db.auditoria" | awk '{print $2}' | md5sum | cut -c1-16
}

{
  echo "# E-BD-012 — Alta disponibilidad: replicación y conmutación ante fallos (demostración)"
  echo "# Fecha (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ) · MySQL $(valor "$P" 'SELECT VERSION()') (imagen $IMAGEN)"
  echo "# Comando: atlas/database/tools/demostrar_replicacion.sh · Entorno: Docker de desarrollo (2 contenedores"
  echo "# en la misma PC), NO es una instalación de producción. Explicación: docs/fase-05-base-datos/alta-disponibilidad.md"
  echo
  echo "## 1. Primario + réplica (replicación asíncrona por GTID)"
  echo
  T0=$(ms)
  # Se instala ATLAS en el primario (mismos scripts que producción) y se cargan los datos representativos.
  en "$P" < docker/mysql/init.sql
  en "$P" atlas_db < database/tools/datos_representativos.sql >/dev/null
  T_CARGA=$(( $(ms) - T0 ))
  replica_al_dia
  T_REPLICA=$(( $(ms) - T0 ))
  echo "Instalación de ATLAS + datos representativos en el primario: $T_CARGA ms; la réplica terminó de aplicarlos a los $T_REPLICA ms."
  echo
  echo "Primario:"; tabla "$P" "$CONTROL"
  echo "Réplica:";  tabla "$R" "$CONTROL"
  CS_P=$(checksum "$P"); CS_R=$(checksum "$R")
  echo "Huella de CHECKSUM TABLE (7 tablas principales): primario $CS_P · réplica $CS_R → $( [ "$CS_P" = "$CS_R" ] && echo 'IGUALES' || echo 'DISTINTAS')"
  echo
  echo "Estado de la réplica:"
  en "$R" -e "SHOW REPLICA STATUS\G" | grep -E "Replica_IO_Running:|Replica_SQL_Running:|Seconds_Behind_Source:|Last_Error:" | sed 's/^ */  /'
  echo
  echo "## 2. La réplica es de solo lectura (super_read_only)"
  echo
  if salida=$(en "$R" -e "DELETE FROM atlas_db.auditoria" 2>&1); then echo "Se pudo escribir en la réplica (NO esperado)"; else echo "DELETE en la réplica → $(echo "$salida" | tail -1)"; fi
  echo
  echo "## 3. Un error humano se replica: la réplica NO reemplaza al respaldo"
  echo
  ANTES=$(valor "$R" "SELECT COUNT(*) FROM atlas_db.interacciones")
  T1=$(ms)
  en "$P" -e "DELETE FROM atlas_db.interacciones WHERE intento_id <= 1000"
  replica_al_dia
  T_ERROR=$(( $(ms) - T1 ))
  DESPUES=$(valor "$R" "SELECT COUNT(*) FROM atlas_db.interacciones")
  echo "Alguien borra por error las interacciones de 1.000 intentos en el PRIMARIO."
  echo "Interacciones en la RÉPLICA: antes $ANTES · después $DESPUES (borradas: $((ANTES - DESPUES))). El borrado llegó a la réplica en $T_ERROR ms."
  echo "Conclusión: la réplica copia todo, también los errores. Para volver atrás hace falta el RESPALDO"
  echo "(completo + binlog hasta antes del error, E-BD-005 / E-BD-009)."
  echo
  echo "## 4. Caída del primario y conmutación a la réplica"
  echo
  # La "aplicación" inserta intentos sin parar; se mata el primario en medio.
  ACT=$(valor "$P" "SELECT MIN(id) FROM atlas_db.actividades WHERE estado_id = (SELECT id FROM atlas_db.estados_actividad WHERE codigo='PUBLICADA')")
  EST=$(valor "$P" "SELECT MIN(u.id) FROM atlas_db.usuarios u JOIN atlas_db.roles r ON r.id=u.rol_id AND r.codigo='ESTUDIANTE'")
  BASE=$(valor "$P" "SELECT COALESCE(MAX(numero_intento),0) FROM atlas_db.intentos WHERE usuario_id=$EST AND actividad_id=$ACT")
  CONFIRMADOS=0
  (
    n=$BASE
    while true; do
      n=$((n + 1))
      if en "$P" -e "INSERT INTO atlas_db.intentos (usuario_id, actividad_id, numero_intento) VALUES ($EST, $ACT, $n)" >/dev/null 2>&1; then
        echo "$n" > /tmp/atlas-ultimo-confirmado
      else
        break
      fi
    done
  ) &
  ESCRITOR=$!
  sleep 3
  T_CAIDA=$(ms)
  docker kill "$P" >/dev/null                       # falla abrupta: se corta la corriente
  wait "$ESCRITOR" 2>/dev/null || true
  ULTIMO=$(cat /tmp/atlas-ultimo-confirmado 2>/dev/null || echo "$BASE"); rm -f /tmp/atlas-ultimo-confirmado
  CONFIRMADOS=$((ULTIMO - BASE))
  # Promoción manual de la réplica (lo que haría el operador según el procedimiento).
  en "$R" -e "STOP REPLICA; RESET REPLICA ALL; SET GLOBAL super_read_only = OFF; SET GLOBAL read_only = OFF;"
  en "$R" -e "INSERT INTO atlas_db.auditoria (accion, resultado) VALUES ('ha.promocion', 'OK')"
  T_PROMOVIDA=$(( $(ms) - T_CAIDA ))
  EN_REPLICA=$(valor "$R" "SELECT COUNT(*) FROM atlas_db.intentos WHERE usuario_id=$EST AND actividad_id=$ACT AND numero_intento > $BASE")
  echo "La aplicación insertó intentos de forma continua durante 3 s; el primario se mató con docker kill."
  echo "Intentos confirmados por el primario antes de caer: $CONFIRMADOS · presentes en la réplica: $EN_REPLICA"
  echo "**RPO medido: $((CONFIRMADOS - EN_REPLICA)) intentos perdidos** (replicación asíncrona: puede perderse lo último que el"
  echo "primario confirmó y no llegó a enviar; con replicación semisincrónica ese número es 0)."
  echo "**RTO medido: $T_PROMOVIDA ms** desde la caída hasta la primera escritura aceptada en la réplica promovida"
  echo "(promoción hecha por el script; con una persona siguiendo el procedimiento son minutos, no milisegundos)."
  echo
  echo "Réplica promovida (ahora es el primario):"
  tabla "$R" "SELECT @@read_only AS read_only, @@super_read_only AS super_read_only,
                     (SELECT COUNT(*) FROM atlas_db.intentos) AS intentos,
                     (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='atlas_db') AS triggers"
  echo
  echo "Resumen"
  echo "- Copia fiel y continua: huellas $( [ "$CS_P" = "$CS_R" ] && echo iguales || echo DISTINTAS ), réplica al día en segundos."
  echo "- Ante la caída del servidor, el servicio vuelve en lo que tarda promover la réplica (RTO), sin restaurar nada."
  echo "- Ante un error humano, la réplica no ayuda: el borrado se replicó en $T_ERROR ms. Sigue haciendo falta el respaldo."
} > "$SALIDA"

echo "Listo: $SALIDA" >&2
