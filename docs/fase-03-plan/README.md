# Fase 3 — Plan maestro de implementación

| Campo | Valor |
| --- | --- |
| Fecha | 26/09/2026 |
| Base | Fase 2 cerrada (decisiones DEC-00..24) |
| Regla | Siempre manda el PDF |

## 1. Alcance por hito

La Tabla 10 (p. 28–29) rige las fechas (DEC-26 → DISC-23).

| Hito | Fecha | Qué se entrega (propuesta de este plan) | Requisitos |
| --- | --- | --- | --- |
| Hito 2 | 23/10/2026 | BD completa y probada (29 tablas, privilegios, triggers); aplicación con autenticación, roles, administración, actividades y ciclo de aprobación completos; resolución de actividades con registro de interacciones, intentos, tiempos y resultados; motor Nivel 1 con las 8 reglas y perfil; panel docente con análisis grupal; scripts de Linux, Windows y red listos para el laboratorio; VLAN y troncal en Packet Tracer | RF-01..RF-18, RNF-01, 06, 12, 13, 14, 15; §28–§30.1 |
| Hito 3 | 20/11/2026 | Servicio de análisis (K-means, regresión logística) y asistente con Groq; firewall fw01, VPN, monitoreo y respaldos ejecutados en el laboratorio; integración en GNS3; pruebas P-01..P-15; evidencias, auditoría final, reportes y manuales | RF-19, RF-20, RNF-02..05, 07..11; §30.2–§30.5 |

**Nota**: el PDF adelanta al Hito 2 algunos ítems de red y seguridad (Tabla 49). Se entregan como **configuración lista** en el Hito 2, pero su ejecución y verificación en el laboratorio dependen de los datos de J.2 y J.3, que todavía faltan.

## 2. Orden de trabajo

| Orden | Fase | Quién | Arranca | Depende de |
| --- | --- | --- | --- | --- |
| 1 | 5. Base de datos (esquema, migraciones, semillas, privilegios, tests) | Claude | Ahora | — |
| 2 | 4. Aplicación PHP (núcleo, autenticación, middleware, administración, actividades, ciclo) | Claude | Tras la Fase 5 | 5 |
| 3 | 4. Resolución, registro de interacciones, resultados, motor Nivel 1, panel docente | Claude | — | 2 |
| 4 | 4. Servicio de análisis (atlas-analysis) + asistente con Groq | Claude | — | 3 |
| 5 | 6, 7. Scripts de Linux y Windows + manuales paso a paso | Claude escribe / Equipo ejecuta | En paralelo con 2–4 | Instalar las VM (Equipo) |
| 6 | 8–10. Configuraciones de Cisco, fw01, VPN + manual de redes | Claude escribe / Equipo ejecuta | Cuando lleguen los datos de J.2 | J.2, J.3 |
| 7 | 11–12. Monitoreo y respaldos | Claude escribe / Equipo ejecuta | — | 6 |
| 8 | 13–15. Integración, pruebas, evidencias | Equipo con guía | Sprint 5 | 1–7 |
| 9 | 16–17. Auditoría final y reportes | Claude | Sprint 5 | 8 |

## 3. Elementos diferenciales (dentro del PDF, sin requisitos nuevos)

El usuario pidió priorizar lo que genere diferencial y se adapte mejor. Todos salen de requisitos del PDF y se implementan como **la forma** de cumplirlos, no como funciones nuevas.

| Diferencial | Qué es | Requisito que cumple |
| --- | --- | --- |
| "Dónde intervenir hoy" | La primera pantalla del docente no es una lista de estadísticas: muestra primero los estudiantes prioritarios y las preguntas con más error de cada grupo, con el motivo en una línea | §20.4 (reducir el tiempo del docente), RF-18, H.2.3 |
| Explicabilidad total | Cada recomendación y cada estudiante prioritario tiene un botón "¿por qué?" con la regla, su versión y los datos exactos usados | RF-10, RF-12, §25.4 |
| Honestidad del ML | Si no hay datos suficientes, se dice cuántos faltan ("12 de 20 estudiantes con 5 intentos"), en vez de mostrar agrupamientos sin sentido | §25.4 (p. 38), H27 |
| Privacidad verificable | En cada respuesta del asistente, el docente puede ver **exactamente qué se envió al modelo**: seudónimos y números, nunca nombres | H28, Ley 18.331, RNF-14 |
| Registro tolerante a mala conectividad | Los eventos se guardan en el navegador y se envían por lotes con secuencia; si la red se corta, no se pierde el orden ni el tiempo | §1 (contextos con dificultades de conectividad), RF-06, OBJ-03 |
| Recomendación accionable | Cada recomendación apunta, cuando existe, a una actividad concreta ya publicada del nivel y la categoría adecuados | RF-12 |
| Reglas ajustables sin programar | El administrador edita umbrales y activa o desactiva reglas; cada cambio queda versionado y auditado | §27.3, RF-15 |

## 4. Esquema de evidencias

Cada evidencia tiene un ID, el requisito que prueba, el comando o acción, lo que se espera, lo que se obtuvo y el anexo del PDF.

| Prefijo | Área | Anexo (Tabla 52) |
| --- | --- | --- |
| E-APP-nnn | Aplicación, API, frontend, tests | B |
| E-BD-nnn | Base de datos | G |
| E-LNX-nnn | atlas-srv01 | C |
| E-WIN-nnn | atlas-dc01 / AD | D |
| E-RED-nnn | Switch, router, fw01, VPN, pruebas P-xx | E |
| E-MON-nnn | Monitoreo | E |
| E-BKP-nnn | Respaldos y restauración | C |

Estados de cada evidencia: **PENDIENTE → EJECUTADA → VERIFICADA**. El resultado de cada prueba es **PASS / FAIL / NO EJECUTADA — requiere laboratorio**.

El índice exhaustivo de evidencias se arma en la Fase 15; cada fase agrega las suyas a `docs/evidencias/`.

## 5. Criterios de salida por fase

- **Fase 5**: script SQL ejecutado en MySQL 8.0 real, tests de integridad (FK, CHECK, triggers, transiciones, privilegios) en PASS con la salida guardada como evidencia E-BD.
- **Fase 4**: tests unitarios y de API en PASS; linter PSR-12 sin errores; cada RF con su test.
- **Fases 6–12**: script de verificación en PASS **en la VM real**, con las capturas del equipo.
