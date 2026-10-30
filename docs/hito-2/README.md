# Hito 2 — Qué se hizo y qué cambia en el documento

| Campo | Valor |
| --- | --- |
| Fecha | 22/10/2026 · entrega del Hito 2: 23/10/2026 ("prototipo o avance funcional validado") |
| Origen | Acta de decisiones [`docs/evidencias/F/acta_tesis`](../evidencias/F/acta_tesis) (D-1 a D-8), tomada sobre la devolución de Programación del Hito 1 |
| Rama | `beracochea` (pull request a `main`) |
| Entorno de las pruebas | Docker de desarrollo (no es el laboratorio). Ver las limitaciones en [fase-04 §5](../fase-04-aplicacion/README.md#5-limitaciones-conocidas) |
| Testing (30/10) | Implementación y ejecución de pruebas, incidencias y ajustes: [testing.md](testing.md) |

## 1. El circuito completo, funcionando

El docente crea una actividad (cada pregunta con sus habilidades) y la publica → el estudiante la resuelve, una pregunta por vez → queda registrado todo (respuestas, eventos, pausas, tiempo total y activo, resultado, auditoría) → el docente ve "¿dónde intervenir hoy?", las consultas guiadas, el acierto por habilidad y las recomendaciones, y decide la siguiente actividad del estudiante.

Verificado de punta a punta en un navegador real (E-APP-009, 27/27, con capturas en [`capturas/hito2`](../evidencias/B/capturas/hito2)) y contra la API real a través de Nginx → Laravel → MySQL.

## 2. Por decisión del acta

| Decisión | Qué se hizo | Dónde | Cómo se probó |
| --- | --- | --- | --- |
| **D-1** Laravel | La aplicación pasa a **Laravel 12**: ruteo, sesión, validación (Form Requests) y errores. Mismo contrato de API (43 rutas + 1 nueva); el frontend no cambió. La lógica propia (servicios, motor, indicadores, asistente, repositorios) se reutilizó sin reescribirse y no depende de Laravel. Se borró el núcleo propio que Laravel reemplaza | `atlas/bootstrap`, `routes/api.php`, `app/Http` | 71 pruebas de API pasan a través de Laravel (E-APP-008); `RutasTest` (E-APP-007) |
| **D-2** Aprobación configurable | Por defecto **sin aprobación**: el docente publica directo desde borrador y queda registrado quién y cuándo. La coordinación puede exigirla por institución (pantalla Instituciones) | `ActividadService`, migración 004, `admin.js` | `CicloAprobacionApiTest`, e2e (E-APP-008, E-APP-009) |
| **D-3** Habilidades | Cada pregunta mide una o más habilidades (obligatorio para publicar). Acierto por habilidad por estudiante y por grupo, de la más débil a la más fuerte, con "a reforzar" en texto | `IndicadoresHabilidad`, editor del docente | `IndicadoresHabilidadTest`, `PanelGrupalTest`, e2e |
| **D-4** Cálculos en PHP | Puntaje, análisis grupal, versión de reglas y detalle de auditoría pasan a PHP. La base guarda y protege: quedan 13 triggers de integridad y 0 procedimientos (migración 004) | `Indicadores`, `ResumenGrupal`, `004_calculos_en_php.sql` | Unitarias, `ResultadosTest`, `AnalisisGrupalTest`; 3FN: 0 inconsistencias en 8.749 resultados (E-BD-008) |
| **D-5** Consultas guiadas | Pantalla **Consultas**: grupo + período + qué ver (quiénes requieren atención, qué preguntas costaron más, cómo va cada habilidad, cómo les fue y cuánto tardaron), explicando cómo se calculó cada número. El asistente queda como opcional | `docente.js` (consultas), `PanelDocenteService` | `PanelGrupalTest::testLaConsultaGuiadaRespetaElPeriodo`, e2e en 1024 y 375 px |
| **D-6** Adaptativo | El sistema sugiere la siguiente actividad (reglas) y el **docente la confirma o la cambia**; el estudiante la ve como "Recomendada por tu docente". Queda el rastro de qué sugirió ATLAS y qué decidió el docente | tabla `decisiones_recomendacion`, `POST /recomendaciones/{id}/decision` | `MotorAnalisisApiTest::testElSistemaRecomiendaYElDocenteDecide`, e2e |
| **D-7** Requieren atención | Con reglas simples y explicables (R01–R08, botón "¿Por qué?"). El ML (Python) queda como experimento y dice "datos insuficientes" cuando corresponde | sin cambios de código en el Hito 2 | `PanelGrupalTest`, E-APP-012 |
| **D-8** Tiempos | Se registra la pausa (más de 60 s sin actividad o pestaña oculta) desde la última actividad, y se muestra el **tiempo activo** (total − pausas) aparte del total. Una pregunta por vez | `TiempoActivo`, `registro.js`, `intentos.duracion_activa_seg` | `TiempoActivoTest`, `ResolucionTest`, e2e |

Pedidos del profesor de Programación para el Hito 2 que no son una decisión del acta:

- **Middleware implementado y explicable:** [fase-04 §2](../fase-04-aplicacion/README.md#la-cadena-de-middleware-para-explicarla-263).
- **Diseño responsivo que no depende solo del color:** e2e sin desplazamiento horizontal de 375 a 1366 px; los estados llevan texto.
- **Nginx en la documentación:** ver §4.

## 3. Hallazgos importantes de esta etapa

Están detallados en [fase-04 §6](../fase-04-aplicacion/README.md#6-hallazgos-y-correcciones).

1. **Un logout se podía deshacer** con Laravel (una petición en curso volvía a guardar la sesión). Corregido con el bloqueo de sesión: de 5/16 a 0/16 (E-APP-011).
2. **Una pantalla lenta podía mostrarse encima de la nueva, incluso con otro usuario** (equipo compartido). Corregido en el navegador.
3. **La auditoría duplicaba cada cambio administrativo** (trigger + middleware). Ahora se registra una sola vez, con el antes y el después.
4. **En Windows no levantaba la demo** (`02-usuarios.sh` y `probar-local.sh`). Corregido; en Linux no cambia nada.
5. **El despliegue al servidor borraba `vendor/`**, que Laravel necesita. Ahora lo instala sin dependencias de desarrollo (E-LNX-004).

## 4. Cambios para pasar al documento (PDF V2.2 → versión del Hito 2)

El acta cambia partes del documento a propósito. Esta lista dice qué sección queda desactualizada y un texto propuesto. Lo que no está acá sigue vigente.

| Sección del PDF | Qué dice hoy | Texto propuesto |
| --- | --- | --- |
| §2 Propuesta (variables) | "memoria, atención, estrategias utilizadas…" | "El sistema registra si el estudiante acertó, cuánto tardó (tiempo total y tiempo activo, sin las pausas), si cambió de respuesta y cuántos intentos hizo. De los tiempos no se concluye nada sobre memoria, atención ni estrategias, porque tienen ruido (distracciones, conexión) (acta D-8)." |
| §5 Funcionalidades (estudiantes) | "Adaptación progresiva de las actividades" | "Actividad siguiente sugerida por el sistema y confirmada o cambiada por el docente (acta D-6)." |
| §11 y §25.1 Arquitectura (diagrama) | "Apache · PHP · MySQL" | "Nginx · PHP 8.3 (Laravel 12) · MySQL 8.0 (contenedores Docker)" |
| §25.2 "No depender de un solo framework" | "La lógica… sin atarlos a ningún framework. Si usamos alguno, va a ser para el ruteo y utilidades" | "La aplicación usa **Laravel** para la entrada HTTP (ruteo, sesión, validación, errores). Las reglas del negocio y el motor de análisis están en clases propias que no dependen de Laravel, y el análisis adicional es un servicio Python separado comunicado por API: cambiar de framework no obliga a reescribir cómo funciona ATLAS (acta D-1)." |
| §25.3 Flujo y "Por qué el administrador aprueba" | La aprobación del administrador es obligatoria | "La aprobación es configurable por institución y por defecto no se exige: el docente publica directamente en sus grupos y queda registrado quién y cuándo. Si la institución la exige, la actividad pasa por pendiente → aprobada/rechazada como antes (acta D-2)." |
| §25.4 Nivel 1 | Cuatro indicadores; reglas en la BD | Agregar: "acierto por habilidad (cada pregunta mide una o más habilidades: lógica, comprensión lectora, cálculo, razonamiento espacial; ampliable) (D-3) y tiempo activo (D-8). Todo se calcula en PHP; la base guarda (D-4)." |
| §25.4 Nivel 2 | Dos modelos | Agregar: "Es un **experimento**: 'requieren atención' se resuelve con reglas explicables (Nivel 1); el ML se muestra solo con datos suficientes (D-7)." |
| §25.4 Nivel 3 | Asistente conversacional | Agregar: "Es **opcional**. La consulta principal son las **consultas guiadas**: el docente elige grupo, período y qué ver (D-5)." |
| §26.1 Tabla 16 | Backend "PHP 8"; Servidor web "Apache 2.4" | Backend "PHP 8.3 + Laravel 12"; Servidor web "**Nginx**" (es el que ya figura en la Tabla 15) |
| §26.2 Estructura del código | Árbol sin framework; "Si Apache queda mal configurado…" | Árbol: `app/Http/{Controllers,Middleware,Requests}`, `app/Services`, `app/Repositories`, `routes/api.php`, `bootstrap/`, `config/`, `database/migrations/*.sql`. Cambiar "Apache" por "Nginx" |
| §26.3 Middleware | Cadena genérica | Igual, con los nombres reales: `atlas.sesion` (401 + CSRF), `atlas.permiso` (403 registrado), Form Request (422), `atlas.auditoria`. Agregar: "la sesión se bloquea por petición para que un cierre de sesión no pueda deshacerse" |
| §26.6 Tabla 18 | "Hito 2" en estructura, login, middleware, paneles | Todo **Listo** (verificado en desarrollo; evidencias E-APP-007 a 012) |
| §27.1 y Tabla 19 | 24 tablas | Agregar: `habilidades`, `pregunta_habilidad` (D-3), `decisiones_recomendacion` (D-6), `transiciones_actividad`, `actividad_grupo`, `recomendacion_regla`, `registro_respaldos`, catálogos. Total: **32 tablas** (diccionario regenerado) |
| §27.3 Normalización | "Para que no se desincronice, usamos un trigger" | "El puntaje lo calcula la aplicación al finalizar el intento y lo guarda una sola vez, en la misma transacción. No se desincroniza porque un intento cerrado no se reabre (trigger), hay un único resultado por intento (UNIQUE) y la aplicación no tiene permiso para modificarlo. La consistencia se verificó sobre 8.749 resultados: 0 diferencias (E-BD-008)." |
| §27.4 Tabla 20 | "Procedimientos almacenados: cálculo de indicadores y análisis grupal"; "Triggers: auditoría automática y actualización de resultados" | Procedimientos: "no se usan: los cálculos están en PHP (D-4)". Triggers: "**integridad**: ciclo de estados, intento cerrado inmutable, respuestas válidas, auditoría no modificable, contenido editable solo en borrador (13)" |
| §27.5 Tabla 21 | `atlas_app` SELECT, INSERT, UPDATE | Agregar: "solo SELECT e INSERT (sin UPDATE ni DELETE) en `auditoria`, `transiciones_actividad`, `resultados`, `analisis_grupal` y `decisiones_recomendacion`" (E-BD-010) |
| §28.1 Tabla 24 (servicios) | "Apache, PHP, MySQL, Samba, SSH" | "Docker (Nginx, PHP/Laravel, MySQL, Python), Samba, SSH" |
| §28.5 Restauración, paso 2 | "Parar Apache y MySQL" | "Detener los contenedores de la aplicación" |
| H.2.4 Restricción tecnológica | "PHP sin depender de un único framework" | "PHP con Laravel para la capa HTTP y la lógica en clases propias; análisis en un servicio Python separado; MySQL; despliegue en contenedores" |
| H.3.2 RF-17 | Criterio: estados del ciclo | Agregar al criterio: "Si la institución no exige aprobación, el docente publica directo; la transición queda registrada con su autor." |
| H.3.2 (nuevos) | — | Proponer **RF-21 Habilidades** ("cada pregunta mide una o más habilidades; el sistema informa el acierto por habilidad por estudiante y por grupo") y **RF-22 Decisión del docente** ("el docente confirma o cambia la actividad que sugiere el sistema; queda registrado"). Criterios: los de las pruebas citadas en §2 |
| Anexos B y G | "HITO 2" | Evidencias: B → E-APP-007 a 012 y capturas; G → E-BD-007 a 012 (y el DER en imagen, `docs/fase-05-base-datos/img`); C → E-LNX-004 |

## 5. Evidencias del Hito 2

| Evidencia | Qué es | Resultado |
| --- | --- | --- |
| [E-APP-007](../evidencias/B/E-APP-007-tests-unitarios-hito2.txt) | Unitarias PHP (incluye rutas de Laravel) | 37/37 |
| [E-APP-008](../evidencias/B/E-APP-008-tests-api-hito2.txt) | API contra MySQL 8.0 real, a través de Laravel | 71/71 |
| [E-APP-009](../evidencias/B/E-APP-009-interfaz-hito2.txt) | Navegador real (Chromium), 5 anchos, con capturas | 27/27 |
| [E-APP-010](../evidencias/B/E-APP-010-psr12-hito2.txt) | PSR-12 | 0 errores, 0 advertencias |
| [E-APP-011](../evidencias/B/E-APP-011-sesion-concurrente-logout.txt) | Logout con peticiones concurrentes | sin bloqueo 5/16 sesiones vivas; con bloqueo 0/16 |
| [E-APP-012](../evidencias/B/E-APP-012-tests-analisis-hito2.txt) | Servicio Python | 23/23 |
| [E-BD-007](../evidencias/G/E-BD-007-tests-hito2.txt) | Base de datos con 004 | 58/58 |
| [E-BD-008](../evidencias/G/E-BD-008-datos-y-consultas-004.txt) | Datos representativos, consultas y 3FN con 004 | 0 inconsistencias |
| [E-BD-009](../evidencias/G/E-BD-009-restauracion-004.txt) | Restauración real con 004 | RPO 0, 0 diferencias, 0 huérfanos |
| [E-BD-010](../evidencias/G/E-BD-010-show-grants-004.txt) | Privilegios con 004 | según Tabla 21 + 004 |
| [E-BD-011](../evidencias/G/E-BD-011-rechazos.txt) | Rechazos demostrados con el error real de MySQL (privilegios, restricciones, triggers) | 36 rechazos + 4 controles, 0 que no coinciden |
| [E-BD-012](../evidencias/G/E-BD-012-replicacion-y-conmutacion.txt) | Alta disponibilidad: réplica, error humano replicado, conmutación | copia idéntica · borrado replicado en 0,7 s · RPO 0, RTO < 1 s |
| [E-LNX-004](../evidencias/C/E-LNX-004-despliegue-laravel.txt) | Despliegue con Laravel (Linux de prueba) | vendor sin dev; Laravel responde |

## 6. Lo que falta (no se hizo en este hito)

- **Desplegar y probar en el laboratorio** (atlas-srv01, red, firewall): todo lo de arriba es del entorno de desarrollo.
- **Probar el asistente con la API real de Groq** (requiere clave; es opcional según D-5).
- **Pasar al PDF los cambios del §4** y renumerar los anexos.
- **Repetir la restauración en el servidor**: los tiempos de Docker anidado (E-BD-009) no sirven como medición.
