#!/usr/bin/env bash
# =============================================================================
# ATLAS · Fase 6 · Paso 11 — Registros y auditoría del servidor (§28.3, §30.5)
#   · journald persistente (los contenedores ya registran ahí, paso 6);
#   · auditd: deja constancia de quién usa chattr y de cambios en archivos clave;
#   · logrotate para los logs de /srv/atlas/logs (menos auditoria.log).
# UFW registra las denegaciones en /var/log/ufw.log (rsyslog, paso 5).
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

paso "journald persistente"
instalar_archivo "$DIR_ARCHIVOS/journald-atlas.conf" /etc/systemd/journald.conf.d/atlas.conf 644
mkdir -p /var/log/journal
svc restart systemd-journald

paso "auditd (reglas ATLAS)"
instalar_archivo "$DIR_ARCHIVOS/auditd-atlas.rules" /etc/audit/rules.d/50-atlas.rules 640
svc enable auditd >/dev/null 2>&1 || true
augenrules --load >/dev/null 2>&1 || service auditd restart || aviso "No se pudieron cargar las reglas de auditd."
command -v auditctl >/dev/null && auditctl -l | grep -c atlas- | xargs -I{} echo "   {} reglas ATLAS activas"

paso "logrotate"
instalar_archivo "$DIR_ARCHIVOS/logrotate-atlas" /etc/logrotate.d/atlas 644
logrotate -d /etc/logrotate.d/atlas >/dev/null 2>&1 || aviso "logrotate informó problemas con /etc/logrotate.d/atlas."

paso "Listo. Siguiente: 12-sudo.sh"
