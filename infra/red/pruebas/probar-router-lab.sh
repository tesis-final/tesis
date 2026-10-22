#!/usr/bin/env bash
# =============================================================================
# ATLAS — Prueba del firewall de router-lab (infra/proxmox/04-router-lab.sh)
# ANTES de llevarlo a Proxmox: se arma la red con espacios de red de Linux, se
# carga EXACTAMENTE el mismo nftables que genera el script y se manda tráfico real
# (conexiones TCP/UDP) entre las "máquinas". Cada caso dice qué regla lo decide.
#
#   rt     el router-lab: ens18.10 … ens18.50 (una "pata" por VLAN) + ens19 (WAN)
#   adm1 (VLAN 10) doc1 (20) est1 (30) srv01 y dc01 (40, mismo switch) gest (50)
#   inet   "Internet" simulada 203.0.113.0/24 (RFC 5737)
#
# Qué NO prueba: el etiquetado 802.1Q (lo hace el switch virtual de Proxmox) ni
# el reenvío de DHCP. Eso se verifica en las VM (guía, paso 8).
# Uso (root, Linux con nftables):  bash infra/red/pruebas/probar-router-lab.sh
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/../../.."
[ "$(id -u)" -eq 0 ] || { echo "Correr como root."; exit 1; }
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
mal() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }
en()  { ip netns exec "$@"; }
NS="rt sw adm1 doc1 est1 srv01 dc01 gest inet"
PIDS=()
limpiar() { [ ${#PIDS[@]} -gt 0 ] && kill "${PIDS[@]}" 2>/dev/null; for n in $NS; do ip netns del "$n" 2>/dev/null; done; }
trap limpiar EXIT
limpiar

# --- El nftables tal cual lo genera 04-router-lab.sh -------------------------
TRONCAL=ens18; WAN=ens19; DC=172.16.40.20; SRV=172.16.40.10
V10=$TRONCAL.10; V20=$TRONCAL.20; V30=$TRONCAL.30; V40=$TRONCAL.40; V50=$TRONCAL.50
REGLAS=$(mktemp)
eval "cat <<EOF
$(sed -n '/^cat > "\$NFT" <<EOF$/,/^EOF$/p' infra/proxmox/04-router-lab.sh | sed '1d;$d')
EOF" > "$REGLAS"
grep -q 'chain forward' "$REGLAS" || { echo "No pude extraer las reglas del script."; exit 1; }

# --- Topología ---------------------------------------------------------------
for n in $NS; do ip netns add "$n"; en "$n" ip link set lo up; done
en rt sysctl -qw net.ipv4.ip_forward=1
pata() { # pata <ifname-en-rt> <ns> <ip-host> <ip-gw>
  ip link add "$1" netns rt type veth peer name eth0 netns "$2"
  en rt ip addr add "$4/24" dev "$1"; en rt ip link set "$1" up
  en "$2" ip addr add "$3/24" dev eth0; en "$2" ip link set eth0 up
  en "$2" ip route add default via "$4"
}
pata "$V10" adm1 172.16.10.100 172.16.10.1
pata "$V20" doc1 172.16.20.100 172.16.20.1
pata "$V30" est1 172.16.30.100 172.16.30.1
pata "$V50" gest 172.16.50.10  172.16.50.1
# VLAN 40: srv01 y dc01 en el mismo switch
en sw ip link add br40 type bridge; en sw ip link set br40 up
ip link add "$V40" netns rt type veth peer name p-rt netns sw
for h in srv01 dc01; do ip link add eth0 netns "$h" type veth peer name "p-$h" netns sw; done
for p in p-rt p-srv01 p-dc01; do en sw ip link set "$p" master br40 up; done
en rt ip addr add 172.16.40.1/24 dev "$V40"; en rt ip link set "$V40" up
en srv01 ip addr add $SRV/24 dev eth0; en dc01 ip addr add $DC/24 dev eth0
for h in srv01 dc01; do en "$h" ip link set eth0 up; en "$h" ip route add default via 172.16.40.1; done
# WAN
ip link add "$WAN" netns rt type veth peer name eth0 netns inet
en rt ip addr add 203.0.113.2/24 dev "$WAN"; en rt ip link set "$WAN" up
en rt ip route add default via 203.0.113.1
en inet ip addr add 203.0.113.1/24 dev eth0; en inet ip link set eth0 up
en inet ip route add 172.16.0.0/16 via 203.0.113.2   # para probar que NO entra nada

en rt nft -f "$REGLAS" || { echo "nftables rechazó las reglas"; exit 1; }

# --- Servicios: un proceso que escucha en varios puertos TCP/UDP y anota el origen
ESCUCHA='
import socket,sys,threading,select
def tcp(p):
    s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1); s.bind(("0.0.0.0",p)); s.listen()
    while True:
        c,a=s.accept(); c.sendall(a[0].encode()); c.close()
def udp(p):
    s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.bind(("0.0.0.0",p))
    while True:
        d,a=s.recvfrom(100); s.sendto(a[0].encode(),a)
for x in sys.argv[2:]:
    pr,p=x.split("/"); threading.Thread(target=tcp if pr=="t" else udp,args=(int(p),),daemon=True).start()
threading.Event().wait()'
esc() { local ns=$1; shift; en "$ns" python3 -c "$ESCUCHA" servicio "$@" & PIDS+=($!); }
esc srv01 t/443 t/445 t/22 t/3306 t/80
esc dc01  t/53 u/53 t/88 t/389 t/3389 t/445 t/22
esc doc1  t/22 t/3389
esc adm1  t/22
esc est1  t/22 t/3389
esc gest  t/22
esc inet  t/443 t/80 t/22 u/53 t/53
esc rt    t/22
sleep 1.5

# conecta <ns> <proto t|u> <ip> <puerto> -> imprime la IP de origen que vio el destino, o nada
conecta() { en "$1" python3 - "$2" "$3" "$4" <<'PY' 2>/dev/null
import socket,sys
pr,ip,p=sys.argv[1],sys.argv[2],int(sys.argv[3])
try:
    if pr=="t":
        s=socket.create_connection((ip,p),timeout=1.5); print(s.recv(100).decode())
    else:
        s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.settimeout(1.5); s.sendto(b"x",(ip,p)); print(s.recvfrom(100)[0].decode())
except Exception: pass
PY
}
debe() { # debe <pasa|bloquea> <regla> <ns> <proto> <ip> <puerto> <texto>
  local r; r=$(conecta "$3" "$4" "$5" "$6")
  if [ "$1" = pasa ] && [ -n "$r" ]; then ok "$2  $7  (pasa)"
  elif [ "$1" = bloquea ] && [ -z "$r" ]; then ok "$2  $7  (bloqueado)"
  else mal "$2  $7  (esperado: $1)"; fi
}

echo; echo "── Usuarios hacia los servidores ──"
debe pasa    R1  doc1 t $SRV 443 "Docentes → ATLAS HTTPS"
debe pasa    R1  adm1 t $SRV 443 "Administración → ATLAS HTTPS"
debe pasa    R1  est1 t $SRV 443 "Estudiantes → ATLAS HTTPS"
debe bloquea R10 doc1 t $SRV 3306 "Docentes → MySQL"
debe bloquea R10 gest t $SRV 3306 "Gestión → MySQL"
debe bloquea M2  doc1 t $SRV 22  "Docentes → SSH al servidor"
debe bloquea M2  est1 t $SRV 22  "Estudiantes → SSH al servidor"
debe pasa    R3  doc1 t $SRV 445 "Docentes → carpetas SMB de srv01"
debe bloquea R3  est1 t $SRV 445 "Estudiantes → carpetas SMB de srv01"
debe pasa    R2  doc1 u $DC 53   "Docentes → DNS del DC (UDP)"
debe pasa    R2  est1 t $DC 88   "Estudiantes → Kerberos del DC"
debe bloquea R12 doc1 t $DC 3389 "Docentes → escritorio remoto del DC"
debe bloquea R12 doc1 t $SRV 80  "Docentes → HTTP sin cifrar a srv01"

echo; echo "── Entre VLAN de usuarios ──"
debe bloquea R11 est1 t 172.16.20.100 22 "Estudiantes → PC de Docentes"
debe bloquea R11 est1 t 172.16.10.100 22 "Estudiantes → Administración"
debe bloquea R11 est1 t 172.16.50.10 22  "Estudiantes → Gestión"
debe bloquea R12 doc1 t 172.16.30.100 22 "Docentes → Estudiantes"
debe bloquea R12 doc1 t 172.16.10.100 22 "Docentes → Administración"

echo; echo "── Gestión (VLAN 50) ──"
debe pasa    R6  gest t $SRV 22  "Gestión → SSH a srv01"
debe pasa    R6  gest t $DC 3389 "Gestión → escritorio remoto del DC"
debe pasa    R6  gest t 172.16.30.100 3389 "Gestión → escritorio remoto de una PC"
debe bloquea R12 gest t $SRV 443 "Gestión → ATLAS (administra, no usa la app)"
debe pasa    p67 gest t 172.16.50.1 22 "Gestión → SSH al router"
debe bloquea p67 doc1 t 172.16.20.1 22 "Docentes → SSH al router"

echo; echo "── Los servidores no inician hacia los usuarios (P-09) ──"
debe bloquea R12 srv01 t 172.16.20.100 22 "srv01 → PC de Docentes"
debe bloquea R12 dc01  t 172.16.50.10 22  "dc01 → Gestión"

echo; echo "── Internet y NAT ──"
r=$(conecta doc1 t 203.0.113.1 443)
[ "$r" = 203.0.113.2 ] && ok "R5  Docentes → web de Internet, con NAT (Internet ve 203.0.113.2, no 172.16.20.100)" \
  || mal "R5/NAT  Docentes → Internet 443 (vio: '${r:-nada}')"
debe pasa    R5  est1 t 203.0.113.1 80  "Estudiantes → web de Internet"
debe bloquea R5  doc1 t 203.0.113.1 22  "Docentes → SSH a Internet"
debe pasa    R7  srv01 t 203.0.113.1 443 "srv01 → actualizaciones (443)"
debe bloquea R7  srv01 u 203.0.113.1 53  "srv01 → DNS de Internet (solo el DC)"
debe pasa    R7  dc01  u 203.0.113.1 53  "dc01 → DNS de Internet (reenvío)"
debe bloquea §30.3 inet t $SRV 443 "Internet → ATLAS (sin NAT de entrada)"
debe bloquea §30.3 inet t 172.16.20.100 22 "Internet → PC de Docentes"

echo
echo "Resultado: $PASS PASS, $FAIL FAIL"
[ "$FAIL" -eq 0 ]
