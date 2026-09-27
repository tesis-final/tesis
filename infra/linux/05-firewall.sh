#!/usr/bin/env bash
# =============================================================================
# ATLAS · Fase 6 · Paso 5 — Firewall del servidor (UFW) alineado con la Tabla 44
# PDF §28.4 + DEC-05 (DISC-06) + CT-04.
#
#   Política: negar entrante, permitir saliente (§28.4, §30.3, DEC-R9).
#   22/tcp   desde VLAN 50 ................................ regla 6
#   443/tcp  desde VLAN 10, 20, 30 y VPN docentes ........ reglas 1 y 9
#   445/tcp  desde VLAN 10 y 20 (Samba) .................. regla 3
#   445/tcp  desde atlas-dc01 ............................ servicios de dominio (Tabla 35)
#   3306     NINGUNA regla: MySQL no se publica (§28.4, DEC-02)
#
# Diferencias con el texto de §28.4, decididas en DEC-05: no se abren 80 ni 139
# (la Tabla 44 no los permite) y se agregan VLAN 10 y la VPN docente a 443.
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

IFACE="$(interfaz_principal)"; export IFACE
[ -n "$IFACE" ] || error "No se encontró la interfaz de red; definir ATLAS_IFACE."

paso "Reglas de UFW"
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
# Reenvío: se niega por defecto. Docker acepta en sus propias cadenas solo el
# tráfico de sus contenedores, después de pasar por DOCKER-USER.
ufw default deny routed
ufw allow from "$RED_GESTION"      to any port 22  proto tcp comment 'R6 SSH desde Gestion'
ufw allow from "$RED_ADMIN"        to any port 443 proto tcp comment 'R1 HTTPS VLAN10'
ufw allow from "$RED_DOCENTES"     to any port 443 proto tcp comment 'R1 HTTPS VLAN20'
ufw allow from "$RED_ESTUDIANTES"  to any port 443 proto tcp comment 'R1 HTTPS VLAN30'
ufw allow from "$RED_VPN_DOCENTES" to any port 443 proto tcp comment 'R9 HTTPS VPN docentes'
ufw allow from "$RED_ADMIN"        to any port 445 proto tcp comment 'R3 SMB VLAN10'
ufw allow from "$RED_DOCENTES"     to any port 445 proto tcp comment 'R3 SMB VLAN20'
ufw allow from "$IP_DC"            to any port 445 proto tcp comment 'Dominio SMB desde DC'
ufw logging on

paso "Filtro para los puertos que publica Docker (cadena DOCKER-USER)"
TMP="$(mktemp)"; renderizar "$DIR_ARCHIVOS/ufw-docker-user.rules.tpl" "$TMP"
sed -i '/# ATLAS-DOCKER-USER-INICIO/,/# ATLAS-DOCKER-USER-FIN/d' /etc/ufw/after.rules
cat "$TMP" >> /etc/ufw/after.rules; rm -f "$TMP"

ufw --force enable
ufw status verbose
echo
iptables -S DOCKER-USER
paso "Listo. Siguiente: 06-docker.sh"
