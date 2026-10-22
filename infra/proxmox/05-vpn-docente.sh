#!/usr/bin/env bash
# =============================================================================
# ATLAS — Proxmox, paso 5 (OPCIONAL): VPN WireGuard para un docente remoto
#
# Se corre ADENTRO de router-lab (VM 110), después de 04-router-lab.sh.
# Diseño: fase-02/05 §4 (DEC-03, CT-08, Tabla 45). wg0 = 10.8.0.1/24, escucha en
# UDP 51820 por la WAN. Perfil docente = 10.8.0.128/25: SOLO llega a ATLAS por
# HTTPS (regla 9, ya está en el firewall). El origen no se traduce (VPN-09).
#
# La clave PRIVADA del docente se genera en su equipo (la app WireGuard de la
# notebook) y nunca llega acá: al script se le pasa solo la clave PÚBLICA.
#
# Uso:  sudo bash 05-vpn-docente.sh '<clave pública de la notebook>' [10.8.0.130]
# =============================================================================
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Correr con sudo."; exit 1; }
PUB=${1:?Falta la clave pública del docente (la muestra la app WireGuard de la notebook)}
IP_CLIENTE=${2:-10.8.0.130}
WAN=${WAN:-ens19}

[[ "$PUB" =~ ^[A-Za-z0-9+/]{42}[AEIMQUYcgkosw048]=$ ]] || { echo "Eso no parece una clave pública de WireGuard."; exit 1; }
[[ "$IP_CLIENTE" =~ ^10\.8\.0\.(1(29|[3-9][0-9])|2([0-4][0-9]|5[0-4]))$ ]] || {
  echo "La IP del docente tiene que estar entre 10.8.0.129 y 10.8.0.254 (Tabla 45)."; exit 1; }
nft list chain inet atlas forward >/dev/null 2>&1 || { echo "Primero correr 04-router-lab.sh."; exit 1; }

apt-get install -y -q wireguard-tools >/dev/null
umask 077
mkdir -p /etc/wireguard
[ -f /etc/wireguard/servidor.key ] || wg genkey > /etc/wireguard/servidor.key
wg pubkey < /etc/wireguard/servidor.key > /etc/wireguard/servidor.pub

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PostUp = wg set %i private-key /etc/wireguard/servidor.key

# Docente remoto (perfil docentes, Tabla 45)
[Peer]
PublicKey = $PUB
AllowedIPs = $IP_CLIENTE/32
EOF
systemctl enable wg-quick@wg0 >/dev/null 2>&1 || true
systemctl restart wg-quick@wg0

WAN_IP=$(ip -4 -br addr show "$WAN" | awk '{print $3}' | cut -d/ -f1)
echo
wg show wg0
cat <<EOF

Listo. En la app WireGuard de la notebook, el túnel queda así
(la línea PrivateKey la pone la app sola, NO la copies de ningún lado):

[Interface]
PrivateKey = (la que generó la app)
Address = $IP_CLIENTE/32

[Peer]
PublicKey = $(cat /etc/wireguard/servidor.pub)
AllowedIPs = 172.16.40.10/32
Endpoint = $WAN_IP:51820
EOF
