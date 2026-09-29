#!/usr/bin/env bash
# =============================================================================
# ATLAS · Fase 6 · Paso 7 — Puesta en marcha de ATLAS en atlas-srv01
#
#  1. /srv/atlas/config/atlas.conf con secretos aleatorios (CT-12). Nunca en Git.
#  2. Clave TLS + pedido de certificado (CSR) para ATLAS-CA (DEC-20). Mientras la
#     CA no lo firme, se usa un certificado TEMPORAL autofirmado.
#  3. Copia de la aplicación a /srv/atlas/web (desplegar-app.sh).
#  4. Servicio systemd atlas.service (CT-03) y primer arranque.
#  5. Primer administrador de ATLAS; su contraseña se muestra UNA vez y se borra
#     de atlas.conf.
#
# Uso: sudo ATLAS_REPO_TESIS=/opt/atlas/tesis ./07-atlas.sh
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

REPO="${ATLAS_REPO_TESIS:-/opt/atlas/tesis}"
ANALISIS="${ATLAS_REPO_ANALISIS:-$REPO/atlas-analysis}"
CONF="$ATLAS_ROOT/config/atlas.conf"
TLS="$ATLAS_ROOT/config/tls"
[ -f "$REPO/atlas/docker-compose.yml" ] || error "No encuentro el repositorio tesis en $REPO (git clone https://github.com/SVinas73/tesis $REPO)."
[ -f "$ANALISIS/Dockerfile" ] || error "No encuentro el servicio de análisis en $ANALISIS (carpeta atlas-analysis del repositorio)."
[ -d "$ATLAS_ROOT/config" ] || error "Falta $ATLAS_ROOT/config: correr antes el paso 3."

secreto() { openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32; }

# ---------------------------------------------------------------------------
paso "1/5 Archivo de secretos $CONF"
chattr -i "$CONF" 2>/dev/null || true
CONTRASENA_ADMIN=""
if ! grep -q '^MYSQL_ROOT_PASSWORD=' "$CONF" 2>/dev/null; then
  CONTRASENA_ADMIN="$(secreto)"
  sed -e "s/^\(MYSQL_ROOT_PASSWORD\|ATLAS_DB_[A-Z]*_PASSWORD\)=CAMBIAR$/\1=__SECRETO__/" \
      -e "s/^ATLAS_ADMIN_CONTRASENA=.*/ATLAS_ADMIN_CONTRASENA=$CONTRASENA_ADMIN/" \
      -e "s/^ATLAS_DEMO_CONTRASENA=.*/ATLAS_DEMO_CONTRASENA=/" \
      -e "s/^LLM_API_KEY=.*/LLM_API_KEY=/" \
      -e "s/^ATLAS_BIND_IP=.*/ATLAS_BIND_IP=$ATLAS_IP/" \
      "$REPO/atlas/.env.example" > "$CONF.nuevo"
  # Cada contraseña distinta (una por usuario de MySQL, Tabla 21).
  while grep -q '__SECRETO__' "$CONF.nuevo"; do
    sed -i "0,/__SECRETO__/s//$(secreto)/" "$CONF.nuevo"
  done
  cat "$CONF.nuevo" > "$CONF"; rm -f "$CONF.nuevo"
  echo "   Generado con contraseñas aleatorias."
else
  echo "   Ya existía: no se modifica."
fi
grep -q '=CAMBIAR' "$CONF" && error "Quedan valores CAMBIAR en $CONF."
grep -q '^LLM_API_KEY=$' "$CONF" && aviso "LLM_API_KEY vacía: el asistente responde con los datos verificados, sin redactar con el LLM (RNF-15). Para activarlo: chattr -i, editar, chattr +i."
chown atlasadmin:atlas-admin "$CONF"; chmod 640 "$CONF"

# ---------------------------------------------------------------------------
paso "2/5 Certificado TLS (DEC-20: CN atlas-srv01.atlas.local, SAN IP $ATLAS_IP)"
if [ ! -f "$TLS/atlas.key" ]; then
  openssl req -new -newkey rsa:3072 -nodes -keyout "$TLS/atlas.key" -out "$TLS/atlas.csr" \
    -subj "/C=UY/O=ITI-CETP UTU/OU=ATLAS/CN=$ATLAS_HOSTNAME.$ATLAS_DOMINIO" \
    -addext "subjectAltName=DNS:$ATLAS_HOSTNAME.$ATLAS_DOMINIO,DNS:$ATLAS_HOSTNAME,IP:$ATLAS_IP" \
    -addext "extendedKeyUsage=serverAuth" 2>/dev/null
  openssl x509 -req -in "$TLS/atlas.csr" -signkey "$TLS/atlas.key" -days 30 -out "$TLS/atlas.crt" \
    -copy_extensions copyall 2>/dev/null
  echo "   CSR listo en $TLS/atlas.csr → firmarlo en atlas-dc01 (Fase 7, 10-certificado-srv01.ps1)."
  echo "   Mientras tanto: certificado TEMPORAL autofirmado (30 días)."
fi
chown -R atlasadmin:atlas-admin "$TLS"; chmod 640 "$TLS"/*

if [ "${ATLAS_SOLO_CONFIG:-0}" = 1 ]; then paso "ATLAS_SOLO_CONFIG=1: se detiene después de la configuración."; exit 0; fi

# ---------------------------------------------------------------------------
paso "3/5 Copia de la aplicación"
ATLAS_ROOT="$ATLAS_ROOT" "$DIR_LINUX/desplegar-app.sh" "$REPO" "$ANALISIS"

# ---------------------------------------------------------------------------
paso "4/5 Servicio atlas.service"
# Durante la instalación con el adaptador NAT la IP del laboratorio todavía no
# existe y Docker no podría publicar 443 en ella: se agrega un momento en "lo".
# Al reiniciar con la red del laboratorio (netplan), la IP pasa a la interfaz real.
if ! ip -4 -o addr show | grep -q " $ATLAS_IP/"; then
  aviso "$ATLAS_IP no está configurada todavía: se agrega temporalmente en 'lo' para poder probar ATLAS."
  ip addr add "$ATLAS_IP/32" dev lo
fi
instalar_archivo "$DIR_ARCHIVOS/atlas.service" /etc/systemd/system/atlas.service 644
svc daemon-reload
svc enable atlas.service >/dev/null
svc restart atlas.service
echo -n "   Esperando a que ATLAS responda"
for _ in $(seq 1 90); do
  if curl -fsk --max-time 3 "https://$ATLAS_IP/api/v1/health" >/dev/null 2>&1; then echo " ✔"; break; fi
  echo -n "."; sleep 5
done
curl -sk "https://$ATLAS_IP/api/v1/health"; echo

# ---------------------------------------------------------------------------
paso "5/5 Primer administrador de ATLAS"
if [ -n "$CONTRASENA_ADMIN" ]; then
  docker exec atlas-php php bin/atlas usuario:crear-admin
  sed -i "s/^ATLAS_ADMIN_CONTRASENA=.*/ATLAS_ADMIN_CONTRASENA=/" "$CONF"
  docker compose --env-file "$CONF" -f "$ATLAS_ROOT/config/docker-compose.yml" up -d --force-recreate atlas-php >/dev/null
  echo
  echo "   ┌──────────────────────────────────────────────────────────────┐"
  echo "   │ Usuario: $(grep '^ATLAS_ADMIN_CORREO=' "$CONF" | cut -d= -f2)"
  echo "   │ Contraseña (se muestra solo esta vez): $CONTRASENA_ADMIN"
  echo "   │ Guardarla en el gestor de contraseñas del equipo.            │"
  echo "   └──────────────────────────────────────────────────────────────┘"
else
  echo "   El administrador ya se había creado antes."
fi
chattr +i "$CONF" 2>/dev/null || aviso "No se pudo aplicar chattr +i a $CONF."

paso "Listo. Siguiente: 08-hora.sh"
