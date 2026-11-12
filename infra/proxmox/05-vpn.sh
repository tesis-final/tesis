#!/usr/bin/env bash
# =============================================================================
# ATLAS — Proxmox, paso 5: VPN WireGuard con los dos perfiles de la Tabla 45
#
# Se corre ADENTRO de router-lab (VM 110), después de 04-router-lab.sh (que ya tiene las
# reglas R8 y R9 y abre UDP 51820 por la WAN).
#   administración  10.8.0.0/25   (10.8.0.2 – 10.8.0.126)   → solo la VLAN 50 (regla 8)
#   docentes        10.8.0.128/25 (10.8.0.129 – 10.8.0.254) → solo HTTPS a 172.16.40.10 (regla 9)
# El firewall distingue el perfil por la dirección de origen; por eso cada dispositivo tiene
# una dirección fija dentro del segmento de su perfil. El origen no se traduce (VPN-09).
#
# La clave PRIVADA de cada dispositivo se genera en el propio dispositivo (la app WireGuard)
# y nunca llega acá: al script se le pasa solo la clave PÚBLICA.
#
# Uso:
#   sudo bash 05-vpn.sh agregar docente '<clave pública>' [10.8.0.130] [nombre]
#   sudo bash 05-vpn.sh agregar admin   '<clave pública>' [10.8.0.10]  [nombre]
#   sudo bash 05-vpn.sh quitar '<clave pública>'
#   sudo bash 05-vpn.sh estado
# =============================================================================
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Correr con sudo."; exit 1; }
WAN=${WAN:-ens19}
DIR=/etc/wireguard
PARES=$DIR/atlas-pares.tsv        # perfil <TAB> ip <TAB> clave pública <TAB> nombre

clave_valida() { [[ "$1" =~ ^[A-Za-z0-9+/]{42}[AEIMQUYcgkosw048]=$ ]]; }
ip_en_perfil() {   # ip_en_perfil <perfil> <ip>
  local n=${2##*.}
  [[ "$2" =~ ^10\.8\.0\.[0-9]{1,3}$ ]] || return 1
  case "$1" in
    admin)   [ "$n" -ge 2 ] && [ "$n" -le 126 ] ;;
    docente) [ "$n" -ge 129 ] && [ "$n" -le 254 ] ;;
    *) return 1 ;;
  esac
}
siguiente_ip() {   # primera dirección libre del segmento del perfil
  local desde hasta n
  [ "$1" = admin ] && { desde=10; hasta=126; } || { desde=130; hasta=254; }
  for n in $(seq "$desde" "$hasta"); do
    grep -q $'\t'"10.8.0.$n"$'\t' "$PARES" 2>/dev/null || { echo "10.8.0.$n"; return; }
  done
  echo "No quedan direcciones en el perfil $1." >&2; exit 1
}

preparar() {
  nft list chain inet atlas forward >/dev/null 2>&1 || { echo "Primero correr 04-router-lab.sh."; exit 1; }
  nft list chain inet atlas forward | grep -q '10.8.0.128/25' || { echo "Las reglas R8/R9 no están cargadas: volver a correr 04-router-lab.sh."; exit 1; }
  command -v wg >/dev/null || apt-get install -y -q wireguard-tools >/dev/null
  umask 077
  mkdir -p "$DIR"; touch "$PARES"
  [ -f "$DIR/servidor.key" ] || wg genkey > "$DIR/servidor.key"
  wg pubkey < "$DIR/servidor.key" > "$DIR/servidor.pub"
}

# wg0.conf se arma siempre desde la lista de pares: así agregar o quitar no deja restos.
escribir_conf() {
  {
    echo "# ATLAS — generado por 05-vpn.sh. No editar a mano: usar 05-vpn.sh agregar/quitar."
    echo "[Interface]"
    echo "Address = 10.8.0.1/24"
    echo "ListenPort = 51820"
    echo "PostUp = wg set %i private-key $DIR/servidor.key"
    while IFS=$'\t' read -r perfil ip pub nombre; do
      [ -n "$pub" ] || continue
      echo
      echo "# $nombre (perfil $perfil, Tabla 45)"
      echo "[Peer]"
      echo "PublicKey = $pub"
      echo "AllowedIPs = $ip/32"
    done < "$PARES"
  } > "$DIR/wg0.conf"
  chmod 600 "$DIR/wg0.conf"
  systemctl enable wg-quick@wg0 >/dev/null 2>&1 || true
  if ip link show wg0 >/dev/null 2>&1; then
    wg syncconf wg0 <(wg-quick strip wg0)       # aplica sin cortar los túneles abiertos
  else
    systemctl restart wg-quick@wg0
  fi
}

mostrar_cliente() {   # mostrar_cliente <perfil> <ip>
  local wan_ip permitidas
  wan_ip=$(ip -4 -br addr show "$WAN" | awk '{print $3}' | cut -d/ -f1)
  [ "$1" = admin ] && permitidas="172.16.50.0/24" || permitidas="172.16.40.10/32"
  cat <<EOF

En la app WireGuard del dispositivo, el túnel queda así (la línea PrivateKey la pone
la app sola: NO la copies de ningún lado):

[Interface]
PrivateKey = (la que generó la app)
Address = $2/32

[Peer]
PublicKey = $(cat "$DIR/servidor.pub")
AllowedIPs = $permitidas
Endpoint = ${ENDPOINT:-$wan_ip}:51820
PersistentKeepalive = 25

Perfil $1: $([ "$1" = admin ] && echo 'llega a la VLAN 50 (Gestión) y desde ahí administra' || echo 'llega solo a ATLAS por HTTPS (https://172.16.40.10)').
EOF
}

case "${1:-}" in
  agregar)
    PERFIL=${2:?Falta el perfil: admin o docente}
    PUB=${3:?Falta la clave pública del dispositivo (la muestra la app WireGuard)}
    [[ "$PERFIL" =~ ^(admin|docente)$ ]] || { echo "El perfil tiene que ser admin o docente."; exit 1; }
    clave_valida "$PUB" || { echo "Eso no parece una clave pública de WireGuard."; exit 1; }
    preparar
    grep -q $'\t'"$PUB"$'\t' "$PARES" && { echo "Esa clave ya está dada de alta."; exit 1; }
    IP=${4:-$(siguiente_ip "$PERFIL")}
    ip_en_perfil "$PERFIL" "$IP" || { echo "La IP $IP no está en el segmento del perfil $PERFIL (Tabla 45)."; exit 1; }
    grep -q $'\t'"$IP"$'\t' "$PARES" && { echo "La IP $IP ya está usada."; exit 1; }
    printf '%s\t%s\t%s\t%s\n' "$PERFIL" "$IP" "$PUB" "${5:-$PERFIL-$IP}" >> "$PARES"
    escribir_conf
    wg show wg0
    mostrar_cliente "$PERFIL" "$IP"
    ;;
  quitar)
    PUB=${2:?Falta la clave pública a quitar}
    preparar
    grep -q $'\t'"$PUB"$'\t' "$PARES" || { echo "Esa clave no está dada de alta."; exit 1; }
    grep -v $'\t'"$PUB"$'\t' "$PARES" > "$PARES.nuevo" || true
    mv "$PARES.nuevo" "$PARES"; chmod 600 "$PARES"
    escribir_conf
    echo "Quitada. Pares que quedan: $(grep -c . "$PARES" || true)"
    ;;
  estado)
    [ -f "$PARES" ] && column -t -s $'\t' "$PARES" || echo "Todavía no hay pares."
    echo; wg show 2>/dev/null || echo "wg0 no está levantada."
    echo; nft list chain inet atlas forward | grep 'wg0' || true
    ;;
  *)
    sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
