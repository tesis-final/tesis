#!/usr/bin/env bash
# =============================================================================
# ATLAS — probar todo en tu PC con un solo comando.
#
# Requisito: Docker (Docker Desktop en Windows/Mac, o Docker Engine en Linux).
# En Windows correrlo desde Git Bash o desde WSL.
#
#   ./probar-local.sh            levanta ATLAS con datos de demostración
#   ./probar-local.sh detener    apaga los contenedores (los datos quedan)
#   ./probar-local.sh borrar     apaga y borra todo lo generado (base incluida)
#
# Abre en https://localhost (el certificado es autofirmado: el navegador avisa;
# es normal en una prueba local). No toca nada fuera de la carpeta atlas/local/.
# =============================================================================
set -euo pipefail
# Git Bash (Windows) convierte las rutas que empiezan con / (p. ej. /tls dentro del
# contenedor) en rutas de Windows y rompe los docker run. En Linux/Mac no hace nada.
export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")/atlas"
L=local
COMPOSE=(docker compose --env-file "$L/atlas.conf" -f docker-compose.yml -f docker-compose.local.yml)

case "${1:-}" in
  detener) "${COMPOSE[@]}" down; exit 0 ;;
  borrar)  [ -f "$L/atlas.conf" ] && "${COMPOSE[@]}" down -v || true
           docker run --rm -v "$PWD:/w" alpine rm -rf "/w/$L"   # los datos son del usuario 5003
           echo "Borrado."; exit 0 ;;
esac

command -v docker >/dev/null || { echo "Falta Docker: https://docs.docker.com/get-docker/"; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker no está corriendo (abrí Docker Desktop)."; exit 1; }

# (tr termina con SIGPIPE cuando head ya leyó lo suficiente: no es un error)
aleatorio() { local r; r="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 24 || true)"; printf '%s' "$r"; }

mkdir -p "$L/datos" "$L/logs" "$L/tls"
if [ ! -f "$L/atlas.conf" ]; then
  echo "→ Generando local/atlas.conf con contraseñas al azar (solo para esta PC)"
  DEMO="$(aleatorio)"; DEMO="Demo-${DEMO:0:10}"
  while IFS= read -r linea || [ -n "$linea" ]; do
    case "$linea" in
      ATLAS_BIND_IP=*)          linea="ATLAS_BIND_IP=127.0.0.1" ;;
      ATLAS_CONF=*)             linea="ATLAS_CONF=./local/atlas.conf" ;;
      ATLAS_ADMIN_CONTRASENA=*) linea="ATLAS_ADMIN_CONTRASENA=$(aleatorio)" ;;
      ATLAS_DEMO_CONTRASENA=*)  linea="ATLAS_DEMO_CONTRASENA=$DEMO" ;;
      LLM_API_KEY=*)            linea="LLM_API_KEY=" ;;
      *=CAMBIAR)                linea="${linea%CAMBIAR}$(aleatorio)" ;;
    esac
    printf '%s\n' "$linea"
  done < .env.example > "$L/atlas.conf.tmp"
  printf '\n# Solo en la PC: Docker Desktop no tiene journald.\nATLAS_LOG_DRIVER=json-file\n' >> "$L/atlas.conf.tmp"
  mv "$L/atlas.conf.tmp" "$L/atlas.conf"
fi

if [ ! -f "$L/tls/atlas.crt" ]; then
  echo "→ Certificado autofirmado para localhost"
  docker run --rm -v "$PWD/$L/tls:/tls" --entrypoint openssl mysql:8.0 req -x509 -newkey rsa:2048 -nodes \
    -keyout /tls/atlas.key -out /tls/atlas.crt -days 365 -subj "/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" >/dev/null 2>&1
fi

# Los contenedores corren con usuarios propios (5002 web, 5003 base), como en el servidor.
docker run --rm -v "$PWD/$L:/l" alpine sh -c "chown -R 5003:5003 /l/datos && chown -R 5002:5002 /l/logs && chmod 644 /l/tls/*"

echo "→ Construyendo y levantando los contenedores (la primera vez tarda unos minutos)"
"${COMPOSE[@]}" up -d --build

echo -n "→ Esperando a que ATLAS responda"
for _ in $(seq 1 90); do
  if docker exec atlas-web wget -q --no-check-certificate -O /dev/null https://127.0.0.1/api/v1/health 2>/dev/null; then echo " ✔"; break; fi
  echo -n "."; sleep 4
done
docker exec atlas-web wget -q --no-check-certificate -O - https://127.0.0.1/api/v1/health; echo

if [ ! -f "$L/.demo-cargada" ]; then
  echo "→ Cargando datos de DEMOSTRACIÓN (sintéticos: 1 grupo, 12 estudiantes, 3 actividades)"
  docker exec atlas-php php bin/atlas demo:datos-sinteticos && touch "$L/.demo-cargada"
fi

DEMO="$(grep '^ATLAS_DEMO_CONTRASENA=' "$L/atlas.conf" | cut -d= -f2)"
cat <<TXT

  ATLAS está funcionando en:  https://localhost
  (el navegador avisa del certificado: "Avanzado" → "Continuar")

  Cuentas de prueba (todas con la contraseña: $DEMO)
    Administrador:  coordinacion.demo@atlas.local
    Docente:        docente.demo@atlas.local
    Estudiante:     ana.demo@atlas.local  (también bruno, camila, diego…)

  Para apagar:  ./probar-local.sh detener
  Para borrar todo y empezar de cero:  ./probar-local.sh borrar
TXT
