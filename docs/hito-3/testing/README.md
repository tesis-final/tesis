# Hito 3 de Testing · análisis de cobertura, calidad y conclusiones

Equipo Error404 · ATLAS · 20/11/2026

| Entregable | Dónde |
|---|---|
| Informe en Word (APA 7, mismo formato que el Hito 2) | [`../Hito3_Testing_ATLAS.docx`](../Hito3_Testing_ATLAS.docx) |
| Informe en PDF | [`../Hito3_Testing_ATLAS.pdf`](../Hito3_Testing_ATLAS.pdf) |
| Fuente del informe | `generar.js` (texto), `resultados.json` (cifras), `base.js` (formato) e `img/` (logos) |

Se regenera con `NODE_PATH=$(npm root -g) node docs/hito-3/testing/generar.js`.

## Resultados (entorno de pruebas, 20/11/2026)

| Medida | Resultado | Evidencia (`docs/evidencias/H/`) |
|---|---|---|
| Corrida completa de `probar-todo.sh` | 11 de 11 conjuntos aprobados (API 75/75) | `E-TST-011-ejecucion-2026-11-20/` |
| Cobertura de PHP (`atlas/app/`) | 91,8 % de líneas, 82,1 % de métodos (antes de las pruebas nuevas: 91,0 % y 80,3 %) | `E-TST-012-cobertura/php-antes/` y `php-despues/` |
| Cobertura de rutas de la API | 44 de 44 (antes: 41) | `E-TST-012-cobertura/php-despues/rutas.txt` |
| Cobertura del servicio de análisis | 76 % (sentencias y ramas) | `E-TST-012-cobertura/python-cobertura.txt` |
| Cobertura del JavaScript de la interfaz | 81,2 % | `E-TST-012-cobertura/javascript-cobertura.txt` |
| Análisis estático | PSR-12, php -l y node --check sin errores; ShellCheck 10 advertencias → 0; Ruff sin errores lógicos | `E-TST-013-calidad-estatica/` |
| Prueba de interfaz | 32/32, repetible (INC-T2 cerrada) | `E-TST-014-interfaz/` |
| Tiempo de respuesta | percentil 95 máximo de 51 ms | `E-TST-015-rendimiento.txt` |
| Disponibilidad (10 min) | 60 de 60 | `E-TST-016-disponibilidad.txt` |
| Base de datos | seguimiento 6/6; 0 diferencias de puntaje en 8749; restauración 13/13; métricas 6 PASS | `E-TST-017-base-de-datos/` |

Las pruebas del laboratorio (19 y 20/11) están en `docs/hito-3/capturas/`.

## Cómo medir la cobertura

```bash
cd atlas && tests/cobertura.sh /tmp/cobertura              # PHP y rutas (necesita pcov o xdebug)
ATLAS_COBERTURA_JS=/tmp/js.txt python3 atlas/tests/e2e/interfaz.py https://localhost <carpeta> <clave>
```
