#!/usr/bin/env bash
# =============================================================================
# ATLAS — Proxmox, paso 3: crear las 4 VM del laboratorio
#
#   110 router-lab   Ubuntu 24.04  1 GB  10 GB  VLAN 20, 40, 50 + Internet (vmbr0)
#   120 atlas-dc01   Win Srv 2022  4 GB  50 GB  VLAN 40
#   130 atlas-srv01  Ubuntu 24.04  4 GB  30 GB  Internet (vmbr0) para instalar;
#                                               después se pasa a VLAN 40
#   140 cliente-doc  Windows 10    2 GB  40 GB  VLAN 20
#
# Las VM Windows usan disco SATA y placa de red Intel E1000: Windows las
# reconoce sin drivers extra. Las Linux usan VirtIO (lo más rápido).
# Todas con el agente de QEMU activado (sirve para copiar archivos, ver copiar.sh).
#
# ANTES: subir las ISO a "local" -> "Imágenes ISO" y poner sus nombres abajo
# (o pasarlos como variables). Correr 01-redes.sh y 02-iso-repo.sh.
# Uso (como root):  bash 03-crear-vms.sh
# Se puede cambiar la memoria con, por ejemplo:  RAM_DC=3072 bash 03-crear-vms.sh
# =============================================================================
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Correr como root."; exit 1; }

ISO_UBUNTU=${ISO_UBUNTU:-ubuntu-24.04.3-live-server-amd64.iso}
ISO_WINSRV=${ISO_WINSRV:-windows-server-2022.iso}
ISO_WINCLI=${ISO_WINCLI:-windows-10-enterprise.iso}
ISO_VIRTIO=${ISO_VIRTIO:-virtio-win.iso}
ISO_REPO=atlas-repo.iso
DISCO=${DISCO:-local-lvm}           # en una instalación con ZFS es local-zfs
RAM_ROUTER=${RAM_ROUTER:-1024}; RAM_DC=${RAM_DC:-4096}
RAM_SRV=${RAM_SRV:-4096};       RAM_CLI=${RAM_CLI:-2048}

D=/var/lib/vz/template/iso
falta=0
for i in "$ISO_UBUNTU" "$ISO_WINSRV" "$ISO_WINCLI" "$ISO_VIRTIO" "$ISO_REPO"; do
  [ -f "$D/$i" ] || { echo "FALTA la ISO: $D/$i"; falta=1; }
done
[ "$falta" -eq 0 ] || { echo "Subí las ISO (o corregí los nombres al principio del script)."; ls "$D"; exit 1; }
ip link show vmbr1 >/dev/null 2>&1 || { echo "No existe vmbr1: correr antes 01-redes.sh"; exit 1; }

crear() { local id=$1; shift
  if qm status "$id" >/dev/null 2>&1; then echo "La VM $id ya existe: no se toca."; return; fi
  qm create "$id" "$@"; echo "VM $id creada."; }

crear 110 --name router-lab --memory "$RAM_ROUTER" --cores 1 --ostype l26 \
  --scsihw virtio-scsi-single --scsi0 "$DISCO:10" \
  --ide2 "local:iso/$ISO_UBUNTU,media=cdrom" --boot "order=scsi0;ide2" \
  --net0 virtio,bridge=vmbr1,tag=20 --net1 virtio,bridge=vmbr1,tag=40 \
  --net2 virtio,bridge=vmbr1,tag=50 --net3 virtio,bridge=vmbr0 --agent 1

crear 120 --name atlas-dc01 --memory "$RAM_DC" --cores 2 --ostype win11 \
  --sata0 "$DISCO:50" --ide2 "local:iso/$ISO_WINSRV,media=cdrom" \
  --ide0 "local:iso/$ISO_VIRTIO,media=cdrom" --ide3 "local:iso/$ISO_REPO,media=cdrom" \
  --boot "order=sata0;ide2" --net0 e1000,bridge=vmbr1,tag=40 --agent 1

crear 130 --name atlas-srv01 --memory "$RAM_SRV" --cores 2 --ostype l26 \
  --scsihw virtio-scsi-single --scsi0 "$DISCO:30" \
  --ide2 "local:iso/$ISO_UBUNTU,media=cdrom" --boot "order=scsi0;ide2" \
  --net0 virtio,bridge=vmbr0 --agent 1

crear 140 --name cliente-doc --memory "$RAM_CLI" --cores 2 --ostype win10 \
  --sata0 "$DISCO:40" --ide2 "local:iso/$ISO_WINCLI,media=cdrom" \
  --ide0 "local:iso/$ISO_VIRTIO,media=cdrom" --ide3 "local:iso/$ISO_REPO,media=cdrom" \
  --boot "order=sata0;ide2" --net0 e1000,bridge=vmbr1,tag=20 --agent 1

echo
qm list
echo "Listo. Prender primero router-lab (110)."
