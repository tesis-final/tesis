#!/usr/bin/env bash
# =============================================================================
# ATLAS — Proxmox, paso 3: crear las 4 VM del laboratorio
#
#   110 router-lab   Ubuntu 24.04  1 GB  10 GB  troncal en vmbr1 (VLAN 10,20,30,40,50)
#                                               + WAN en vmbr0 o vmbr2 (Internet, con NAT)
#   120 atlas-dc01   Win Srv 2022  4 GB  50 GB  VLAN 40
#   130 atlas-srv01  Ubuntu 24.04  4 GB  30 GB  Internet (vmbr0 o vmbr2) para instalar;
#                                               después se pasa a VLAN 40
#   140 cliente-doc  Windows 10    2 GB  40 GB  VLAN 20 (cambiando la etiqueta a 30
#                                               pasa a ser una PC de Estudiantes)
#
# Las VM Windows usan disco SATA y placa de red Intel E1000: Windows las
# reconoce sin drivers extra. Las Linux usan VirtIO (lo más rápido).
# Todas con el agente de QEMU activado (sirve para copiar archivos, ver copiar.sh).
#
# ANTES: subir las ISO a "local" -> "Imágenes ISO" y poner sus nombres abajo
# (o pasarlos como variables). Correr 01-redes.sh y 02-iso-repo.sh.
# Uso (como root):  bash 03-crear-vms.sh
# Se puede cambiar la memoria con, por ejemplo:  RAM_DC=3072 bash 03-crear-vms.sh
#
# CPU: sin --cpu, "qm create" usa kvm64, que no tiene las instrucciones x86-64-v2.
# La imagen mysql:8.0 las exige: en el laboratorio atlas-db se reiniciaba en bucle
# con "CPU does not support x86-64-v2" hasta poner --cpu host (Hito 2 de Redes,
# incidencia del 23/10 01:35). Por defecto x86-64-v2-AES (el modelo que propone
# Proxmox); en el laboratorio se probó host:  CPU=host bash 03-crear-vms.sh
#
# WAN: por defecto la de router-lab y la placa de instalación de srv01 van a vmbr0.
# Si se creó vmbr2 (WAN_INTERNA=si bash 01-redes.sh), como en el laboratorio del
# Hito 2:  PUENTE_WAN=vmbr2 bash 03-crear-vms.sh
# En vmbr2 nadie da DHCP: router-lab usa 10.99.0.2 y srv01, mientras se instala,
# 10.99.0.3 (puerta de enlace 10.99.0.1, el propio Proxmox).
# =============================================================================
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Correr como root."; exit 1; }

ISO_UBUNTU=${ISO_UBUNTU:-ubuntu-24.04.3-live-server-amd64.iso}
ISO_WINSRV=${ISO_WINSRV:-windows-server-2022.iso}
ISO_WINCLI=${ISO_WINCLI:-windows-10.iso}       # Windows 10 Pro (Home no se une a un dominio)
ISO_VIRTIO=${ISO_VIRTIO:-virtio-win.iso}
ISO_REPO=atlas-repo.iso
DISCO=${DISCO:-local-lvm}           # en una instalación con ZFS es local-zfs
RAM_ROUTER=${RAM_ROUTER:-1024}; RAM_DC=${RAM_DC:-4096}
RAM_SRV=${RAM_SRV:-4096};       RAM_CLI=${RAM_CLI:-2048}
CPU=${CPU:-x86-64-v2-AES}
PUENTE_WAN=${PUENTE_WAN:-vmbr0}

D=/var/lib/vz/template/iso
falta=0
for i in "$ISO_UBUNTU" "$ISO_WINSRV" "$ISO_WINCLI" "$ISO_VIRTIO" "$ISO_REPO"; do
  [ -f "$D/$i" ] || { echo "FALTA la ISO: $D/$i"; falta=1; }
done
[ "$falta" -eq 0 ] || { echo "Subí las ISO (o corregí los nombres al principio del script)."; ls "$D"; exit 1; }
ip link show vmbr1 >/dev/null 2>&1 || { echo "No existe vmbr1: correr antes 01-redes.sh"; exit 1; }
ip link show "$PUENTE_WAN" >/dev/null 2>&1 || { echo "No existe $PUENTE_WAN (para vmbr2: WAN_INTERNA=si bash 01-redes.sh)"; exit 1; }

crear() { local id=$1; shift
  if qm status "$id" >/dev/null 2>&1; then echo "La VM $id ya existe: no se toca."; return; fi
  qm create "$id" "$@"; echo "VM $id creada."; }

crear 110 --name router-lab --memory "$RAM_ROUTER" --cores 1 --cpu "$CPU" --ostype l26 \
  --scsihw virtio-scsi-single --scsi0 "$DISCO:10" \
  --ide2 "local:iso/$ISO_UBUNTU,media=cdrom" --boot "order=scsi0;ide2" \
  --net0 "virtio,bridge=vmbr1,trunks=10;20;30;40;50" --net1 "virtio,bridge=$PUENTE_WAN" --agent 1

crear 120 --name atlas-dc01 --memory "$RAM_DC" --cores 2 --cpu "$CPU" --ostype win11 \
  --sata0 "$DISCO:50" --ide2 "local:iso/$ISO_WINSRV,media=cdrom" \
  --ide0 "local:iso/$ISO_VIRTIO,media=cdrom" --ide3 "local:iso/$ISO_REPO,media=cdrom" \
  --boot "order=sata0;ide2" --net0 e1000,bridge=vmbr1,tag=40 --agent 1

crear 130 --name atlas-srv01 --memory "$RAM_SRV" --cores 2 --cpu "$CPU" --ostype l26 \
  --scsihw virtio-scsi-single --scsi0 "$DISCO:30" \
  --ide2 "local:iso/$ISO_UBUNTU,media=cdrom" --boot "order=scsi0;ide2" \
  --net0 "virtio,bridge=$PUENTE_WAN" --agent 1

crear 140 --name cliente-doc --memory "$RAM_CLI" --cores 2 --cpu "$CPU" --ostype win10 \
  --sata0 "$DISCO:40" --ide2 "local:iso/$ISO_WINCLI,media=cdrom" \
  --ide0 "local:iso/$ISO_VIRTIO,media=cdrom" --ide3 "local:iso/$ISO_REPO,media=cdrom" \
  --boot "order=sata0;ide2" --net0 e1000,bridge=vmbr1,tag=20 --agent 1

echo
qm list
echo "Listo. Prender primero router-lab (110)."
