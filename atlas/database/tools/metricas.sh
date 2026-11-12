#!/usr/bin/env bash
# =============================================================================
# ATLAS — tools/metricas.sh  (Hito 3: métricas para verificar requisitos y objetivos)
#
# Devolución de Gestión del Hito 2: «Incorporar métricas que permitan verificar los
# requisitos y objetivos establecidos». Sección 12 del documento: tiempo de respuesta,
# disponibilidad, actividades correctamente registradas, recomendaciones, recuperación,
# respaldos exitosos, eventos de seguridad. Tabla 5: criterio de cada objetivo.
#
# Este script calcula las que salen de la base de datos, con consultas de SOLO LECTURA sobre
# la base en uso. Las otras se miden con su propia herramienta y se citan al final:
#   tiempo de respuesta → atlas/tests/rendimiento/medir.py
#   disponibilidad      → atlas/tests/rendimiento/disponibilidad.sh y Zabbix (laboratorio)
#   recuperación        → atlas/database/tools/restaurar_intento.sh
#
# Uso:  sudo atlas/database/tools/metricas.sh [archivo_salida]
#       (en atlas-srv01 con sudo; las contraseñas las lee el contenedor de atlas.conf)
# =============================================================================
set -euo pipefail
CONT=${ATLAS_DB_CONTENEDOR:-atlas-db}
SALIDA=${1:-}
q() { docker exec -i "$CONT" sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --default-character-set=utf8mb4 -N -B atlas_db -e "$1"' sh "$1" 2>&1 | { grep -v 'Using a password' || true; }; }
docker inspect "$CONT" >/dev/null 2>&1 || { echo "No encuentro el contenedor $CONT (¿ATLAS está levantado?)."; exit 1; }

PASS=0; FALLA=0; INFO=0
fila() {   # fila <id> <métrica> <valor> <meta> <estado PASS|FAIL|INFO> <de dónde sale>
  printf '%-4s %-58s %-26s %-22s %-5s %s\n' "$1" "$2" "$3" "$4" "$5" "$6"
  case "$5" in PASS) PASS=$((PASS + 1)) ;; FAIL) FALLA=$((FALLA + 1)) ;; *) INFO=$((INFO + 1)) ;; esac
}
pct() { awk -v a="$1" -v b="$2" 'BEGIN { if (b == 0) print "—"; else printf "%.1f %%", 100 * a / b }'; }

ejecutar() {
  echo "ATLAS — Métricas de verificación de requisitos y objetivos"
  echo "Fecha (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ) · Equipo: $(hostname) · MySQL $(q 'SELECT VERSION()')"
  echo "Base: $(q 'SELECT COUNT(*) FROM usuarios') usuarios · $(q 'SELECT COUNT(*) FROM intentos') intentos · $(q 'SELECT COUNT(*) FROM resultados') resultados · $(q 'SELECT COUNT(*) FROM interacciones') interacciones"
  echo
  printf '%-4s %-58s %-26s %-22s %-5s %s\n' ID Métrica Valor Meta Est. Origen
  printf '%.0s-' $(seq 1 150); echo

  # M1 · Objetivo 3 / RF-06..09: cada intento finalizado queda con respuestas, tiempo, inicio, fin y resultado.
  FIN=$(q "SELECT COUNT(*) FROM intentos WHERE estado = 'FINALIZADO'")
  COMPLETOS=$(q "SELECT COUNT(*) FROM intentos i
                 WHERE i.estado = 'FINALIZADO' AND i.duracion_seg IS NOT NULL
                   AND EXISTS (SELECT 1 FROM resultados r WHERE r.intento_id = i.id)
                   AND EXISTS (SELECT 1 FROM respuestas re WHERE re.intento_id = i.id)
                   AND EXISTS (SELECT 1 FROM interacciones x WHERE x.intento_id = i.id AND x.tipo = 'INICIO')
                   AND EXISTS (SELECT 1 FROM interacciones x WHERE x.intento_id = i.id AND x.tipo = 'FIN')")
  fila M1 "Intentos finalizados registrados completos (Obj. 3)" "$COMPLETOS de $FIN ($(pct "$COMPLETOS" "$FIN"))" "100 %" "$([ "$FIN" -gt 0 ] && [ "$COMPLETOS" = "$FIN" ] && echo PASS || echo FAIL)" "intentos, respuestas, interacciones, resultados"

  # M2 · Unicidad del puntaje (devolución de BD): un único resultado por intento.
  DUP=$(q "SELECT COUNT(*) FROM (SELECT intento_id FROM resultados GROUP BY intento_id HAVING COUNT(*) > 1) d")
  fila M2 "Intentos con más de un resultado" "$DUP" "0" "$([ "$DUP" = 0 ] && echo PASS || echo FAIL)" "resultados (UNIQUE uq_resultados_intento)"

  # M3 · Consistencia del puntaje guardado contra el calculado desde las respuestas.
  DIF=$(q "SELECT COUNT(*) FROM resultados r JOIN (
             SELECT i.id, ROUND(100 * COALESCE(SUM(o.es_correcta), 0) / (SELECT COUNT(*) FROM preguntas p WHERE p.actividad_id = i.actividad_id), 2) AS p
               FROM intentos i LEFT JOIN respuestas re ON re.intento_id = i.id LEFT JOIN opciones o ON o.id = re.opcion_id
              WHERE i.estado = 'FINALIZADO' GROUP BY i.id, i.actividad_id) c ON c.id = r.intento_id WHERE c.p <> r.puntaje")
  fila M3 "Resultados distintos del puntaje recalculado" "$DIF de $(q 'SELECT COUNT(*) FROM resultados')" "0" "$([ "$DIF" = 0 ] && echo PASS || echo FAIL)" "resultados vs respuestas/opciones"

  # M4 · Objetivo 5 / RF-12: cada recomendación es rastreable a su regla (y su versión).
  REC=$(q "SELECT COUNT(*) FROM recomendaciones")
  TRAZ=$(q "SELECT COUNT(DISTINCT rr.recomendacion_id) FROM recomendacion_regla rr")
  fila M4 "Recomendaciones con regla y versión registradas (Obj. 5)" "$TRAZ de $REC ($(pct "$TRAZ" "$REC"))" "100 %" "$([ "$REC" -gt 0 ] && [ "$TRAZ" = "$REC" ] && echo PASS || { [ "$REC" = 0 ] && echo INFO || echo FAIL; })" "recomendaciones, recomendacion_regla"
  REGLAS=$(q "SELECT COUNT(*) FROM reglas_analisis WHERE activa")
  fila M5 "Reglas explicables activas (Obj. 5: al menos 8)" "$REGLAS" "≥ 8" "$([ "$REGLAS" -ge 8 ] && echo PASS || echo FAIL)" "reglas_analisis"

  # M6 · D-6: el sistema sugiere y el docente decide. Proporción en que confirma la sugerencia.
  DEC=$(q "SELECT COUNT(*) FROM decisiones_recomendacion")
  CONF=$(q "SELECT COUNT(*) FROM decisiones_recomendacion WHERE decision = 'CONFIRMADA'")
  fila M6 "Sugerencias confirmadas por el docente (acuerdo, D-6)" "$CONF de $DEC ($(pct "$CONF" "$DEC"))" "informativa" INFO "decisiones_recomendacion"

  # M7 · D-3: cada pregunta de una actividad publicada mide al menos una habilidad.
  PREG=$(q "SELECT COUNT(*) FROM preguntas p JOIN actividades a ON a.id = p.actividad_id JOIN estados_actividad e ON e.id = a.estado_id WHERE e.codigo = 'PUBLICADA'")
  CONH=$(q "SELECT COUNT(DISTINCT p.id) FROM preguntas p JOIN actividades a ON a.id = p.actividad_id JOIN estados_actividad e ON e.id = a.estado_id JOIN pregunta_habilidad ph ON ph.pregunta_id = p.id WHERE e.codigo = 'PUBLICADA'")
  fila M7 "Preguntas publicadas con habilidad (D-3)" "$CONH de $PREG ($(pct "$CONH" "$PREG"))" "100 %" "$([ "$PREG" -gt 0 ] && [ "$CONH" = "$PREG" ] && echo PASS || { [ "$PREG" = 0 ] && echo INFO || echo FAIL; })" "preguntas, pregunta_habilidad"

  # M8 · Objetivo 7 / RNF-01: los accesos no autorizados se rechazan y quedan registrados.
  DEN=$(q "SELECT COUNT(*) FROM auditoria WHERE resultado = 'DENEGADO'")
  DEN7=$(q "SELECT COUNT(*) FROM auditoria WHERE resultado = 'DENEGADO' AND creado_en >= UTC_TIMESTAMP() - INTERVAL 7 DAY")
  fila M8 "Accesos denegados registrados (total · últimos 7 días)" "$DEN · $DEN7" "registrados" INFO "auditoria (revisión semanal, Tabla 47)"
  BLOQ=$(q "SELECT COUNT(*) FROM usuarios WHERE bloqueado_hasta IS NOT NULL AND bloqueado_hasta > UTC_TIMESTAMP()")
  fila M9 "Cuentas bloqueadas ahora por intentos fallidos (RF-02)" "$BLOQ" "informativa" INFO "usuarios.bloqueado_hasta"

  # M10/M11 · RNF-04 / Objetivo 11: respaldos según la frecuencia definida y verificados.
  RESP=$(q "SELECT COUNT(*) FROM registro_respaldos WHERE iniciado_en >= UTC_TIMESTAMP() - INTERVAL 30 DAY")
  OK=$(q "SELECT COUNT(*) FROM registro_respaldos WHERE iniciado_en >= UTC_TIMESTAMP() - INTERVAL 30 DAY AND resultado = 'OK'")
  VER=$(q "SELECT COUNT(*) FROM registro_respaldos WHERE iniciado_en >= UTC_TIMESTAMP() - INTERVAL 30 DAY AND resultado = 'OK' AND verificado")
  if [ "$RESP" = 0 ]; then
    fila M10 "Respaldos exitosos en 30 días (RNF-04)" "sin registros" "100 %" INFO "registro_respaldos (correr 13-respaldos.sh)"
  else
    fila M10 "Respaldos exitosos en 30 días (RNF-04)" "$OK de $RESP ($(pct "$OK" "$RESP")) · $VER verificados" "100 %" "$([ "$OK" = "$RESP" ] && echo PASS || echo FAIL)" "registro_respaldos"
  fi
  EDAD=$(q "SELECT COALESCE(TIMESTAMPDIFF(HOUR, MAX(finalizado_en), UTC_TIMESTAMP()), -1) FROM registro_respaldos WHERE resultado = 'OK' AND tipo IN ('COMPLETO','INCREMENTAL')")
  if [ "$EDAD" = -1 ]; then
    fila M11 "Horas desde el último respaldo de la base (RPO)" "sin registros" "≤ 24 h" INFO "registro_respaldos"
  else
    fila M11 "Horas desde el último respaldo de la base (RPO)" "$EDAD h" "≤ 24 h" "$([ "$EDAD" -le 24 ] && echo PASS || echo FAIL)" "registro_respaldos"
  fi

  echo
  echo "Resultado: $PASS PASS · $FALLA FAIL · $INFO informativas"
  echo
  echo "Métricas que se miden con otra herramienta (sección 12 y Tabla 47):"
  echo "  Tiempo de respuesta ≤ 3 s (RNF-03) ........ python3 atlas/tests/rendimiento/medir.py https://<servidor> <clave> 30"
  echo "  Disponibilidad ≥ 99 % (RNF-02) ............ atlas/tests/rendimiento/disponibilidad.sh https://<servidor> <minutos>, y Zabbix en el laboratorio"
  echo "  Recuperación: RTO < 4 h, RPO ≤ 24 h ....... sudo atlas/database/tools/restaurar_intento.sh"
  echo "  CPU, memoria y disco: alerta al 80 % ...... Zabbix (infra/monitoreo)"
  echo "  Eventos de seguridad de red ............... registro ATLAS-* de router-lab (journalctl -k) y Visor de eventos del DC"
  [ "$FALLA" = 0 ]
}

if [ -n "$SALIDA" ]; then ejecutar | tee "$SALIDA"; else ejecutar; fi
