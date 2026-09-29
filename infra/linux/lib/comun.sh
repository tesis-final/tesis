#!/usr/bin/env bash
# =============================================================================
# ATLAS — funciones comunes de los scripts de atlas-srv01.
# Todos los scripts son idempotentes: se pueden correr más de una vez.
# =============================================================================
set -euo pipefail

DIR_LINUX="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DIR_ARCHIVOS="$DIR_LINUX/archivos"
# shellcheck source=../parametros.conf
source "${ATLAS_PARAMETROS:-$DIR_LINUX/parametros.conf}"

ROJO=$'\e[31m'; VERDE=$'\e[32m'; AMARILLO=$'\e[33m'; NORMAL=$'\e[0m'

paso()  { echo "${VERDE}==>${NORMAL} $*"; }
aviso() { echo "${AMARILLO}AVISO:${NORMAL} $*" >&2; }
error() { echo "${ROJO}ERROR:${NORMAL} $*" >&2; exit 1; }

requiere_root() {
  [ "$(id -u)" -eq 0 ] || error "Correr con sudo (se necesita root)."
}

# Copia un archivo de configuración guardando una copia de seguridad del
# original la primera vez (.atlas-orig) y deja dueño y modo indicados.
instalar_archivo() {
  local origen="$1" destino="$2" modo="${3:-644}" duenio="${4:-root:root}"
  if [ -f "$destino" ] && [ ! -f "$destino.atlas-orig" ]; then
    cp -a "$destino" "$destino.atlas-orig"
  fi
  install -D -m "$modo" -o "${duenio%%:*}" -g "${duenio##*:}" "$origen" "$destino"
}

# Reemplaza {{VARIABLE}} por el valor de la variable de entorno del mismo nombre.
renderizar() {
  local plantilla="$1" salida="$2" linea var
  : > "$salida"
  while IFS= read -r linea || [ -n "$linea" ]; do
    while [[ "$linea" =~ \{\{([A-Z0-9_]+)\}\} ]]; do
      var="${BASH_REMATCH[1]}"
      [ -n "${!var+x}" ] || error "Falta la variable $var para $plantilla"
      linea="${linea//\{\{$var\}\}/${!var}}"
    done
    printf '%s\n' "$linea" >> "$salida"
  done < "$plantilla"
}

interfaz_principal() {
  if [ -n "${ATLAS_IFACE:-}" ]; then echo "$ATLAS_IFACE"; return; fi
  ip -o link show | awk -F': ' '$2 ~ /^(en|eth)/ {print $2; exit}' | cut -d@ -f1
}

# systemctl solo si el equipo arrancó con systemd (en la VM siempre; en un
# contenedor de prueba no), para que los scripts se puedan probar en ambos.
svc() {
  if [ -d /run/systemd/system ]; then systemctl "$@"; else aviso "Sin systemd: se omite 'systemctl $*'"; fi
}
