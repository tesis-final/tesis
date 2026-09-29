# Fase 2 — Arquitectura final y resolución de discrepancias

| Campo | Valor |
| --- | --- |
| Base | Fase 1 aprobada; decisiones aceptadas el 26/09/2026 |
| Regla vigente | Siempre manda el PDF |
| Estado | Diseño cerrado, salvo los pendientes de abajo. **Nada implementado ni probado.** |

## Documentos

| # | Documento | Contenido |
| --- | --- | --- |
| 01 | [Registro de decisiones](01-registro-decisiones.md) | DEC-00..24, J.0, consecuencias técnicas CT-01..12 |
| 02 | [Arquitectura final](02-arquitectura-final.md) | Capas, contenedores, sistema de archivos, API, seguridad, degradación, frontend, asistente |
| 03 | [Modelo de datos](03-modelo-datos.md) | 29 tablas, integridad, ciclo de estados, vistas, privilegios, semillas |
| 04 | [Motor de análisis](04-motor-analisis.md) | Indicadores, **8 reglas aprobadas**, atención prioritaria, parámetros de ML, anonimización |
| 05 | [Red y seguridad por dispositivo](05-red-y-seguridad.md) | Switch, ZBF del router, nftables de fw01, UFW + DOCKER-USER, firewall del DC |
| 06 | [Estructura de repositorios](06-estructura-repositorio.md) | `tesis` + `atlas-analysis` |

## Criterio de salida de la Fase 2

| Condición | Estado |
| --- | --- |
| Decisiones críticas aprobadas y registradas | Cumplido (DEC-00..22) |
| Motor de análisis aprobado (DEC-23) | Cumplido (26/09/2026) |
| Proveedor del LLM (DEC-24) | Cumplido: Groq |
| Repositorio `atlas-analysis` creado (DEC-14) | Cumplido |
| Datos de red faltantes (J.2) | **Pendiente**: solo bloquea las Fases 8–10 |

Fase 2 cerrada. Solo quedan pendientes los datos de red y laboratorio (J.2, J.3), que bloquean las Fases 8–10, no la aplicación.
