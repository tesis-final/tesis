#!/usr/bin/env bash
# =============================================================================
# ATLAS · Fase 6 · Paso 9 — Unir atlas-srv01 al dominio atlas.local
# PDF Tabla 35 (SSSD/Kerberos, grupos AD → POSIX) y Tabla 36; DEC-07, DEC-13, DEC-18.
#
# Requisitos: atlas-dc01 funcionando (Fase 7), DNS apuntando a 172.16.40.20,
# hora sincronizada (paso 8) y una cuenta de AD con permiso para unir equipos
# a OU=Servidores (delegada a GG_SoporteTI en la Fase 7).
#
# Uso: sudo ATLAS_USUARIO_UNION=adm.soporte ./09-dominio.sh
#      (realm pide la contraseña de esa cuenta; no se guarda en ningún lado)
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
USUARIO_UNION="${ATLAS_USUARIO_UNION:?Definir ATLAS_USUARIO_UNION (cuenta de AD que une equipos)}"

paso "Comprobaciones previas"
host -t SRV "_ldap._tcp.$ATLAS_DOMINIO" "$ATLAS_DNS" >/dev/null || error "El DNS $ATLAS_DNS no resuelve _ldap._tcp.$ATLAS_DOMINIO (¿DC listo? ¿DNS del servidor?)."
host "$ATLAS_HOSTNAME.$ATLAS_DOMINIO" "$ATLAS_DNS" >/dev/null || aviso "El DC todavía no tiene el registro A de $ATLAS_HOSTNAME (lo crea la Fase 7, 05-dns.ps1)."
DESFASE="$(chronyc tracking 2>/dev/null | awk '/System time/ {print $4}')"
awk -v d="${DESFASE:-999}" 'BEGIN { exit !(d < 300) }' || error "El reloj difiere ${DESFASE:-?} s del DC: Kerberos exige menos de 5 minutos (paso 8)."
realm discover "$ATLAS_DOMINIO"

paso "Unión al dominio (SSSD para identidades, Samba como software de membresía, DEC-13)"
if realm list | grep -q "domain-name: $ATLAS_DOMINIO"; then
  echo "   Ya estaba unido."
else
  realm join --verbose --user="$USUARIO_UNION" \
    --client-software=sssd --membership-software=samba \
    --computer-ou="$ATLAS_OU_EQUIPO" "$ATLAS_DOMINIO"
fi

paso "SSSD"
renderizar "$DIR_ARCHIVOS/sssd.conf.tpl" /etc/sssd/sssd.conf
chmod 600 /etc/sssd/sssd.conf; chown root:root /etc/sssd/sssd.conf
svc restart sssd
pam-auth-update --enable mkhomedir >/dev/null

paso "Correspondencia GG_SoporteTI → atlas-admin y atlas-audit (Tabla 36, DEC-18)"
sed -i '/# ATLAS-INICIO/,/# ATLAS-FIN/d' /etc/security/group.conf
{ echo "# ATLAS-INICIO"; grep -v '^#' "$DIR_ARCHIVOS/pam-group.conf"; echo "# ATLAS-FIN"; } >> /etc/security/group.conf
grep -q 'pam_group.so' /etc/pam.d/sshd || \
  sed -i '/^@include common-auth/a auth optional pam_group.so # ATLAS Tabla 36' /etc/pam.d/sshd

paso "Comprobación"
realm list
getent group "$AD_GRUPO_SOPORTE" || aviso "SSSD todavía no ve $AD_GRUPO_SOPORTE (esperar un minuto o revisar /var/log/sssd)."
paso "Listo. Siguiente: 10-samba.sh"
