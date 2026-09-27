#!/usr/bin/env bash
# =============================================================================
# ATLAS · Fase 6 · Paso 8 — Hora sincronizada con atlas-dc01 (Tabla 35, DEC-R8)
# El NTP (UDP 123) viaja dentro de la VLAN 40: no cruza el router ni necesita reglas.
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

paso "chrony → $IP_DC"
# Se desactivan las fuentes públicas por defecto de Ubuntu: la regla 7 no permite NTP hacia Internet.
sed -i 's/^\(pool .*\)$/# ATLAS (DEC-R8): \1/' /etc/chrony/chrony.conf
rm -f /etc/chrony/sources.d/ubuntu-ntp-pools.sources 2>/dev/null || true
instalar_archivo "$DIR_ARCHIVOS/chrony-atlas.conf" /etc/chrony/conf.d/atlas.conf 644
svc enable chrony >/dev/null 2>&1 || true
svc restart chrony
sleep 3
chronyc sources -v || true
chronyc tracking | grep -E 'Reference ID|System time|Leap status' || true
paso "Listo. Siguiente: 09-dominio.sh (requiere atlas-dc01 funcionando, Fase 7)"
