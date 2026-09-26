# atlas-analysis

Servicio de análisis de **ATLAS** (TC4 — Error404, ITI-CETP/UTU). Corre en el
contenedor `atlas-analysis` (PDF Tabla 15: `python:3.11-slim`) y cubre:

| Nivel | Qué hace | Requisito |
|---|---|---|
| 2 — Patrones | Agrupamiento K-means (k ∈ {2,3,4}, silueta ≥ 0,25) y estimación de riesgo con regresión logística (AUC con validación cruzada de 5 pliegues). | RF-19 |
| 3 — Redacción | Cliente del LLM (Groq, API compatible con OpenAI). Recibe **solo** datos ya anonimizados por la aplicación PHP y devuelve texto. | RF-20 |

El Nivel 1 (indicadores y reglas R01–R08) vive en la aplicación PHP: ATLAS
funciona completo aunque este servicio esté caído (RNF-15; prueba
`PanelGrupalTest::testSinServicioDeAnalisis*`). Diseño completo:
`tesis/docs/fase-02-arquitectura/04-motor-analisis.md`.

## Reglas de diseño

- **Suficiencia de datos antes que modelos.** Si no hay ≥ 20 estudiantes con
  ≥ 5 intentos finalizados, no se entrena nada y la respuesta lo dice
  (`suficiente: false` con los números reales). Para la regresión logística
  se exigen además ≥ 100 ejemplos y cada clase ≥ 20 %.
- **Sin datos personales.** El usuario de base de datos `atlas_analysis` no
  puede leer nombres ni correos (verificado en
  `tesis/atlas/tests/Database/PrivilegiosTest.php`); trabaja con ids.
- **Solo escribe en tablas de análisis** (`agrupamientos` e `indicadores` con origen `NIVEL2`),
  nunca en datos académicos.
- **Barrera final antes del LLM.** `app/llm/client.py` rechaza cualquier texto
  que contenga un correo o un número con forma de cédula, aunque la aplicación
  ya lo haya anonimizado.
- **Sin secretos en el código.** Todo sale del entorno (`/srv/atlas/config/atlas.conf`).

## API interna (solo red `atlas_back`, sin puerto publicado)

| Método | Ruta | Uso |
|---|---|---|
| GET | `/health` | Salud y conexión a MySQL |
| GET | `/v1/grupos/{grupo}/estado?desde=AAAA-MM-DD&hasta=AAAA-MM-DD` | Suficiencia de datos y último resultado |
| POST | `/v1/grupos/{grupo}/recalcular` | Recalcula agrupamiento y riesgo del período |
| POST | `/v1/llm/redactar` | Redacta la respuesta del asistente a partir de datos anonimizados |

## Variables de entorno

| Variable | Valor por defecto |
|---|---|
| `ATLAS_DB_HOST` / `ATLAS_DB_PORT` / `ATLAS_DB_NAME` | `atlas-db` / `3306` / `atlas_db` |
| `ATLAS_DB_ANALYSIS_USER` / `ATLAS_DB_ANALYSIS_PASSWORD` | `atlas_analysis` / *(obligatoria)* |
| `LLM_PROVIDER` / `LLM_API_URL` | `groq` / `https://api.groq.com/openai/v1` |
| `LLM_API_KEY` | *(vacía = asistente sin LLM: responde con los datos verificados)* |
| `LLM_MODEL` / `LLM_TIMEOUT` | `llama-3.3-70b-versatile` / `25` |
| `ML_MIN_ESTUDIANTES` / `ML_MIN_INTENTOS_POR_ESTUDIANTE` | `20` / `5` |

## Desarrollo y pruebas

```bash
python3.11 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt
python -m pytest -v          # 23 pruebas; no necesitan MySQL ni Internet
```

Construcción de la imagen (la hace `docker compose` desde el repositorio `tesis`):

```bash
docker build -t atlas/analysis:1.0 .
```

## Estructura

```
app/
  config.py        variables de entorno
  db.py            consultas (usuario atlas_analysis, solo ids)
  features.py      6 variables por estudiante
  servicio.py      suficiencia, entrenamiento y escritura de resultados
  models/          clustering.py (K-means) · risk.py (regresión logística)
  llm/             client.py (Groq + barrera de privacidad) · prompts.py
  main.py          FastAPI
tests/             pytest (datos sintéticos)
```
