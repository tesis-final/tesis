#!/usr/bin/env bash
# =============================================================================
# ATLAS · Fase 6 — Paso 14: monitoreo centralizado con Zabbix 7.0 LTS (§30.5, Tablas 46 y 47;
# DEC-19, CT-07)
#
#  1. /srv/atlas/config/monitoreo.conf con contraseñas aleatorias (root, modo 600, sin ACL).
#     Nunca va al repositorio; sí entra en el respaldo de la configuración (paso 13).
#  2. Compose del monitoreo en /srv/atlas/monitoreo (zabbix-db, zabbix-server, zabbix-web y
#     el agente de srv01). La interfaz web queda SOLO en 127.0.0.1:8080.
#  3. UFW: el agente (10050) solo atiende a la red de zabbix-server, 192.168.250.64/28.
#  4. configurar-zabbix.py: cambia la contraseña inicial de Admin, da de alta atlas-srv01 y
#     atlas-dc01 con alertas al 80 %, el chequeo de /api/v1/health (≤ 3 s) y el SLA del 99 %.
#  5. Estado inicial (estado-zabbix.py). El agente de atlas-dc01 se instala con
#     infra/windows/14-agente-zabbix.ps1; hasta entonces ese host figura sin respuesta.
#
# Entrar a la interfaz (desde la VLAN 50, con el usuario de soporte):
#   ssh -L 8080:127.0.0.1:8080 atlasadmin@172.16.40.10   → http://127.0.0.1:8080 (Admin)
#   La contraseña de Admin se lee en el servidor con: sudo grep ZBX_ADMIN /srv/atlas/config/monitoreo.conf
#
# Uso: sudo ATLAS_REPO_TESIS=/opt/atlas/tesis ./14-monitoreo.sh
# Requiere los pasos 5, 6 y 7. La primera vez descarga las imágenes de Zabbix (Internet).
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

REPO="${ATLAS_REPO_TESIS:-/opt/atlas/tesis}"
ORIGEN="$REPO/infra/monitoring"
DESTINO="$ATLAS_ROOT/monitoreo"
CONF="$ATLAS_ROOT/config/monitoreo.conf"
RED_MONITOREO="${RED_MONITOREO:-192.168.250.64/28}"
[ -f "$ORIGEN/docker-compose.yml" ] || error "No encuentro $ORIGEN/docker-compose.yml (¿git pull en $REPO?)."
command -v docker >/dev/null || error "Falta Docker: correr antes el paso 6."
[ -d "$ATLAS_ROOT/config" ] || error "Falta $ATLAS_ROOT/config: correr antes el paso 3."

secreto() { openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32; }

paso "1/5 Contraseñas del monitoreo en $CONF (root 600)"
( umask 077; touch "$CONF" )
for clave in ZBX_DB_PASSWORD ZBX_DB_ROOT_PASSWORD ZBX_ADMIN_PASSWORD; do
  grep -q "^$clave=." "$CONF" || echo "$clave=$(secreto)" >> "$CONF"
done
grep -q '^ZBX_DATOS=' "$CONF" || echo "ZBX_DATOS=$DESTINO/db" >> "$CONF"
grep -q '^ATLAS_LOG_DRIVER=' "$CONF" || echo "ATLAS_LOG_DRIVER=journald" >> "$CONF"
chown root:root "$CONF"; chmod 600 "$CONF"
setfacl -b "$CONF" 2>/dev/null || true      # sin la ACL por defecto de config/ (Tabla 27)
echo "    $(stat -c '%U:%G %a' "$CONF") · claves: $(cut -d= -f1 "$CONF" | paste -sd' ')"

paso "2/5 Compose del monitoreo en $DESTINO"
install -d -m 750 -o root -g root "$DESTINO"
install -m 640 -o root -g root "$ORIGEN/docker-compose.yml" "$DESTINO/docker-compose.yml"
install -m 750 -o root -g root "$ORIGEN/configurar-zabbix.py" "$ORIGEN/estado-zabbix.py" "$DESTINO/"
COMPOSE=(docker compose --env-file "$CONF" -f "$DESTINO/docker-compose.yml")
"${COMPOSE[@]}" config -q
"${COMPOSE[@]}" pull -q 2>/dev/null || aviso "No se pudieron bajar las imágenes (¿sin Internet?); se usan las que ya estén."
"${COMPOSE[@]}" up -d
"${COMPOSE[@]}" ps

paso "3/5 UFW: el agente (10050) solo para zabbix-server ($RED_MONITOREO)"
if command -v ufw >/dev/null; then
  ufw allow from "$RED_MONITOREO" to any port 10050 proto tcp comment 'Monitoreo: zabbix-server al agente' >/dev/null
  ufw status | grep 10050 || true
else
  aviso "UFW no está instalado: correr el paso 5."
fi

paso "4/5 Configuración de Zabbix por su API (espera a que termine de crear su base)"
set -a; source "$CONF"; set +a
ZBX_URL="http://127.0.0.1:${ZBX_WEB_PUERTO:-8080}" SRV_IP="$ATLAS_IP" DC_IP="$IP_DC" ATLAS_URL="https://$ATLAS_IP" \
  python3 "$DESTINO/configurar-zabbix.py"

paso "5/5 Estado inicial (los primeros datos tardan 1 o 2 minutos)"
sleep 90
ZBX_URL="http://127.0.0.1:${ZBX_WEB_PUERTO:-8080}" python3 "$DESTINO/estado-zabbix.py" \
  || aviso "Hay controles pendientes (si es atlas-dc01: falta infra/windows/14-agente-zabbix.ps1)."
unset ZBX_DB_PASSWORD ZBX_DB_ROOT_PASSWORD ZBX_ADMIN_PASSWORD
ss -ltn '( sport = :8080 or sport = :10050 )'
echo "==> Listo. Estado en cualquier momento: sudo atlas-ctl monitoreo"
