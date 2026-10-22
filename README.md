# ATLAS — Plataforma Inteligente de Aprendizaje Adaptativo

Proyecto de **TC4 — Grupo Error404** (ITI-CETP/UTU). La especificación que manda sobre todo es
[`docs/especificacion/TC4-Error404-ATLAS-V2.2.pdf`](docs/especificacion/TC4-Error404-ATLAS-V2.2.pdf).

## Probar ATLAS en tu PC

Solo hace falta **Docker** ([Docker Desktop](https://www.docker.com/products/docker-desktop/) en Windows o Mac; Docker Engine en Linux).

```bash
git clone https://github.com/tesis-final/tesis
cd tesis
./probar-local.sh
```

En Windows, correr esos comandos en **Git Bash** o en **WSL** (Docker Desktop tiene que estar abierto).

La primera vez tarda unos minutos (descarga las imágenes y construye los contenedores). Al terminar muestra la dirección y las cuentas:

| Qué | Valor |
| --- | --- |
| Dirección | https://localhost (el navegador avisa del certificado autofirmado: *Avanzado → Continuar*) |
| Administrador | `coordinacion.demo@atlas.local` |
| Docente | `docente.demo@atlas.local` |
| Estudiantes | `ana.demo@atlas.local`, `bruno.demo@atlas.local`, `camila.demo@atlas.local`… |
| Contraseña | La muestra el script al final (es la misma para todas las cuentas de prueba) |

Los datos son **sintéticos** (un grupo 3A con 12 estudiantes y 3 actividades), solo para probar.

| Comando | Qué hace |
| --- | --- |
| `./probar-local.sh` | Levanta ATLAS (si ya estaba, lo deja como está) |
| `./probar-local.sh detener` | Apaga los contenedores; los datos quedan |
| `./probar-local.sh borrar` | Apaga y borra todo lo generado, para empezar de cero |

Qué probar, por perfil:

- **Estudiante**: resolver una actividad (una pregunta por vez) y ver el resultado con el tiempo total y el tiempo activo; ver primero la actividad que le recomendó su docente.
- **Docente**: el panel "¿Dónde intervenir hoy?"; **Consultas** (grupo + período + qué ver); el análisis del grupo 3A con el acierto por habilidad; en el perfil de un estudiante, el botón "¿Por qué?" y **confirmar o cambiar** la actividad sugerida; crear una actividad marcando qué habilidades mide cada pregunta y publicarla (por defecto sin aprobación previa); el asistente (opcional).
- **Administrador**: usuarios, grupos, **instituciones** (exigir o no aprobación antes de publicar), aprobar actividades si la institución lo exige, editar las reglas del motor, auditoría.

El asistente funciona sin Internet con los datos verificados. Para que redacte con Groq, poner la clave en `atlas/local/atlas.conf` (`LLM_API_KEY=…`) y volver a correr `./probar-local.sh`. El aprendizaje automático (Nivel 2) va a decir "datos insuficientes": necesita 20 estudiantes con 5 intentos y la demo tiene 12. Es el comportamiento correcto.

Todo lo que genera el script queda en `atlas/local/` (ignorado por Git). No toca nada fuera de esa carpeta.

## Qué hay en el repositorio

| Carpeta | Contenido |
| --- | --- |
| `atlas/` | Aplicación en **Laravel 12** (API `/api/v1`, middleware, validación) con la lógica propia en PHP (servicios, motor de reglas, indicadores), interfaz web, base de datos y contenedores |
| `atlas-analysis/` | Servicio Python: aprendizaje automático y conexión con el modelo de lenguaje |
| `infra/linux/` | Scripts de atlas-srv01 (Fase 6) |
| `infra/windows/` | Scripts de atlas-dc01 (Fase 7) |
| `infra/red/` | Configuraciones de switch, router y firewall (Fase 8) |
| `docs/` | Auditoría, decisiones, manuales de cada fase, evidencias, el [reporte del Hito 1](docs/reporte-hito-1/README.md) y lo hecho en el [Hito 2](docs/hito-2/README.md) |

## Pruebas automáticas (para desarrollo)

```bash
cd atlas && composer install && vendor/bin/phpunit --testsuite unit     # PHP: unitarias y rutas
ATLAS_TEST_SUITES=api tests/Database/run.sh                             # API (a través de Laravel) contra MySQL real
tests/Database/run.sh                                                   # base de datos contra MySQL real
cd ../atlas-analysis && pip install -r requirements.txt -r requirements-dev.txt && python -m pytest
```

`run.sh` usa la misma subred que la app levantada: antes de correrlo, `./probar-local.sh detener`. Si no tenés PHP instalado, los comandos de PHP se pueden correr dentro del contenedor (ver [fase-04 §7](docs/fase-04-aplicacion/README.md#7-cómo-reproducir)). La prueba de la interfaz en un navegador real está en `atlas/tests/e2e/interfaz.py`.
