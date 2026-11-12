#!/usr/bin/env bash
# =============================================================================
# ATLAS · Fase 6 — Paso 13: respaldos automáticos (§28.5, Tablas 28 y 29; RNF-04, RNF-05)
#
# Instala /usr/local/sbin/atlas-respaldo y sus temporizadores de systemd:
#   completo      domingos 02:00          (4 semanas, local + Windows)
#   incremental   lunes a sábado 02:00    (7 días, local + Windows, DEC-09)
#   config        cuando cambia /srv/atlas/config (10 versiones, local + Windows)
#   verificar     todos los días 03:30    (huellas y frecuencia)
#   prueba        día 1 de cada mes 04:00 (restauración en una base aparte)
# La copia externa va a \\atlas-dc01\atlas-backups con svc_atlas_backup (crear sí, borrar no:
# CT-05). Su contraseña la muestra la Etapa 3 del DC; acá se escribe una sola vez, sin eco,
# en /etc/atlas/respaldo-smb.cred (root, modo 600). Nunca va al repositorio.
#
# Uso: sudo ./13-respaldos.sh            (pide la contraseña de svc_atlas_backup si falta)
#      SIN_COPIA_WINDOWS=si sudo ./13-respaldos.sh   (solo respaldos locales, por ahora)
# Requiere los pasos 2, 3 y 7 (usuarios, carpetas y ATLAS corriendo).
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
CRED=/etc/atlas/respaldo-smb.cred

paso "Herramientas (smbclient para la copia al DC)"
if ! command -v smbclient >/dev/null; then
  apt-get install -y -q smbclient >/dev/null 2>&1 || aviso "No se pudo instalar smbclient (¿sin Internet?). La copia a Windows queda pendiente."
fi

paso "atlas-respaldo en /usr/local/sbin (de root; nadie más lo puede editar, como atlas-ctl)"
install -m 750 -o root -g root "$DIR_ARCHIVOS/atlas-respaldo" /usr/local/sbin/atlas-respaldo

paso "Carpeta de respaldos: $ATLAS_ROOT/backups (atlasbkp:atlas-backup 700, Tabla 27)"
install -d -m 700 -o atlasbkp -g atlas-backup "$ATLAS_ROOT/backups"
for d in completo incremental config; do install -d -m 700 -o atlasbkp -g atlas-backup "$ATLAS_ROOT/backups/$d"; done

if [ "${SIN_COPIA_WINDOWS:-no}" != si ] && [ ! -f "$CRED" ]; then
  if [ -t 0 ]; then
    paso "Credencial de svc_atlas_backup para \\\\atlas-dc01\\atlas-backups"
    read -r -s -p "Contraseña de ATLAS\\svc_atlas_backup (no se muestra): " CLAVE; echo
    [ -n "$CLAVE" ] || error "La contraseña está vacía."
    install -d -m 700 -o root -g root /etc/atlas
    ( umask 077; printf 'username = svc_atlas_backup\npassword = %s\ndomain = %s\n' "$CLAVE" "${AD_NETBIOS:-ATLAS}" > "$CRED" )
    unset CLAVE
    chmod 600 "$CRED"
  else
    aviso "Sin terminal para pedir la contraseña: la copia a Windows queda pendiente (volver a correr este paso)."
  fi
fi

paso "Temporizadores de systemd"
for u in "$DIR_ARCHIVOS"/respaldo/atlas-respaldo-*; do
  install -m 644 -o root -g root "$u" "/etc/systemd/system/$(basename "$u")"
done
systemctl daemon-reload
systemctl enable --now atlas-respaldo-completo.timer atlas-respaldo-incremental.timer \
  atlas-respaldo-verificar.timer atlas-respaldo-prueba.timer atlas-respaldo-config.path >/dev/null

paso "Primer respaldo completo, copia de la configuración y verificación"
/usr/local/sbin/atlas-respaldo completo
/usr/local/sbin/atlas-respaldo config || true
/usr/local/sbin/atlas-respaldo verificar || aviso "La verificación informó problemas (ver arriba)."
systemctl list-timers 'atlas-respaldo*' --no-pager || true
echo "==> Listo. Estado en cualquier momento: sudo atlas-respaldo estado"
