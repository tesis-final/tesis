#!/usr/bin/env bash
# =============================================================================
# ATLAS — prueba del monitoreo (infra/monitoring, paso 14 de atlas-srv01) con Zabbix real.
#
# Levanta el compose del monitoreo con contraseñas DESCARTABLES, un servicio de salud de
# prueba en la IP del «servidor» (el bridge de zbx_front, como en srv01) y comprueba:
#   · la interfaz web queda solo en 127.0.0.1 y la base en una red interna;
#   · configurar-zabbix.py deja todo creado y se puede correr dos veces sin duplicar;
#   · la contraseña inicial de Admin deja de servir;
#   · el agente de srv01 responde y manda CPU, memoria y disco;
#   · el escenario web ve /api/v1/health con código 200 y en menos de 3 s;
#   · el SLA del 99 % existe; atlas-dc01 figura sin respuesta (acá no hay Windows).
# Si el servicio de salud se cae, Zabbix abre el problema «ATLAS no responde».
#
# Uso: sudo infra/pruebas/probar-monitoreo.sh      (necesita Docker y las imágenes de Zabbix)
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/../.."
RAIZ=$PWD
TMP=$(mktemp -d)
PUERTO=${ZBX_WEB_PUERTO:-18081}
PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); echo "  PASS  $1"; }
mal() { FAIL=$((FAIL + 1)); echo "  FAIL  $1${2:+  →  $2}"; }
COMPOSE=(docker compose -p atlas-monitoreo-prueba --env-file "$TMP/monitoreo.conf" -f "$RAIZ/infra/monitoring/docker-compose.yml")
limpiar() {
  docker rm -f atlas-salud-prueba >/dev/null 2>&1 || true
  "${COMPOSE[@]}" down -v >/dev/null 2>&1 || true
  docker run --rm -v "$TMP:/t" alpine rm -rf /t/db >/dev/null 2>&1 || true
  rm -rf "${TMP:?}"
}
trap limpiar EXIT

for c in zabbix-db zabbix-server zabbix-web zabbix-agent; do
  docker inspect "$c" >/dev/null 2>&1 && { echo "NO EJECUTADA: ya hay un contenedor $c (¿monitoreo real en este equipo?)."; exit 2; }
done
umask 077
{
  for v in ZBX_DB_PASSWORD ZBX_DB_ROOT_PASSWORD ZBX_ADMIN_PASSWORD; do echo "$v=$(openssl rand -hex 16)"; done
  echo "ZBX_DATOS=$TMP/db"; echo "ZBX_WEB_PUERTO=$PUERTO"; echo "ATLAS_LOG_DRIVER=json-file"
} > "$TMP/monitoreo.conf"
mkdir -p "$TMP/db" "$TMP/salud/api/v1" && chmod 777 "$TMP/db"
echo '{"estado":"ok","base_de_datos":true,"servicio_analisis":true,"ms":3}' > "$TMP/salud/api/v1/health"
chmod -R a+rX "$TMP/salud"; chmod 755 "$TMP"

echo "== Compose del monitoreo"
"${COMPOSE[@]}" up -d 2>&1 | grep -E 'Started|Healthy|Error' | sed 's/^/    /'
GW=$(docker network inspect -f '{{(index .IPAM.Config 0).Gateway}}' zbx_front 2>/dev/null)
[ -z "$GW" ] && GW=192.168.250.65
docker run -d --name atlas-salud-prueba -p "$GW:18443:80" -v "$TMP/salud:/usr/share/nginx/html:ro" "${ATLAS_NGINX_IMAGE:-nginx:alpine}" >/dev/null

echo
echo "[aislamiento]"
[ "$(docker inspect -f '{{json .NetworkSettings.Ports}}' zabbix-web | grep -o '"HostIp":"[^"]*"' | sort -u)" = '"HostIp":"127.0.0.1"' ] \
  && ok "la interfaz web escucha solo en 127.0.0.1:$PUERTO" || mal "la interfaz web escucha solo en 127.0.0.1"
[ "$(docker network inspect -f '{{.Internal}}' zbx_back)" = true ] && ok "zabbix-db está en una red interna (zbx_back)" || mal "zbx_back es interna"
[ -z "$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' zabbix-db | grep -v zbx_back | tr -d ' ')" ] \
  && ok "zabbix-db no está en ninguna otra red" || mal "zabbix-db solo en zbx_back"
[ -z "$(docker port zabbix-db)" ] && ok "MySQL del monitoreo no se publica" || mal "MySQL del monitoreo no se publica"

echo
echo "[configuración por la API]"
set -a; source "$TMP/monitoreo.conf"; set +a
export ZBX_URL="http://127.0.0.1:$PUERTO" SRV_IP="$GW" DC_IP=192.0.2.250 ATLAS_URL="http://$GW:18443"
python3 infra/monitoring/configurar-zabbix.py > "$TMP/config1.txt" 2>&1 && ok "configurar-zabbix.py terminó bien" || mal "configurar-zabbix.py" "$(tail -1 "$TMP/config1.txt")"
sed 's/^/    /' "$TMP/config1.txt"
python3 infra/monitoring/configurar-zabbix.py > "$TMP/config2.txt" 2>&1 && ! grep -qE 'creado|Escenario|Disparador|Servicio:|SLA:' "$TMP/config2.txt" \
  && ok "segunda corrida: no crea nada de nuevo (idempotente)" || mal "segunda corrida idempotente"

echo
echo "[datos — se espera hasta 5 minutos a que lleguen]"
for _ in $(seq 1 30); do
  python3 infra/monitoring/estado-zabbix.py > "$TMP/estado.txt" 2>&1
  grep -q 'PASS  atlas-srv01' "$TMP/estado.txt" && grep -q 'PASS  último chequeo' "$TMP/estado.txt" && grep -qE '^ +memoria' "$TMP/estado.txt" \
    && grep -qE '^ +disco /' "$TMP/estado.txt" && break
  sleep 10
done
sed 's/^/    /' "$TMP/estado.txt"
grep -q 'PASS  la contraseña inicial' "$TMP/estado.txt" && ok "la contraseña inicial de Admin ya no entra" || mal "la contraseña inicial de Admin ya no entra"
grep -q 'PASS  atlas-srv01' "$TMP/estado.txt" && ok "el agente de srv01 responde (solo a 192.168.250.64/28)" || mal "el agente de srv01 responde"
grep -qE '^ +CPU' "$TMP/estado.txt" && grep -qE '^ +memoria' "$TMP/estado.txt" && grep -qE '^ +disco /' "$TMP/estado.txt" \
  && ok "llegan CPU, memoria y disco del servidor" || mal "llegan CPU, memoria y disco"
grep -q 'PASS  último chequeo' "$TMP/estado.txt" && grep -q 'código HTTP 200' "$TMP/estado.txt" && ok "escenario web: /api/v1/health con 200" || mal "escenario web con 200"
grep -q 'PASS  tiempo de respuesta' "$TMP/estado.txt" && ok "escenario web: responde en menos de 3 s" || mal "tiempo de respuesta ≤ 3 s"
grep -q 'PASS  SLA' "$TMP/estado.txt" && ok "SLA del 99 % definido" || mal "SLA del 99 % definido"
grep -q 'FAIL  atlas-dc01' "$TMP/estado.txt" && ok "atlas-dc01 figura sin respuesta (esperado: acá no hay Windows)" || mal "atlas-dc01 sin respuesta"

echo
echo "[caída de ATLAS: Zabbix abre el problema]"
docker stop atlas-salud-prueba >/dev/null
for _ in $(seq 1 24); do
  python3 infra/monitoring/estado-zabbix.py > "$TMP/estado2.txt" 2>&1
  grep -q 'ATLAS no responde' "$TMP/estado2.txt" && break
  sleep 10
done
grep -q 'ATLAS no responde' "$TMP/estado2.txt" && ok "con ATLAS caído aparece el problema «ATLAS no responde»" || mal "problema «ATLAS no responde»"
grep 'ATLAS no responde' "$TMP/estado2.txt" | head -1 | sed 's/^/    /'

echo
echo "Resultado: $PASS PASS · $FAIL FAIL"
[ "$FAIL" -eq 0 ]
