#!/usr/bin/env bash
# =============================================================================
# ATLAS · Fase 6 · Paso 4 — Quién puede conectarse (PDF §28.4, DEC-07)
# SSH endurecido + TCP Wrappers. Es una segunda capa, aparte del firewall:
# si una regla del firewall se rompe, el servicio igual rechaza la conexión.
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

# Protección para no quedar afuera: sin clave pública de atlasadmin no se sigue.
[ -s /home/atlasadmin/.ssh/authorized_keys ] || \
  error "atlasadmin no tiene authorized_keys. Correr el paso 2 con la clave pública (ATLAS_CLAVE_PUBLICA_ADMIN)."

paso "sshd: /etc/ssh/sshd_config.d/10-atlas.conf"
instalar_archivo "$DIR_ARCHIVOS/sshd-10-atlas.conf" /etc/ssh/sshd_config.d/10-atlas.conf 644
instalar_archivo "$DIR_ARCHIVOS/issue.net" /etc/issue.net 644
sshd -t || error "La configuración de sshd tiene errores: no se recarga."

paso "TCP Wrappers: /etc/hosts.allow y /etc/hosts.deny"
ldd /usr/sbin/sshd | grep -q libwrap || aviso "Este sshd no está enlazado con libwrap: los TCP Wrappers no tendrían efecto."
# Primero allow y después deny, para no cortar una sesión SSH abierta desde VLAN 50.
instalar_archivo "$DIR_ARCHIVOS/hosts.allow" /etc/hosts.allow 644
instalar_archivo "$DIR_ARCHIVOS/hosts.deny"  /etc/hosts.deny  644

svc enable ssh >/dev/null 2>&1 || true
svc reload ssh 2>/dev/null || svc restart ssh 2>/dev/null || aviso "No se pudo recargar ssh (¿sin systemd?)."

paso "Configuración efectiva para un origen de VLAN 50 y uno de VLAN 30:"
sshd -T -C "user=atlasadmin,host=gestion,addr=172.16.50.10" | grep -E '^(allowusers|allowgroups|permitrootlogin|passwordauthentication|maxauthtries|allowtcpforwarding) '
echo "---"
sshd -T -C "user=atlasadmin,host=estudiante,addr=172.16.30.100" | grep -E '^(allowusers|allowgroups|allowtcpforwarding) '
paso "Listo. Siguiente: 05-firewall.sh"
