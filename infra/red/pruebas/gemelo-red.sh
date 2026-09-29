#!/usr/bin/env bash
# =============================================================================
# ATLAS · Fase 8 — "Gemelo de red": la topología de la Figura 1 recreada con
# espacios de red de Linux, para probar que el DISEÑO funciona antes del laboratorio.
#
#   Qué representa cada pieza:
#     sw01   un bridge por VLAN = atlas-sw01 (Tabla 41: accesos por VLAN, Fa0/24
#            apagado en VLAN 999, gestión en VLAN 50). Cada VLAN es un dominio de
#            difusión separado, que es exactamente lo que hace una VLAN.
#     rt01   una interfaz por VLAN = las subinterfaces Gi0/0.10….50 (Tabla 38) +
#            reenvío DHCP (dhcrelay, equivalente a "ip helper-address 172.16.40.20").
#            La VLAN 999 no tiene interfaz en el router (nativa sin servicio).
#     dc01   servidor DHCP/DNS con los 3 ámbitos de la Tabla 34 (dnsmasq en lugar de Windows)
#     srv01  172.16.40.10 (Tabla 40)
#     fw01   maqueta del firewall + "Internet simulada" 203.0.113.0/24 (RFC 5737)
#     PCs    adm1 (Fa0/1), doc1 (Fa0/5), est1 (Fa0/11), est2 (Fa0/12), gest (Fa0/23),
#            intruso (Fa0/24, puerto sin uso)
#
#   Qué NO es: no es Cisco IOS. Valida direccionamiento, separación en VLAN,
#   enrutamiento, reenvío DHCP y aislamiento de capa 2. El ETIQUETADO 802.1Q del
#   troncal no se emula: el kernel de este entorno no tiene el módulo 8021q
#   (CONFIG_VLAN_8021Q no está). El troncal se valida en Packet Tracer
#   ("show interfaces trunk") y su configuración, con revisar_configuraciones.py.
#   Esta es la etapa de la Fase 8: todavía SIN filtrado entre VLAN (llega en la Fase 9).
#
# Uso (en un contenedor privilegiado con la imagen de infra/linux/pruebas):
#   docker run --rm --privileged -v "$PWD/infra/red:/red:ro" atlas-ubuntu-test:24.04 bash /red/pruebas/gemelo-red.sh
# =============================================================================
set -uo pipefail
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  PASS  $1"; }
mal() { FAIL=$((FAIL+1)); echo "  FAIL  $1${2:+  →  $2}"; }
t()   { printf '\n── %s ──\n' "$*"; }
en()  { ip netns exec "$@"; }

t "Armado de la topología"
for ns in sw01 rt01 fw01 internet dc01 srv01 adm1 doc1 est1 est2 gest intruso; do ip netns add "$ns"; en "$ns" ip link set lo up; done

# --- atlas-sw01: un dominio de difusión por VLAN --------------------------------
for v in 10 20 30 40 50 999; do
  en sw01 ip link add "vlan$v" type bridge
  en sw01 ip link set "vlan$v" up
done

# puerto_acceso <nombre-puerto> <equipo> <vlan>
puerto_acceso() {
  ip link add "$1" netns sw01 type veth peer name eth0 netns "$2"
  en sw01 ip link set "$1" master "vlan$3" up
  en "$2" ip link set eth0 up
}
puerto_acceso fa0_1  adm1    10
puerto_acceso fa0_5  doc1    20
puerto_acceso fa0_11 est1    30
puerto_acceso fa0_12 est2    30
puerto_acceso fa0_21 srv01   40
puerto_acceso fa0_22 dc01    40
puerto_acceso fa0_23 gest    50
puerto_acceso fa0_24 intruso 999
en sw01 ip link set fa0_24 down        # Tabla 41: Fa0/24 deshabilitado

# Troncal Gi0/1 ↔ rt01 Gi0/0: un enlace lógico por cada VLAN permitida (10–50).
# La VLAN 999 NO llega al router (nativa, sin subinterfaz con IP).
for v in 10 20 30 40 50; do
  ip link add "gi0_1.$v" netns sw01 type veth peer name "gi00.$v" netns rt01
  en sw01 ip link set "gi0_1.$v" master "vlan$v" up
done

# Gestión del switch: interfaz de VLAN 50 con 172.16.50.2 (propuesto), gateway 172.16.50.1.
en sw01 ip addr add 172.16.50.2/24 dev vlan50
en sw01 ip route add default via 172.16.50.1

# --- atlas-rt01: subinterfaces (Tabla 38) --------------------------------------
for v in 10 20 30 40 50; do
  en rt01 ip addr add "172.16.$v.1/24" dev "gi00.$v"
  en rt01 ip link set "gi00.$v" up
done
ip link add gi01 netns rt01 type veth peer name gi00 netns fw01
en rt01 ip addr add 172.16.255.1/30 dev gi01; en rt01 ip link set gi01 up
en rt01 ip route add default via 172.16.255.2
en rt01 sysctl -qw net.ipv4.ip_forward=1

# --- maqueta de atlas-fw01 + Internet simulada ---------------------------------
en fw01 ip addr add 172.16.255.2/30 dev gi00; en fw01 ip link set gi00 up
ip link add gi01 netns fw01 type veth peer name eth0 netns internet
en fw01 ip addr add 203.0.113.1/24 dev gi01; en fw01 ip link set gi01 up
en fw01 ip route add 172.16.0.0/16 via 172.16.255.1
en fw01 sysctl -qw net.ipv4.ip_forward=1
en internet ip addr add 203.0.113.10/24 dev eth0; en internet ip link set eth0 up
en internet ip route add default via 203.0.113.1

# --- Servidores con IP fija (Tabla 40) -----------------------------------------
en srv01 ip addr add 172.16.40.10/24 dev eth0; en srv01 ip route add default via 172.16.40.1
en dc01  ip addr add 172.16.40.20/24 dev eth0; en dc01  ip route add default via 172.16.40.1
en gest  ip addr add 172.16.50.10/24 dev eth0; en gest  ip route add default via 172.16.50.1

# --- DHCP y DNS en dc01 (Tabla 34, §29.4) --------------------------------------
cat > /tmp/dnsmasq-dc01.conf <<'CONF'
listen-address=172.16.40.20
bind-interfaces
no-resolv
domain=atlas.local
host-record=atlas-srv01.atlas.local,172.16.40.10
host-record=atlas-dc01.atlas.local,172.16.40.20
dhcp-authoritative
dhcp-leasefile=/tmp/dc01.leases
log-dhcp
dhcp-range=set:v10,172.16.10.100,172.16.10.200,255.255.255.0,8h
dhcp-range=set:v20,172.16.20.100,172.16.20.200,255.255.255.0,8h
dhcp-range=set:v30,172.16.30.100,172.16.30.250,255.255.255.0,8h
dhcp-option=tag:v10,option:router,172.16.10.1
dhcp-option=tag:v20,option:router,172.16.20.1
dhcp-option=tag:v30,option:router,172.16.30.1
dhcp-option=option:dns-server,172.16.40.20
dhcp-option=option:domain-name,atlas.local
CONF
en dc01 dnsmasq --conf-file=/tmp/dnsmasq-dc01.conf --log-facility=/tmp/dc01.log --pid-file=/tmp/dc01.pid
# "ip helper-address 172.16.40.20" en .10, .20 y .30 (regla 4); arriba, la subinterfaz .40.
en rt01 dhcrelay -4 -q -pf /tmp/relay.pid -iu gi00.40 -id gi00.10 -id gi00.20 -id gi00.30 172.16.40.20
sleep 1

pedir_ip() {  # equipo → pide IP por DHCP con resolv.conf propio del equipo
  mkdir -p "/etc/netns/$1"; : > "/etc/netns/$1/resolv.conf"
  en "$1" timeout 25 dhclient -4 -1 -lf "/tmp/$1.leases" -pf "/tmp/$1.dhpid" eth0 >/dev/null 2>&1
}
ip4() { en "$1" ip -4 -o addr show dev eth0 | awk '{print $4}' | cut -d/ -f1 | head -1; }
en_rango() { local ip="$1" red="$2" a="$3" b="$4" h; [[ "$ip" == "$red".* ]] || return 1; h="${ip##*.}"; [ "$h" -ge "$a" ] && [ "$h" -le "$b" ]; }
alcanza() { en "$1" ping -c 2 -W 2 "$2" >/dev/null 2>&1; }
echo "  listo: 12 equipos, switch con 8 puertos de acceso en 6 VLAN, troncal con 5 VLAN, router con 5 subinterfaces"

t "1. DHCP a través del router (reenvío, regla 4; ámbitos de la Tabla 34)"
# Captura en la placa del DC: se ve el campo giaddr ("Gateway-IP") que agrega el router.
en dc01 tcpdump -i eth0 -n -v -l udp port 67 > /tmp/dc01-dhcp.pcap.txt 2>/dev/null &
sleep 1
for par in adm1:172.16.10:100:200 doc1:172.16.20:100:200 est1:172.16.30:100:250 est2:172.16.30:100:250; do
  e="${par%%:*}"; IFS=: read -r _ red a b <<< "$par"
  pedir_ip "$e"; ip="$(ip4 "$e")"; gw="$(en "$e" ip route show default | awk '{print $3}')"
  en_rango "${ip:-0.0.0.0}" "$red" "$a" "$b" && ok "$e recibió $ip (ámbito $red.$a–$b)" || mal "$e recibió IP del ámbito $red.$a–$b" "${ip:-sin IP}"
  [ "$gw" = "$red.1" ] && ok "$e: puerta de enlace $gw (opción 003)" || mal "$e: puerta de enlace $red.1" "$gw"
done
grep -q 'nameserver 172.16.40.20' /etc/netns/est1/resolv.conf && ok "est1: DNS 172.16.40.20 (opción 006)" || mal "est1: DNS 172.16.40.20"
grep -qE '^(search|domain) atlas.local' /etc/netns/est1/resolv.conf && ok "est1: sufijo atlas.local (opción 015)" || mal "est1: sufijo atlas.local"
sleep 1; pkill -f "tcpdump -i eth0" 2>/dev/null; sleep 1
for gw in 172.16.10.1 172.16.20.1 172.16.30.1; do
  grep -q "Gateway-IP $gw" /tmp/dc01-dhcp.pcap.txt && ok "el DC recibió pedidos con giaddr $gw (así elige el ámbito de esa VLAN)" || mal "giaddr $gw en la captura del DC"
done
echo "  Extracto de la captura en dc01:"; grep -E 'BOOTP/DHCP|Gateway-IP|DHCP-Message' /tmp/dc01-dhcp.pcap.txt | head -6 | sed 's/^ */        /'
r="$(en est1 getent hosts atlas-srv01.atlas.local | awk '{print $1}')"
[ "$r" = 172.16.40.10 ] && ok "est1 resuelve atlas-srv01.atlas.local → 172.16.40.10" || mal "est1 resuelve atlas-srv01.atlas.local" "$r"

t "2. Enrutamiento entre VLAN (Fase 8: todavía sin filtrado; lo agrega la Fase 9)"
alcanza est1 172.16.40.10 && ok "VLAN 30 → srv01 (172.16.40.10) pasa por el router" || mal "VLAN 30 → srv01"
alcanza adm1 "$(ip4 doc1)" && ok "VLAN 10 → VLAN 20 enrutado" || mal "VLAN 10 → VLAN 20"
alcanza gest 172.16.40.20 && ok "VLAN 50 → dc01" || mal "VLAN 50 → dc01"
# (se guarda la salida primero: ping termina con código 1 cuando el TTL expira)
salto1="$(en est1 ping -c1 -W2 -t1 203.0.113.10 2>&1)"; salto2="$(en est1 ping -c1 -W2 -t2 203.0.113.10 2>&1)"
grep -q 'From 172.16.30.1 .*Time to live exceeded' <<< "$salto1" && ok "primer salto de VLAN 30 = 172.16.30.1 (su gateway)" || mal "primer salto 172.16.30.1"
grep -q 'From 172.16.255.2 .*Time to live exceeded' <<< "$salto2" && ok "segundo salto = 172.16.255.2 (atlas-fw01, ruta por defecto)" || mal "segundo salto 172.16.255.2"
alcanza est1 203.0.113.10 && ok "VLAN 30 llega a la 'Internet simulada' 203.0.113.10" || mal "VLAN 30 → Internet simulada"

t "3. Aislamiento de capa 2 (qué NO debe pasar)"
DOC="$(ip4 doc1)"
en est1 ip addr add 172.16.20.99/24 dev eth0
alcanza est1 "$DOC" && mal "un equipo de VLAN 30 que se pone una IP de VLAN 20 NO llega a doc1" || ok "un equipo de VLAN 30 que se pone una IP de VLAN 20 NO llega a doc1 (VLAN separadas)"
en est1 ip addr del 172.16.20.99/24 dev eth0
[ "$(en sw01 cat /sys/class/net/fa0_24/operstate)" = down ] && ok "Fa0/24 apagado: el cable no da enlace" || mal "Fa0/24 apagado"
en sw01 ip link set fa0_24 up; sleep 1
pedir_ip intruso; ip="$(ip4 intruso)"
[ -z "$ip" ] && ok "aunque alguien encienda Fa0/24, en VLAN 999 no hay DHCP" || mal "VLAN 999 sin DHCP" "$ip"
en intruso ip addr add 172.16.30.200/24 dev eth0; en intruso ip route add default via 172.16.30.1 2>/dev/null
alcanza intruso 172.16.30.1 && mal "VLAN 999 no llega a ningún gateway" || ok "VLAN 999 no llega a ningún gateway aunque se invente una IP (no está en el troncal)"
en sw01 ip link set fa0_24 down

t "4. Gestión (p. 67)"
alcanza gest 172.16.50.2 && ok "estación de gestión → atlas-sw01 (172.16.50.2)" || mal "gestión → sw01"
alcanza gest 172.16.50.1 && ok "estación de gestión → atlas-rt01 (172.16.50.1)" || mal "gestión → rt01"
[ "$(en sw01 bash -c 'ls /sys/class/net/vlan999/brif' | tr '\n' ' ')" = "fa0_24 " ] && ok "VLAN 999: solo el puerto sin uso, sin enlace al router (nativa sin servicio)" || mal "VLAN 999 aislada"

t "Concesiones entregadas por el DC"
sed 's/^/  /' /tmp/dc01.leases

printf '\nResultado: %d PASS · %d FAIL\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
