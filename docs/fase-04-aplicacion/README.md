# Fase 4 — Aplicación

| Campo | Valor |
| --- | --- |
| Fecha | 26/09/2026 (Hito 1) · **actualizada el 22/10/2026 (Hito 2)** |
| Estado | **Implementada y verificada en el entorno de desarrollo** (Docker Compose local con los 4 contenedores de la Tabla 15). Falta desplegarla en atlas-srv01 del laboratorio (Fases 6 y 13) |
| Decisiones | Acta del Hito 2: [`docs/evidencias/F/acta_tesis`](../evidencias/F/acta_tesis) (D-1 a D-8) · detalle por decisión en [`docs/hito-2`](../hito-2/README.md) |
| Diseño | [fase-02/02-arquitectura-final](../fase-02-arquitectura/02-arquitectura-final.md), [04-motor-analisis](../fase-02-arquitectura/04-motor-analisis.md), [06-estructura-repositorio](../fase-02-arquitectura/06-estructura-repositorio.md) |
| Código | carpeta `atlas/` (Laravel 12 + lógica propia en PHP) y carpeta `atlas-analysis/` (servicio Python, DEC-14b) |

> Convención de estados: **DISEÑADO** = está en el documento · **CONFIGURADO** = existe el archivo · **EJECUTADO** = se corrió · **VERIFICADO** = se corrió y la salida está guardada como evidencia. Todo lo de esta fase está **VERIFICADO en el entorno de desarrollo**; nada de esto reemplaza las pruebas en el laboratorio (Fase 14).

## 1. Qué se construyó

| Capa | Tecnología | Dónde |
| --- | --- | --- |
| Presentación | HTML + CSS + JavaScript sin frameworks, mobile-first (§26.5, RNF-12) | `atlas/public/` |
| Servidor web | nginx:alpine, HTTPS, redirección 80→443, CSP estricta (Tabla 15) | `atlas/docker/nginx/default.conf` |
| Framework HTTP (D-1) | **Laravel 12** sobre PHP 8.3-fpm: ruteo, sesión del servidor, validación (Form Requests) y manejo de errores | `atlas/bootstrap/`, `atlas/routes/api.php`, `atlas/app/Http/` |
| Seguridad transversal | Cadena [1] `atlas.sesion` 401 (+ CSRF) → [2] `atlas.permiso` 403 + auditoría → [3] Form Request 422 → [4] `atlas.auditoria` (§26.3) | `atlas/app/Http/Middleware/`, `atlas/app/Http/Requests/` |
| Lógica propia (no depende de Laravel) | Servicios, motor de análisis, indicadores, asistente y repositorios (PDO); Laravel los recibe por `AtlasServiceProvider` | `atlas/app/Services/`, `atlas/app/Repositories/`, `atlas/app/Core/` |
| Datos | MySQL 8.0 (Fase 5) con 5 usuarios de privilegios distintos; **la base no calcula** (D-4) | `atlas/database/`, `atlas/docker/mysql/` |
| Análisis Nivel 1 | Puntaje, mejora, persistencia, eficiencia, tiempo activo, análisis grupal, acierto por habilidad y reglas R01–R08, todo en PHP, determinista, versionado y auditado | `atlas/app/Services/Analysis/` |
| Análisis Nivel 2 | Python 3.11 + FastAPI + scikit-learn (K-means, regresión logística); experimento (D-7) | `atlas-analysis/` |
| Asistente Nivel 3 | Opcional (D-5): intérprete local + anonimizador en PHP; redacción con Groq vía `atlas-analysis` | `atlas/app/Services/Asistente/`, `atlas-analysis/app/llm/` |
| Operación | CLI `bin/atlas` (crear admin, cerrar intentos abandonados, datos sintéticos) y `php artisan route:list` | `atlas/bin/`, `atlas/artisan` |

### Independencia de un único framework (D-1)

Laravel atiende solo la entrada HTTP. Las reglas del negocio y el análisis están en clases PHP propias que no importan nada de Laravel (`Atlas\Services\…`, `Atlas\Repositories\…`): la misma lógica la usa también la consola `bin/atlas` sin pasar por Laravel. El análisis adicional es un servicio aparte en Python, comunicado por API. Cambiar de framework obligaría a reescribir `app/Http/` y `routes/`, no las reglas de ATLAS (§25.2).

### Contenedores (Tabla 15)

| Contenedor | Imagen | Usuario | Red | Puerto publicado |
| --- | --- | --- | --- | --- |
| atlas-web | nginx:alpine | nginx | atlas_front | 80, 443 en `ATLAS_BIND_IP` |
| atlas-php | atlas/php:1.0 (php:8.3-fpm) | 5002 | atlas_front + atlas_back | ninguno |
| atlas-db | mysql:8.0 | 5003 | atlas_back (**internal**) | **ninguno** |
| atlas-analysis | atlas/analysis:1.0 (python:3.11-slim) | 65534 | atlas_back + atlas_egress | ninguno |

El código se monta **en solo lectura** en atlas-php (§28.3). Lo único que Laravel escribe (archivos de sesión, bloqueos de sesión y cachés de arranque) va a `ATLAS_STORAGE` (`/tmp/atlas` dentro del contenedor), igual que antes iban las sesiones nativas de PHP. Laravel **no** crea tablas: no se usa `migrate`; la base sale de `database/migrations/*.sql` (Fase 5).

## 2. API REST (`/api/v1`)

Las 44 rutas están en [`atlas/routes/api.php`](../../atlas/routes/api.php): las 43 del contrato original (mismos métodos, URLs, códigos y JSON; el frontend no cambió) y `POST /recomendaciones/{id}/decision` (D-6). Cada ruta declara su permiso y con qué nombre queda en la auditoría; `RutasTest` verifica que todas exijan sesión (salvo `/health` y `/auth/login`) y que toda escritura quede auditada.

| Grupo | Rutas principales | Permiso |
| --- | --- | --- |
| Sesión | `POST /auth/login`, `POST /auth/logout`, `GET /auth/me`, `GET /health` | público / sesión |
| Administración | `/usuarios`, `/usuarios/{id}/desactivar`, `/instituciones` (incluye `requiere_aprobacion`, D-2), `/roles`, `/roles/{id}/permisos`, `/grupos`, `/grupos/{id}/miembros` | `usuarios.gestionar`, `instituciones.gestionar`, `permisos.gestionar`, `grupos.gestionar` |
| Actividades | `/catalogos` (incluye habilidades, D-3), `/actividades` (CRUD en borrador), `/enviar`, `/aprobar`, `/rechazar`, `/publicar` (directo desde borrador si la institución no exige aprobación, D-2), `/transiciones` | `actividades.crear/enviar/aprobar/publicar` |
| Estudiante | `/estudiante/actividades` (marca la recomendada por el docente, D-6), `/intentos`, `/intentos/{id}/eventos`, `/intentos/{id}/respuestas/{pregunta}`, `/finalizar`, `/abandonar`, `/intentos/{id}/resultado` (tiempo total y activo, D-8) | `actividades.resolver`, `resultados.ver_propios` |
| Docente | `/docente/grupos/{id}/analisis` (consulta guiada: `desde`, `hasta`, `actividad`, D-5), `/docente/estudiantes/{id}/perfil`, `/recomendaciones/{id}/fundamento`, `/recomendaciones/{id}/decision` (D-6), `/reportes` | `panel.docente`, `perfiles.ver`, `recomendaciones.ver`, `recomendaciones.decidir`, `reportes.ver` |
| Motor | `GET /reglas`, `PATCH /reglas/{codigo}` | `reglas.gestionar` |
| Asistente (opcional) | `POST /asistente/consultas`, `GET /asistente/consultas` | `asistente.usar` |
| Auditoría | `GET /auditoria` | `auditoria.ver` |

Códigos de respuesta: 401 sin sesión, 403 sin permiso o sin token CSRF (se audita como `acceso.denegado` / `seguridad.csrf`), 404, 405, 409 conflicto de estado (los `SIGNAL 45000` de los triggers de integridad se traducen a 409), 422 con detalle por campo (`{"error": …, "errores": {campo: mensaje}}`, mensajes en `lang/es/validation.php`), 423 cuenta bloqueada.

### La cadena de middleware, para explicarla (§26.3)

1. **`atlas.sesion`** (`Autenticacion`): busca el usuario de la sesión (cookie `ATLASSID`, Secure, HttpOnly, SameSite=Strict). Si no hay → **401**. Si la petición modifica datos, exige la cabecera `X-CSRF-Token` igual al token de la sesión; si no → **403** y queda registrado `seguridad.csrf`.
2. **`atlas.permiso:codigo`** (`Permiso`): consulta `rol_permiso`. Si el rol no tiene el permiso → **403** y queda registrado `acceso.denegado` con el rol y el permiso pedido (RF-03).
3. **Form Request** (`app/Http/Requests/*`): valida los datos con las mismas reglas que antes. Si no sirven → **422** con el detalle por campo. Laravel lo ejecuta justo antes del controlador.
4. **`atlas.auditoria:accion`** (`Auditoria`): si la operación se hizo (2xx), la registra con su autor, la ruta, el recurso y el detalle que deja el controlador (por ejemplo el antes y el después de un cambio de usuario). Así RF-15 se cumple sin que cada controlador tenga que acordarse.

Además, la sesión se **bloquea por petición** (`session.block`): dos peticiones de la misma sesión no se procesan a la vez, como hacía la sesión nativa de PHP (ver §6, H-H2-01).

## 3. Trazabilidad: requisito → implementación → prueba → evidencia

Evidencias del Hito 2: **E-APP-007** unitarias PHP · **E-APP-008** API contra MySQL real (a través de Laravel) · **E-APP-009** navegador real (Chromium) + capturas en `capturas/hito2/` · **E-APP-010** PSR-12 · **E-APP-011** logout con peticiones concurrentes · **E-APP-012** servicio Python · **E-BD-007** base de datos con la migración 004 · **E-LNX-004** despliegue con Laravel. Las del Hito 1 (E-APP-001 a 006) quedan como registro histórico.

| Requisito / decisión | Implementación | Prueba | Evidencia | Resultado |
| --- | --- | --- | --- | --- |
| RF-01 Registro de usuarios | `UsuarioService`, `AdminController::crearUsuario` (correo único, contraseña ≥ 10, Argon2id) | `GestionAdministrativaTest` | E-APP-008 | PASS |
| RF-02 Autenticación | `AuthService` (mensaje genérico, 3 fallos → bloqueo 15 min, regeneración de sesión al entrar) | `AutenticacionTest` + e2e "mensaje genérico" | E-APP-008, E-APP-009 | PASS |
| RF-03 Gestión de roles | `rol_permiso` + middleware `atlas.permiso` | `ControlAccesoTest`, `RutasTest` + e2e "el estudiante no ve menú docente" | E-APP-007, E-APP-008, E-APP-009 | PASS |
| RF-04 Acceso a actividades | Solo publicadas en sus grupos; la recomendada por el docente primero (D-6) | `CicloAprobacionApiTest`, `MotorAnalisisApiTest::testElSistemaRecomiendaYElDocenteDecide` | E-APP-008 | PASS |
| RF-05 Niveles | `niveles_dificultad` | `CicloAprobacionApiTest::testEstudianteVeSoloPublicadasDeSusGruposConNivel` | E-APP-008 | PASS |
| RF-06 Interacciones | `registro.js` (lotes, reintento) + `IntentoService::registrarEventos` (idempotente) | `ResolucionTest` | E-APP-008 | PASS |
| RF-07 Resultados | **Puntaje calculado en PHP** al finalizar (`Indicadores::puntaje`, D-4); la base lo guarda | `IndicadoresTest`, `ResolucionTest::testPreguntaSinResponderCuentaComoIncorrecta`, `ResultadosTest`, e2e | E-APP-007, E-APP-008, E-BD-007, E-APP-009 | PASS |
| RF-08 Intentos | estados EN_CURSO/FINALIZADO/ABANDONADO; `intentos:cerrar-abandonados` | `ResolucionTest` | E-APP-008 | PASS |
| RF-09 Tiempo / D-8 | Tiempo total y por pregunta; **tiempo activo** = total − pausas (`TiempoActivo`) | `TiempoActivoTest`, `ResolucionTest::testTiempoActivoDescuentaLasPausas`, e2e | E-APP-007, E-APP-008, E-APP-009 | PASS |
| RF-10 Perfil | `AnalisisService` + `PanelDocenteService::perfilEstudiante` (incluye acierto por habilidad) | `MotorAnalisisApiTest`, `PanelGrupalTest` | E-APP-008 | PASS |
| RF-11 Panel docente | "¿Dónde intervenir hoy?" | `PanelGrupalTest` + capturas en 5 anchos | E-APP-008, E-APP-009 | PASS |
| RF-12 Recomendaciones / D-6 | Reglas R01–R08 con versión y datos; el docente confirma o cambia la actividad sugerida (`decisiones_recomendacion`) | `MotorReglasTest`, `MotorAnalisisApiTest`, e2e "¿por qué?" y "el docente confirma" | E-APP-007, E-APP-008, E-APP-009 | PASS |
| RF-13 Reportes | Filtros por grupo, actividad y período; tiempo total y activo | `PanelGrupalTest::testReportesFiltrables…`, e2e "reportes" | E-APP-008, E-APP-009 | PASS |
| RF-14 Gestión administrativa | Usuarios, instituciones (con aprobación configurable), grupos, permisos | `GestionAdministrativaTest` | E-APP-008 | PASS |
| RF-15 Auditoría | `AuditoriaService` + middleware `atlas.auditoria` con detalle antes/después (sin triggers que escriban, D-4) | `GestionAdministrativaTest`, `MotorAnalisisApiTest`, `AuditoriaTest`, `RutasTest` | E-APP-008, E-BD-007 | PASS |
| RF-16 Creación de actividades / D-3 | Preguntas con opciones (una correcta) y **una o más habilidades** | `CicloAprobacionApiTest` (habilidades), e2e "editor con habilidades" | E-APP-008, E-APP-009 | PASS |
| RF-17 Ciclo / D-2 | Aprobación configurable por institución, **por defecto sin aprobación**; transición auditada | `CicloAprobacionApiTest` (D-2), `HabilidadesAprobacionTest`, e2e "publicación directa" e "instituciones" | E-APP-008, E-BD-007, E-APP-009 | PASS |
| RF-18 Análisis grupal | **Calculado en PHP** (`ResumenGrupal`, D-4), con preguntas de más error y acierto por habilidad (D-3) | `ResumenGrupalTest`, `IndicadoresHabilidadTest`, `PanelGrupalTest` | E-APP-007, E-APP-008 | PASS |
| D-5 Consultas guiadas | Pantalla Consultas: grupo + período + qué ver, con explicación de cada número | `PanelGrupalTest::testLaConsultaGuiadaRespetaElPeriodo`, e2e "consultas" (1024 y 375 px) | E-APP-008, E-APP-009 | PASS |
| RF-19 Análisis de patrones | `atlas-analysis` con umbrales de suficiencia (experimento, D-7) | pytest | E-APP-012 | PASS (datos sintéticos) |
| RF-20 Consulta conversacional | Asistente opcional (D-5), con anonimización | `AsistenteTest`, `AsistenteApiTest`, pytest, e2e | E-APP-007, E-APP-008, E-APP-012, E-APP-009 | PASS (sin llamar a Groq real) |
| RNF-01 Seguridad | 401/403/422, CSRF, PDO preparado, Argon2id, **sesión bloqueada por petición** | `ControlAccesoTest`, `RutasTest`, reproducción concurrente | E-APP-008, E-APP-011 | PASS |
| RNF-12 Diseño responsivo | Mobile-first, cortes 480/768/1024, tablas → tarjetas, estados con texto | e2e sin desplazamiento horizontal en 375–1366 px | E-APP-009 | PASS |
| RNF-13 Mantenibilidad | Capas, PSR-12, rutas declarativas | `phpcs --standard=PSR12` → 0 errores, 0 advertencias | E-APP-010 | PASS |
| RNF-14 Privacidad | Seudónimos y barrera en PHP y en Python | `AsistenteTest`, `AsistenteApiTest`, pytest | E-APP-007, E-APP-008, E-APP-012 | PASS |
| RNF-15 Independencia de externos | Nivel 1 en PHP; si Python o el LLM no responden, ATLAS sigue | `PanelGrupalTest::testSinServicioDeAnalisis…`, `AsistenteApiTest`, e2e | E-APP-008, E-APP-009 | PASS |
| Despliegue (§28.3) | `desplegar-app.sh` instala `vendor/` de producción con la imagen de Composer | despliegue en Linux de prueba | E-LNX-004 | VERIFICADO fuera del laboratorio |

## 4. Diferenciales implementados

1. **"¿Dónde intervenir hoy?"** y **consultas guiadas**: el docente de un grupo masivo llega en uno o dos clics a quién atender y qué reforzar (§20.4).
2. **"¿Por qué?" rastreable**: cada recomendación muestra la regla, su versión y los valores exactos que la dispararon.
3. **El sistema recomienda y el docente decide** (D-6): queda registrado qué sugirió ATLAS y qué decidió el docente.
4. **Reglas editables sin programar**, versionadas y auditadas.
5. **Privacidad verificable**: el docente ve exactamente qué se envió al modelo de lenguaje.
6. **Honestidad estadística**: el Nivel 2 no muestra resultados sin datos suficientes; los tiempos solo describen tiempo activo y total (D-8).
7. **Funciona sin Internet**: el registro, el panel y las consultas no dependen del servicio Python ni del LLM.

## 5. Limitaciones conocidas

| # | Limitación | Consecuencia | Qué falta |
| --- | --- | --- | --- |
| L-01 | Todo se ejecutó en el entorno de desarrollo, no en atlas-srv01 | No prueba la red, el firewall ni el hardware del laboratorio | Fases 6, 13 y 14 |
| L-02 | No se llamó a la API real de Groq (no hay clave en el repositorio, a propósito) | El formato de la petición se verificó con un transporte simulado | Probar con `LLM_API_KEY` real: **NO EJECUTADA — requiere laboratorio** |
| L-03 | Los datos de la demo son sintéticos (12 estudiantes) | El Nivel 2 responde "datos insuficientes", que es lo correcto | Datos reales o una demo con ≥ 20 estudiantes |
| L-04 | Certificado TLS autofirmado en desarrollo | El navegador muestra advertencia | Certificado de la CA del dominio |
| L-05 | El despliegue necesita salida a Internet para descargar la imagen de Composer y los paquetes | Sin Internet, `desplegar-app.sh` se detiene con un mensaje claro | Alternativa: preparar `vendor/` en otra máquina y copiarlo |
| L-06 | La eficiencia (R02) usa la duración real de cada intento | En pruebas automáticas que duran 0–1 s puede o no calcularse; la prueba afectada no depende de R02 | Ninguna (es el comportamiento correcto) |

## 6. Hallazgos y correcciones

### Hito 2 (22/10/2026)

| ID | Hallazgo | Corrección | Evidencia |
| --- | --- | --- | --- |
| H-H2-01 | Con las sesiones de Laravel, una petición que empezaba antes del logout volvía a guardar la sesión al terminar y su cookie dejaba al usuario adentro (5 de 16 intentos). La sesión nativa de PHP no lo permitía porque bloqueaba la sesión | `session.block` (bloqueo por archivo): 0 de 16 | E-APP-011 |
| H-H2-02 | En el navegador, una pantalla lenta se dibujaba encima de la que el usuario abrió después, incluso con otro usuario ya logueado (equipo compartido) | Recarga al iniciar y cerrar sesión; las lecturas de una pantalla anterior se descartan (`api.js`, `nuevaNavegacion`) | E-APP-009 |
| H-H2-03 | En Windows (Docker Desktop), MySQL no creaba los usuarios: el script de inicio se ejecutaba en vez de incluirse | `02-usuarios.sh` define `docker_process_sql` si falta | E-BD-007 |
| H-H2-04 | En Git Bash, `probar-local.sh` se cortaba al crear el certificado (conversión de rutas) | `MSYS_NO_PATHCONV=1` | Circuito completo contra https://localhost |
| H-H2-05 | Cada cambio de usuario, permiso o regla quedaba dos veces en la auditoría (trigger + middleware) | Se borran los triggers que escribían auditoría (D-4); el middleware registra una vez, con el detalle | E-APP-008 (`GestionAdministrativaTest`) |
| H-H2-06 | Las "preguntas con más error" no respetaban el período y usaban una vista lenta (~490 ms con 88.700 respuestas, E-BD-006 Q5) | Consulta que arranca por el grupo y filtra por período, con el mismo enfoque que la Q5b de E-BD-006 (~41 ms). Esta consulta nueva **no se volvió a medir** con el volumen grande | E-APP-008 (resultado correcto) |
| H-H2-07 | El atributo `hidden` no ocultaba elementos con `display` propio | Regla `[hidden] { display: none !important; }` | E-APP-009 |

### Hito 1

| Hallazgo | Corrección |
| --- | --- |
| El validador no recortaba espacios antes de validar el correo | Se recortan los textos antes de validar (hoy: middleware TrimStrings de Laravel) |
| El anonimizador reemplazaba el nombre de pila por `[persona]` aunque era inequívoco | Mapa de alias cuando no hay ambigüedad |
| El asistente explicaba solo la última recomendación | Explica todas las del último intento |
| `features.construir` descartaba a todos si las duraciones eran 0 | `tiempo_relativo` sin dato → 1,0 |
| PyMySQL no autenticaba con `caching_sha2_password` | Dependencia `cryptography` |
| nginx no arrancaba con `listen [::]` en hosts sin IPv6 | Se quitaron los listeners IPv6 |
| 233 errores y 171 advertencias de PSR-12 | `phpcbf` + ajuste manual → 0/0 |
| La barrera del lado Python solo detectaba correos | También detecta cédulas |

## 7. Cómo reproducir

```bash
cd atlas
composer install
vendor/bin/phpunit --testsuite unit                                   # E-APP-007
ATLAS_TEST_SUITES=api tests/Database/run.sh                            # E-APP-008 (MySQL 8.0 real y efímero)
tests/Database/run.sh                                                  # E-BD-007
vendor/bin/phpcs --standard=PSR12 app bootstrap config routes lang public/index.php bin tests  # E-APP-010
php artisan route:list --path=api                                      # las 44 rutas con su middleware
cd ../atlas-analysis && python -m pytest -v                            # E-APP-012
```

Sin PHP instalado (por ejemplo en Windows), los mismos comandos corren dentro del contenedor de PHP: `docker build -t atlas/php -f docker/php/Dockerfile .` y `docker run --rm -v "$PWD:/app" -w /app atlas/php vendor/bin/phpunit --testsuite unit`. `run.sh` usa la subred de `atlas_back` (192.168.250.16/28): hay que detener el stack antes de correrlo.

Interfaz en navegador real (con el stack levantado por `./probar-local.sh`):

```bash
docker run --rm --network atlas_front -v "$PWD/atlas/tests/e2e:/e2e:ro" -v "$PWD/capturas:/capturas" \
  mcr.microsoft.com/playwright/python:v1.48.0-jammy \
  sh -c "pip install -q playwright==1.48.0 && python /e2e/interfaz.py https://atlas-web /capturas \"$ATLAS_DEMO_CONTRASENA\""   # E-APP-009
```

## 8. Para la defensa oral

- **¿Por qué Laravel, si el documento decía "sin depender de un framework"?** Fue una corrección del profesor (acta D-1): Laravel resuelve de forma estándar sesión, CSRF, validación y errores. La independencia se mantiene de dos formas: la lógica de ATLAS está en clases propias que no dependen de Laravel (la consola las usa sin él) y el análisis es un servicio Python separado. Cambiar de framework tocaría `app/Http` y `routes`, no las reglas.
- **¿Dónde está el middleware y qué hace cada paso?** §2 de este documento: sesión (401 + CSRF), permiso (403 auditado), Form Request (422), auditoría. Se ve en `php artisan route:list --path=api`.
- **¿Por qué la base ya no calcula el puntaje?** Acta D-4: los cálculos están en PHP, donde se prueban con pruebas unitarias y se explican; MySQL guarda y protege la integridad (13 triggers que solo rechazan lo inválido, CHECK, FK y privilegios: `atlas_app` agrega resultados pero no puede modificarlos).
- **¿Cómo se evita la inyección SQL?** Solo sentencias preparadas de PDO; además `atlas_app` no puede alterar estructura ni borrar auditoría.
- **¿Qué pasa si se cae Internet?** El Nivel 1 corre en PHP y la base es local: el estudiante resuelve y el docente ve panel, consultas y recomendaciones.
- **¿Cómo sabemos que no se envían datos personales al LLM?** Anonimizador en PHP, barrera final en PHP y en Python, y el registro `contexto_enviado` que el docente puede revisar.
- **¿Qué encontraron al probar en el navegador?** H-H2-01 y H-H2-02: dos fallas de concurrencia que las pruebas de API no podían ver, corregidas y medidas (E-APP-011).
