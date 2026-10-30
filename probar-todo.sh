#!/usr/bin/env bash
# =============================================================================
# ATLAS — correr TODAS las pruebas automáticas que no necesitan el laboratorio.
#
# Requisitos: Docker, PHP 8.3 + Composer (o se instala vendor/ al empezar) y,
# para las pruebas de red, ser root en Linux (espacios de red y nftables).
#
#   ./probar-todo.sh                      todas
#   ./probar-todo.sh unit api firewall    solo esas
#   SALIDA=/otra/carpeta ./probar-todo.sh
#   CA_EXTRA=/ruta/ca.crt ./probar-todo.sh   si la red sale por un proxy con
#                                            certificado propio (pip en contenedores)
#
# Conjuntos: unit psr12 bd api analisis firewall windows linux gemelo cisco
# Cada uno guarda su salida completa en resultados-pruebas/<fecha>/<conjunto>.txt
# y al final se imprime una tabla. Termina con código 1 si alguno falló.
# La prueba de interfaz (Playwright) se corre aparte, con la pila levantada
# (ver docs/hito-2/testing.md), y los verificadores del laboratorio adentro de las VM.
# =============================================================================
set -uo pipefail
RAIZ="$(cd "$(dirname "$0")" && pwd)"
cd "$RAIZ"
SALIDA="${SALIDA:-$RAIZ/resultados-pruebas/$(date +%Y-%m-%d_%H%M)}"
mkdir -p "$SALIDA"
TODOS=(unit psr12 bd api analisis firewall windows linux gemelo cisco)
[ $# -gt 0 ] && PEDIDOS=("$@") || PEDIDOS=("${TODOS[@]}")

declare -A ESTADO DETALLE
hay() { command -v "$1" >/dev/null 2>&1; }
commit() { echo "$(git rev-parse --short HEAD 2>/dev/null || echo '?')$(git diff --quiet HEAD 2>/dev/null || echo ' + cambios sin commitear')"; }
encabezado() { echo "# $1"; echo "# Fecha: $(date -u +%Y-%m-%dT%H:%M:%SZ) · Equipo: $(uname -sr) · Commit: $(commit)"; echo; }
# Variables del proxy (si las hay) para los contenedores que instalan paquetes.
PROXY=(); for v in HTTP_PROXY HTTPS_PROXY http_proxy https_proxy NO_PROXY no_proxy; do [ -n "${!v:-}" ] && PROXY+=(-e "$v"); done
CA=(); [ -n "${CA_EXTRA:-}" ] && CA=(-v "$CA_EXTRA:/ca-extra.crt:ro" -e PIP_CERT=/ca-extra.crt)

vendor() {
  [ -x atlas/vendor/bin/phpunit ] && return 0
  echo "→ Instalando dependencias de PHP (composer install)"
  (cd atlas && composer install --no-interaction --no-progress -q)
}

# --- un bloque por conjunto: imprime la salida y devuelve 0 si pasó ----------
p_unit()   { vendor && (cd atlas && vendor/bin/phpunit --testsuite unit --testdox --colors=never); }
p_psr12()  { vendor && (cd atlas && vendor/bin/phpcs --standard=PSR12 app bootstrap config routes lang public/index.php bin tests && echo "PSR-12: sin errores ni advertencias"); }
p_bd()     { vendor && (cd atlas && tests/Database/run.sh); }
p_api()    { vendor && (cd atlas && ATLAS_TEST_SUITES=api tests/Database/run.sh); }
p_analisis() {
  if python3 -c 'import fastapi, sklearn, pytest' 2>/dev/null; then
    (cd atlas-analysis && python3 -m pytest -v -p no:cacheprovider)
  else
    docker run --rm --network host "${PROXY[@]}" "${CA[@]}" -v "$RAIZ/atlas-analysis:/src:ro" python:3.11-slim bash -c \
      'cp -r /src /app && cd /app && pip install -q --disable-pip-version-check -r requirements-dev.txt && python -m pytest -v -p no:cacheprovider'
  fi
}
p_firewall() {
  [ "$(id -u)" -eq 0 ] || { echo "NO EJECUTADA: hace falta root (espacios de red y nftables)."; return 2; }
  hay ip && hay nft || { echo "NO EJECUTADA: faltan iproute2 o nftables."; return 2; }
  bash infra/red/pruebas/probar-router-lab.sh
}
p_windows() {
  if hay pwsh; then pwsh -NoProfile -File infra/windows/pruebas/probar-modulo.ps1
  else docker run --rm -v "$RAIZ/infra/windows:/w:ro" mcr.microsoft.com/powershell:7.4-ubuntu-22.04 pwsh -NoProfile -File /w/pruebas/probar-modulo.ps1
  fi
}
imagen_ubuntu() {
  docker image inspect atlas-ubuntu-test:24.04 >/dev/null 2>&1 && return 0
  docker build -q --network host "${PROXY[@]/#-e/--build-arg}" -t atlas-ubuntu-test:24.04 infra/linux/pruebas >/dev/null
}
p_linux()  { imagen_ubuntu && infra/linux/pruebas/probar-en-contenedor.sh; }
p_gemelo() { imagen_ubuntu && docker run --rm --privileged -v "$RAIZ/infra/red:/red:ro" atlas-ubuntu-test:24.04 bash /red/pruebas/gemelo-red.sh; }
p_cisco()  { python3 -I infra/red/pruebas/revisar_configuraciones.py; }

# Resumen de una salida: la línea final de PHPUnit, pytest o los "Resultado:" propios.
# Si hay varias líneas "Resultado: N PASS · M FAIL" (una por sección), se suman.
resumen() {
  local n; n=$(grep -acE '^Resultado: [0-9]+ PASS' "$1")
  if [ "$n" -gt 1 ]; then
    grep -aoE '^Resultado: [0-9]+ PASS[ ,·]+[0-9]+ FAIL' "$1" | grep -oE '[0-9]+' | paste - - |
      awk -v n="$n" '{p+=$1; f+=$2} END {printf "Resultado: %d PASS · %d FAIL (%d secciones)\n", p, f, n}'
  else
    grep -aE '^(OK \(|Tests: |FAILURES!|Resultado: |=+ .*(passed|failed)|PSR-12:|NO EJECUTADA)' "$1" | tail -1 | sed 's/=//g; s/^ *//'
  fi
}

for c in "${PEDIDOS[@]}"; do
  declare -F "p_$c" >/dev/null || { echo "Conjunto desconocido: $c (opciones: ${TODOS[*]})"; exit 2; }
  printf '→ %-9s ' "$c"
  { encabezado "ATLAS · prueba '$c' · ./probar-todo.sh $c"; "p_$c"; r=$?; echo; echo "rc=$r"; } > "$SALIDA/$c.txt" 2>&1
  rc=$(tail -1 "$SALIDA/$c.txt" | sed 's/rc=//')
  case "$rc" in 0) ESTADO[$c]=Aprobada ;; 2) ESTADO[$c]="No ejecutada" ;; *) ESTADO[$c]=Fallada ;; esac
  DETALLE[$c]="$(resumen "$SALIDA/$c.txt")"
  echo "${ESTADO[$c]}  ${DETALLE[$c]}"
done

{
  echo "# Resumen · $(date '+%Y-%m-%d %H:%M') · commit $(commit)"
  printf '%-10s %-13s %s\n' Conjunto Estado Detalle
  for c in "${PEDIDOS[@]}"; do printf '%-10s %-13s %s\n' "$c" "${ESTADO[$c]}" "${DETALLE[$c]}"; done
} | tee "$SALIDA/resumen.txt"
echo "Salidas completas en: $SALIDA"
for c in "${PEDIDOS[@]}"; do [ "${ESTADO[$c]}" = Fallada ] && exit 1; done
exit 0
