#!/usr/bin/env bash
# =============================================================================
# ATLAS — Pruebas de los ajustes que salieron del laboratorio Proxmox (Hito 2)
#
# Cada bloque prueba un script corregido a partir de una incidencia del informe
# del Hito 2 de Redes, con su caso "antes" (la falla) cuando se puede reproducir:
#   01-redes.sh        WAN_INTERNA=si crea vmbr2 sin tocar vmbr0 (INC-05)
#   03-crear-vms.sh    PUENTE_WAN y --cpu en las 4 VM (INC-03, INC-05)
#   04-router-lab.sh   otro netplan para la WAN se guarda aparte (INC-04)
#   verificar.sh       atlas.conf con las ACL de la Tabla 27 (INC-10)
# No es Proxmox: qm e ifreload se reemplazan por comandos de prueba que solo
# anotan lo que reciben. Lo que se prueba es lo que cada script escribe o pide.
#
# Uso (contenedor privilegiado con la imagen de infra/linux/pruebas):
#   docker run --rm --privileged -v "$PWD/infra:/infra:ro" atlas-ubuntu-test:24.04 \
#     bash /infra/pruebas/probar-ajustes-laboratorio.sh
# =============================================================================
set -u
I=${INFRA:-/infra}
pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  PASS  $1"; }
mal() { fail=$((fail+1)); echo "  FAIL  $1"; }
[ "$(id -u)" -eq 0 ] || { echo "Correr como root (dentro del contenedor)."; exit 1; }

echo "[01-redes.sh: WAN_INTERNA=si (INC-05)]"
mkdir -p /etc/network
printf 'auto lo\niface lo inet loopback\n\nauto vmbr0\niface vmbr0 inet static\n    address 192.168.2.2/24\n    gateway 192.168.2.1\n    bridge-ports enxec9a0c113f5b\n' > /etc/network/interfaces
printf '#!/bin/sh\nexit 0\n' > /usr/local/bin/ifreload; chmod +x /usr/local/bin/ifreload
WAN_INTERNA=si bash "$I/proxmox/01-redes.sh" >/dev/null 2>&1
WAN_INTERNA=si bash "$I/proxmox/01-redes.sh" >/dev/null 2>&1   # segunda corrida
F=/etc/network/interfaces
[ "$(grep -c '^iface vmbr2 ' $F)" = 1 ] && ok "crea vmbr2 una sola vez aunque se corra dos veces" || mal "vmbr2"
grep -q 'address 10.99.0.1/24' $F && grep -q 'MASQUERADE' $F && ok "vmbr2 con 10.99.0.1/24 y NAT hacia vmbr0" || mal "vmbr2 dirección y NAT"
[ "$(grep -c 'bridge-ports enxec9a0c113f5b' $F)" = 1 ] && ok "vmbr0 queda como estaba" || mal "vmbr0 modificado"
[ "$(grep -c '^iface vmbr1 ' $F)" = 1 ] && [ "$(grep -c '^iface vmbr1.50 ' $F)" = 1 ] && ok "vmbr1 y vmbr1.50 como antes" || mal "vmbr1"
[ -f $F.antes-de-atlas ] && ok "guarda una copia del archivo original" || mal "copia"

echo; echo "[03-crear-vms.sh: PUENTE_WAN y CPU (INC-03, INC-05)]"
mkdir -p /var/lib/vz/template/iso
for i in ubuntu-24.04.3-live-server-amd64.iso windows-server-2022.iso windows-10.iso virtio-win.iso atlas-repo.iso; do
  touch "/var/lib/vz/template/iso/$i"; done
printf '#!/bin/sh\n[ "$1" = status ] && exit 1\necho "qm $*" >> /tmp/qm.log\n' > /usr/local/bin/qm; chmod +x /usr/local/bin/qm
for b in vmbr0 vmbr1; do ip link add "$b" type bridge; done
rm -f /tmp/qm.log; bash "$I/proxmox/03-crear-vms.sh" >/dev/null 2>&1
grep -q 'create 110 .*--net1 virtio,bridge=vmbr0' /tmp/qm.log && ok "sin PUENTE_WAN, la WAN de router-lab va a vmbr0 (como antes)" || mal "router-lab vmbr0"
grep -q 'create 130 .*--net0 virtio,bridge=vmbr0' /tmp/qm.log && ok "sin PUENTE_WAN, atlas-srv01 se instala por vmbr0" || mal "srv01 vmbr0"
[ "$(grep -c -- '--cpu x86-64-v2-AES' /tmp/qm.log)" = 4 ] && ok "las 4 VM se crean con --cpu x86-64-v2-AES (no kvm64)" || mal "cpu"
rm -f /tmp/qm.log; PUENTE_WAN=vmbr2 bash "$I/proxmox/03-crear-vms.sh" >/dev/null 2>&1
[ ! -s /tmp/qm.log ] && ok "con PUENTE_WAN=vmbr2 y sin vmbr2 creado, no crea nada" || mal "crea VM sin vmbr2"
ip link add vmbr2 type bridge
rm -f /tmp/qm.log; PUENTE_WAN=vmbr2 CPU=host bash "$I/proxmox/03-crear-vms.sh" >/dev/null 2>&1
grep -q 'create 110 .*--net1 virtio,bridge=vmbr2' /tmp/qm.log && ok "router-lab con la WAN en vmbr2, como en el laboratorio" || mal "router-lab vmbr2"
grep -q 'create 130 .*--net0 virtio,bridge=vmbr2' /tmp/qm.log && ok "atlas-srv01 se instala por vmbr2, como en el laboratorio" || mal "srv01 vmbr2"
[ "$(grep -c -- '--cpu host' /tmp/qm.log)" = 4 ] && ok "CPU=host se aplica a las 4 VM" || mal "cpu host"

echo; echo "[04-router-lab.sh: un netplan armado a mano no duplica la WAN (INC-04)]"
mkdir -p /etc/netplan
echo 'network: {}' > /etc/netplan/60-wan.yaml; echo 'x' > /etc/netplan/60-atlas-router.yaml
eval "$(sed -n '/^for f in \/etc\/netplan\/\*.yaml; do$/,/^done$/p' "$I/proxmox/04-router-lab.sh")"
[ -e /etc/netplan/60-wan.yaml.antes-de-atlas ] && [ ! -e /etc/netplan/60-wan.yaml ] && ok "60-wan.yaml queda guardado como 60-wan.yaml.antes-de-atlas" || mal "netplan aparte"
[ -e /etc/netplan/60-atlas-router.yaml ] && ok "el netplan del propio script no se toca" || mal "netplan propio"

echo; echo "[verificar.sh: atlas.conf con las ACL de la Tabla 27 (INC-10)]"
for g in atlas-admin atlas-web atlas-db atlas-backup; do groupadd "$g"; done
useradd -g atlas-admin atlasadmin
R=/srv/atlas; f=$R/config/atlas.conf
mkdir -p $R/config; install -m 640 -o atlasadmin -g atlas-admin /dev/null $f
setfacl -R -m g:atlas-admin:rwX,g:atlas-web:rX,g:atlas-db:rX,g:atlas-backup:rX $R/config   # como 03-directorios-permisos.sh
echo "  archivo: $(stat -c '%U:%G %a' $f) $(ls -l $f | cut -c1-11)"
# El chequeo se toma de verificar.sh tal cual está.
cond=$(grep 'atlasadmin:atlas-admin\\ 6' "$I/linux/verificar.sh" | sed 's/^ *//; s/ *\\$//')
[ -n "$cond" ] || { mal "no encontré el chequeo en verificar.sh"; cond=false; }
[ "$(stat -c %a $f)" = 640 ] && mal "el chequeo anterior (640 exacto) lo acepta" || ok "el chequeo anterior (640 exacto) da FAIL con las ACL: falla del laboratorio reproducida"
eval "$cond" && ok "verificar.sh acepta atlas.conf con las ACL de la Tabla 27" || mal "verificar.sh rechaza el archivo correcto"
chmod o+r $f; eval "$cond" && mal "verificar.sh acepta lectura para otros" || ok "verificar.sh rechaza atlas.conf si otros pueden leerlo"
chmod o-r $f; chown root $f; eval "$cond" && mal "verificar.sh acepta otro dueño" || ok "verificar.sh rechaza atlas.conf con otro dueño"

echo; echo "Resultado: $pass PASS · $fail FAIL"
[ "$fail" -eq 0 ]
