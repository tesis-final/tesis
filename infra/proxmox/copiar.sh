#!/usr/bin/env bash
# =============================================================================
# ATLAS — Proxmox: copiar archivos de texto entre el Proxmox y una VM
#
# Usa el agente de QEMU (tiene que estar instalado y corriendo en la VM).
# Sirve para el pedido de certificado, los certificados y las evidencias de
# texto, sin abrir puertos nuevos en la red.
#
#   bash copiar.sh leer     <VMID> <ruta en la VM>  > archivo-local
#   bash copiar.sh escribir <VMID> <ruta en la VM> <archivo-local>
#
# Ejemplos:
#   bash copiar.sh leer 130 /srv/atlas/config/tls/atlas.csr > atlas.csr
#   bash copiar.sh escribir 120 'C:\ATLAS\atlas.csr' atlas.csr
# Solo para archivos de texto chicos (menos de 60 KB).
# =============================================================================
set -euo pipefail
NODO=$(hostname)
uso() { sed -n '9,15p' "$0"; exit 2; }
[ $# -ge 3 ] || uso
command -v jq >/dev/null || { apt-get update -q && apt-get install -y -q jq; }

case "$1" in
  leer)
    pvesh get "/nodes/$NODO/qemu/$2/agent/file-read" --file "$3" --output-format json | jq -r '.content' ;;
  escribir)
    [ $# -eq 4 ] && [ -f "$4" ] || uso
    pvesh create "/nodes/$NODO/qemu/$2/agent/file-write" --file "$3" --content "$(cat "$4")" >/dev/null
    echo "Copiado a $3 (VM $2)" >&2 ;;
  *) uso ;;
esac
