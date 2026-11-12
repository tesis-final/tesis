#!/usr/bin/env bash
# =============================================================================
# ATLAS — tools/seguir_intento.sh  (Hito 3, devolución de Base de Datos, punto 1)
#
# La parte de la base del seguimiento de un intento, para correr en atlas-srv01 después de
# que un estudiante resuelve una actividad desde la VLAN 30 (en el laboratorio no hay
# Playwright: la parte de la pantalla son las capturas del cliente). Muestra, para un intento:
#   · el intento (inicio y fin puestos por el servidor, duración);
#   · la respuesta FINAL de cada pregunta (una sola fila por pregunta);
#   · todas las interacciones en orden, con los cambios de opción (CAMBIO_OPCION);
#   · el resultado: una sola fila, con correctas, total y puntaje;
#   · el puntaje recalculado desde las respuestas, para compararlo con el guardado.
# Son las mismas consultas que atlas/tests/e2e/trazar_intento.py (trazado automático en desarrollo).
#
# Uso:  sudo atlas/database/tools/seguir_intento.sh [intento_id] [archivo_salida]
#       Sin intento_id toma el último intento finalizado.
#       En atlas-srv01: sudo /opt/atlas/tesis/atlas/database/tools/seguir_intento.sh
# Solo lee. La contraseña no se escribe: la usa el contenedor de su propio entorno.
# =============================================================================
set -euo pipefail
CONT=${ATLAS_DB_CONTENEDOR:-atlas-db}
sql() {   # sql "<consulta>" [opciones de mysql]: por defecto en forma de tabla
  docker exec -i "$CONT" sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 '"${2:---table}"' atlas_db' \
    <<<"$1" 2> >(grep -v 'Using a password' >&2)
}
valor() { sql "$1" "-N --batch" | tr -d '\r' | head -1; }   # un solo valor, sin encabezados

ID=${1:-$(valor "SELECT id FROM intentos WHERE estado = 'FINALIZADO' ORDER BY finalizado_en DESC, id DESC LIMIT 1;")}
[[ "$ID" =~ ^[0-9]+$ ]] || { echo "No hay intentos finalizados (o el número no es válido)."; exit 1; }
SALIDA=${2:-/dev/stdout}

{
  echo "ATLAS — seguimiento del intento $ID en la base ($(hostname), $(date -u +%Y-%m-%dT%H:%M:%SZ))"
  echo
  echo "== Intento (inicio y fin los pone el servidor)"
  sql "SELECT i.id, i.usuario_id, a.titulo AS actividad, i.numero_intento, i.estado, i.iniciado_en, i.finalizado_en, i.duracion_seg
         FROM intentos i JOIN actividades a ON a.id = i.actividad_id WHERE i.id = $ID;"
  echo
  echo "== Respuesta final de cada pregunta (una fila por pregunta)"
  sql "SELECT p.orden AS pregunta, o.texto AS opcion_final, o.es_correcta, r.tiempo_seg, r.respondido_en
         FROM respuestas r JOIN preguntas p ON p.id = r.pregunta_id JOIN opciones o ON o.id = r.opcion_id
        WHERE r.intento_id = $ID ORDER BY p.orden;"
  echo
  echo "== Interacciones en orden (el proceso: selecciones, cambios, pausas)"
  sql "SELECT i.secuencia, i.tipo, p.orden AS pregunta, o.texto AS opcion, i.ocurrido_en
         FROM interacciones i LEFT JOIN preguntas p ON p.id = i.pregunta_id LEFT JOIN opciones o ON o.id = i.opcion_id
        WHERE i.intento_id = $ID ORDER BY i.secuencia;"
  echo
  echo "== Cambios de opción por pregunta"
  sql "SELECT p.orden AS pregunta, COUNT(*) AS cambios
         FROM interacciones i JOIN preguntas p ON p.id = i.pregunta_id
        WHERE i.intento_id = $ID AND i.tipo = 'CAMBIO_OPCION' GROUP BY p.orden ORDER BY p.orden;"
  echo
  echo "== Resultado guardado (tiene que haber UNA sola fila)"
  sql "SELECT id, intento_id, correctas, total_preguntas, puntaje, calculado_en FROM resultados WHERE intento_id = $ID;"
  FILAS=$(valor "SELECT COUNT(*) FROM resultados WHERE intento_id = $ID;")
  GUARDADO=$(valor "SELECT puntaje FROM resultados WHERE intento_id = $ID;")
  CALCULADO=$(valor "SELECT ROUND(100 * SUM(o.es_correcta) / (SELECT COUNT(*) FROM preguntas p WHERE p.actividad_id = i.actividad_id), 2)
                       FROM intentos i JOIN respuestas r ON r.intento_id = i.id JOIN opciones o ON o.id = r.opcion_id WHERE i.id = $ID;")
  echo
  echo "== Comprobación"
  echo "  filas en resultados: $FILAS  (esperado: 1)"
  echo "  puntaje guardado:    $GUARDADO"
  echo "  puntaje recalculado: $CALCULADO  (100 × correctas / preguntas de la actividad)"
  if [ "$FILAS" = 1 ] && awk -v a="$GUARDADO" -v b="$CALCULADO" 'BEGIN { exit !(a + 0 == b + 0) }'; then
    echo "  RESULTADO: OK — un único resultado y el puntaje guardado coincide con el recalculado"
  else
    echo "  RESULTADO: REVISAR — no coincide (o hay más de un resultado)"
  fi
} > "$SALIDA"
