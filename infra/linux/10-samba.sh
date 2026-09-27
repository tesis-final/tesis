#!/usr/bin/env bash
# =============================================================================
# ATLAS · Fase 6 · Paso 10 — Samba: recursos compartidos para el dominio
# PDF Tabla 35, CT-10: \\atlas-srv01\administracion y \\atlas-srv01\docentes.
# (La unidad de estudiantes está en atlas-dc01, DEC-08: la VLAN 30 no tiene SMB a srv01.)
# Requiere el paso 9 (unión al dominio): los grupos de AD tienen que existir para Linux.
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

for g in "$AD_GRUPO_ADMINISTRACION" "$AD_GRUPO_DOCENTES" "$AD_GRUPO_SOPORTE"; do
  getent group "$g" >/dev/null || error "Linux no ve el grupo de AD '$g'. ¿Se hizo el paso 9?"
done

paso "Carpetas"
install -d -m 755 -o root -g root /srv/samba
for par in "administracion:$AD_GRUPO_ADMINISTRACION" "docentes:$AD_GRUPO_DOCENTES"; do
  d="/srv/samba/${par%%:*}"; g="${par##*:}"
  install -d -m 2770 -o root -g "$g" "$d"
  setfacl -m "g:$g:rwx,g:$AD_GRUPO_SOPORTE:rwx" "$d"
  setfacl -d -m "g:$g:rwx,g:$AD_GRUPO_SOPORTE:rwx" "$d"
done

paso "smb.conf"
TMP="$(mktemp)"; renderizar "$DIR_ARCHIVOS/smb.conf.tpl" "$TMP"
testparm -s "$TMP" >/dev/null || error "smb.conf con errores (testparm)."
instalar_archivo "$TMP" /etc/samba/smb.conf 644; rm -f "$TMP"
svc disable --now nmbd 2>/dev/null || true   # sin NetBIOS
svc enable smbd >/dev/null
svc restart smbd

paso "Comprobación"
testparm -s 2>/dev/null | grep -E '^\[|path|valid users'
ss -ltn "sport = :445" | tail -n +2
paso "Listo. Siguiente: 11-registros.sh"
