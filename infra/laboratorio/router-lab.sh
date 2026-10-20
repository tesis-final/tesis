#!/usr/bin/env bash
# =============================================================================
# ATLAS — Router de laboratorio para VirtualBox (Hito 2)
#
# Qué es: una VM Ubuntu Server 24.04 chiquita que hace de atlas-rt01 entre las
# redes internas de VirtualBox, para que las VM se comporten como en la red real
# (cada VLAN con su puerta de enlace .1 y el DHCP reenviado al DC).
#
# NO filtra nada: el filtrado lo hacen los firewalls de cada servidor (UFW en
# srv01, Windows Defender en dc01), que es justamente lo que se quiere probar.
# El filtrado entre VLAN de la Tabla 44 se demuestra en Packet Tracer (Fase 9).
#
# Adaptadores de la VM (en este orden, en VirtualBox):
#   1  enp0s3   Red interna  atlas-vlan20   -> 172.16.20.1/24 (Docentes)
#   2  enp0s8   Red interna  atlas-vlan40   -> 172.16.40.1/24 (Servidores)
#   3  enp0s9   Solo anfitrión (gestión)    -> 172.16.50.1/24 (tu PC = .10)
#   4  enp0s10  NAT (solo para instalar paquetes; después se desconecta)
#
# Uso:  sudo bash router-lab.sh
# =============================================================================
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Correr con sudo."; exit 1; }

V20=${V20:-enp0s3}; V40=${V40:-enp0s8}; GES=${GES:-enp0s9}; NAT=${NAT:-enp0s10}
DC=172.16.40.20

for i in "$V20" "$V40" "$GES"; do
  ip link show "$i" >/dev/null 2>&1 || {
    echo "No existe la interfaz $i. Revisá los adaptadores de la VM (ip -br link)."; exit 1; }
done

echo "→ 1/4 Direcciones fijas (netplan)"
mkdir -p /etc/cloud/cloud.cfg.d
echo 'network: {config: disabled}' > /etc/cloud/cloud.cfg.d/99-atlas-sin-red.cfg
rm -f /etc/netplan/50-cloud-init.yaml
cat > /etc/netplan/60-atlas-router.yaml <<EOF
network:
  version: 2
  ethernets:
    $V20:
      addresses: [172.16.20.1/24]
    $V40:
      addresses: [172.16.40.1/24]
    $GES:
      addresses: [172.16.50.1/24]
    $NAT:
      dhcp4: true
      optional: true
EOF
chmod 600 /etc/netplan/60-atlas-router.yaml
netplan apply

echo "→ 2/4 Reenvío de paquetes entre redes"
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/60-atlas-router.conf
sysctl -q --system

echo "→ 3/4 Reenvío de DHCP hacia el DC ($DC)"
export DEBIAN_FRONTEND=noninteractive
echo "isc-dhcp-relay isc-dhcp-relay/servers string $DC" | debconf-set-selections
echo "isc-dhcp-relay isc-dhcp-relay/interfaces string $V20 $V40" | debconf-set-selections
echo "isc-dhcp-relay isc-dhcp-relay/options string" | debconf-set-selections
apt-get update -q
apt-get install -y -q isc-dhcp-relay
cat > /etc/default/isc-dhcp-relay <<EOF
SERVERS="$DC"
INTERFACES="$V20 $V40"
OPTIONS=""
EOF
systemctl enable isc-dhcp-relay >/dev/null 2>&1 || true
systemctl restart isc-dhcp-relay

echo "→ 4/4 Sin firewall en este equipo (es solo un router de laboratorio)"
ufw disable >/dev/null 2>&1 || true

echo
ip -br addr show "$V20" "$V40" "$GES"
echo "ip_forward = $(cat /proc/sys/net/ipv4/ip_forward)"
systemctl is-active isc-dhcp-relay >/dev/null && echo "Relay DHCP: activo" || echo "Relay DHCP: NO activo (revisar con: journalctl -u isc-dhcp-relay)"
echo
echo "Listo. Ahora apagá la VM y desmarcá 'Cable conectado' en el adaptador 4 (NAT)."
