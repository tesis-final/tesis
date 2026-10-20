#!/usr/bin/env bash
# =============================================================================
# ATLAS — Proxmox, paso 2: el repositorio como un CD (ISO)
#
# Las VM Windows no tienen Internet ni "arrastrar y soltar" en Proxmox. La forma
# más simple de pasarles los scripts es un CD virtual con el repositorio: se
# arma acá y se "inserta" en la VM (el script 03 ya lo deja puesto).
#
# Uso (como root):  bash 02-iso-repo.sh
# Volver a correrlo cada vez que cambie el repo (baja la última versión).
# =============================================================================
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Correr como root."; exit 1; }
REPO_URL=${REPO_URL:-https://github.com/tesis-final/tesis}
DIR=/root/tesis
ISO=/var/lib/vz/template/iso/atlas-repo.iso

command -v git >/dev/null && command -v genisoimage >/dev/null || {
  apt-get update -q && apt-get install -y -q git genisoimage jq; }

if [ -d "$DIR/.git" ]; then git -C "$DIR" pull -q; else git clone -q "$REPO_URL" "$DIR"; fi
genisoimage -quiet -J -r -joliet-long -V ATLAS -m .git -o "$ISO" "$DIR"
ls -lh "$ISO"
echo "Listo: en las VM Windows aparece como un CD llamado ATLAS."
