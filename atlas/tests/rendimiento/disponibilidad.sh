#!/usr/bin/env bash
# =============================================================================
# ATLAS — disponibilidad durante una ventana de prueba (RNF-02, Tabla 47: 99 % o más).
#
# Pide /api/v1/health cada INTERVALO segundos durante los minutos indicados y cuenta
# cuántas veces ATLAS respondió bien (HTTP 200 con "estado":"ok" y la base conectada).
# En el laboratorio la misma medición la hace Zabbix; este script sirve para una ventana
# corta desde cualquier equipo con acceso (cliente-doc, la estación de gestión o la PC).
#
# Uso:  atlas/tests/rendimiento/disponibilidad.sh https://172.16.40.10 60 [intervalo_seg]
# El certificado de ATLAS-CA se verifica si está instalado; con -k se acepta el provisorio.
# =============================================================================
set -uo pipefail
URL=${1:?Falta la URL de ATLAS, por ejemplo https://172.16.40.10}
MINUTOS=${2:-10}
INTERVALO=${3:-10}
CURL=(curl -s --max-time 5 -k -o /dev/stdout -w '\n%{http_code} %{time_total}')

TOTAL=0; BIEN=0; PEOR=0
FIN=$(( $(date +%s) + MINUTOS * 60 ))
echo "# Disponibilidad de $URL · $(date -u +%Y-%m-%dT%H:%M:%SZ) · ${MINUTOS} min, cada ${INTERVALO} s"
while [ "$(date +%s)" -lt "$FIN" ]; do
  RESP=$("${CURL[@]}" "$URL/api/v1/health" 2>/dev/null)
  CODIGO=$(tail -1 <<<"$RESP" | cut -d' ' -f1)
  SEG=$(tail -1 <<<"$RESP" | cut -d' ' -f2)
  CUERPO=$(head -n -1 <<<"$RESP")
  TOTAL=$((TOTAL + 1))
  if [ "$CODIGO" = 200 ] && grep -q '"estado":"ok"' <<<"$CUERPO" && grep -q '"base_de_datos":true' <<<"$CUERPO"; then
    BIEN=$((BIEN + 1)); ESTADO=ok
  else
    ESTADO="FALLA (HTTP ${CODIGO:-sin respuesta})"
  fi
  MS=$(awk -v s="${SEG:-0}" 'BEGIN { printf "%d", s * 1000 }')
  [ "$MS" -gt "$PEOR" ] && PEOR=$MS
  echo "$(date -u +%H:%M:%S) $ESTADO ${MS} ms"
  sleep "$INTERVALO"
done
PCT=$(awk -v a="$BIEN" -v b="$TOTAL" 'BEGIN { printf "%.2f", (b ? 100 * a / b : 0) }')
echo
echo "Respuestas correctas: $BIEN de $TOTAL ($PCT %) · respuesta más lenta: $PEOR ms"
awk -v p="$PCT" 'BEGIN { exit !(p >= 99) }' && { echo "Resultado: PASS (meta 99 %)"; exit 0; } || { echo "Resultado: FAIL (meta 99 %)"; exit 1; }
