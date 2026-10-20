#!/usr/bin/env bash
# =============================================================================
# ATLAS — Proxmox, paso 1: las redes del laboratorio
#
# Crea en el Proxmox:
#   vmbr1      Un "switch virtual" con VLAN (hace de atlas-sw01). No tiene puerto
#              físico: lo que pasa por acá no sale del Proxmox. Cada VM se conecta
#              con su etiqueta de VLAN (20 Docentes, 40 Servidores, 50 Gestión).
#   vmbr1.50   El propio Proxmox con la IP 172.16.50.10 en la VLAN 50: es la
#              ESTACIÓN DE GESTIÓN (la única desde donde srv01 acepta SSH).
#              Para llegar al resto de 172.16.0.0/16 pasa por router-lab (.50.1).
#
# vmbr0 (el que crea el instalador de Proxmox, con la placa de red física) no
# se toca: es por donde entrás a la web de Proxmox y por donde hay Internet.
#
# Uso (en la consola del Proxmox, como root):  bash 01-redes.sh
# =============================================================================
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Correr como root."; exit 1; }
F=/etc/network/interfaces

if grep -q '^iface vmbr1 ' "$F"; then
  echo "vmbr1 ya existe en $F: no se toca nada."
else
  cp "$F" "$F.antes-de-atlas"
  cat >> "$F" <<'EOF'

# --- ATLAS: switch virtual con VLAN (como atlas-sw01). Sin puerto físico. ---
auto vmbr1
iface vmbr1 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094

# --- ATLAS: el Proxmox es la estación de gestión (VLAN 50) ---
auto vmbr1.50
iface vmbr1.50 inet static
    address 172.16.50.10/24
    post-up ip route add 172.16.0.0/16 via 172.16.50.1 || true
    pre-down ip route del 172.16.0.0/16 via 172.16.50.1 || true
EOF
  echo "Copia de seguridad: $F.antes-de-atlas"
fi

ifreload -a
echo
ip -br addr show vmbr1 || true
ip -br addr show vmbr1.50 || true
ip route show 172.16.0.0/16 || true
echo "Listo. En la web de Proxmox (Sistema -> Red) tienen que aparecer vmbr1 y vmbr1.50."
