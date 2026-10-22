#!/usr/bin/env bash
# =============================================================================
# ATLAS — copia la aplicación a la estructura de §28.3 (fase-02/02-arquitectura §3).
#
#   /srv/atlas/web/public   ← atlas/public          (atlasweb:atlas-web 755)
#   /srv/atlas/web/app      ← atlas/{app,bootstrap,config,database,docker,lang,routes,bin,vendor}  (750)
#                             (vendor/ se instala acá con Composer, sin dependencias de desarrollo)
#   /srv/atlas/web/analysis ← carpeta atlas-analysis del mismo repositorio
#
# Uso: sudo ATLAS_ROOT=/srv/atlas ./desplegar-app.sh <ruta_repo_tesis> [ruta_atlas_analysis]
# En un entorno de prueba se puede usar otro ATLAS_ROOT y SIN_CHOWN=1.
# =============================================================================
set -euo pipefail

REPO="${1:?ruta del repositorio tesis}"
ANALISIS="${2:-$REPO/atlas-analysis}"
ROOT="${ATLAS_ROOT:-/srv/atlas}"

echo "→ Preparando el código (Laravel + dependencias de producción, sin herramientas de desarrollo)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp -a "$REPO/atlas/." "$TMP/"
rm -rf "$TMP/vendor" "$TMP/tests" "$TMP/.phpunit.cache" "$TMP/.env" "$TMP/local" "$TMP/docker-compose.local.yml" \
       "$TMP/storage" "$TMP/bootstrap/cache"
# Acta D-1: la aplicación es Laravel y necesita vendor/. Se instala con la imagen oficial
# de Composer (Docker ya está instalado, 06-docker.sh): el servidor no necesita PHP ni
# Composer propios. Versiones exactas de composer.lock; sin PHPUnit ni el linter (--no-dev).
# pdo_mysql no está en la imagen de Composer pero sí en atlas-php, que es donde corre.
docker run --rm -v "$TMP:/app" -w /app composer:2 install --no-dev --no-interaction --no-progress \
  --optimize-autoloader --ignore-platform-req=ext-pdo_mysql
[ -f "$TMP/vendor/autoload.php" ] || { echo "No se pudo instalar vendor/ (¿salida a Internet?)" >&2; exit 1; }

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
if [ "${SIN_CHOWN:-0}" != "1" ] && [ -x "$(dirname "$0")/03-directorios-permisos.sh" ]; then
  echo "→ Reaplicando las ACL de la Tabla 27"
  "$(dirname "$0")/03-directorios-permisos.sh" --acl >/dev/null
fi
echo "Listo. Siguiente: docker compose --env-file $ROOT/config/atlas.conf -f $ROOT/config/docker-compose.yml up -d --build"
