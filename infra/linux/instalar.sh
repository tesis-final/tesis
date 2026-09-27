#!/usr/bin/env bash
# =============================================================================
# ATLAS · Fase 6 — Instalación completa de atlas-srv01, en orden.
# Uso: sudo ./instalar.sh              (todos los pasos)
#      sudo ./instalar.sh 3 5          (solo los pasos 3 a 5)
# Los pasos 9 y 10 necesitan atlas-dc01 (Fase 7) y ATLAS_USUARIO_UNION.
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
DESDE="${1:-1}"; HASTA="${2:-12}"
PASOS=(01-sistema-base 02-usuarios-grupos 03-directorios-permisos 04-acceso-ssh 05-firewall
       06-docker 07-atlas 08-hora 09-dominio 10-samba 11-registros 12-sudo)
for n in $(seq "$DESDE" "$HASTA"); do
  s="${PASOS[$((n-1))]}"
  echo; echo "████ Paso $n: $s"
  "$DIR_LINUX/$s.sh"
done
echo; paso "Instalación terminada. Verificación completa:"
"$DIR_LINUX/verificar.sh" || true
