#!/usr/bin/env bash
# =============================================================================
# ATLAS — tools/restaurar_intento.sh  (Hito 3, devolución de Base de Datos)
#
# Pedido: «Repitan la prueba [E-BD-014] después de completar la actividad. Además de contar
# filas, recuperen el intento por su identificador y comparen sus respuestas, interacciones y
# puntaje. Registren cuánto demoraron y cuál fue el último intento recuperado, para
# contrastar ambos datos con sus objetivos de recuperación.»
#
# Qué hace (sobre la base EN USO, sin tocarla):
#   1. Anota el último intento de la base y el intento a seguir (el indicado o el último finalizado).
#   2. Respaldo completo con atlas_backup (mysqldump --single-transaction), con tiempo, tamaño y sha256.
#   3. Restaura ese respaldo en una base aparte (atlas_restore_prueba), con tiempo.
#   4. Recupera el intento por su número en las dos bases y compara intento, respuestas,
#      interacciones y resultado (filas y huella sha256 de cada conjunto), más los conteos de las tablas.
#   5. Informa el último intento recuperado y los tiempos frente a los objetivos (§28.5:
#      perder como máximo 24 h de datos y volver a operar en menos de 4 h).
#   6. Borra la base de prueba y el archivo del respaldo (tienen datos de personas).
#
# Uso:  sudo atlas/database/tools/restaurar_intento.sh [intento_id] [archivo_salida]
#       En atlas-srv01: sudo /opt/atlas/tesis/atlas/database/tools/restaurar_intento.sh
# Las contraseñas no se escriben: las lee el contenedor de su propio entorno (atlas.conf).
# =============================================================================
set -euo pipefail
CONT=${ATLAS_DB_CONTENEDOR:-atlas-db}
INTENTO=${1:-}
SALIDA=${2:-}
PRUEBA=atlas_restore_prueba

# El aviso de MySQL sobre la contraseña en la línea de comandos se filtra (la contraseña no se ve:
# la expande el shell del contenedor). grep sin líneas que mostrar no es un error.
raiz() { docker exec -i "$CONT" sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 "$@"' sh "$@" 2>&1 | { grep -v 'Using a password' || true; }; }
q() { raiz -N -B -e "$2" "$1"; }
ms() { date +%s%3N; }

docker inspect "$CONT" >/dev/null 2>&1 || { echo "No encuentro el contenedor $CONT (¿ATLAS está levantado?)."; exit 1; }
[ -n "$INTENTO" ] || INTENTO=$(q atlas_db "SELECT MAX(id) FROM intentos WHERE estado = 'FINALIZADO'")
[ -n "$INTENTO" ] && [ "$INTENTO" != NULL ] || { echo "No hay intentos finalizados para seguir."; exit 1; }

limpiar() {
  q atlas_db "DROP DATABASE IF EXISTS $PRUEBA" >/dev/null 2>&1 || true
  docker exec "$CONT" rm -f /tmp/atlas_respaldo_prueba.sql >/dev/null 2>&1 || true
}
trap limpiar EXIT

# Huella de un conjunto de filas del intento (mismo orden y mismas columnas en las dos bases).
huella() {   # huella <base> <tabla> <columnas> <condición> <orden>
  q "$1" "SELECT CONCAT(COUNT(*), ' filas · sha256 ', LEFT(SHA2(COALESCE(GROUP_CONCAT(CONCAT_WS('|', $3) ORDER BY $5 SEPARATOR '\n'), ''), 256), 16))
            FROM $2 WHERE $4"
}

ejecutar() {
  echo "ATLAS — Recuperación de un intento después de restaurar un respaldo"
  echo "Fecha (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ) · Equipo: $(hostname) · contenedor $CONT"
  echo "Motor: MySQL $(q atlas_db 'SELECT VERSION()')"
  echo
  echo "== 1. Antes del respaldo"
  ULTIMO=$(q atlas_db "SELECT CONCAT(id, ' · ', estado, ' · ', COALESCE(finalizado_en, iniciado_en)) FROM intentos ORDER BY id DESC LIMIT 1")
  echo "Último intento en la base en uso: $ULTIMO"
  echo "Intento a seguir: $INTENTO"
  raiz -t -e "SELECT i.id, u.correo AS estudiante, a.titulo AS actividad, i.estado, i.finalizado_en, r.puntaje
                FROM intentos i JOIN usuarios u ON u.id = i.usuario_id JOIN actividades a ON a.id = i.actividad_id
                LEFT JOIN resultados r ON r.intento_id = i.id WHERE i.id = $INTENTO" atlas_db

  echo
  echo "== 2. Respaldo completo con atlas_backup (mysqldump --single-transaction, sin bloquear la aplicación)"
  T0=$(ms)
  MARCA=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  docker exec "$CONT" sh -c 'mysqldump -uatlas_backup -p"$ATLAS_DB_BACKUP_PASSWORD" --single-transaction --routines --triggers --no-tablespaces --set-gtid-purged=OFF atlas_db > /tmp/atlas_respaldo_prueba.sql' 2>&1 | grep -v 'Using a password' || true
  T_RESP=$(( $(ms) - T0 ))
  TAM=$(docker exec "$CONT" stat -c %s /tmp/atlas_respaldo_prueba.sql)
  SHA=$(docker exec "$CONT" sha256sum /tmp/atlas_respaldo_prueba.sql | cut -c1-16)
  echo "Respaldo tomado a las $MARCA · $T_RESP ms · $TAM bytes · sha256 $SHA…"

  echo
  echo "== 3. Restauración en una base aparte ($PRUEBA)"
  T0=$(ms)
  q atlas_db "DROP DATABASE IF EXISTS $PRUEBA; CREATE DATABASE $PRUEBA CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci" >/dev/null
  docker exec "$CONT" sh -c "mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" --default-character-set=utf8mb4 $PRUEBA < /tmp/atlas_respaldo_prueba.sql" 2>&1 | grep -v 'Using a password' || true
  T_REST=$(( $(ms) - T0 ))
  echo "Restauración: $T_REST ms"

  echo
  echo "== 4. El intento $INTENTO en las dos bases"
  COMPARACIONES=0; IGUALES=0
  comparar() {   # comparar <título> <tabla> <columnas> <condición> <orden>
    local a b
    a=$(huella atlas_db "$2" "$3" "$4" "$5"); b=$(huella "$PRUEBA" "$2" "$3" "$4" "$5")
    COMPARACIONES=$((COMPARACIONES + 1))
    if [ "$a" = "$b" ]; then IGUALES=$((IGUALES + 1)); echo "PASS $1: en uso $a · restaurada $b"; else echo "FAIL $1: en uso $a · restaurada $b"; fi
  }
  comparar "Intento" intentos "id, usuario_id, actividad_id, numero_intento, estado, iniciado_en, COALESCE(finalizado_en,''), COALESCE(duracion_seg,'')" "id = $INTENTO" id
  comparar "Respuestas" respuestas "pregunta_id, opcion_id, COALESCE(tiempo_seg,''), respondido_en" "intento_id = $INTENTO" pregunta_id
  comparar "Interacciones" interacciones "secuencia, tipo, COALESCE(pregunta_id,''), COALESCE(opcion_id,''), ocurrido_en, COALESCE(duracion_ms,'')" "intento_id = $INTENTO" secuencia
  comparar "Resultado (puntaje)" resultados "correctas, total_preguntas, puntaje, calculado_en" "intento_id = $INTENTO" id
  echo
  echo "Respuestas recuperadas de la base restaurada:"
  raiz -t -e "SELECT p.orden AS pregunta, o.texto AS opcion, o.es_correcta FROM respuestas r JOIN preguntas p ON p.id = r.pregunta_id
                JOIN opciones o ON o.id = r.opcion_id WHERE r.intento_id = $INTENTO ORDER BY p.orden" "$PRUEBA"
  echo "Cambios de respuesta recuperados: $(q "$PRUEBA" "SELECT COUNT(*) FROM interacciones WHERE intento_id = $INTENTO AND tipo = 'CAMBIO_OPCION'")"
  echo "Puntaje recuperado: $(q "$PRUEBA" "SELECT puntaje FROM resultados WHERE intento_id = $INTENTO")"
  echo
  echo "Conteo de filas por tabla:"
  for t in usuarios actividades preguntas opciones intentos respuestas interacciones resultados auditoria; do
    a=$(q atlas_db "SELECT COUNT(*) FROM $t"); b=$(q "$PRUEBA" "SELECT COUNT(*) FROM $t")
    COMPARACIONES=$((COMPARACIONES + 1)); [ "$a" = "$b" ] && IGUALES=$((IGUALES + 1))
    printf '  %-14s en uso %-7s restaurada %-7s %s\n' "$t" "$a" "$b" "$([ "$a" = "$b" ] && echo PASS || echo 'distinto (la base en uso siguió recibiendo datos)')"
  done

  echo
  echo "== 5. Frente a los objetivos de recuperación (§28.5)"
  RECUP=$(q "$PRUEBA" "SELECT CONCAT(id, ' · ', estado, ' · ', COALESCE(finalizado_en, iniciado_en)) FROM intentos ORDER BY id DESC LIMIT 1")
  echo "Último intento recuperado: $RECUP"
  echo "Último intento en la base en uso al terminar: $(q atlas_db "SELECT CONCAT(id, ' · ', estado, ' · ', COALESCE(finalizado_en, iniciado_en)) FROM intentos ORDER BY id DESC LIMIT 1")"
  echo "Tiempo de respaldo + restauración: $(( (T_RESP + T_REST) / 1000 )) s ($T_RESP ms + $T_REST ms). Objetivo de vuelta a operar (RTO): menos de 4 h."
  echo "Datos perdidos con este respaldo: los posteriores a $MARCA. Objetivo (RPO): como máximo 24 h, que cumple el respaldo diario de las 02:00 (infra/linux/13-respaldos.sh)."
  echo "El tiempo medido es el de la base; volver a operar también incluye reiniciar los contenedores (atlas-ctl reiniciar) y comprobar el acceso."
  echo
  echo "Resultado: $IGUALES de $COMPARACIONES comparaciones iguales."
  echo "La base de prueba y el archivo del respaldo se borran al terminar (tienen datos de personas)."
}

if [ -n "$SALIDA" ]; then ejecutar | tee "$SALIDA"; else ejecutar; fi
