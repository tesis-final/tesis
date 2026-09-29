#!/usr/bin/env bash
# =============================================================================
# ATLAS · Fase 6 — Prueba de los scripts de atlas-srv01 en un Ubuntu 24.04 REAL
# (contenedor privilegiado), antes de llevarlos a la VM del laboratorio.
#
# Qué SÍ prueba: usuarios, permisos/ACL de la Tabla 27 celda por celda, chattr
# sobre ext4, sshd + TCP Wrappers con conexiones reales desde "VLAN 50" y
# "VLAN 30" (espacios de red), la correspondencia GG_SoporteTI → atlas-admin,
# UFW + DOCKER-USER, sudoers, smb.conf y logrotate.
# Qué NO prueba (requiere laboratorio): netplan, systemd, Docker de la pila,
# unión real al dominio, Samba con usuarios de AD, chrony contra el DC.
#
# Uso: infra/linux/pruebas/probar-en-contenedor.sh [imagen]
# Imagen: docker build -t atlas-ubuntu-test:24.04 infra/linux/pruebas
# =============================================================================
set -euo pipefail
IMAGEN="${1:-atlas-ubuntu-test:24.04}"
DIR="$(cd "$(dirname "$0")/.." && pwd)"
docker rm -f atlas-srv01-prueba >/dev/null 2>&1 || true
docker run --rm --name atlas-srv01-prueba --privileged --hostname atlas-srv01 \
  -v "$DIR":/opt/atlas-infra/linux:ro "$IMAGEN" bash /opt/atlas-infra/linux/pruebas/dentro.sh
