#!/usr/bin/env bash
# =============================================================================
# ATLAS — copia la aplicación a la estructura de §28.3 (fase-02/02-arquitectura §3).
#
#   /srv/atlas/web/public   ← atlas/public          (atlasweb:atlas-web 755)
#   /srv/atlas/web/app      ← atlas/{app,config,database,docker,bin,vendor}  (750)
#   /srv/atlas/web/analysis ← repositorio atlas-analysis
#
# Uso: sudo ATLAS_ROOT=/srv/atlas ./desplegar-app.sh <ruta_repo_tesis> <ruta_repo_atlas_analysis>
# En un entorno de prueba se puede usar otro ATLAS_ROOT y SIN_CHOWN=1.
# =============================================================================
set -euo pipefail

REPO="${1:?ruta del repositorio tesis}"
ANALISIS="${2:?ruta del repositorio atlas-analysis}"
ROOT="${ATLAS_ROOT:-/srv/atlas}"

command -v composer >/dev/null || { echo "Falta composer"; exit 1; }

echo "→ Dependencias de producción (sin herramientas de desarrollo)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp -a "$REPO/atlas/." "$TMP/"
rm -rf "$TMP/vendor" "$TMP/tests" "$TMP/.phpunit.cache"
composer install --no-dev --optimize-autoloader --no-interaction --working-dir="$TMP" >/dev/null

echo "→ Copiando a $ROOT/web"
mkdir -p "$ROOT/web/public" "$ROOT/web/app" "$ROOT/web/analysis" "$ROOT/logs" "$ROOT/datos" "$ROOT/config/tls"
rsync -a --delete "$TMP/public/" "$ROOT/web/public/"
rsync -a --delete --exclude public --exclude '.env*' "$TMP/" "$ROOT/web/app/"
rsync -a --delete --exclude .git --exclude tests --exclude '.venv' "$ANALISIS/" "$ROOT/web/analysis/"
cp "$REPO/atlas/docker-compose.yml" "$ROOT/config/docker-compose.yml"

if [ "${SIN_CHOWN:-0}" != "1" ]; then
  echo "→ Dueños y permisos (§28.3)"
  chown -R atlasweb:atlas-web "$ROOT/web"
  find "$ROOT/web/public" -type d -exec chmod 755 {} + ; find "$ROOT/web/public" -type f -exec chmod 644 {} +
  chmod 750 "$ROOT/web" "$ROOT/web/app" "$ROOT/web/analysis"
fi
echo "Listo. Siguiente: docker compose --env-file $ROOT/config/atlas.conf -f $ROOT/config/docker-compose.yml up -d --build"
