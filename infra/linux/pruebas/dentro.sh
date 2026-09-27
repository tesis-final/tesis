#!/usr/bin/env bash
# Parte que corre DENTRO del contenedor de prueba (ver probar-en-contenedor.sh).
set -uo pipefail
L=/opt/atlas-infra/linux
titulo() { printf '\n══════ %s ══════\n' "$*"; }
# Las "VLAN" de prueba llegan a srv01 por un bridge que hace de interfaz física.
export ATLAS_IFACE=br-lan

titulo "Entorno"
. /etc/os-release; echo "$PRETTY_NAME · kernel $(uname -r)"

titulo "Disco ext4 para /srv (chattr no funciona sobre overlay)"
truncate -s 256M /tmp/srv.img && mkfs.ext4 -q /tmp/srv.img && mkdir -p /srv && mount -o loop /tmp/srv.img /srv && df -hT /srv | tail -1

titulo "Clave pública de prueba para atlasadmin"
ssh-keygen -q -t ed25519 -N '' -f /root/prueba_admin -C prueba-admin && cp /root/prueba_admin.pub /root/atlasadmin.pub

titulo "Paso 2 — usuarios y grupos"
bash $L/02-usuarios-grupos.sh
titulo "Paso 3 — directorios, permisos, ACL y atributos"
bash $L/03-directorios-permisos.sh
titulo "Paso 3 otra vez (idempotencia)"
bash $L/03-directorios-permisos.sh >/dev/null && echo "segunda ejecución sin errores"

titulo "Verificación: usuarios, permisos (Tabla 27), atributos"
bash $L/verificar.sh usuarios permisos atributos

titulo "Paso 4 — SSH y TCP Wrappers"
mkdir -p /run/sshd; ssh-keygen -A >/dev/null
bash $L/04-acceso-ssh.sh
/usr/sbin/sshd -E /var/log/auth.log
bash $L/verificar.sh ssh

titulo "Red de prueba: 'VLAN 50' (172.16.50.10) y 'VLAN 30' (172.16.30.100) → srv01 172.16.40.10"
ip addr add 172.16.40.10/32 dev lo
ip link add br-lan type bridge; ip link set br-lan up
for par in gestion:50:10 estudiante:30:100; do
  n="${par%%:*}"; v="$(echo "$par" | cut -d: -f2)"; h="${par##*:}"
  ip netns add "$n"
  ip link add "v$v" type veth peer name eth0 netns "$n"
  ip link set "v$v" master br-lan up; ip addr add "172.16.$v.1/24" dev br-lan
  ip -n "$n" addr add "172.16.$v.$h/24" dev eth0; ip -n "$n" link set eth0 up; ip -n "$n" link set lo up
  ip -n "$n" route add default via "172.16.$v.1"
done
sysctl -qw net.ipv4.ip_forward=1

# Usuario de prueba que representa a un miembro de GG_SoporteTI (en el laboratorio es una cuenta de AD).
groupadd gg_soporteti; useradd -m -s /bin/bash -G gg_soporteti soporte1
install -d -m 700 -o soporte1 -g soporte1 /home/soporte1/.ssh
install -m 600 -o soporte1 -g soporte1 /root/prueba_admin.pub /home/soporte1/.ssh/authorized_keys
# Lo mismo que hace 09-dominio.sh para la correspondencia de la Tabla 36:
{ echo "# ATLAS-INICIO"; grep -v '^#' $L/archivos/pam-group.conf; echo "# ATLAS-FIN"; } >> /etc/security/group.conf
sed -i '/^@include common-auth/a auth optional pam_group.so # ATLAS Tabla 36' /etc/pam.d/sshd
# Un usuario común que NO es de Soporte TI:
useradd -m -s /bin/bash intruso; install -d -m 700 -o intruso /home/intruso/.ssh
install -m 600 -o intruso /root/prueba_admin.pub /home/intruso/.ssh/authorized_keys
pkill -HUP -x sshd; sleep 1

SSH=(ssh -i /root/prueba_admin -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20 -o LogLevel=ERROR)
prueba() {  # descripción esperado(entra|no) netns usuario
  local salida rc
  salida="$(ip netns exec "$3" "${SSH[@]}" "$4@172.16.40.10" 'echo ENTRO; id' 2>&1)"; rc=$?
  if { [ "$2" = entra ] && [ $rc -eq 0 ]; } || { [ "$2" = no ] && [ $rc -ne 0 ]; }; then
    echo "  PASS  $1"; else echo "  FAIL  $1"; fi
  echo "$salida" | sed 's/^/        /' | head -3
}
titulo "Conexiones SSH reales (solo TCP Wrappers + sshd, todavía sin firewall)"
prueba "atlasadmin desde VLAN 50 entra" entra gestion atlasadmin
prueba "soporte1 (GG_SoporteTI) desde VLAN 50 entra y recibe atlas-admin y atlas-audit" entra gestion soporte1
prueba "intruso (no es Soporte TI) desde VLAN 50 NO entra (AllowGroups)" no gestion intruso
prueba "atlasadmin desde VLAN 30 NO entra (TCP Wrappers corta antes de autenticar)" no estudiante atlasadmin
prueba "root desde VLAN 50 NO entra (PermitRootLogin no)" no gestion root
echo "  Registro de sshd de esas conexiones:"; grep -hE 'refused connect|Accepted publickey|not allowed because|User root' /var/log/auth.log 2>/dev/null | tail -6 | sed 's/^/        /' || true

titulo "Paso 5 — UFW + DOCKER-USER"
bash $L/05-firewall.sh 2>&1 | tail -30
bash $L/verificar.sh firewall
titulo "Conexiones SSH con el firewall activo (dos capas)"
prueba "atlasadmin desde VLAN 50 sigue entrando" entra gestion atlasadmin
prueba "atlasadmin desde VLAN 30 NO entra" no estudiante atlasadmin
titulo "Otros puertos desde VLAN 30 hacia srv01 (nc -z, se espera que ninguno conecte)"
for p in 22 3306 139 80; do
  if ip netns exec estudiante nc -z -w 2 172.16.40.10 "$p" 2>/dev/null; then echo "  FAIL  puerto $p abierto desde VLAN 30"; else echo "  PASS  puerto $p cerrado desde VLAN 30"; fi
done
echo "  Denegaciones registradas por UFW (kernel):"; dmesg 2>/dev/null | grep -c 'UFW BLOCK' | sed 's/^/        líneas UFW BLOCK: /' || true

titulo "DOCKER-USER en acción: se simula lo que hace Docker al publicar 443 de atlas-web"
# Un "contenedor" (espacio de red) 192.168.250.2 escuchando en 443, y la misma
# DNAT + aceptación que arma Docker. Sin DOCKER-USER, cualquiera llegaría.
ip netns add web
ip link add vweb type veth peer name eth0 netns web
ip addr add 192.168.250.1/28 dev vweb; ip link set vweb up
ip -n web addr add 192.168.250.2/28 dev eth0; ip -n web link set eth0 up; ip -n web link set lo up
ip -n web route add default via 192.168.250.1
ip netns exec web nc -lk -p 443 >/dev/null 2>&1 &
iptables -t nat -A PREROUTING -d 172.16.40.10 -p tcp --dport 443 -j DNAT --to-destination 192.168.250.2:443
iptables -I FORWARD 1 -j DOCKER-USER
iptables -I FORWARD 2 -o vweb -d 192.168.250.2 -p tcp --dport 443 -j ACCEPT
iptables -I FORWARD 3 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sleep 1
conecta() { ip netns exec "$1" nc -z -w 3 172.16.40.10 443 2>/dev/null; }
conecta estudiante && echo "  PASS  VLAN 30 llega a HTTPS de ATLAS (regla 1)" || echo "  FAIL  VLAN 30 debería llegar a HTTPS"
conecta gestion && echo "  FAIL  VLAN 50 no debería llegar a HTTPS (Tabla 44)" || echo "  PASS  VLAN 50 NO llega a HTTPS: DOCKER-USER lo descarta (la Tabla 44 no lo permite)"
echo "  Contadores de DOCKER-USER (paquetes descartados y registrados):"
iptables -L DOCKER-USER -v -n | awk 'NR<=2 || /LOG|DROP/' | sed 's/^/        /'
echo "  Contraprueba: vaciando DOCKER-USER (como si no existiera el paso 5)…"
iptables -F DOCKER-USER
conecta gestion && echo "  PASS  sin DOCKER-USER, VLAN 50 SÍ llega: el riesgo R-01 es real y el paso 5 lo cierra" || echo "  ?     sin DOCKER-USER tampoco llega"
ufw reload >/dev/null && iptables -S DOCKER-USER | grep -q DROP && echo "  PASS  'ufw reload' vuelve a cargar DOCKER-USER"
conecta gestion && echo "  FAIL  tras recargar, VLAN 50 no debería llegar" || echo "  PASS  tras recargar, VLAN 50 vuelve a quedar bloqueada"

titulo "Paso 12 — sudo acotado"
bash $L/12-sudo.sh 2>&1 | tail -15
bash $L/verificar.sh sudo
echo "  ¿atlasadmin puede abrir una shell de root con sudo?"
if setpriv --reuid=atlasadmin --regid=atlas-admin --init-groups sudo -n bash -c id >/dev/null 2>&1; then echo "  FAIL  sí puede"; else echo "  PASS  no puede (sudo: comando no permitido)"; fi

titulo "Paso 10 — Samba (smb.conf; grupos locales en lugar de los de AD)"
groupadd gg_administracion; groupadd gg_docentes
bash $L/10-samba.sh 2>&1 | tail -12
bash $L/verificar.sh samba 2>&1 | grep -v 'smbd activo'

titulo "Paso 11 — registros (sin systemd ni auditd en contenedor: solo archivos)"
bash $L/11-registros.sh 2>&1 | tail -8
logrotate -d /etc/logrotate.d/atlas 2>&1 | grep -E 'rotating pattern|error' | head -3

titulo "FIN"
