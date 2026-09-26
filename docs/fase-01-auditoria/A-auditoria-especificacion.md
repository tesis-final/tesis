# A. Auditoría completa de la especificación

Fuente: `docs/especificacion/TC4-Error404-ATLAS-V2.2.pdf`. Las citas usan la numeración impresa del PDF, que coincide con la página del archivo.

## A.1 Identificación del documento

| Campo | Valor | Fuente |
| --- | --- | --- |
| Título | ATLAS — Plataforma Inteligente de Aprendizaje Adaptativo. Documento Integrador — Versión 2 | pág. 1 |
| Hito | Hito 1: Plan de trabajo consolidado y avance inicial | pág. 1 |
| Versión vigente | V2.2 (18/09/2026) | Tabla 1, pág. 2 |
| Equipo | Grupo Error404: S. Viñas (PO, Gestión), J. P. Beracochea (SM, Redes MS y Conectividad), A. Britos (Programación), B. Reyes (Base de datos), S. Rodríguez (POSIX/Linux) | pág. 1; Tabla 3, pág. 16 |
| Institución | ITI-CETP/UTU, Tecnicatura en Redes y Software, clase TC4 | pág. 1 |
| Cuerpo docente | E. Valles, M. Viar | pág. 1 |
| Estándar del Anexo H | IEEE 830-1998 (especificación de requisitos), versión 1.0 del anexo | Tabla H1, pág. 85 |
| Páginas | 123 (la pág. 75 está en blanco en el original) | — |

## A.2 Historial de versiones (Tabla 1, pág. 2)

| Versión | Fecha | Qué cambió | Relevancia para implementar |
| --- | --- | --- | --- |
| V1 | 01/09/2026 | Propuesta: problema, objetivos, alcance, límites, requisitos | Las secciones 1–18 se reproducen sin cambios (pág. 5). Algunas funciones de V1 no quedaron formalizadas en V2 (ver G, DISC-16, DISC-17, AMB-09). |
| V2 | 17/09/2026 | Relevamiento, criterios de verificación, metodología, cronograma, avance | Agrega criterios de verificación (Tabla 5), que son la base de la aceptación. |
| V2.1 | 18/09/2026 | Corrige la matriz entre VLAN y las reglas de firewall (dominio, Samba, DHCP, Internet); agrega puertos del switch, VLAN nativa, VLAN de gestión, inventario, entorno de implementación; divide la VPN en dos segmentos; agrega plan de pruebas de red | Es la versión que define el diseño de red a implementar (§30). |
| V2.2 | 18/09/2026 | Resultados del relevamiento, Anexo A, Anexo H (IEEE 830), referencias, estado diseño/implementación separado | El Anexo H es la especificación de requisitos más detallada y reciente: se usa como autoridad para los criterios de aceptación. |

## A.3 Estructura del documento y carácter de cada parte

"Normativo" significa que define algo que hay que construir o cumplir. "Contexto" explica o justifica. "Proceso" describe cómo trabaja el equipo; no genera código ni configuración, pero sí evidencias de gestión.

| Sección | Págs. | Contenido | Carácter |
| --- | --- | --- | --- |
| Portada, Tabla 1, Índice | 1–4 | Identificación, versiones, índice | Contexto |
| Parte I (V1) §1 Problema | 5 | Evaluación por resultados finales, no por proceso | Contexto |
| §2 Propuesta | 5–6 | Actividades y juegos; variables (tiempo, intentos, evolución, estrategias, memoria, razonamiento, resolución de problemas, atención, adaptación); no diagnostica | Contexto + restricción (no diagnóstico) |
| §3 Objetivo general | 6 | Plataforma web que recopila, procesa y analiza interacciones | Normativo (general) |
| §4 Objetivos específicos 1–12 | 6–7 | 12 objetivos | Normativo; se verifican con la Tabla 5 |
| §5 Funcionalidades | 7–8 | Por rol: estudiante, docente, administrador | Normativo parcial: no todo tiene RF (ver B.15) |
| §6 Inteligencia | 8 | Ejemplo de recomendación basada en datos, no en etiqueta fija | Contexto + restricción |
| §7 Base de datos | 8 | Qué se almacena; privilegios diferenciados | Normativo |
| §8 Linux / POSIX | 9 | Usuarios, grupos, permisos, ACL, servicios, scripts, firewall, logs, backups, políticas; jerarquía documentada | Normativo (detallado en §28) |
| §9 Windows | 9 | AD, usuarios y grupos, DNS, DHCP, GPO, control de acceso, integración | Normativo (detallado en §29) |
| §10 Redes (Tabla 2) | 9–10 | 5 VLAN por área; firewall, NAT, reglas, VPN, segmentación, monitoreo, registro | Normativo (detallado en §30) |
| §11 Arquitectura | 10 | Cliente-servidor en capas (versión general) | Contexto; la reemplaza en detalle §25 |
| §12 Métricas | 10–11 | 8 métricas medibles | Normativo (OBJ-12) |
| §13–14 Impacto, proyección | 11 | Piloto futuro con consentimiento; evolución comercial | Contexto (fuera de alcance) |
| §15 Metodología | 11–12 | Ágil, etapas 1–10 | Proceso |
| §16 Resultado esperado | 12 | Lista de componentes del prototipo | Normativo (alcance) |
| §17 Alcance | 13 | Prototipo para el ITI; Linux + Windows; VLAN, firewall, VPN, monitoreo, respaldo | Normativo |
| §18 Límites | 13–14 | Una institución; no diagnóstico; prototipo académico; sin integración externa; IA clásica + LLM de terceros solo para redactar | Restricciones normativas |
| Parte II (V2) §19 Equipo | 16 | Roles y tutorías | Proceso |
| §20 Relevamiento | 17–21 | 4 respuestas; conclusión: prioridad del análisis grupal (RF-18) | Contexto que cambia prioridades (normativo para RF-18) |
| §21 Criterios de verificación (Tabla 5) | 22–23 | Cómo se prueba cada objetivo | Normativo (aceptación) |
| §22 Cómo trabajamos | 24–27 | Scrum, eventos, artefactos, definición de terminado, herramientas | Proceso; la definición de terminado (§22.6) es normativa para las evidencias |
| §23 Cronograma (Tablas 9–11) | 28–29 | Hitos, Sprints, riesgos | Proceso; fija fechas de entrega |
| §24 Requisitos (Tablas 12–14) | 30–34 | RF-01..RF-20, RNF-01..RNF-15, ejemplo RF-02 | Normativo |
| §25 Arquitectura en detalle (Tabla 15) | 34–40 | Capas, flujo, motor de análisis en 3 niveles, contenedores | Normativo |
| §26 Programación (Tablas 16–18) | 41–44 | Stack, estructura de código, middleware, criterios, interfaz | Normativo |
| §27 Base de datos (Tablas 19–23) | 45–49 | Grupos de tablas, relaciones, normalización, integridad, privilegios, integración con el SO, respaldo | Normativo |
| §28 Linux (Tablas 24–30) | 50–57 | Servidor, usuarios/grupos, permisos, ACL, atributos, SSH, TCP Wrappers, UFW, respaldo/recuperación | Normativo |
| §29 Windows (Tablas 31–37) | 58–62 | DC, OU, grupos, seguridad, GPO, DNS, DHCP, relay, integración con Linux | Normativo |
| §30 Redes y seguridad (Tablas 38–49, Figura 1) | 63–74 | Direccionamiento, topología, switch, inventario, entorno, matriz, firewall/NAT, VPN, monitoreo, plan de pruebas | Normativo |
| §31 Dónde estamos hoy (Tablas 50–51) | 76–77 | Estado: diseño listo, implementación en Hito 2; decisiones del Sprint 1 | Contexto + decisiones justificadas |
| §32 Referencias | 78 | Bibliografía | Contexto |
| §33 Anexos (Tabla 52) | 79 | A–H y su estado | Normativo para las evidencias (B–G pendientes) |
| Anexo A (Figuras 2–5) | 79–84 | Formulario y gráficos del relevamiento | Contexto; sin requisitos técnicos |
| Anexo H | 85–123 | Especificación IEEE 830: propósito, alcance, definiciones, usuarios, restricciones, suposiciones, interfaces, fichas de RF con pre/postcondición y criterios de aceptación, RNF con criterio de verificación, matriz de trazabilidad | Normativo (autoridad para la aceptación) |

## A.4 Inventario de tablas y figuras

| Elemento | Pág. | Tema | Usado en |
| --- | --- | --- | --- |
| Tabla 1 | 2 | Control de versiones | A.2 |
| Tabla 2 | 9 | VLAN por área | RED |
| Tabla 3 | 16 | Roles e integrantes | Proceso |
| Tabla 4 | 17 | Objetivos del relevamiento | Contexto |
| Tabla 5 | 22–23 | Criterios de verificación de los objetivos | OBJ-01..12 |
| Tablas 6–8 | 24–26 | Roles Scrum, eventos, herramientas | DOC |
| Tablas 9–10 | 28–29 | Hitos y Sprints | I, DISC-23 |
| Tabla 11 | 29 | Riesgos del equipo | H |
| Tabla 12 | 30–31 | Requisitos funcionales | RF |
| Tabla 13 | 32–33 | Requisitos no funcionales | RNF |
| Tabla 14 | 33–34 | Descomposición de RF-02 | RF-02 |
| Tabla 15 | 40 | Contenedores | ARQ-09, DISC-01/02 |
| Tabla 16 | 41 | Stack por capa | ARQ, DISC-01 |
| Tabla 17 | 43 | Criterios de desarrollo | ARQ-10 |
| Tabla 18 | 44 | Estado de programación | DOC |
| Tabla 19 | 45–46 | Tablas y relaciones | BD, DISC-15 |
| Tabla 20 | 47 | Integridad y rendimiento | BD-06, DISC-12 |
| Tabla 21 | 47–48 | Usuarios MySQL | BD-07, DISC-11 |
| Tabla 22 | 48 | BD en el SO | BD-09, DISC-02 |
| Tabla 23 | 49 | Estado de BD | DOC |
| Tabla 24 | 50 | Servidor Linux | LNX-01 |
| Tablas 25–26 | 51 | Grupos y usuarios POSIX | LNX-03/04 |
| Tabla 27 | 51–52 | Permisos por recurso | LNX-05, DISC-07 |
| Tablas 28–29 | 54–55 | Qué se respalda, frecuencia y destino | LNX-13/14, DISC-10 |
| Tabla 30 | 56–57 | Estado Linux | DOC |
| Tabla 31 | 58 | Servidor Windows (el título dice "OU y grupos", ver ED-01) | WIN-01 |
| Tabla 32 | 59 | Seguridad Windows | WIN-05 |
| Tabla 33 | 59–60 | GPO (el título dice "Configuración de DNS", ver ED-02) | WIN-06 |
| Tabla 34 | 60 | Ámbitos DHCP | WIN-08 |
| Tablas 35–36 | 61–62 | Integración Linux–Windows y mapeo de grupos | WIN-10/11 |
| Tabla 37 | 62 | Estado Windows | DOC |
| Tablas 38–40 | 63–65 | Direccionamiento, dimensionamiento, IP fijas | RED-01..04 |
| Figura 1 | 65 | Topología (imagen; revisada visualmente) | RED-05 |
| Tabla 41 | 66 | Puertos del switch | RED-06 |
| Tabla 42 | 67 | Inventario de red | RED-10 |
| Tabla 43 | 68–69 | Matriz de comunicación | RED-13 |
| Tabla 44 | 69–70 | Reglas de firewall y NAT | FW-01..12 |
| Tabla 45 | 71 | VPN WireGuard | VPN |
| Tabla 46 | 72 | Herramientas de monitoreo | MON |
| Tabla 47 | 72–73 | Indicadores y metas | MON-07 |
| Tabla 48 | 73–74 | Plan de pruebas P-01..P-15 | P-01..P-15 |
| Tabla 49 | 74 | Estado de redes | DOC |
| Tablas 50–51 | 76–77 | Estado general y decisiones | A.5 |
| Tabla 52 | 79 | Anexos | DOC-01 |
| Figuras 2–5 | 80–83 | Gráficos del relevamiento (imágenes; revisadas) | Contexto |
| Tablas H1–H7 | 85–94 | Datos, definiciones, funciones, usuarios, restricciones, suposiciones, interfaces | B, C |
| Tabla H8 | 95–97 | Resumen de RF con prioridad y objetivo | RF |
| Tablas H9–H28 | 97–117 | Ficha de cada RF | RF-01..20 |
| Tabla H29 | 117–120 | RNF con criterio de verificación | RNF |
| Tabla H30 | 120–123 | Trazabilidad RF → objetivo → sección → Sprint | F, DISC-23 |

## A.5 Estado que declara el propio documento

El PDF es honesto: separa diseño de implementación. **Nada está implementado todavía**; toda la implementación figura como "Hito 2".

| Área | Diseño | Implementación | Fuente |
| --- | --- | --- | --- |
| Programación | Listo (stack, estructura, middleware, criterios, interfaz) | Hito 2 (estructura, BD, login, middleware, paneles, repositorio Git) | Tabla 18, pág. 44 |
| Base de datos | Listo (modelo, normalización, integridad, privilegios, integración, respaldo) | Hito 2 (DER, diccionario, script, usuarios, datos de prueba) | Tabla 23, pág. 49 |
| Linux | Listo (usuarios, jerarquía, ACL, políticas, respaldo) | Hito 2 (VM, usuarios aplicados, ACL, firewall) | Tabla 30, págs. 56–57 |
| Windows | Listo (OU, grupos, GPO, DNS/DHCP, integración) | Hito 2 (instalación, dominio, OU, DNS/DHCP, GPO) | Tabla 37, pág. 62 |
| Redes | Listo (direccionamiento, topología, puertos, inventario, matriz, firewall/NAT, VPN, plan de pruebas) | Hito 2 (VLAN y troncal, reglas, VPN, monitoreo) | Tabla 49, pág. 74 |

## A.6 Anexos y evidencias que hay que producir (Tabla 52, pág. 79)

| Anexo | Contenido | Estado en el PDF | Se produce en la fase (ver I) |
| --- | --- | --- | --- |
| A | Formulario y resultados del relevamiento | Listo | — (ya existe) |
| B | Evidencias de programación | Hito 2 | Fases 4, 14, 15 |
| C | Evidencias del servidor Linux | Hito 2 | Fases 6, 12, 15 |
| D | Evidencias de Active Directory | Hito 2 | Fases 7, 15 |
| E | Diagrama de red y configuración (incluye las capturas de P-01..P-15, pág. 74) | Hito 2 | Fases 8–11, 14, 15 |
| F | Actas de las reuniones de Scrum | Hito 2 | Lo produce el equipo (proceso), no el código |
| G | Modelo entidad-relación y script de base de datos | Hito 2 | Fase 5 |
| H | Especificación IEEE 830 | Listo | — (ya existe) |

Además, la definición de terminado (§22.6, pág. 26) exige para cada tarea: funciona, está documentada, **tiene evidencia (captura, registro de prueba o código)**, la revisó otro integrante y está actualizada en el tablero.

## A.7 Observaciones de calidad del documento

El documento es coherente en lo general y tiene buena trazabilidad (Tabla 5, Anexo H, H30). Los problemas encontrados se registran en el apartado G:

- **24 contradicciones internas** (DISC-01..24): por ejemplo Apache contra Nginx, MySQL nativo contra contenedor, ubicación de WireGuard, UFW contra las reglas de red, permisos POSIX contra ACL, y RPO de 24 h contra incrementales solo locales.
- **30 ambigüedades o vacíos** (AMB-01..30): la más importante es que **las "ocho reglas documentadas" que exige la Tabla 5 no están enumeradas en ningún lugar del PDF**.
- **6 diferencias entre tu prompt y el PDF** (PR-01..06). En esos casos prevalece el PDF hasta que decidas otra cosa.
- **Observaciones editoriales** (ED-01..08), que no afectan la implementación.

## A.8 Cobertura de la revisión pedida (punto 1 de tu prompt)

| # | Qué pediste identificar | Dónde está |
| --- | --- | --- |
| 1–2 | PDF completo y secciones | A.3, A.4 |
| 3 | RF-01..RF-20 | B.2 |
| 4 | RNF | B.3 (RNF-01..RNF-15) |
| 5 | Objetivos específicos | B.1 |
| 6 | Criterios de verificación | B.1 (Tabla 5) y B.2/B.3 (Anexo H) |
| 7 | Arquitectura | C |
| 8 | Linux/POSIX | D.2, B.7 |
| 9 | Windows | D.3, B.8 |
| 10 | Redes y seguridad | E, B.9–B.12 |
| 11–12 | Tablas de direccionamiento y VLAN | E.1–E.3 |
| 13 | Servicios | C.3, D, E.10 |
| 14 | Matriz de comunicación | E.6 |
| 15 | Firewall/NAT | E.7, E.8, B.10 |
| 16 | VPN | E.9, B.11 |
| 17 | Monitoreo | D.6, B.12 |
| 18 | Plan de pruebas | E.11, B.13 |
| 19 | Anexos y evidencias | A.6, B (columna "Evidencia requerida") |
| 20 | Inconsistencias, ambigüedades, dependencias | G, F, H |

## A.9 Método de lectura

- Se extrajo el texto de las 123 páginas con dos herramientas (pypdf y pdfplumber) y se detectaron 61 tablas, que se revisaron con sus columnas.
- Las páginas que contienen imágenes se renderizaron y se revisaron visualmente: Figura 1 (pág. 65), árbol de OU (pág. 58), matriz (pág. 68) y Anexo A (págs. 80–84).
- Se contrastaron las referencias cruzadas entre secciones (por ejemplo, §30.5 remite a §28.4 y §29.3; H30 remite a secciones de diseño).
- Se verificaron dos supuestos técnicos contra paquetes reales de Ubuntu 24.04. El paquete `openssh-server 1:9.6p1-3ubuntu13.x` depende de `libwrap0`, así que TCP Wrappers (§28.4) sigue funcionando y **no** es un riesgo.
