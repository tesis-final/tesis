#!/usr/bin/env bash
# =============================================================================
# ATLAS · Cobertura de las pruebas de la aplicación (informe de Testing del Hito 3)
#
# Corre juntas las pruebas unitarias, de API y de base de datos contra un MySQL 8.0
# descartable (tests/Database/run.sh) y mide:
#   1. Cobertura de código de app/ (líneas, métodos y clases), con pcov o xdebug.
#   2. Cobertura de rutas: qué rutas de /api/v1 alcanzan las pruebas de API y con qué
#      códigos de respuesta (ATLAS_RUTAS_CUBIERTAS en tests/Api/Cliente.php).
#
# Uso (desde atlas/):   tests/cobertura.sh [carpeta de salida]
# Deja en la carpeta: phpunit.txt, cobertura.txt, cobertura.xml (Clover) y rutas.txt.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

SALIDA="${1:-$(mktemp -d)}"
mkdir -p "$SALIDA"
SALIDA="$(cd "$SALIDA" && pwd)"

php -m | grep -qiE '^(pcov|xdebug)$' || { echo "Falta la extensión pcov o xdebug (por ejemplo: apt-get install php8.3-pcov)."; exit 2; }
php -m | grep -qi '^xdebug$' && export XDEBUG_MODE=coverage

RUTAS="$SALIDA/rutas-crudas.txt"
rm -f "$RUTAS" "$RUTAS.todas"
export ATLAS_RUTAS_CUBIERTAS="$RUTAS"
export ATLAS_TEST_SUITES="unit,api,database"
export ATLAS_PHPUNIT_ARGS="--configuration phpunit-cobertura.xml --coverage-text=$SALIDA/cobertura.txt --coverage-clover=$SALIDA/cobertura.xml"

tests/Database/run.sh "$SALIDA/phpunit.txt"
RC=$?

# Resumen de rutas: cada ruta de la API, si alguna prueba la alcanzó y con qué códigos.
python3 - "$RUTAS" "$SALIDA/rutas.txt" <<'PY'
import collections, sys
crudo, salida = sys.argv[1], sys.argv[2]
todas = [l.strip() for l in open(crudo + '.todas') if l.strip().split(' ', 1)[-1].startswith('api/v1')]
codigos = collections.defaultdict(set)
veces = collections.Counter()
for linea in open(crudo):
    ruta, codigo = linea.rstrip('\n').split('\t')
    codigos[ruta].add(codigo)
    veces[ruta] += 1
cubiertas = [r for r in todas if r in codigos]
con_error = [r for r in cubiertas if any(c[0] == '4' for c in codigos[r])]
with open(salida, 'w') as f:
    f.write(f'Rutas de /api/v1: {len(todas)}\n')
    f.write(f'Alcanzadas por las pruebas de API: {len(cubiertas)} ({100 * len(cubiertas) / len(todas):.1f} %)\n')
    f.write(f'Probadas también con una respuesta de error (4xx): {len(con_error)}\n')
    f.write(f'Pedidos hechos por las pruebas: {sum(veces.values())}\n\n')
    f.write(f'{"Ruta":58} {"Pedidos":>7}  Códigos\n')
    for r in todas:
        marca = ' '.join(sorted(codigos[r])) if r in codigos else 'SIN PRUEBA'
        f.write(f'{r:58} {veces[r]:>7}  {marca}\n')
print(open(salida).read())
PY

echo "== Cobertura de código (app/)"
grep -E 'Classes:|Methods:|Lines:' "$SALIDA/cobertura.txt" | head -3
echo "Archivos en: $SALIDA"
exit "$RC"
