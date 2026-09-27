#!/usr/bin/env bash
# =============================================================================
# ATLAS · Fase 6 · Paso 12 — sudo acotado (DEC-21) y herramientas de operación
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

paso "Herramientas en /usr/local/sbin (de root, no editables por atlasadmin)"
instalar_archivo "$DIR_ARCHIVOS/atlas-ctl" /usr/local/sbin/atlas-ctl 755
instalar_archivo "$DIR_LINUX/verificar.sh" /usr/local/sbin/atlas-verificar 755
# verificar.sh necesita sus parámetros: se copian junto a la herramienta.
instalar_archivo "$DIR_LINUX/parametros.conf" /usr/local/lib/atlas/parametros.conf 644
instalar_archivo "$DIR_LINUX/lib/comun.sh" /usr/local/lib/atlas/lib/comun.sh 644

paso "sudoers"
TMP="$(mktemp)"; cp "$DIR_ARCHIVOS/sudoers-atlas" "$TMP"
visudo -cf "$TMP" >/dev/null || error "sudoers con errores: no se instala."
instalar_archivo "$TMP" /etc/sudoers.d/atlas 440; rm -f "$TMP"
visudo -c >/dev/null

paso "Qué puede hacer atlasadmin con sudo:"
sudo -l -U atlasadmin | sed -n '/may run/,$p'
paso "Listo. Verificar todo con: sudo atlas-verificar"
