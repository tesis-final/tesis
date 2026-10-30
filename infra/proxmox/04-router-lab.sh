#!/usr/bin/env bash
# =============================================================================
# ATLAS — Proxmox, paso 4: router-lab = atlas-rt01 + atlas-fw01 en una VM Linux
#
# Se corre ADENTRO de la VM 110 (Ubuntu Server 24.04), no en el Proxmox.
#
# Qué hace (todo en Linux, sin Packet Tracer):
#   1. "Router en un palo" (router-on-a-stick), igual que atlas-rt01: UNA placa
#      troncal hacia el switch virtual vmbr1 y una subinterfaz por VLAN, cada una
#      con la puerta de enlace .1 (Tabla 38):
#         ens18.10 172.16.10.1  Administración     ens18.40 172.16.40.1  Servidores
#         ens18.20 172.16.20.1  Docentes           ens18.50 172.16.50.1  Gestión
#         ens18.30 172.16.30.1  Estudiantes
#      La VLAN 999 (nativa) no tiene IP: lo que llega sin etiqueta no se enruta.
#   2. Reenvío de DHCP hacia el DC 172.16.40.20 (= "ip helper-address").
#   3. Firewall CON ESTADO con nftables: la Tabla 44 en orden (R1..R12) + M2 de
#      la tabla del profesor (SSH al servidor desde la LAN: denegado). Lo que no
#      está permitido se descarta y queda registrado ("ATLAS-R10", "ATLAS-R12"...).
#      Es el diseño de atlas-fw01 (fase-02/05 §4) más la política por zonas de
#      atlas-rt01 (§3), juntos en un equipo.
#   4. NAT de salida (masquerade): las VLAN salen a Internet con la IP del
#      router-lab en la red de tu casa/liceo (vmbr0). No hay NAT de entrada
#      (ningún servidor queda publicado hacia afuera, §30.3).
#
# Placas de la VM (las crea 03-crear-vms.sh):
#   net0 -> ens18  troncal 802.1Q en vmbr1 (VLAN 10, 20, 30, 40, 50)
#   net1 -> ens19  vmbr0: la red de tu casa/liceo = "Internet" (WAN)
#
# Uso:   sudo bash 04-router-lab.sh
#        Otras placas:  sudo TRONCAL=ens18 WAN=ens19 bash 04-router-lab.sh
#        WAN fija (cuando nadie da DHCP en la red de afuera, como en el
#        laboratorio del Hito 2 con vmbr2 10.99.0.0/24):
#          sudo WAN_IP=10.99.0.2/24 WAN_GW=10.99.0.1 bash 04-router-lab.sh
#        Sin WAN_IP la WAN pide dirección por DHCP.
# Ver lo bloqueado:     sudo journalctl -k -f | grep ATLAS-
# Ver los contadores:   sudo nft list ruleset
# =============================================================================
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Correr con sudo."; exit 1; }

TRONCAL=${TRONCAL:-ens18}; WAN=${WAN:-ens19}
DC=172.16.40.20; SRV=172.16.40.10
NFT=${NFT:-/etc/nftables.conf}

for i in "$TRONCAL" "$WAN"; do
  ip link show "$i" >/dev/null 2>&1 || {
    echo "No existe la interfaz $i. Mirá los nombres con: ip -br link"; exit 1; }
done
V10=$TRONCAL.10; V20=$TRONCAL.20; V30=$TRONCAL.30; V40=$TRONCAL.40; V50=$TRONCAL.50

# WAN por DHCP o fija. En el laboratorio nadie daba DHCP afuera y hubo que
# copiar el script a mano para fijarla (Hito 2 de Redes, incidencia 22/10 22:47).
WAN_IP=${WAN_IP:-}; WAN_GW=${WAN_GW:-}; WAN_DNS=${WAN_DNS:-1.1.1.1}
if [ -n "$WAN_IP" ]; then
  [[ "$WAN_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]] || { echo "WAN_IP tiene que ser como 10.99.0.2/24"; exit 1; }
  [[ "$WAN_GW" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "Con WAN_IP hace falta WAN_GW (ej. 10.99.0.1)"; exit 1; }
  WAN_NETPLAN="{addresses: [$WAN_IP], routes: [{to: default, via: $WAN_GW}], nameservers: {addresses: [$WAN_DNS]}}"
else
  WAN_NETPLAN="{dhcp4: true}"
fi

echo "→ 1/5 Subinterfaces de VLAN y salida a Internet (netplan)"
mkdir -p /etc/cloud/cloud.cfg.d
echo 'network: {config: disabled}' > /etc/cloud/cloud.cfg.d/99-atlas-sin-red.cfg
rm -f /etc/netplan/50-cloud-init.yaml
# Cualquier otro netplan (por ejemplo uno armado a mano para la WAN) definiría la
# misma placa dos veces: se guarda aparte y queda solo el de este script. En el
# laboratorio hubo que borrar a mano un 60-wan.yaml (Hito 2 de Redes, 6.4).
for f in /etc/netplan/*.yaml; do
  [ -e "$f" ] && [ "$f" != /etc/netplan/60-atlas-router.yaml ] && mv "$f" "$f.antes-de-atlas"
done
cat > /etc/netplan/60-atlas-router.yaml <<EOF
network:
  version: 2
  ethernets:
    $TRONCAL: {}
    $WAN: $WAN_NETPLAN
  vlans:
    $V10: {id: 10, link: $TRONCAL, addresses: [172.16.10.1/24]}
    $V20: {id: 20, link: $TRONCAL, addresses: [172.16.20.1/24]}
    $V30: {id: 30, link: $TRONCAL, addresses: [172.16.30.1/24]}
    $V40: {id: 40, link: $TRONCAL, addresses: [172.16.40.1/24]}
    $V50: {id: 50, link: $TRONCAL, addresses: [172.16.50.1/24]}
EOF
chmod 600 /etc/netplan/60-atlas-router.yaml
netplan apply
sleep 3

echo "→ 2/5 Reenvío de paquetes entre redes"
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/60-atlas-router.conf
sysctl -q --system

echo "→ 3/5 Paquetes: reenvío de DHCP, nftables y agente de QEMU"
export DEBIAN_FRONTEND=noninteractive
echo "isc-dhcp-relay isc-dhcp-relay/servers string $DC" | debconf-set-selections
echo "isc-dhcp-relay isc-dhcp-relay/interfaces string $V10 $V20 $V30 $V40" | debconf-set-selections
echo "isc-dhcp-relay isc-dhcp-relay/options string" | debconf-set-selections
apt-get update -q
apt-get install -y -q isc-dhcp-relay nftables qemu-guest-agent
cat > /etc/default/isc-dhcp-relay <<EOF
SERVERS="$DC"
INTERFACES="$V10 $V20 $V30 $V40"
OPTIONS=""
EOF
systemctl enable isc-dhcp-relay qemu-guest-agent >/dev/null 2>&1 || true
systemctl restart isc-dhcp-relay || true
systemctl start qemu-guest-agent || true
# UFW y nftables a la vez se pisan: en este equipo manda nftables.
ufw disable >/dev/null 2>&1 || true

echo "→ 4/5 Firewall (Tabla 44) y NAT: $NFT"
cat > "$NFT" <<EOF
#!/usr/sbin/nft -f
# ATLAS router-lab — generado por infra/proxmox/04-router-lab.sh. No editar a mano.
flush ruleset

define V10 = "$V10"
define V20 = "$V20"
define V30 = "$V30"
define V40 = "$V40"
define V50 = "$V50"
define WAN = "$WAN"
define SRV = $SRV
define DC  = $DC
define INTERNAS = 172.16.0.0/16

table inet atlas {
  # Servicios de dominio hacia el DC (regla 2, DEC-17)
  set dominio_tcp { type inet_service; flags interval
    elements = { 53, 88, 135, 389, 445, 464, 636, 3268-3269, 49152-65535 } }
  set dominio_udp { type inet_service
    elements = { 53, 88, 123, 389, 464 } }

  # Tráfico dirigido AL router-lab
  chain input {
    type filter hook input priority filter; policy drop;
    ct state established,related accept
    ct state invalid drop
    iif lo accept
    # R4: reenvío de DHCP (pedidos de los clientes y respuestas del DC)
    iifname { \$V10, \$V20, \$V30 } udp dport 67 accept
    iifname \$V40 ip saddr \$DC udp sport 67 udp dport 67 accept
    # Gestión del router solo desde la VLAN 50 (PDF p. 67): SSH y ping
    iifname \$V50 ip saddr 172.16.50.0/24 tcp dport 22 accept
    iifname \$V50 ip saddr 172.16.50.0/24 icmp type echo-request accept
    # VPN WireGuard (opcional, router-vpn.sh) por la WAN
    iifname \$WAN udp dport 51820 accept
    limit rate 10/second log prefix "ATLAS-IN-DROP " level info
  }

  # Tráfico que ATRAVIESA el router-lab (de una red a otra): la Tabla 44, en orden
  chain forward {
    type filter hook forward priority filter; policy drop;
    ct state established,related accept
    ct state invalid drop
    # R10: MySQL nunca, desde ningún lado
    ip daddr \$SRV tcp dport 3306 log prefix "ATLAS-R10 " level info drop
    # M2 (tabla del profesor): SSH al servidor desde las LAN de usuarios, no
    iifname { \$V10, \$V20, \$V30 } ip daddr \$SRV tcp dport 22 log prefix "ATLAS-M2 " level info drop
    # R11: Estudiantes hacia Administración, Docentes y Gestión: negado
    iifname \$V30 oifname { \$V10, \$V20, \$V50 } log prefix "ATLAS-R11 " level info drop
    # R1: HTTPS a ATLAS desde Administración, Docentes y Estudiantes
    iifname { \$V10, \$V20, \$V30 } ip daddr \$SRV tcp dport 443 accept
    # R2: servicios de dominio al DC
    iifname { \$V10, \$V20, \$V30 } ip daddr \$DC tcp dport @dominio_tcp accept
    iifname { \$V10, \$V20, \$V30 } ip daddr \$DC udp dport @dominio_udp accept
    # R3: carpetas compartidas (SMB) de srv01, solo Administración y Docentes
    iifname { \$V10, \$V20 } ip daddr \$SRV tcp dport 445 accept
    # R5: navegar (80/443) hacia fuera de 172.16.0.0/16
    iifname { \$V10, \$V20, \$V30, \$V50 } oifname \$WAN ip daddr != \$INTERNAS tcp dport { 80, 443 } accept
    # R6: Gestión administra todo por SSH y escritorio remoto
    iifname \$V50 oifname { \$V10, \$V20, \$V30, \$V40 } tcp dport { 22, 3389 } accept
    # R7: servidores a Internet (actualizaciones); DNS hacia afuera solo el DC
    iifname \$V40 oifname \$WAN ip saddr 172.16.40.0/24 tcp dport { 80, 443 } accept
    iifname \$V40 oifname \$WAN ip saddr \$DC meta l4proto { tcp, udp } th dport 53 accept
    # R8: VPN de administradores hacia Gestión  ·  R9: VPN de docentes hacia ATLAS
    iifname "wg0" ip saddr 10.8.0.0/25 oifname \$V50 accept
    iifname "wg0" ip saddr 10.8.0.128/25 ip daddr \$SRV tcp dport 443 accept
    # R12: todo lo demás, negado y registrado
    log prefix "ATLAS-R12 " level info drop
  }

  chain output {
    type filter hook output priority filter; policy accept;
  }
}

# NAT de salida: solo las redes internas, solo hacia la WAN. La VPN no se
# traduce (VPN-09) y no hay NAT de entrada (§30.3).
table ip atlas_nat {
  chain postrouting {
    type nat hook postrouting priority srcnat; policy accept;
    oifname \$WAN ip saddr \$INTERNAS masquerade
  }
}
EOF
nft -c -f "$NFT"
nft -f "$NFT"
systemctl enable nftables >/dev/null 2>&1 || true

echo "→ 5/5 Hora del router desde el DC (Tabla 35)"
mkdir -p /etc/systemd/timesyncd.conf.d
printf '[Time]\nNTP=%s\n' "$DC" > /etc/systemd/timesyncd.conf.d/atlas.conf
systemctl restart systemd-timesyncd 2>/dev/null || true

echo
ip -br addr show | grep -E "^($TRONCAL|$WAN)" || true
echo "ip_forward = $(cat /proc/sys/net/ipv4/ip_forward)"
echo "Firewall: $(nft list chain inet atlas forward | grep -c 'accept\|drop') reglas en forward"
systemctl is-active isc-dhcp-relay >/dev/null && echo "Relay DHCP: activo" \
  || echo "Relay DHCP: todavía NO activo (es normal hasta que exista el DC; después: sudo systemctl restart isc-dhcp-relay)"
echo
echo "Listo. router-lab es la puerta de enlace de las 5 VLAN, filtra con la Tabla 44 y hace NAT."
