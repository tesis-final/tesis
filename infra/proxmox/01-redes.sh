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
# Opcional, WAN_INTERNA=si: crea además vmbr2 (10.99.0.1/24), un bridge SIN placa
# física con NAT de Proxmox hacia vmbr0, para enchufar ahí la WAN de router-lab.
# Hace falta cuando la placa física de Proxmox es un adaptador USB que corta el
# enlace si ve la MAC de una VM, o cuando nadie da DHCP en la red de afuera. Es lo
# que se armó a mano en el laboratorio del Hito 2 (incidencias del 22/10 22:14 y
# 22:39). Después: qm set 110 --net1 virtio,bridge=vmbr2 y, en router-lab,
#   sudo WAN_IP=10.99.0.2/24 WAN_GW=10.99.0.1 bash 04-router-lab.sh
#
# Uso (en la consola del Proxmox, como root):  bash 01-redes.sh
#                                    o bien:   WAN_INTERNA=si bash 01-redes.sh
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

if [ "${WAN_INTERNA:-no}" = si ]; then
  if grep -q '^iface vmbr2 ' "$F"; then
    echo "vmbr2 ya existe en $F: no se toca."
  else
    [ -f "$F.antes-de-atlas" ] || cp "$F" "$F.antes-de-atlas"
    cat >> "$F" <<'EOF'

# --- ATLAS: "Internet" de router-lab sin pasar por la placa física (NAT de Proxmox) ---
auto vmbr2
iface vmbr2 inet static
    address 10.99.0.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    post-up   echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up   iptables -t nat -A POSTROUTING -s 10.99.0.0/24 -o vmbr0 -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s 10.99.0.0/24 -o vmbr0 -j MASQUERADE
EOF
  fi
fi

ifreload -a
echo
ip -br addr show vmbr1 || true
ip -br addr show vmbr1.50 || true
ip route show 172.16.0.0/16 || true
ip -br addr show vmbr2 2>/dev/null || true
echo "Listo. En la web de Proxmox (Sistema -> Red) tienen que aparecer vmbr1 y vmbr1.50."
