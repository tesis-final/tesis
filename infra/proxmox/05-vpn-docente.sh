#!/usr/bin/env bash
# =============================================================================
# ATLAS — Proxmox, paso 5 (compatibilidad): VPN para un docente remoto.
# Se mantiene porque lo cita el informe del Hito 2 de Redes. Ahora delega en 05-vpn.sh,
# que maneja los dos perfiles de la Tabla 45 (administración y docentes).
#
# Uso:  sudo bash 05-vpn-docente.sh '<clave pública de la notebook>' [10.8.0.130]
# =============================================================================
set -euo pipefail
exec bash "$(dirname "$0")/05-vpn.sh" agregar docente "${1:?Falta la clave pública del docente}" "${2:-10.8.0.130}" docente-remoto
