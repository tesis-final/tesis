#!/usr/bin/env bash
# =============================================================================
# ATLAS · Fase 6 · Paso 2 — Grupos y usuarios técnicos (PDF Tabla 25 y Tabla 26)
#
#   Grupo          GID    Usuario     UID    Shell
#   atlas-admin    5001   atlasadmin  5001   /bin/bash
#   atlas-web      5002   atlasweb    5002   /usr/sbin/nologin
#   atlas-db       5003   atlasdb     5003   /usr/sbin/nologin
#   atlas-backup   5004   atlasbkp    5004   /usr/sbin/nologin
#   atlas-audit    5005   (sin usuario local; miembros: GG_SoporteTI por SSSD, DEC-18)
#
# Son cuentas de servicio, no de personas (§28.2). Los usuarios de ATLAS
# (docentes, estudiantes) viven en la base de datos y NO tienen cuenta acá.
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

crear_grupo() {  # nombre gid
  if getent group "$1" >/dev/null; then
    [ "$(getent group "$1" | cut -d: -f3)" = "$2" ] || error "El grupo $1 existe con otro GID (se esperaba $2)."
  else
    getent group "$2" >/dev/null && error "El GID $2 ya lo usa $(getent group "$2" | cut -d: -f1)."
    groupadd --gid "$2" "$1"
  fi
}

crear_usuario() {  # nombre uid grupo shell
  if id "$1" >/dev/null 2>&1; then
    [ "$(id -u "$1")" = "$2" ] || error "El usuario $1 existe con otro UID (se esperaba $2)."
    usermod --gid "$3" --shell "$4" "$1"
  else
    getent passwd "$2" >/dev/null && error "El UID $2 ya lo usa $(getent passwd "$2" | cut -d: -f1)."
    if [ "$4" = /bin/bash ]; then
      useradd --uid "$2" --gid "$3" --shell "$4" --create-home "$1"
    else
      # Cuenta de servicio: sin home real y sin shell (§28.2: "no se pueden usar para entrar").
      useradd --system --uid "$2" --gid "$3" --shell "$4" --home-dir /nonexistent --no-create-home "$1"
    fi
  fi
  # Sin contraseña utilizable: el acceso es solo con clave pública (§28.4).
  passwd -l "$1" >/dev/null
}

paso "Grupos (Tabla 25)"
crear_grupo atlas-admin  5001
crear_grupo atlas-web    5002
crear_grupo atlas-db     5003
crear_grupo atlas-backup 5004
crear_grupo atlas-audit  5005

paso "Usuarios (Tabla 26)"
crear_usuario atlasadmin 5001 atlas-admin  /bin/bash
crear_usuario atlasweb   5002 atlas-web    /usr/sbin/nologin
crear_usuario atlasdb    5003 atlas-db     /usr/sbin/nologin
crear_usuario atlasbkp   5004 atlas-backup /usr/sbin/nologin

paso "Clave pública de atlasadmin (acceso de emergencia, DEC-07)"
install -d -m 700 -o atlasadmin -g atlas-admin /home/atlasadmin/.ssh
if [ -f "$ATLAS_CLAVE_PUBLICA_ADMIN" ]; then
  grep -qE '^(ssh-ed25519|ecdsa-sha2-|ssh-rsa) ' "$ATLAS_CLAVE_PUBLICA_ADMIN" || error "$ATLAS_CLAVE_PUBLICA_ADMIN no parece una clave pública SSH."
  install -m 600 -o atlasadmin -g atlas-admin "$ATLAS_CLAVE_PUBLICA_ADMIN" /home/atlasadmin/.ssh/authorized_keys
else
  aviso "No existe $ATLAS_CLAVE_PUBLICA_ADMIN. Sin esa clave, el paso 4 (SSH) se niega a continuar para no dejarte afuera."
fi

paso "Listo. Siguiente: 03-directorios-permisos.sh"
