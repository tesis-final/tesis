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

# Hito 3: instalador del agente de Zabbix para atlas-dc01 (14-agente-zabbix.ps1). Proxmox
# tiene Internet y el DC no: se baja acá y viaja en el CD, en extras\ (fuera de Git).
ZABBIX_VERSION=${ZABBIX_VERSION:-7.0.32}
MSI="zabbix_agent2-${ZABBIX_VERSION}-windows-amd64-openssl.msi"
ZABBIX_MSI_URL=${ZABBIX_MSI_URL:-https://cdn.zabbix.com/zabbix/binaries/stable/${ZABBIX_VERSION%.*}/${ZABBIX_VERSION}/$MSI}
mkdir -p "$DIR/extras"
if [ ! -s "$DIR/extras/$MSI" ]; then
  curl -fsSL -o "$DIR/extras/$MSI.part" "$ZABBIX_MSI_URL" && mv "$DIR/extras/$MSI.part" "$DIR/extras/$MSI" \
    || { rm -f "$DIR/extras/$MSI.part"; echo "AVISO: no se pudo bajar $ZABBIX_MSI_URL. Bajarlo de https://www.zabbix.com/download_agents (Windows, agente 2, 7.0 LTS, MSI) y dejarlo en $DIR/extras/."; }
fi
ls -l "$DIR/extras/" 2>/dev/null | tail -n +2

genisoimage -quiet -J -r -joliet-long -V ATLAS -m .git -o "$ISO" "$DIR"
ls -lh "$ISO"
echo "Listo: en las VM Windows aparece como un CD llamado ATLAS (el MSI del agente, en extras\\)."
