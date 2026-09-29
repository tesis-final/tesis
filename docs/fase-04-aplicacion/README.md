# Fase 4 — Aplicación

| Campo | Valor |
| --- | --- |
| Fecha | 26/09/2026 |
| Estado | **Implementada y verificada en el entorno de desarrollo** (Docker Compose local con los 4 contenedores de la Tabla 15). Falta desplegarla en atlas-srv01 del laboratorio (Fases 6 y 13) |
| Diseño | [fase-02/02-arquitectura-final](../fase-02-arquitectura/02-arquitectura-final.md), [04-motor-analisis](../fase-02-arquitectura/04-motor-analisis.md), [06-estructura-repositorio](../fase-02-arquitectura/06-estructura-repositorio.md) |
| Repositorios | `SVinas73/tesis` (carpeta `atlas/`) y `SVinas73/atlas-analysis` (servicio Python) |

> Convención de estados (prompt §4): **DISEÑADO** = está en el documento · **CONFIGURADO** = existe el archivo · **EJECUTADO** = se corrió · **VERIFICADO** = se corrió y la salida está guardada como evidencia. Todo lo de esta fase está **VERIFICADO en el entorno de desarrollo**; nada de esto reemplaza las pruebas en el laboratorio (Fase 14).

## 1. Qué se construyó

| Capa | Tecnología (PDF) | Dónde |
| --- | --- | --- |
| Presentación | HTML + CSS + JavaScript sin frameworks, mobile-first (§26.5, RNF-12) | `atlas/public/` |
| Servidor web | nginx:alpine, HTTPS, redirección 80→443, CSP estricta (Tabla 15) | `atlas/docker/nginx/default.conf` |
| Aplicación | PHP 8.3-fpm sin framework, en capas: Controladores → Servicios → Repositorios (§26.3) | `atlas/app/` |
| Seguridad transversal | Cadena de middleware [1] Autenticación 401 → [2] Permisos 403 + auditoría → [3] Validación 422 → [4] Auditoría (§26.3, Fig. 11) | `atlas/app/Middleware/` |
| Datos | MySQL 8.0 (Fase 5) con 5 usuarios de privilegios distintos | `atlas/database/`, `atlas/docker/mysql/` |
| Análisis Nivel 1 | Indicadores + reglas R01–R08 en PHP, deterministas, versionadas y auditadas | `atlas/app/Services/Analysis/` |
| Análisis Nivel 2 | Python 3.11 + FastAPI + scikit-learn (K-means, regresión logística) | repo `atlas-analysis` |
| Asistente Nivel 3 | Intérprete local + anonimizador en PHP; redacción con Groq vía `atlas-analysis` | `atlas/app/Services/Asistente/`, `atlas-analysis/app/llm/` |
| Operación | CLI `bin/atlas` (crear admin, cerrar intentos abandonados, datos sintéticos) | `atlas/bin/` |

### Contenedores (Tabla 15, verificado en E-APP-006)

| Contenedor | Imagen | Usuario | Red | Puerto publicado |
| --- | --- | --- | --- | --- |
| atlas-web | nginx:alpine | nginx | atlas_front | 80, 443 en `ATLAS_BIND_IP` |
| atlas-php | atlas/php:1.0 (php:8.3-fpm) | 5002 | atlas_front + atlas_back | ninguno |
| atlas-db | mysql:8.0 | 5003 | atlas_back (**internal**) | **ninguno** |
| atlas-analysis | atlas/analysis:1.0 (python:3.11-slim) | 65534 | atlas_back + atlas_egress | ninguno |

`atlas_egress` existe solo para que `atlas-analysis` pueda llegar a la API de Groq; `atlas-db` no tiene salida a Internet (verificado).

## 2. API REST (`/api/v1`)

Todas las rutas y su permiso están declarados en un único archivo, [`atlas/config/rutas.php`](../../atlas/config/rutas.php); la prueba `RouterTest::testTodasLasRutasDeclaradasSonValidas` comprueba que cada ruta apunte a un método existente y a un permiso sembrado en la base.

| Grupo | Rutas principales | Permiso |
| --- | --- | --- |
| Sesión | `POST /auth/login`, `POST /auth/logout`, `GET /auth/me`, `GET /health` | público / sesión |
| Administración | `/usuarios`, `/usuarios/{id}/desactivar`, `/instituciones`, `/roles`, `/roles/{id}/permisos`, `/grupos`, `/grupos/{id}/miembros` | `usuarios.gestionar`, `instituciones.gestionar`, `permisos.gestionar`, `grupos.gestionar` |
| Actividades | `/actividades` (CRUD en borrador), `/enviar`, `/aprobar`, `/rechazar`, `/publicar`, `/transiciones` | `actividades.crear/enviar/aprobar/publicar` |
| Estudiante | `/estudiante/actividades`, `/intentos` (iniciar), `/intentos/{id}/eventos`, `/intentos/{id}/respuestas/{pregunta}`, `/finalizar`, `/abandonar`, `/intentos/{id}/resultado` | `actividades.resolver`, `resultados.ver_propios` |
| Docente | `/docente/grupos/{id}/analisis` (incluye "¿dónde intervenir hoy?"), `/docente/estudiantes/{id}/perfil`, `/recomendaciones/{id}/fundamento`, `/reportes` | `panel.docente`, `perfiles.ver`, `recomendaciones.ver`, `reportes.ver` |
| Motor | `GET /reglas`, `PATCH /reglas/{codigo}` | `reglas.gestionar` |
| Asistente | `POST /asistente/consultas`, `GET /asistente/consultas` | `asistente.usar` |
| Auditoría | `GET /auditoria` | `auditoria.ver` |

Códigos de respuesta: 401 sin sesión, 403 sin permiso (se audita como `acceso.denegado`), 404, 405, 409 conflicto de estado (los `SIGNAL 45000` de los triggers se traducen a 409), 422 con detalle por campo, 423 cuenta bloqueada.

## 3. Trazabilidad: requisito → implementación → prueba → evidencia

Evidencias: **E-APP-001** unitarias PHP · **E-APP-002** API contra MySQL real · **E-APP-003** navegador real (Chromium) + 14 capturas · **E-APP-004** servicio Python · **E-APP-005** PSR-12 · **E-APP-006** integración del stack · **E-BD-001/002** (Fase 5).

| Requisito | Implementación | Prueba | Evidencia | Resultado |
| --- | --- | --- | --- | --- |
| RF-01 Registro de usuarios | `UsuarioService`, `AdminController::crearUsuario` (correo único, contraseña ≥ 10, Argon2id) | `GestionAdministrativaTest` (alta, correo repetido, vacíos, contraseña corta) | E-APP-002 | PASS |
| RF-02 Autenticación | `AuthService` (mensaje genérico, 3 fallos → bloqueo 15 min, sesión Secure/HttpOnly/SameSite=Strict, regeneración de id) | `AutenticacionTest` (7) + e2e "mensaje genérico" | E-APP-002, E-APP-003 | PASS |
| RF-03 Gestión de roles | `rol_permiso` + middleware `Permisos` | `ControlAccesoTest::testAccesoCruzado…` (403 + auditoría) + e2e "el estudiante no ve menú docente" | E-APP-002, E-APP-003 | PASS |
| RF-04 Acceso a actividades | `ActividadRepository::publicadasParaEstudiante` (solo publicadas en sus grupos) | `CicloAprobacionApiTest::testEstudianteVeSoloPublicadas…`, `…NoRecibeLaRespuestaCorrecta` | E-APP-002 | PASS |
| RF-05 Niveles | `niveles_dificultad`, filtro por nivel | `CicloAprobacionApiTest::testEstudianteVeSoloPublicadasDeSusGruposConNivel` | E-APP-002 | PASS |
| RF-06 Interacciones | `public/js/registro.js` (lotes en localStorage) + `IntentoService::eventos` (idempotente por secuencia) | `ResolucionTest::testResolverGeneraResultadoYSecuenciaReconstruible`, `testReenviarUnLoteNoDuplicaEventos` | E-APP-002 | PASS |
| RF-07 Resultados | trigger `trg_intentos_finalizar` + `IntentoService::finalizar` | `ResolucionTest`, `ResultadosTest`, e2e "el estudiante ve su resultado" | E-APP-002, E-BD-001, E-APP-003 | PASS |
| RF-08 Intentos | estados EN_CURSO/FINALIZADO/ABANDONADO; `intentos:cerrar-abandonados` (30 min) | `ResolucionTest::testAbandonoSinResultadoYConTiempo`, `testCadaInicioEsDistinguible…` | E-APP-002 | PASS |
| RF-09 Tiempo | tiempo total y por pregunta en segundos | `ResolucionTest::testTiempoTotalYPorPreguntaEnSegundos` | E-APP-002 | PASS |
| RF-10 Perfil de aprendizaje | `AnalisisService` (perfil por período mensual) + `PanelDocenteService::perfilEstudiante` | `MotorAnalisisApiTest` | E-APP-002 | PASS |
| RF-11 Panel docente | `PanelDocenteService::analisisGrupal` ("¿dónde intervenir hoy?") | `PanelGrupalTest::testDondeIntervenirHoy`, `testDocenteSoloVeSusGrupos` + capturas en 5 anchos | E-APP-002, E-APP-003 | PASS |
| RF-12 Recomendaciones | `MotorReglas` (R01–R08) + `recomendacion_regla` (versión y valores de entrada) + botón "¿por qué?" | `MotorReglasTest` (11), `MotorAnalisisApiTest` (4), e2e "¿por qué?" | E-APP-001, E-APP-002, E-APP-003 | PASS |
| RF-13 Estadísticas y reportes | `ReporteRepository`, filtros por grupo, actividad y período | `PanelGrupalTest::testReportesFiltrables…` | E-APP-002 | PASS |
| RF-14 Gestión administrativa | usuarios, instituciones, grupos, miembros, permisos | `GestionAdministrativaTest` (8) | E-APP-002 | PASS |
| RF-15 Auditoría | `AuditoriaService` (tabla + archivo solo-anexar) + middleware `Auditoria` | `AutenticacionTest::testElLogDeAuditoriaEnArchivoRecibeLineas`, `GestionAdministrativaTest::testAuditoriaConsultable…`, `AuditoriaTest` | E-APP-002, E-BD-001 | PASS |
| RF-16 Creación de actividades | `ActividadService` (preguntas y opciones, una sola correcta) | `CicloAprobacionApiTest::testRecorridoCompleto…` | E-APP-002 | PASS |
| RF-17 Ciclo de aprobación | BORRADOR → PENDIENTE → APROBADA/RECHAZADA → PUBLICADA; triggers impiden saltos | `CicloAprobacionApiTest` (6), `CicloActividadTest` (6) | E-APP-002, E-BD-001 | PASS |
| RF-18 Análisis grupal | `sp_analisis_grupal` + `DocenteController::analisisGrupal` | `AnalisisGrupalTest` (3), e2e "análisis grupal visible" | E-BD-001, E-APP-003 | PASS |
| RF-19 Análisis de patrones | `atlas-analysis`: K-means y regresión logística **con umbrales de suficiencia** | pytest `test_modelos.py`, `test_features.py` | E-APP-004 | PASS (con datos sintéticos; ver §5) |
| RF-20 Consulta conversacional | `IntentParser` + `Anonimizador` + `AsistenteService` + `atlas-analysis/app/llm` | `AsistenteTest` (5), `AsistenteApiTest` (6), pytest `test_llm_y_api.py`, e2e asistente | E-APP-001, E-APP-002, E-APP-004, E-APP-003 | PASS (sin llamar a Groq real; ver §5) |
| RNF-01 Seguridad de acceso | middleware 401/403/422, CSRF (`X-CSRF-Token`), PDO preparado, Argon2id | `ControlAccesoTest` (6) | E-APP-002 | PASS |
| RNF-03 Rendimiento | consultas indexadas; `/health` responde en 6–30 ms en desarrollo | `ResolucionTest::testCincuentaResolucionesQuedanCompletamenteRegistradas` | E-APP-002, E-APP-006 | PASS en desarrollo; la medición formal es P-xx de la Fase 14 |
| RNF-11 Usabilidad | estados con texto + símbolo + color, foco visible, enlace "saltar al contenido", objetivos táctiles de 44 px | e2e + capturas | E-APP-003 | VERIFICADO (inspección) |
| RNF-12 Diseño responsivo | CSS mobile-first, cortes 480/768/1024, tablas → tarjetas | e2e: sin desplazamiento horizontal en 375/480/768/1024/1366 px | E-APP-003 | PASS |
| RNF-13 Mantenibilidad | capas, PSR-12, rutas declarativas, reglas editables sin programar | `phpcs --standard=PSR12` → 0 errores, 0 advertencias (78 archivos) | E-APP-005 | PASS |
| RNF-14 Privacidad | seudónimos E1..En / G1, alias de nombre, limpieza de correo y cédula, barrera en PHP **y** en Python; `conversaciones.contexto_enviado` guarda exactamente lo enviado | `AsistenteTest::testAnonimizacionYReidentificacion`, `AsistenteApiTest::testHistorialGuardaPreguntaRespuestaYLoEnviado` (busca nombres y correos reales en lo enviado), pytest `test_no_envia_si_hay_un_correo`, `test_no_envia_si_hay_una_cedula` | E-APP-001, E-APP-002, E-APP-004 | PASS |
| RNF-15 Independencia de externos | Nivel 1 en PHP; si `atlas-analysis` o Groq no responden, ATLAS sigue | `PanelGrupalTest::testSinServicioDeAnalisis…` (2), `AsistenteApiTest::testSinLlm…`, e2e asistente sin LLM | E-APP-002, E-APP-003 | PASS |
| CSP / sin estilos en línea | `default-src 'self'`; anchos de barras por CSSOM | e2e "sin violaciones de CSP", "sin errores de JavaScript" | E-APP-003 | PASS |
| Tabla 15 / §28.3 contenedores | `docker-compose.yml`, Dockerfiles | inspección del stack | E-APP-006 | VERIFICADO en desarrollo |

## 4. Diferenciales implementados (Fase 3)

1. **"¿Dónde intervenir hoy?"** — el panel docente ordena a los estudiantes por atención prioritaria (≥ 1 regla de RIESGO en el período) y muestra la acción sugerida.
2. **"¿Por qué?" rastreable** — cada recomendación muestra la regla, su **versión** y los valores exactos que la dispararon. Si la coordinación cambia un umbral, las recomendaciones viejas conservan la versión con que se generaron.
3. **Reglas editables sin programar** — la coordinación ajusta umbrales desde la interfaz; cada cambio versiona la regla y queda auditado.
4. **Privacidad verificable** — el docente puede ver, en cada respuesta del asistente, *exactamente* qué se envió al modelo (solo seudónimos y números).
5. **Honestidad estadística** — el Nivel 2 no entrena si no hay datos suficientes y lo dice con los números reales, en vez de mostrar un modelo sin validez.
6. **Funciona sin Internet** — el asistente sin LLM responde con los datos verificados; el panel y la resolución no dependen del servicio Python.

## 5. Limitaciones conocidas (honestas)

| # | Limitación | Consecuencia | Qué falta |
| --- | --- | --- | --- |
| L-01 | Todo se ejecutó en el entorno de desarrollo, no en atlas-srv01 | No prueba la red, el firewall ni el hardware del laboratorio | Fases 6, 13 y 14 |
| L-02 | No se llamó a la API real de Groq (no hay clave en el repositorio, a propósito) | El formato de la petición se verificó con un transporte simulado | Probar con `LLM_API_KEY` real en el laboratorio: **NO EJECUTADA — requiere laboratorio** |
| L-03 | Los datos de la demo son sintéticos (12 estudiantes) | Con 12 < 20 estudiantes el Nivel 2 responde correctamente "datos insuficientes (8/20)". El camino de escritura del K-means se verificó bajando umbrales temporalmente (k = 3, silueta 0,2946) y se restauraron | Datos reales o una demo con ≥ 20 estudiantes |
| L-04 | Certificado TLS autofirmado en desarrollo | El navegador muestra advertencia | Certificado emitido por la CA del dominio (Fase 7, AD CS) o el definido en Fase 9 |
| L-05 | En desarrollo el host puede alcanzar la IP interna de `atlas-db` | Equivale a acceso desde `localhost` del servidor; desde otras máquinas no hay ruta | Verificar desde la VLAN de usuarios en la Fase 14 (P-03) |
| L-06 | La advertencia `DeprecationWarning` de pytest viene de starlette (dependencia) | Ninguna | Actualizar FastAPI cuando se estabilice la versión |

## 6. Hallazgos y correcciones durante la fase

| Hallazgo | Corrección |
| --- | --- |
| El validador no recortaba espacios antes de validar el correo | `Validator` recorta los textos antes de aplicar reglas |
| `const API` en `rutas.php` se redefinía al crear varios `Kernel` | Se usa la variable `$api` |
| El anonimizador reemplazaba el nombre de pila por `[persona]` aunque era inequívoco | Mapa de alias: nombre o apellido sueltos → seudónimo cuando no hay ambigüedad |
| El asistente explicaba solo la última recomendación | Explica todas las del último intento |
| `features.construir` descartaba a todos si las duraciones eran 0 | `tiempo_relativo` sin dato → 1,0; test agregado |
| PyMySQL no autenticaba con `caching_sha2_password` | Dependencia `cryptography` |
| nginx no arrancaba con `listen [::]` en hosts sin IPv6 | Se quitaron los listeners IPv6 |
| `montar()` mostraba `[object HTMLElement]` con arreglos anidados | Aplana los hijos |
| El aviso de un login fallido seguía visible tras entrar | Se limpian los mensajes al iniciar sesión |
| 233 errores y 171 advertencias de PSR-12 | `phpcbf` + ajuste manual de líneas largas → 0/0 |
| La barrera del lado Python solo detectaba correos | También detecta cédulas (con y sin puntos); 4 tests nuevos, sin falsos positivos con fechas y decimales |

## 7. Cómo reproducir

```bash
cd atlas
composer install
vendor/bin/phpunit --testsuite unit                                   # E-APP-001
ATLAS_TEST_SUITES=api tests/Database/run.sh                            # E-APP-002 (MySQL 8.0 real y efímero)
ATLAS_TEST_SUITES=database tests/Database/run.sh                       # E-BD-001
vendor/bin/phpcs --standard=PSR12 app config public/index.php bin tests  # E-APP-005
cd ../../atlas-analysis && python -m pytest -v                         # E-APP-004
```

Si Docker Hub limita las descargas: `ATLAS_TEST_MYSQL_IMAGE=mirror.gcr.io/library/mysql:8.0`. `run.sh` usa la subred de `atlas_back` (192.168.250.16/28), así que hay que detener el stack antes de correrlo.

Stack completo (entorno de prueba, sin `chown`):

```bash
SIN_CHOWN=1 ATLAS_ROOT=/ruta/prueba infra/linux/desplegar-app.sh "$PWD" ../atlas-analysis
# crear /ruta/prueba/config/atlas.conf a partir de atlas/.env.example (secretos aleatorios) y tls/
docker compose --env-file /ruta/prueba/config/atlas.conf -f /ruta/prueba/config/docker-compose.yml up -d --build
docker exec atlas-php php bin/atlas usuario:crear-admin        # lee ATLAS_ADMIN_* del entorno
docker exec atlas-php php bin/atlas demo:datos-sinteticos      # opcional; lee ATLAS_DEMO_CONTRASENA
python atlas/tests/e2e/interfaz.py https://127.0.0.1 docs/evidencias/B/capturas "$ATLAS_DEMO_CONTRASENA"  # E-APP-003
```

## 8. Para la defensa oral

- **¿Por qué PHP sin framework?** El PDF (§26.3) define la arquitectura en capas y la cadena de middleware; implementarla a mano muestra que el equipo entiende cada paso (quién rechaza con 401, quién con 403, quién con 422) y deja el código auditable en ~80 archivos.
- **¿Cómo se evita la inyección SQL?** Solo sentencias preparadas de PDO; ningún valor del usuario se concatena en SQL. Además `atlas_app` no puede alterar estructura ni borrar auditoría (PrivilegiosTest).
- **¿Qué pasa si se cae Internet?** El Nivel 1 corre en PHP y la base es local: el estudiante resuelve y el docente ve su panel y las recomendaciones. Solo el texto redactado por el LLM se reemplaza por los datos verificados (PanelGrupalTest, AsistenteApiTest).
- **¿Cómo sabemos que no se envían datos personales al LLM?** Tres capas: el anonimizador en PHP, una barrera final que rechaza correos y cédulas en PHP y otra en Python, y el registro `contexto_enviado` que el docente puede inspeccionar. El test busca los nombres y correos reales de los usuarios de prueba en todo lo enviado y exige cero coincidencias.
- **¿Por qué el Nivel 2 dice "datos insuficientes"?** Porque un agrupamiento o un modelo de riesgo con 12 estudiantes no tiene validez estadística; mostrarlo sería inventar. Los umbrales (≥ 20 estudiantes, silueta ≥ 0,25, AUC por validación cruzada) están en el documento de diseño aprobado.
