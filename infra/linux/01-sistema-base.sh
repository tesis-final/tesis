#!/usr/bin/env bash
# =============================================================================
# ATLAS · Fase 6 · Paso 1 — Sistema base de atlas-srv01
# PDF: Tabla 24 (Ubuntu Server 24.04 LTS, atlas-srv01, 172.16.40.10/24, VLAN 40).
# Hace: nombre, /etc/hosts, zona horaria, paquetes, actualizaciones automáticas
# de seguridad e IP fija con netplan.
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

. /etc/os-release
[ "$ID" = ubuntu ] && [ "$VERSION_ID" = "24.04" ] || aviso "El PDF pide Ubuntu Server 24.04 LTS; este equipo tiene $PRETTY_NAME."

paso "Nombre del equipo: $ATLAS_HOSTNAME.$ATLAS_DOMINIO"
hostnamectl set-hostname "$ATLAS_HOSTNAME"
sed -i "/[[:space:]]$ATLAS_HOSTNAME\([[:space:]]\|$\)/d" /etc/hosts
echo "$ATLAS_IP $ATLAS_HOSTNAME.$ATLAS_DOMINIO $ATLAS_HOSTNAME" >> /etc/hosts

paso "Zona horaria: $ATLAS_ZONA_HORARIA"
timedatectl set-timezone "$ATLAS_ZONA_HORARIA" 2>/dev/null || ln -sf "/usr/share/zoneinfo/$ATLAS_ZONA_HORARIA" /etc/localtime

paso "Paquetes (sin entorno gráfico, §28.1)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get -y -q upgrade
# acl/attr: §28.3 · openssh-server + libwrap: §28.4 · ufw: §28.4 · chrony: Tabla 35 (hora)
# docker: §25.5 · samba/sssd/realmd/adcli/krb5: Tabla 35 · auditd: registrar el uso de chattr (§28.3)
apt-get -y -q install --no-install-recommends \
  acl attr openssh-server ufw chrony auditd \
  docker.io docker-compose-v2 \
  realmd sssd sssd-tools libnss-sss libpam-sss adcli krb5-user samba samba-common-bin \
  unattended-upgrades rsync curl ca-certificates openssl gzip jq \
  iproute2 iputils-ping dnsutils netcat-openbsd tcpdump nmap

paso "Actualizaciones automáticas solo de seguridad (sin reinicio automático)"
cat > /etc/apt/apt.conf.d/52atlas-unattended <<'CONF'
// ATLAS: solo parches de seguridad; los reinicios se hacen a mano en ventana de mantenimiento.
Unattended-Upgrade::Allowed-Origins { "${distro_id}:${distro_codename}-security"; };
Unattended-Upgrade::Automatic-Reboot "false";
CONF
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'CONF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
CONF

if [ "$ATLAS_APLICAR_RED" = si ]; then
  IFACE="$(interfaz_principal)"; export IFACE
  [ -n "$IFACE" ] || error "No se encontró la interfaz de red; definir ATLAS_IFACE en parametros.conf"
  paso "IP fija $ATLAS_IP/$ATLAS_PREFIJO en $IFACE (gateway $ATLAS_GATEWAY, DNS $ATLAS_DNS)"
  mkdir -p /etc/netplan/atlas-respaldo
  for f in /etc/netplan/*.yaml; do
    [ "$f" = /etc/netplan/60-atlas.yaml ] || { [ -e "$f" ] && mv "$f" /etc/netplan/atlas-respaldo/; }
  done
  renderizar "$DIR_ARCHIVOS/netplan-atlas.yaml.tpl" /etc/netplan/60-atlas.yaml
  chmod 600 /etc/netplan/60-atlas.yaml
  netplan generate
  netplan apply
else
  aviso "ATLAS_APLICAR_RED=no: no se tocó la red. Correr de nuevo con 'si' al pasar la VM a la red del laboratorio."
fi

paso "Listo. Siguiente: 02-usuarios-grupos.sh"
