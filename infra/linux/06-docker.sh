#!/usr/bin/env bash
# =============================================================================
# ATLAS · Fase 6 · Paso 6 — Docker Engine (PDF §25.5, Tabla 15; DEC-02, CT-03)
#
# /etc/docker/daemon.json:
#   · journald: los logs de los contenedores quedan en journalctl (§30.5);
#   · live-restore: reiniciar dockerd no corta los contenedores;
#   · no-new-privileges: ningún proceso de contenedor puede ganar privilegios (setuid);
#   · bip + default-address-pools: redes internas de Docker en 192.168.250–251.x,
#     lejos de 172.16.0.0/16 (VLAN), 10.8.0.0/24 (VPN) y de las redes de casa (CT-07, CT-16).
#
# atlasadmin NO entra al grupo docker: pertenecer a ese grupo equivale a ser root (DEC-21).
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

command -v dockerd >/dev/null || error "Falta docker.io (paso 1)."
docker compose version >/dev/null 2>&1 || error "Falta docker-compose-v2 (paso 1)."

paso "Configuración del daemon"
instalar_archivo "$DIR_ARCHIVOS/docker-daemon.json" /etc/docker/daemon.json 644
svc enable docker >/dev/null
svc restart docker

if id -nG atlasadmin 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
  gpasswd -d atlasadmin docker
  aviso "Se quitó a atlasadmin del grupo docker (DEC-21)."
fi

# UFW necesita volver a cargar DOCKER-USER después de que Docker arma sus cadenas.
ufw reload >/dev/null 2>&1 || true

docker info --format 'Docker {{.ServerVersion}} · logs={{.LoggingDriver}} · cgroup={{.CgroupDriver}}'
paso "Listo. Siguiente: 07-atlas.sh"
