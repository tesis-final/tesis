# B. Inventario de requisitos

Todos los estados arrancan en **PENDIENTE**. La columna "Evidencia requerida" describe **qué** habrá que presentar; no existe todavía ninguna evidencia. Entre corchetes se indica el anexo del PDF donde va cada evidencia (Tabla 52, pág. 79).

Prefijos: OBJ (objetivos), RF, RNF, ARQ (arquitectura y aplicación), ANA (motor de análisis), BD, LNX, WIN, RED, FW (firewall/NAT), VPN, MON, P (pruebas de red), DOC (documentación y gestión), FUN (funciones de la propuesta V1 sin requisito formal).

Cuando una fila depende de una discrepancia sin resolver, se indica con "→ DISC-nn" o "→ AMB-nn" (ver G).

## B.1 Objetivos específicos y sus criterios de verificación

| ID | Especificación | Fuente en PDF | Qué debe implementarse | Componente | Cómo se verificará | Evidencia requerida | Estado |
| -- | -------------- | ------------- | ---------------------- | ---------- | ------------------ | ------------------- | ------ |
| OBJ-01 | Plataforma web con usuarios, roles y autenticación | §4 obj. 1 (p. 6); Tabla 5 (p. 22) | Login, 3 roles, control de acceso por rol | App PHP: autenticación + middleware | Diez casos de prueba documentados: cada rol accede solo a lo suyo | Planilla de 10 casos con resultado + capturas [B] | PENDIENTE |
| OBJ-02 | Crear actividades educativas interactivas | §4 obj. 2; Tabla 5 | Una actividad recorre los cinco estados y queda registro de cada cambio | App: actividades + ciclo de estados; BD | Prueba de punta a punta por los 5 estados (→ DISC-13) | Historial de transiciones (consulta SQL) + capturas [B] | PENDIENTE |
| OBJ-03 | Registrar las interacciones | §4 obj. 3; Tabla 5 | Registro de respuestas, tiempo e intentos | JS cliente + API + BD | 50 resoluciones de prueba; el 100 % con respuestas, tiempo e intentos | Script SQL de conteo + salida [B/G] | PENDIENTE |
| OBJ-04 | Diseñar la base de datos | §4 obj. 4; Tabla 5 | 3FN, mínimo 15 tablas, integridad referencial, privilegios distintos por rol | MySQL | Revisión de 3FN, conteo de tablas, FK, `SHOW GRANTS` por usuario | DER, diccionario, script, salida de `SHOW GRANTS` [G] | PENDIENTE |
| OBJ-05 | Algoritmos de análisis | §4 obj. 5; Tabla 5 | Al menos 8 reglas documentadas; cada recomendación rastreable a la regla (→ AMB-01) | Motor Nivel 1 (PHP) + `reglas_analisis` | Ejecución con datos de prueba y rastreo de cada recomendación | Catálogo de reglas + trazas regla→datos→recomendación [B] | PENDIENTE |
| OBJ-06 | Generar perfiles y recomendaciones | §4 obj. 6; Tabla 5 | Perfil individual y grupal a partir de datos registrados | Motor Nivel 1 + panel docente | Generación de ambos perfiles con datos de prueba | Capturas del panel + consultas [B] | PENDIENTE |
| OBJ-07 | Seguridad y control de acceso | §4 obj. 7; Tabla 5 | Rechazo y registro de accesos no autorizados | Middleware + auditoría | Cinco intentos de acceso no autorizado rechazados y registrados | Respuestas 401/403 + filas de `auditoria` [B] | PENDIENTE |
| OBJ-08 | Infraestructura Linux y Windows | §4 obj. 8; Tabla 5 | Autenticación centralizada funcionando y recursos compartidos accesibles entre ambos | atlas-srv01 (SSSD, Samba) + atlas-dc01 (AD, carpeta compartida) | `realm list`, `id usuario@atlas.local`; acceso Windows→Samba y Linux→carpeta de Windows | Capturas [C/D] | PENDIENTE |
| OBJ-09 | Red segmentada mediante VLAN | §4 obj. 9; Tabla 5 | Cinco VLAN operativas con pruebas de lo permitido y lo bloqueado | atlas-sw01, atlas-rt01, atlas-fw01 | Plan P-01..P-15 | Captura por prueba [E] | PENDIENTE |
| OBJ-10 | Firewall, VPN y monitoreo | §4 obj. 10; Tabla 5 | Los tres funcionando, con registro de eventos | atlas-fw01, WireGuard, Zabbix, logs | Reglas probadas, túnel por perfil, alertas generadas | Logs de denegación, `wg show`, alertas de Zabbix [E] | PENDIENTE |
| OBJ-11 | Respaldo y recuperación | §4 obj. 11; Tabla 5 | Respaldo automatizado con verificación; al menos una restauración documentada; perder ≤ 24 h, restablecer < 4 h | Scripts de respaldo + carpeta compartida en Windows | Restauración cronometrada en entorno aparte (→ DISC-10) | Acta con hora de inicio/fin, checksums, resultado [C] | PENDIENTE |
| OBJ-12 | Evaluar con métricas objetivas | §4 obj. 12; Tabla 5 (p. 23); §12 (p. 10–11) | Informe con disponibilidad, tiempo de respuesta y porcentaje de registros correctos | Zabbix + scripts de medición | Medición durante las ventanas de prueba | Informe de métricas con datos crudos | PENDIENTE |

## B.2 Requisitos funcionales (Tabla 12 + fichas del Anexo H)

| ID | Especificación | Fuente en PDF | Qué debe implementarse | Componente | Cómo se verificará | Evidencia requerida | Estado |
| -- | -------------- | ------------- | ---------------------- | ---------- | ------------------ | ------------------- | ------ |
| RF-01 | Registro de usuarios (prioridad Alta, obj. 1) | Tabla 12 (p. 30); H8 (p. 95); H9 (p. 97–98) | Alta de usuario hecha por un administrador, con rol e institución; correo único; campos obligatorios (→ DISC-16, AMB-07) | Módulo de usuarios (admin) + tabla `usuarios` | Alta válida → puede iniciar sesión; correo repetido → rechazo con motivo; campos vacíos → no se guarda | Tests automatizados + capturas [B] | PENDIENTE |
| RF-02 | Autenticación (Alta, obj. 1) | Tabla 12; Tabla 14 (p. 33–34); H10 (p. 98–99) | Login con credenciales; panel según rol; error que no revela qué dato falló; bloqueo temporal a los 3 intentos fallidos; contraseña con hash; acceso auditado (→ AMB-05) | Autenticación, sesión, `auditoria` | Credenciales válidas → panel del rol; inválidas → mensaje genérico; 3 fallidas → bloqueo | Tests + filas de auditoría + capturas [B] | PENDIENTE |
| RF-03 | Gestión de roles (Alta, obj. 1) | Tabla 12; H11 (p. 99–100) | Roles estudiante, docente y administrador con permisos asociados; acceso no autorizado → 403 y registro | `roles`, `permisos`, `rol_permiso` + middleware [2] | Estudiante → panel docente = 403; docente → gestión administrativa = 403; ambos registrados | Tests + auditoría [B] | PENDIENTE |
| RF-04 | Acceso a actividades educativas (Alta, obj. 2) | Tabla 12; H12 (p. 100–101) | El estudiante ve únicamente las actividades publicadas de sus grupos (→ DISC-15: falta la relación actividad↔grupo) | Actividades + asignación a grupos | Borrador o pendiente no visibles; actividades de otros grupos no visibles | Tests [B] | PENDIENTE |
| RF-05 | Niveles de dificultad (Media, obj. 2) | Tabla 12; H13 (p. 101–102) | Nivel asignado a cada actividad, visible para el estudiante y en los reportes | `niveles_dificultad` | Crear actividad con nivel; verlo en la vista del estudiante y en un reporte | Tests + capturas [B] | PENDIENTE |
| RF-06 | Registro de interacciones (Alta, obj. 3) | Tabla 12; H14 (p. 102–103); H.1.2 (p. 86) | Registrar cambios de opción, pausas y desplazamientos entre preguntas, con marca temporal; poder reconstruir la secuencia (→ AMB-06) | JS cliente + API + `interacciones` | Reconstruir la secuencia de un intento a partir de sus eventos | Consulta de reconstrucción + test [B] | PENDIENTE |
| RF-07 | Registro de resultados (Alta, obj. 3) | Tabla 12; H15 (p. 103–104) | Al cerrar un intento se genera el resultado con su puntaje; los intentos abandonados no generan resultado | `resultados` (1:1 con `intentos`) + trigger | Cerrar → resultado; abandonar → sin resultado | Tests [B] | PENDIENTE |
| RF-08 | Registro de intentos (Alta, obj. 3) | Tabla 12; H16 (p. 104–105) | Cada inicio genera un registro distinguible; estados en curso / finalizado / abandonado | `intentos` | Varios inicios → registros distintos con el estado correcto | Tests [B] | PENDIENTE |
| RF-09 | Registro de tiempo (Alta, obj. 3) | Tabla 12; H17 (p. 105–106) | Duración total y tiempos parciales por pregunta, en segundos; un intento interrumpido registra el tiempo hasta la interrupción | `intentos` / `respuestas` (columnas de tiempo) | Comparación contra reloj; interrupción simulada | Tests [B] | PENDIENTE |
| RF-10 | Perfil de aprendizaje (Media, obj. 5) | Tabla 12; H18 (p. 106–107) | El perfil se actualiza tras cada actividad finalizada; cada indicador es rastreable hasta los datos que lo originaron | `perfiles_aprendizaje`, `indicadores` + motor Nivel 1 | Finalizar actividad → perfil actualizado; rastreo indicador → intentos | Tests + consulta de rastreo [B] | PENDIENTE |
| RF-11 | Panel docente (Alta, obj. 6) | Tabla 12; H19 (p. 107–108) | Evolución individual y grupal en el tiempo; el docente ve solo sus propios grupos | Frontend docente + vistas (`atlas_read`) | Docente A no puede ver el grupo del docente B | Tests + capturas en 3 tamaños [B] | PENDIENTE |
| RF-12 | Recomendaciones (Media, obj. 6) | Tabla 12; H20 (p. 108–109) | Recomendaciones de actividades asociadas al perfil, con la regla que las generó; fundamento consultable | `recomendaciones` + `reglas_analisis` | Cada recomendación muestra regla y datos de entrada | Tests + captura del "por qué" [B] | PENDIENTE |
| RF-13 | Estadísticas y reportes (Media, obj. 6) | Tabla 12; H21 (p. 109–110) | Reportes según el alcance de cada rol; filtros por grupo, actividad y período | Reportes + vistas | Filtros y alcance por rol | Tests [B] | PENDIENTE |
| RF-14 | Gestión administrativa (Alta, obj. 1) | Tabla 12; H22 (p. 110–111) | Crear, modificar y desactivar usuarios; gestionar instituciones y permisos; cada operación auditada con autor y fecha | Módulo de administración | Operaciones + filas de auditoría | Tests [B] | PENDIENTE |
| RF-15 | Auditoría (Media, obj. 7) | Tabla 12; H23 (p. 111–112); §26.3 (p. 43); §28.3 (p. 53) | Registrar inicios de sesión, intentos fallidos y operaciones administrativas; registros no modificables ni eliminables desde la aplicación (→ AMB-30) | `auditoria` (solo INSERT para la app) + `auditoria.log` con `chattr +a` | UPDATE/DELETE con `atlas_app` → denegado; `lsattr` | `SHOW GRANTS`, `lsattr`, tests [B/C] | PENDIENTE |
| RF-16 | Creación de actividades (Alta, obj. 2) | Tabla 12; H24 (p. 112–113) | El docente crea la actividad con preguntas y opciones; queda en borrador; sin preguntas no se envía a aprobación; una respuesta correcta por pregunta | Módulo de actividades | Validaciones | Tests [B] | PENDIENTE |
| RF-17 | Ciclo de aprobación (Media, obj. 2) | Tabla 12; H25 (p. 113–114); §25.3 (p. 36–37) | Estados borrador, pendiente, aprobada, rechazada y publicada; cada transición registrada con su autor; solo las publicadas son visibles (→ DISC-13) | Máquina de estados + historial | Recorrido completo; transiciones inválidas rechazadas | Tests + historial [B] | PENDIENTE |
| RF-18 | Análisis grupal (Alta, obj. 5) | Tabla 12; H26 (p. 114–115); §20.4 (p. 19–21) | Promedios, distribución de resultados, preguntas con mayor proporción de error y estudiantes que requieren atención prioritaria (→ AMB-04) | `analisis_grupal` + vistas/procedimientos + panel | Datos de prueba con resultado conocido → valores esperados | Tests + capturas [B] | PENDIENTE |
| RF-19 | Análisis de patrones (Baja, obj. 5) | Tabla 12; H27 (p. 115–116); §25.4 (p. 38) | K-means por grupo y período; recálculo por período; condición de volumen suficiente; la plataforma sigue funcionando si el servicio cae (→ AMB-03) | atlas-analysis + `agrupamientos` | Sin volumen → no se presenta; servicio caído → el resto opera | Tests pytest + prueba de caída [B] | PENDIENTE |
| RF-20 | Consulta conversacional (Baja, obj. 6) | Tabla 12; H28 (p. 116–117); §25.4 (p. 38–39) | Consultas en lenguaje natural sobre datos ya procesados; ninguna consulta al modelo externo con datos identificables; historial en `conversaciones` (→ AMB-10) | PHP (contexto y anonimización) + atlas-analysis/llm + `conversaciones` | Inspección del contenido enviado al LLM (sin nombres ni cédulas); historial guardado | Log del contenido anonimizado + tests [B] | PENDIENTE |

## B.3 Requisitos no funcionales (Tabla 13 + Tabla H29)

| ID | Especificación | Fuente en PDF | Qué debe implementarse | Componente | Cómo se verificará | Evidencia requerida | Estado |
| -- | -------------- | ------------- | ---------------------- | ---------- | ------------------ | ------------------- | ------ |
| RNF-01 | Seguridad: autenticación y control de acceso | Tabla 13 (p. 32); H29 (p. 117) | Ningún usuario accede a información que no le corresponde | Middleware, permisos, alcance por grupo | Pruebas de acceso cruzado entre roles: todo intento no autorizado devuelve error y queda registrado | Tests + auditoría [B] | PENDIENTE |
| RNF-02 | Disponibilidad | Tabla 13; H29 (p. 117) | ≥ 99 % durante las ventanas de prueba, medida con la herramienta de monitoreo (→ AMB-25) | Zabbix | Ítem de disponibilidad (ICMP/HTTP) durante la ventana | Reporte de disponibilidad de Zabbix [E] | PENDIENTE |
| RNF-03 | Rendimiento | Tabla 13; H29 (p. 118) | ≤ 3 s en las operaciones de consulta más frecuentes (→ AMB-25) | App + BD (índices, vistas) | Medición de tiempos (script con curl o Zabbix web scenario) | Tabla de tiempos medidos [B/E] | PENDIENTE |
| RNF-04 | Respaldo | Tabla 13; H29 (p. 118) | Respaldos según la frecuencia definida, verificables en el destino | Scripts + carpeta compartida en Windows | Listado de respaldos en local y en Windows con fechas | Capturas de ambos destinos [C] | PENDIENTE |
| RNF-05 | Recuperación | Tabla 13; H29 (p. 118) | Restauración completa desde un respaldo, con verificación de integridad | Procedimiento de restauración | Restauración completa en entorno aparte + checksum | Acta de restauración [C] | PENDIENTE |
| RNF-06 | Escalabilidad | Tabla 13; H29 (p. 118) | Incorporar un nuevo módulo sin modificar las capas existentes | Arquitectura por capas | Agregar un módulo de prueba y mostrar el diff (sin cambios en otras capas) | Diff/PR de ejemplo [B] | PENDIENTE |
| RNF-07 | Infraestructura Linux y Windows | Tabla 13; H29 (p. 118) | Despliegue funcional sobre los servidores de §28 y §29 | atlas-srv01, atlas-dc01 | Sistema funcionando en las VM | Capturas [C/D] | PENDIENTE |
| RNF-08 | Segmentación con VLAN | Tabla 13; H29 (p. 119) | Cada segmento obtiene direccionamiento de su propia VLAN | Switch, router, DHCP | P-15 | `ipconfig`/`ip a` por VLAN [E] | PENDIENTE |
| RNF-09 | Control de acceso de red | Tabla 13 (p. 33); H29 (p. 119) | Ejecutar el plan de pruebas de §30.5 con resultados que coincidan con la matriz | Router + firewall + firewalls de host | P-01..P-14 | Capturas [E] | PENDIENTE |
| RNF-10 | Monitoreo | Tabla 13; H29 (p. 119) | Alertas ante los umbrales definidos y registros consultables | Zabbix, rsyslog/journald, Visor de eventos | Forzar el 80 % de CPU, memoria o disco → alerta | Captura de la alerta + logs [E] | PENDIENTE |
| RNF-11 | Usabilidad | Tabla 13; H29 (p. 119) | Personas sin formación técnica completan las tareas principales sin asistencia | Frontend | Prueba de uso con docentes reales (requiere participantes, ver J) | Acta de la prueba de uso | PENDIENTE |
| RNF-12 | Diseño responsivo | Tabla 13; H29 (p. 119) | Escritorio, tableta y celular; cortes 480/768/1024; sin desplazamiento horizontal ni pérdida de contenido | Frontend (CSS) | Verificación en los 3 cortes (navegador automatizado) | Capturas en 3 anchos [B] | PENDIENTE |
| RNF-13 | Mantenibilidad | Tabla 13; H29 (p. 120) | Estructura por capas y criterios de §26.4 | Código | Revisión de estructura, linter PSR-12 | Salida del linter + árbol del proyecto [B] | PENDIENTE |
| RNF-14 | Privacidad | Tabla 13; H29 (p. 120) | Registrar solo los datos necesarios, conforme a la Ley 18.331 | Modelo de datos + LLM | Revisión de campos contra la finalidad declarada | Diccionario de datos con la justificación de cada campo [G] | PENDIENTE |
| RNF-15 | Independencia de servicios externos | Tabla 13 (p. 33); H29 (p. 120) | Con el servicio de análisis o el LLM caídos, siguen operando el registro y la consulta de actividades | App PHP (timeouts, degradación) | Detener atlas-analysis y bloquear el LLM → registrar y consultar funcionan | Test + capturas [B] | PENDIENTE |

## B.4 Arquitectura y aplicación

| ID | Especificación | Fuente en PDF | Qué debe implementarse | Componente | Cómo se verificará | Evidencia requerida | Estado |
| -- | -------------- | ------------- | ---------------------- | ---------- | ------------------ | ------------------- | ------ |
| ARQ-01 | Capas: Usuarios → Presentación → Middleware → Lógica de negocio → Acceso a datos → MySQL; cada capa habla solo con la de al lado | §25.1 (p. 34–35); §25.2 (p. 35) | Separación estricta de capas | App PHP | Revisión de dependencias (ninguna consulta SQL fuera de Repositories) | Análisis estático + árbol [B] | PENDIENTE |
| ARQ-02 | Acceso de los usuarios por HTTPS | §25.1 (p. 34); H7 (p. 94) | TLS en atlas-web (→ AMB-16) | atlas-web | `curl -v https://172.16.40.10` | Captura del certificado y la conexión [B/E] | PENDIENTE |
| ARQ-03 | Comunicación por API REST que devuelve JSON | §25.1; §25.2 (p. 35); Tabla 16 (p. 41) | Endpoints REST/JSON consumidos por el frontend | Controllers + Core (ruteo) | Tests de API | Colección de pruebas de API [B] | PENDIENTE |
| ARQ-04 | Lógica de negocio y motor en PHP, en clases propias, sin atarse a un framework | §25.2 (p. 35); H5 (p. 91) | `Services/` sin dependencias de framework | App PHP | Revisión: Services no importa clases de framework | Revisión de código [B] | PENDIENTE |
| ARQ-05 | Servicio de análisis Python separado, API REST interna; si cae, ATLAS sigue | §25.2 (p. 36); H7 (p. 94) | atlas-analysis (FastAPI) + cliente PHP con timeout | atlas-analysis + PHP | RNF-15 | Test de caída [B] | PENDIENTE |
| ARQ-06 | Cadena de middleware: [1] autenticación → 401; [2] permisos → 403; [3] validación → 422; [4] auditoría | §26.3 (p. 42–43) | Cadena única antes de cada controlador | `app/Middleware` | Tests por código de respuesta | Tests [B] | PENDIENTE |
| ARQ-07 | Estructura de código: solo `public/` expuesto; `app/Core`, `Middleware`, `Controllers`, `Models`, `Services`, `Services/Analysis`, `Repositories`; `config/`, `database/migrations`, `database/seeds`, `tests/`, `.env.example`, `README.md` | §26.2 (p. 41–42) | Árbol exacto | Repositorio | Comparación del árbol | `tree` [B] | PENDIENTE |
| ARQ-08 | Estructura de atlas-analysis: `app/main.py` (FastAPI), `models/clustering.py`, `models/risk.py`, `features.py`, `llm/client.py`, `llm/prompts.py`, `tests/`, `requirements.txt` | §26.2 (p. 42) | Árbol exacto (→ AMB-24: "repositorio aparte") | atlas-analysis | Comparación del árbol | `tree` [B] | PENDIENTE |
| ARQ-09 | Contenedores: atlas-web `nginx:alpine` (80, 443), atlas-php `php:8.3-fpm` (interno), atlas-db `mysql:8.0` (interno), atlas-analysis `python:3.11-slim` (interno); `docker/php/Dockerfile`, `docker/nginx/default.conf`, `docker/mysql/init.sql`, `docker-compose.yml`, `.dockerignore`; un solo comando levanta todo | Tabla 15 (p. 40); §25.5 (p. 40); §26.2 (p. 42); Tabla 16 (p. 41) | `docker-compose.yml` con 4 servicios (→ DISC-01, DISC-02) | Docker Compose en atlas-srv01 | `docker compose ps`; solo 80/443 publicados | Salida de `docker compose ps` y `ss -tlnp` [B/C] | PENDIENTE |
| ARQ-10 | Criterios: DRY, una responsabilidad por clase, capas con dependencias en un solo sentido, PSR-12, comentarios en clases y métodos públicos, commits chicos, una rama por funcionalidad | Tabla 17 (p. 43) | Convenciones aplicadas | Código + Git | Linter PSR-12; historial de Git | Salida del linter + log de Git [B] | PENDIENTE |
| ARQ-11 | Frontend en HTML5, CSS3 y JavaScript, sin depender de librerías externas | Tabla 16 (p. 41) | JS y CSS propios, sin frameworks | `public/` | Revisión: sin CDN ni librerías externas | Listado de assets [B] | PENDIENTE |
| ARQ-12 | Interfaz mobile-first, cortes 480/768/1024; tarjetas en pantalla chica y tabla en grande; paleta sobria; nunca solo color | §26.5 (p. 44); H7 (p. 94) | CSS responsivo accesible | Frontend | Ver RNF-12 | Capturas [B] | PENDIENTE |
| ARQ-13 | Flujo: docente crea → borrador → pendiente → administrador aprueba o rechaza → publicada → estudiante resuelve → se registran respuestas, tiempo, intentos y resultado → motor de análisis individual y grupal → perfil y recomendaciones | §25.3 (p. 36) | Flujo de punta a punta (→ DISC-13, DISC-14) | Toda la aplicación | Prueba de punta a punta | Video o capturas secuenciales [B] | PENDIENTE |

## B.5 Motor de análisis

| ID | Especificación | Fuente en PDF | Qué debe implementarse | Componente | Cómo se verificará | Evidencia requerida | Estado |
| -- | -------------- | ------------- | ---------------------- | ---------- | ------------------ | ------------------- | ------ |
| ANA-01 | Puntaje = correctas / total de preguntas × 100 | §25.4 (p. 37) | Cálculo exacto | Motor Nivel 1 (PHP) | Test unitario con casos conocidos | Tests [B] | PENDIENTE |
| ANA-02 | Eficiencia: relaciona el puntaje con el tiempo respecto al promedio del grupo | §25.4 (p. 37) | Fórmula a definir (→ AMB-02) | Motor Nivel 1 | Test unitario | Tests [B] | PENDIENTE |
| ANA-03 | Mejora = resultado del último intento − resultado del primero | §25.4 (p. 37) | Cálculo exacto | Motor Nivel 1 | Test unitario | Tests [B] | PENDIENTE |
| ANA-04 | Persistencia = cantidad de intentos hasta llegar al resultado final | §25.4 (p. 37) | Cálculo exacto | Motor Nivel 1 | Test unitario | Tests [B] | PENDIENTE |
| ANA-05 | Reglas si-entonces guardadas en la BD (`reglas_analisis`), ajustables por el administrador sin tocar el código; resultado determinista | §25.4 (p. 37); §27.3 (p. 47) | Intérprete de reglas leído desde la BD + ABM de reglas para el administrador | Motor Nivel 1 + BD | Mismos datos → mismo resultado; cambiar un umbral en la BD cambia el resultado | Tests [B] | PENDIENTE |
| ANA-06 | Al menos 8 reglas documentadas | Tabla 5 obj. 5 (p. 22) | Catálogo de ≥ 8 reglas. **El PDF no las enumera** (→ AMB-01) | `reglas_analisis` (seeds) | Revisión del catálogo | Catálogo de reglas [B/G] | PENDIENTE |
| ANA-07 | Trazabilidad: de cada recomendación se puede rastrear qué regla la generó y con qué datos | §25.4 (p. 37); H18 (p. 107); H20 (p. 109) | Guardar regla, versión y valores de entrada por recomendación | `recomendaciones` + relación con regla (→ DISC-15) | Consulta "¿por qué?" | Captura + consulta [B] | PENDIENTE |
| ANA-08 | Agrupamiento de perfiles con K-means (scikit-learn) | §25.4 (p. 38); RF-19 | `models/clustering.py` | atlas-analysis | pytest con datos sintéticos rotulados como tales | Tests [B] | PENDIENTE |
| ANA-09 | Detección de riesgo con regresión logística (scikit-learn) | §25.4 (p. 38) | `models/risk.py` (→ AMB-03: variable objetivo no definida) | atlas-analysis | pytest | Tests [B] | PENDIENTE |
| ANA-10 | Variables de los modelos: puntaje promedio, tiempo relativo al grupo, cantidad de intentos, variación entre intentos, actividades abandonadas, frecuencia de uso | §25.4 (p. 38) | `features.py` con exactamente esas 6 variables | atlas-analysis | Test de `features.py` | Tests [B] | PENDIENTE |
| ANA-11 | El Nivel 2 se incorpora cuando haya volumen suficiente; presentar ML sobre 20 registros sería incorrecto | §25.4 (p. 38); H6 (p. 93); H27 (p. 115) | Condición explícita de volumen (→ AMB-03) | atlas-analysis + UI | Con datos insuficientes, la API responde "insuficiente" y la UI no muestra agrupamientos | Tests [B] | PENDIENTE |
| ANA-12 | El LLM no analiza ni decide: recibe indicadores de los niveles 1 y 2 y los redacta; ATLAS consulta la BD y arma el contexto | §25.4 (p. 38–39); §18 (p. 14); H7 (p. 94) | Flujo BD → indicadores → contexto → LLM → texto | PHP + atlas-analysis/llm | Revisión del flujo: el LLM nunca recibe filas crudas | Traza de una consulta [B] | PENDIENTE |
| ANA-13 | Ninguna consulta al modelo incluye nombres, cédulas ni datos identificables; la asociación con la persona se resuelve del lado de ATLAS | §25.4 (p. 39); H5 (p. 92); H28 (p. 117) | Anonimizador y re-identificación local (→ AMB-10) | PHP + atlas-analysis | Test: el contenido enviado no contiene ningún nombre ni cédula de la BD | Tests + log [B] | PENDIENTE |
| ANA-14 | Consultas de ejemplo: "¿Cómo viene el grupo 3A en resolución de problemas?", "¿Qué estudiantes tuvieron más dificultad esta semana?", "Explicame por qué ATLAS recomienda esto para Juan" | §25.4 (p. 38–39) | Soporte de esos tres tipos de consulta (→ AMB-08: "resolución de problemas" no existe en el modelo) | Asistente | Ejecutar las 3 consultas | Capturas [B] | PENDIENTE |
| ANA-15 | El análisis grupal es la vía principal de valor: reducir el tiempo para identificar dónde intervenir | §20.4 (p. 19–21); H.1.2 (p. 86); H.2.3 (p. 91) | Panel que prioriza la vista grupal sobre el detalle individual | Panel docente | Prueba de uso (RNF-11) | Capturas + acta [B] | PENDIENTE |
| ANA-16 | No diagnostica, no etiqueta, no sustituye el criterio del docente | §2 (p. 6); §6 (p. 8); §18 (p. 14); H.1.2 (p. 86) | Redacción de la interfaz y de las recomendaciones como sugerencias | UI + textos | Revisión de textos | Revisión [B] | PENDIENTE |

## B.6 Base de datos

| ID | Especificación | Fuente en PDF | Qué debe implementarse | Componente | Cómo se verificará | Evidencia requerida | Estado |
| -- | -------------- | ------------- | ---------------------- | ---------- | ------------------ | ------------------- | ------ |
| BD-01 | Almacenar estudiantes, docentes, instituciones, actividades, resultados, intentos, tiempos, eventos, perfiles, recomendaciones, usuarios, roles, permisos, auditoría y backups | §7 (p. 8) | Cobertura de todas esas entidades (→ DISC-15: "backups" sin tabla) | MySQL | Matriz entidad → tabla | Diccionario de datos [G] | PENDIENTE |
| BD-02 | Cinco grupos (identidad, contenido, interacción, análisis, control) y las tablas de Tabla 19 | §27.1 (p. 45); Tabla 19 (p. 45–46) | Unión de §27.1 y Tabla 19 = 24 tablas (→ DISC-15) | MySQL | Conteo y comparación | DER [G] | PENDIENTE |
| BD-03 | 3FN; única excepción: `resultados` guarda el puntaje calculado, sincronizado con trigger | §27.3 (p. 46) | Esquema en 3FN + trigger | MySQL | Revisión de dependencias funcionales; test del trigger | DER + test [G] | PENDIENTE |
| BD-04 | Separar `intentos` de `resultados` y `interacciones` de `respuestas` | §27.3 (p. 46) | Tablas separadas | MySQL | Revisión | DER [G] | PENDIENTE |
| BD-05 | Las reglas del motor viven en la BD | §27.3 (p. 47) | `reglas_analisis` editable | MySQL + ABM | Ver ANA-05 | [G] | PENDIENTE |
| BD-06 | FK en todas las relaciones; CHECK de rangos de puntajes y tiempos; índices sobre FK y columnas filtradas; índice compuesto (usuario_id, actividad_id) en `intentos`; vistas para el panel docente; procedimientos (indicadores y análisis grupal); triggers (auditoría y resultados); transacciones (resolución completa atómica) | Tabla 20 (p. 47) | Todo lo listado (→ DISC-12) | MySQL | `information_schema`, tests de CHECK, transacción con falla simulada | Script + salidas [G] | PENDIENTE |
| BD-07 | Usuarios MySQL: `atlas_app` (SELECT, INSERT, UPDATE en tablas operativas); `atlas_read` (SELECT sobre vistas de reporte); `atlas_analysis` (SELECT en interacción, INSERT en análisis); `atlas_backup` (SELECT, LOCK TABLES, SHOW VIEW); `atlas_admin` (todo sobre atlas_db, nunca lo usa la app) | Tabla 21 (p. 47–48) | Cinco usuarios con esos privilegios (→ DISC-11) | MySQL | `SHOW GRANTS` + intentos denegados (DROP con atlas_app) | Salidas [G] | PENDIENTE |
| BD-08 | MySQL solo acepta conexiones locales (bind-address = 127.0.0.1); sentencias preparadas; contraseñas con hash; operaciones sensibles auditadas | §27.5 (p. 48); H5 (p. 92) | Configuración + código (→ DISC-02) | MySQL + Repositories | `ss -tlnp`; revisión de código; nmap a 3306 desde la red | Salidas [C/G] | PENDIENTE |
| BD-09 | Servicio con usuario sin acceso interactivo; datos en `/srv/atlas/datos/` del grupo atlas-db con permisos 770; el respaldo accede con una ACL de lectura; logs en `/srv/atlas/logs/`; gestionado por systemd | Tabla 22 (p. 48) | Integración con el SO (→ DISC-02) | atlas-srv01 | `ls -ld`, `getfacl`, `systemctl status` | Salidas [C] | PENDIENTE |
| BD-10 | Respaldo con `mysqldump --single-transaction` (sin bloquear tablas) | §27.7 (p. 49) | Script de respaldo | atlas-srv01 | Respaldo con la app en uso | Log [C] | PENDIENTE |
| BD-11 | Entregables: DER, diccionario de datos, script de creación, usuarios y privilegios creados, datos de prueba | Tabla 23 (p. 49) | Los cinco entregables | Repositorio | Existencia y ejecución del script | [G] | PENDIENTE |

## B.7 Linux / POSIX (atlas-srv01)

| ID | Especificación | Fuente en PDF | Qué debe implementarse | Componente | Cómo se verificará | Evidencia requerida | Estado |
| -- | -------------- | ------------- | ---------------------- | ---------- | ------------------ | ------------------- | ------ |
| LNX-01 | Ubuntu Server 24.04 LTS, `atlas-srv01`, 172.16.40.10/24, VLAN 40, sin entorno gráfico; servicios Apache (→ DISC-01), PHP, MySQL, Samba, SSH | Tabla 24 (p. 50) | VM instalada y configurada | VirtualBox | `hostnamectl`, `ip a`, `lsb_release -a` | Capturas [C] | PENDIENTE |
| LNX-02 | Usuarios del SO (técnicos, de servicios) separados de los usuarios de ATLAS (en la BD); un docente no tiene cuenta en Linux | §28.2 (p. 50) | Ninguna cuenta de persona usuaria de ATLAS en el SO | atlas-srv01 | `getent passwd` | Salida [C] | PENDIENTE |
| LNX-03 | Grupos: atlas-admin 5001, atlas-web 5002, atlas-db 5003, atlas-backup 5004, atlas-audit 5005 | Tabla 25 (p. 51) | `groupadd -g` exactos | atlas-srv01 | `getent group` | Salida [C] | PENDIENTE |
| LNX-04 | Usuarios: atlasadmin 5001/atlas-admin/bash; atlasweb 5002/atlas-web/nologin; atlasdb 5003/atlas-db/nologin; atlasbkp 5004/atlas-backup/nologin | Tabla 26 (p. 51) | `useradd` exactos | atlas-srv01 | `getent passwd`; `su` a cuenta nologin falla | Salidas [C] | PENDIENTE |
| LNX-05 | Matriz de permisos por recurso (web, datos, logs, scripts, backups, config) × (admin, web, db, backup, audit) | Tabla 27 (p. 51–52) | Permisos efectivos iguales a la matriz (→ DISC-07) | atlas-srv01 | Script que prueba cada celda con `sudo -u` | Salida del script [C] | PENDIENTE |
| LNX-06 | Jerarquía de `/srv/atlas` con dueños y modos | §28.3 (p. 52) | `chown`/`chmod` exactos (→ DISC-07) | atlas-srv01 | `ls -la`, `stat` | Salidas [C] | PENDIENTE |
| LNX-07 | ACL: atlasbkp rx en datos; atlasweb rwx + default en logs; atlas-audit rx + default en logs | §28.3 (p. 52–53) | Los 5 `setfacl` (+ los que falten, → DISC-07) | atlas-srv01 | `getfacl -R /srv/atlas` | Salida [C] | PENDIENTE |
| LNX-08 | Atributos: `chattr +i /srv/atlas/config/atlas.conf`; `chattr +a /srv/atlas/logs/auditoria.log`; el procedimiento `chattr -i` va al manual de operación | §28.3 (p. 53) | Atributos aplicados (→ AMB-30) | atlas-srv01 | `lsattr`; intento de borrado falla | Salidas [C] | PENDIENTE |
| LNX-09 | sshd: PermitRootLogin no; PasswordAuthentication no; PubkeyAuthentication yes; AllowGroups atlas-admin; AllowUsers atlasadmin@172.16.50.*; MaxAuthTries 3 | §28.4 (p. 53) | `/etc/ssh/sshd_config` (→ DISC-08) | atlas-srv01 | `sshd -T`; SSH desde VLAN 50 funciona y desde otra VLAN falla | Salidas [C/E] | PENDIENTE |
| LNX-10 | TCP Wrappers: hosts.deny `ALL: ALL`; hosts.allow `sshd: 172.16.50.0/255.255.255.0` | §28.4 (p. 54) | Archivos exactos (libwrap sigue presente en Ubuntu 24.04, verificado) | atlas-srv01 | `ldd /usr/sbin/sshd`; prueba de conexión | Salidas [C] | PENDIENTE |
| LNX-11 | UFW: deny incoming; allow outgoing; 22 desde 172.16.50.0/24; 80,443 desde 172.16.20.0/24 y 172.16.30.0/24; 139,445 desde 172.16.40.0/24; logging on | §28.4 (p. 54) | Reglas (→ DISC-06: contradicen las reglas 1, 3 y 9) | atlas-srv01 | `ufw status verbose` | Salida [C] | PENDIENTE |
| LNX-12 | MySQL no aparece en ninguna regla; escucha solo local | §28.4 (p. 54) | Sin regla para 3306 | atlas-srv01 | nmap desde otra VLAN → filtrado | Salida de nmap [E] | PENDIENTE |
| LNX-13 | Qué se respalda: BD (alta), configuraciones (alta), usuarios/grupos/ACL (alta), código (media), logs (media) | Tabla 28 (p. 54–55) | Todo en el esquema (→ DISC-10: los logs faltan en los comandos) | Scripts | Contenido de los respaldos | Listado del contenido [C] | PENDIENTE |
| LNX-14 | Frecuencia: completo domingos 02:00, 4 semanas, local + Windows; incremental diario 02:00, 7 días, local; configuraciones al cambiar, 10 versiones, local + Windows; criterio 3-2-1 | Tabla 29 (p. 55) | Programación y retención (→ DISC-10, AMB-22) | systemd timers/cron + share | `systemctl list-timers`; conteo de versiones | Salidas [C] | PENDIENTE |
| LNX-15 | Comandos: mysqldump con --single-transaction --routines --triggers + gzip; tar con --acls --xattrs de web y config; getent passwd/group; getfacl -R | §28.5 (p. 55) | Script basado en esos comandos (→ DISC-11) | Scripts | Ejecución | Log [C] | PENDIENTE |
| LNX-16 | Restauración: 1) checksum; 2) parar web y BD; 3) restaurar BD; 4) restaurar archivos con --acls --xattrs; 5) setfacl --restore; 6) levantar y probar; 7) anotar | §28.5 (p. 56) | Procedimiento y script | Manual de operación | Restauración real | Acta [C] | PENDIENTE |
| LNX-17 | Perder como máximo 24 h de datos; volver a operar en menos de 4 h | §28.5 (p. 56); Tabla 5 | RPO y RTO medidos (→ DISC-10) | Esquema de respaldo | Restauración cronometrada | Acta con tiempos [C] | PENDIENTE |
| LNX-18 | Verificación automática diaria de integridad; restauración de prueba mensual en entorno aparte; revisión trimestral; actas | §28.5 (p. 56) | Script de verificación + procedimiento | Scripts | Logs de verificación | Logs + actas [C] | PENDIENTE |
| LNX-19 | Entregables: VM instalada, usuarios/grupos/permisos aplicados, ACL y atributos, firewall y hosts permitidos | Tabla 30 (p. 56–57) | Los cuatro | atlas-srv01 | Ver filas anteriores | [C] | PENDIENTE |
| LNX-20 | Logs: journalctl/rsyslog centralizados del lado Linux; logs de UFW | §8 (p. 9); Tabla 46 (p. 72) | rsyslog + journald + UFW logging | atlas-srv01 | `journalctl`, `/var/log/ufw.log` | Capturas [C/E] | PENDIENTE |
| LNX-21 | Automatización mediante scripts; jerarquía de permisos documentada | §8 (p. 9) | Scripts versionados en `/srv/atlas/scripts` | Repositorio + servidor | Ejecución reproducible | Scripts [C] | PENDIENTE |

## B.8 Windows Server (atlas-dc01)

| ID | Especificación | Fuente en PDF | Qué debe implementarse | Componente | Cómo se verificará | Evidencia requerida | Estado |
| -- | -------------- | ------------- | ---------------------- | ---------- | ------------------ | ------------------- | ------ |
| WIN-01 | Windows Server 2022, `atlas-dc01`, 172.16.40.20/24, VLAN 40, controlador de dominio de `atlas.local` | Tabla 31 (p. 58) | DC instalado y promovido | VirtualBox | `Get-ADDomain`, `ipconfig /all` | Capturas [D] | PENDIENTE |
| WIN-02 | OU: ATLAS\{Administracion, Docentes, Estudiantes}\{Usuarios, Equipos}, ATLAS\Servidores, ATLAS\ServiciosTI; **OU=Grupos en la raíz del dominio** | §29.2 (p. 58) | Árbol exacto (→ PR-01) | AD | `Get-ADOrganizationalUnit` | Captura de ADUC [D] | PENDIENTE |
| WIN-03 | Grupos GG_Administracion, GG_Docentes, GG_Estudiantes, GG_SoporteTI dentro de OU=Grupos | §29.2 (p. 58) | Grupos de seguridad globales | AD | `Get-ADGroup` | Captura [D] | PENDIENTE |
| WIN-04 | Las OU siguen la división de las VLAN; los equipos de las VLAN 10, 20 y 30 se unen al dominio y quedan en el contenedor Equipos de su OU | §29.2 (p. 58–59) | Unión al dominio y ubicación de equipos | AD + clientes | `Get-ADComputer` por OU | Captura [D] | PENDIENTE |
| WIN-05 | Contraseñas: mínimo 10, complejidad, historial 5, vencen a los 90 días; bloqueo a los 5 intentos durante 15 min; cuentas administrativas separadas; Administrator renombrada; Guest deshabilitada; auditoría de logins, cambios en el directorio y accesos a recursos; delegación acotada por OU | Tabla 32 (p. 59) | GPO_Seguridad_Base + configuración de cuentas | AD/GPO | `Get-ADDefaultDomainPasswordPolicy`; 5 intentos → bloqueo | Capturas [D] | PENDIENTE |
| WIN-06 | GPO_Seguridad_Base (dominio); GPO_Estudiantes (sin instalar software, unidades mapeadas); GPO_Docentes (recursos compartidos e impresoras); GPO_Servidores (endurecimiento y actualizaciones controladas); GPO_Auditoria (registro detallado) | Tabla 33 (p. 59–60) | Cinco GPO vinculadas (→ DISC-09) | GPMC | `gpresult /r` en un cliente | Capturas [D] | PENDIENTE |
| WIN-07 | DNS integrado en AD: zona directa atlas.local, zona inversa de 172.16.0.0/16, reenviadores; el servidor Linux registrado | §29.4 (p. 60) | Zonas y registros (→ AMB-18) | DNS | `nslookup atlas-srv01.atlas.local`; resolución inversa | Capturas [D] | PENDIENTE |
| WIN-08 | DHCP: VLAN 10 .100–.200; VLAN 20 .100–.200; VLAN 30 .100–.250; VLAN 40 y 50 sin DHCP; cada ámbito entrega puerta de enlace, DNS del dominio y sufijo DNS | Tabla 34 (p. 60) | Tres ámbitos con opciones 003, 006 y 015 | DHCP | P-15 | Capturas [D/E] | PENDIENTE |
| WIN-09 | Los pedidos DHCP llegan al DC por el reenvío configurado en el router de capa 3 | §29.4 (p. 60–61) | `ip helper-address 172.16.40.20` en las interfaces de VLAN 10, 20 y 30 | atlas-rt01 | P-15 | `show run` + leases [E] | PENDIENTE |
| WIN-10 | Integración: Linux registrado en DNS; atlas-srv01 unido con SSSD/Kerberos; Samba accesible desde el dominio; grupos AD → POSIX; destino de respaldos en carpeta compartida de Windows; NTP desde el DC | Tabla 35 (p. 61) | Todos los ítems (→ DISC-24, PR-02, DISC-20) | srv01 + dc01 | `realm list`, `id`, `timedatectl`, `smbclient` | Capturas [C/D] | PENDIENTE |
| WIN-11 | GG_SoporteTI → atlas-admin (administrar el servidor); GG_Docentes y GG_Estudiantes → sin grupo POSIX (solo web) | Tabla 36 (p. 62) | Mapeo (→ DISC-08) | SSSD | `id usuario_soporte` | Salida [C] | PENDIENTE |
| WIN-12 | Firewall de Windows Defender en atlas-dc01 como segunda capa | §30.5 (p. 72) | Reglas de entrada (→ AMB-19) | atlas-dc01 | `Get-NetFirewallRule` | Captura [D] | PENDIENTE |
| WIN-13 | Visor de eventos para eventos de seguridad del dominio | Tabla 46 (p. 72) | Auditoría activa y revisada | atlas-dc01 | Eventos 4624, 4625, 4740, 5136 | Capturas [D/E] | PENDIENTE |
| WIN-14 | Entregables: Windows instalado, dominio creado, OU y grupos, DNS y DHCP, GPO base | Tabla 37 (p. 62) | Los cinco | atlas-dc01 | Ver filas anteriores | [D] | PENDIENTE |
| WIN-15 | Suposición: al menos un cliente Windows unido al dominio para las pruebas de integración | H6 (p. 93) | VM cliente Windows (Pro/Enterprise) | VirtualBox | Unión al dominio | Captura [D] | PENDIENTE |

## B.9 Red

| ID | Especificación | Fuente en PDF | Qué debe implementarse | Componente | Cómo se verificará | Evidencia requerida | Estado |
| -- | -------------- | ------------- | ---------------------- | ---------- | ------------------ | ------------------- | ------ |
| RED-01 | Rango 172.16.0.0/16 con una /24 por VLAN (evita solapamiento con redes hogareñas vía VPN) | §30.1 (p. 63); Tabla 51 (p. 77) | Direccionamiento | Todos | Revisión de configuraciones | [E] | PENDIENTE |
| RED-02 | VLAN 10 172.16.10.0/24 gw .1; VLAN 20 172.16.20.0/24 gw .1; VLAN 30 172.16.30.0/24 gw .1; VLAN 40 172.16.40.0/24 gw .1; VLAN 50 172.16.50.0/24 gw .1 | Tabla 38 (p. 63); Tabla 2 (p. 9) | Subinterfaces del router con esas IP | atlas-rt01 | `show ip interface brief` | Captura [E] | PENDIENTE |
| RED-03 | Dimensionamiento (12, 25, 120, 2, 3 equipos); /24 uniforme; VLSM evaluado y descartado | Tabla 39 (p. 63–64) | Mantener /24 en todas | Diseño | Revisión | — | PENDIENTE |
| RED-04 | IP fijas: atlas-srv01 172.16.40.10; atlas-dc01 172.16.40.20 | Tabla 40 (p. 65) | Configuración estática | Servidores | `ip a`, `ipconfig` | Capturas [C/D] | PENDIENTE |
| RED-05 | Topología: Internet – atlas-fw01 (firewall perimetral, NAT de origen, VPN WireGuard, UDP 51820) – atlas-rt01 (router L3, enrutamiento entre VLAN, ACL, DHCP relay) – troncal 802.1Q Gi0/1 (VLAN 10,20,30,40,50; nativa 999) – atlas-sw01 – VLAN 10..50 | Figura 1 (p. 65) | Topología exacta (→ DISC-03, DISC-04) | Laboratorio | Diagrama del laboratorio igual a la Figura 1 | Captura PT/GNS3 [E] | PENDIENTE |
| RED-06 | Puertos: Fa0/1–4 VLAN 10; Fa0/5–10 VLAN 20; Fa0/11–20 VLAN 30; Fa0/21 VLAN 40 (srv01); Fa0/22 VLAN 40 (dc01); Fa0/23 VLAN 50 (estación de administración); Fa0/24 deshabilitado VLAN 999; Gi0/1 troncal (10,20,30,40,50) al router; Gi0/2 deshabilitado VLAN 999 | Tabla 41 (p. 66) | Configuración exacta del switch (→ DISC-22) | atlas-sw01 | `show vlan brief`, `show interfaces trunk`, `show interfaces status` | Capturas [E] | PENDIENTE |
| RED-07 | Puertos sin uso deshabilitados y en VLAN 999, sin enrutamiento ni servicios | Tabla 41 nota (p. 66) | `shutdown` + `switchport access vlan 999`; sin subinterfaz 999 en el router | atlas-sw01/rt01 | `show interfaces status` | Captura [E] | PENDIENTE |
| RED-08 | VLAN nativa 999 en el troncal (no la VLAN 1) | §30.1 (p. 66); Figura 1 | `switchport trunk native vlan 999` en ambos extremos | sw01 + rt01 | `show interfaces trunk` | Captura [E] | PENDIENTE |
| RED-09 | Las interfaces de administración del switch y del router pertenecen a la VLAN 50; es la única desde la que se administra la infraestructura | §30.1 (p. 67); §30.2 (p. 69) | SVI VLAN 50 en el switch; acceso VTY restringido a 172.16.50.0/24 (→ AMB-12, AMB-23) | sw01 + rt01 | SSH desde VLAN 50 funciona; desde otras falla | Capturas [E] | PENDIENTE |
| RED-10 | Inventario: atlas-sw01 (switch L2, Packet Tracer); atlas-rt01 (router L3, Packet Tracer); atlas-fw01 (firewall perimetral con estado, NAT, terminación de VPN; máquina virtual) | Tabla 42 (p. 67) | Tres equipos con esos nombres (→ AMB-11) | Laboratorio | `show run \| include hostname` | Capturas [E] | PENDIENTE |
| RED-11 | Entorno: red en Packet Tracer (Hito 1); servidores en VirtualBox; migración a GNS3 en el Sprint 2 cuando se necesite integrar red y servidores | §30.1 (p. 67); Tabla 51 (p. 77) | Dos etapas documentadas (→ DISC-22) | Laboratorio | Archivos .pkt y proyecto GNS3 | Archivos + capturas [E] | PENDIENTE |
| RED-12 | Router: enrutamiento entre VLAN, listas de control de acceso, DHCP relay | Tabla 42 (p. 67); Figura 1 | Router-on-a-stick con subinterfaces, ACL y helper (→ DISC-04) | atlas-rt01 | `show ip route`, `show access-lists` | Capturas [E] | PENDIENTE |
| RED-13 | Matriz de comunicación entre VLAN y VPN (Tabla 43 completa, con notas a, b, c) | Tabla 43 (p. 68–69) | Políticas que la implementen exactamente | Router + firewall | P-01..P-14 | [E] | PENDIENTE |
| RED-14 | Principios: estudiantes solo llegan al servicio web; los servidores no inician conexiones a VLAN de usuarios; Gestión llega a todos y nadie llega a Gestión; a los servidores solo se llega por HTTPS (ningún usuario alcanza SSH ni la BD) | §30.2 (p. 69) | Reflejado en las ACL y los firewalls | Router + firewall + hosts | P-02..P-05, P-08, P-09 | [E] | PENDIENTE |

## B.10 Firewall y NAT (Tabla 44, págs. 69–70)

| ID | Especificación | Fuente en PDF | Qué debe implementarse | Componente | Cómo se verificará | Evidencia requerida | Estado |
| -- | -------------- | ------------- | ---------------------- | ---------- | ------------------ | ------------------- | ------ |
| FW-00 | Política base: negar entrante, permitir saliente, más las restricciones entre VLAN | §30.3 (p. 69) | Política por dispositivo (→ DISC-05) | fw01 + rt01 | Revisión de la política por defecto | Configuración [E] | PENDIENTE |
| FW-01 | Regla 1: VLAN 10, 20, 30 → 172.16.40.10 HTTPS 443 → Permitir | Tabla 44 | ACE en el router | atlas-rt01 | P-01 | [E] | PENDIENTE |
| FW-02 | Regla 2: VLAN 10, 20, 30 → 172.16.40.20 servicios de dominio → Permitir | Tabla 44 + nota a (p. 70) | ACE para DNS 53, Kerberos 88, LDAP 389, LDAPS 636, SMB 445, NTP 123, RPC 135 + rango dinámico (→ DISC-19) | atlas-rt01 | P-06, unión al dominio | [E] | PENDIENTE |
| FW-03 | Regla 3: VLAN 10, 20 → 172.16.40.10 SMB 445 → Permitir | Tabla 44 | ACE | atlas-rt01 | P-07 | [E] | PENDIENTE |
| FW-04 | Regla 4: Router L3 (relay) → 172.16.40.20 DHCP UDP 67 → Permitir | Tabla 44 | Permitir relay y respuesta (tráfico originado en el router) | atlas-rt01 + firewall del DC | P-15 | [E] | PENDIENTE |
| FW-05 | Regla 5: VLAN 10, 20, 30, 50 → Internet HTTP 80, HTTPS 443 → Permitir | Tabla 44 (p. 70) | Regla en fw01 (y en el router hacia fw01) (→ DISC-21) | fw01 + rt01 | P-12 | [E] | PENDIENTE |
| FW-06 | Regla 6: VLAN 50 → VLAN 10, 20, 30, 40 SSH 22, RDP 3389 → Permitir | Tabla 44 | ACE | atlas-rt01 | P-10, P-11 | [E] | PENDIENTE |
| FW-07 | Regla 7: VLAN 40 → Internet HTTP 80, HTTPS 443, DNS 53 (DNS solo desde el DC, para los reenviadores) → Permitir | Tabla 44 + nota b (p. 70) | Regla en fw01 (→ DISC-18, DISC-20) | fw01 + rt01 | apt, DNS externo desde el DC | [E] | PENDIENTE |
| FW-08 | Regla 8: 10.8.0.0/25 → VLAN 50 Todo → Permitir | Tabla 44 | Regla en fw01 + ruta en rt01 | fw01 | Prueba VPN administrador | [E] | PENDIENTE |
| FW-09 | Regla 9: 10.8.0.128/25 → 172.16.40.10 HTTPS 443 → Permitir | Tabla 44 | Regla en fw01 | fw01 | P-13 | [E] | PENDIENTE |
| FW-10 | Regla 10: Cualquiera → 172.16.40.10 MySQL 3306 → Negar y registrar (registro específico, aunque la regla 12 ya lo cubre) | Tabla 44 + explicación (p. 70) | Deny + log en el router y en fw01 | rt01 + fw01 | P-03 | Log de la denegación [E] | PENDIENTE |
| FW-11 | Regla 11: VLAN 30 → VLAN 10, 20, 50 Todo → Negar y registrar | Tabla 44 | Deny + log | atlas-rt01 | P-04, P-05 | Log [E] | PENDIENTE |
| FW-12 | Regla 12: Cualquiera → Cualquiera Todo → Negar y registrar | Tabla 44 | Deny final explícito + log | rt01 + fw01 | P-02, P-08, P-09, P-14 | Log [E] | PENDIENTE |
| FW-13 | Evaluación en orden, de arriba abajo; se aplica la primera coincidencia | Tabla 44 nota (p. 70) | Orden exacto de las ACE | rt01 + fw01 | `show access-lists` con contadores | Captura [E] | PENDIENTE |
| FW-14 | Firewall con estado: las respuestas de una sesión permitida se aceptan sin regla propia | Tabla 43 nota (p. 68); Tabla 44 nota (p. 70); Tabla 42 (p. 67) | Inspección con estado (→ DISC-04) | fw01 (y router según la decisión) | Prueba de conexión iniciada desde cada lado | [E] | PENDIENTE |
| FW-15 | El rango RPC dinámico se fija en el DC y se documenta en el Sprint 2 | Tabla 44 nota a (p. 70) | Valor explícito (→ DISC-19) | atlas-dc01 + ACL | `netsh int ipv4 show dynamicport tcp` | Captura [D] | PENDIENTE |
| FW-16 | DNS hacia Internet únicamente desde el controlador de dominio | Tabla 44 nota b (p. 70) | Regla restringida a 172.16.40.20 | fw01 | `nslookup` externo desde srv01 → solo vía DC | [E] | PENDIENTE |
| FW-17 | NAT de origen para la salida a Internet; sin traducción de destino hacia servidores; el acceso externo solo por VPN | §30.3 NAT (p. 70) | SNAT/masquerade en fw01; ningún DNAT | fw01 | Escaneo desde el lado WAN → sin servicios expuestos salvo UDP 51820 | nmap desde WAN [E] | PENDIENTE |
| FW-18 | Las reglas de Tabla 44 se implementan en el router y en el firewall perimetral; además, firewall de host en cada servidor (ufw en srv01, Windows Defender en dc01) | §30.5 (p. 72) | Dos capas | rt01 + fw01 + hosts | Revisión cruzada | Configuraciones [E] | PENDIENTE |

## B.11 VPN (Tabla 45, pág. 71)

| ID | Especificación | Fuente en PDF | Qué debe implementarse | Componente | Cómo se verificará | Evidencia requerida | Estado |
| -- | -------------- | ------------- | ---------------------- | ---------- | ------------------ | ------------------- | ------ |
| VPN-01 | WireGuard (elegido frente a OpenVPN e IPsec) | §30.4 (p. 71); Tabla 51 (p. 77) | Servidor WireGuard (→ DISC-03: dónde) | atlas-fw01 (propuesto) | `wg show` | Captura [E] | PENDIENTE |
| VPN-02 | Red del túnel 10.8.0.0/24 dividida en 2 segmentos | Tabla 45 | Direccionamiento del túnel | fw01 | `ip a show wg0` | Captura [E] | PENDIENTE |
| VPN-03 | Segmento de administradores 10.8.0.0/25 (10.8.0.1–10.8.0.126) | Tabla 45 | AllowedIPs de pares administradores dentro del /25 | fw01 | `wg show` | Captura [E] | PENDIENTE |
| VPN-04 | Segmento de docentes 10.8.0.128/25 (10.8.0.129–10.8.0.254) | Tabla 45 | AllowedIPs de pares docentes dentro del /25 | fw01 | `wg show` | Captura [E] | PENDIENTE |
| VPN-05 | Puerto UDP 51820 | Tabla 45; Figura 1 | ListenPort 51820; único puerto expuesto en WAN | fw01 | nmap -sU desde WAN | Captura [E] | PENDIENTE |
| VPN-06 | Autenticación con claves públicas, una por dispositivo | Tabla 45 | Un `[Peer]` por dispositivo | fw01 + clientes | Revisión de la configuración (sin claves privadas en el repo) | Captura [E] | PENDIENTE |
| VPN-07 | Alcance del perfil de administrador: VLAN 50 (regla 8) | Tabla 45 | Regla 8 (→ AMB-23) | fw01 | Prueba con par administrador | Captura [E] | PENDIENTE |
| VPN-08 | Alcance del perfil de docente: HTTPS hacia 172.16.40.10 (regla 9) | Tabla 45 | Regla 9 | fw01 | P-13, P-14 | Capturas [E] | PENDIENTE |
| VPN-09 | El firewall distingue el perfil por la IP de origen; entrar por VPN no da acceso a toda la red | Tabla 45 nota; §30.4 (p. 71) | Sin NAT del túnel antes del filtrado; reglas por origen | fw01 | P-14 + prueba de administrador hacia VLAN 30 (debe fallar) | Capturas [E] | PENDIENTE |

## B.12 Monitoreo

| ID | Especificación | Fuente en PDF | Qué debe implementarse | Componente | Cómo se verificará | Evidencia requerida | Estado |
| -- | -------------- | ------------- | ---------------------- | ---------- | ------------------ | ------------------- | ------ |
| MON-01 | Zabbix: disponibilidad y recursos de los servidores | Tabla 46 (p. 72) | Servidor Zabbix + agentes en srv01 y dc01 (→ AMB-13: el PDF no dice dónde corre el servidor Zabbix) | Zabbix | Hosts en verde; gráficos | Capturas [E] | PENDIENTE |
| MON-02 | Logs de ufw: ver qué tráfico se bloquea | Tabla 46 | `ufw logging on` + revisión | atlas-srv01 | `/var/log/ufw.log` tras P-02 | Captura [E] | PENDIENTE |
| MON-03 | Visor de eventos de Windows: eventos de seguridad del dominio | Tabla 46 | Auditoría (GPO_Auditoria) | atlas-dc01 | Eventos de login y bloqueo | Captura [D] | PENDIENTE |
| MON-04 | journalctl / rsyslog: logs centralizados del lado Linux | Tabla 46 | rsyslog (→ AMB-14) | atlas-srv01 | Consulta de logs | Captura [C] | PENDIENTE |
| MON-05 | Wireshark para diagnóstico | Tabla 46 | Capturas de diagnóstico | Estación | Captura de una prueba (por ejemplo, DHCP relay) | Archivo .pcapng [E] | PENDIENTE |
| MON-06 | ping, traceroute, nmap para verificar conectividad y probar las políticas | Tabla 46 | Uso en el plan de pruebas | Clientes por VLAN | P-01..P-14 | Salidas [E] | PENDIENTE |
| MON-07 | Metas: disponibilidad ≥ 99 % durante las pruebas; respuesta ≤ 3 s; accesos denegados revisados una vez por semana; alerta al 80 % de CPU, memoria y disco | Tabla 47 (p. 72–73) | Triggers de Zabbix al 80 %; ítem de disponibilidad; web scenario | Zabbix | Forzar umbral | Captura de la alerta [E] | PENDIENTE |
| MON-08 | Verificación desde VLAN 30: se llega por HTTPS y no se llega a SSH, MySQL ni otras VLAN | §30.5 (p. 72) | Parte del plan de pruebas | Cliente VLAN 30 | P-01..P-05 | [E] | PENDIENTE |

## B.13 Plan de pruebas de red (Tabla 48, págs. 73–74)

Nota del PDF: el resultado se completa en el Sprint 3 y las capturas van al Anexo E (p. 74).

| ID | Especificación | Fuente en PDF | Qué debe implementarse | Componente | Cómo se verificará | Evidencia requerida | Estado |
| -- | -------------- | ------------- | ---------------------- | ---------- | ------------------ | ------------------- | ------ |
| P-01 | VLAN 30 → 172.16.40.10: acceso a la plataforma por navegador → Responde | Tabla 48 | Reglas 1 + UFW + TLS | Cliente VLAN 30 | Navegador / `curl -k https://172.16.40.10` | Captura [E] | PENDIENTE |
| P-02 | VLAN 30 → 172.16.40.10: conexión al puerto 22 → Rechazada y registrada | Tabla 48 | Regla 12 (+ UFW) | Cliente VLAN 30 | `ssh`/`nmap -p22` + log | Captura + log [E] (→ AMB-15) | PENDIENTE |
| P-03 | VLAN 30 → 172.16.40.10: conexión al puerto 3306 → Rechazada y registrada | Tabla 48 | Regla 10 | Cliente VLAN 30 | `nmap -p3306` + log | Captura + log [E] | PENDIENTE |
| P-04 | VLAN 30 → VLAN 10: alcance a un equipo de Administración → Sin respuesta | Tabla 48 | Regla 11 | Cliente VLAN 30 | ping/nmap | Captura [E] | PENDIENTE |
| P-05 | VLAN 30 → VLAN 50: alcance a la estación de administración → Sin respuesta | Tabla 48 | Regla 11 | Cliente VLAN 30 | ping/nmap | Captura [E] | PENDIENTE |
| P-06 | VLAN 30 → 172.16.40.20: resolución de nombres del dominio → Responde | Tabla 48 | Regla 2 | Cliente VLAN 30 | `nslookup atlas-srv01.atlas.local 172.16.40.20` | Captura [E] | PENDIENTE |
| P-07 | VLAN 20 → 172.16.40.10: acceso al recurso compartido de Samba → Accede | Tabla 48 | Regla 3 + UFW (→ DISC-06) | Cliente VLAN 20 | `\\atlas-srv01\recurso` | Captura [E] | PENDIENTE |
| P-08 | VLAN 10 → VLAN 20: alcance a un equipo de Docentes → Sin respuesta | Tabla 48 | Regla 12 | Cliente VLAN 10 | ping/nmap | Captura [E] | PENDIENTE |
| P-09 | VLAN 40 → VLAN 30: conexión iniciada hacia un equipo de Estudiantes → Sin respuesta | Tabla 48 | Regla 12 | atlas-srv01 | ping/nmap | Captura [E] | PENDIENTE |
| P-10 | VLAN 50 → 172.16.40.10: administración remota por consola → Accede | Tabla 48 | Regla 6 + sshd + TCP Wrappers + UFW | Estación VLAN 50 | `ssh atlasadmin@172.16.40.10` | Captura [E] | PENDIENTE |
| P-11 | VLAN 50 → 172.16.40.20: administración remota por escritorio → Accede | Tabla 48 (p. 74) | Regla 6 + firewall de Windows | Estación VLAN 50 | `mstsc /v:172.16.40.20` | Captura [E] | PENDIENTE |
| P-12 | VLAN 10, 20, 30 → Internet: navegación web → Responde | Tabla 48 | Regla 5 + NAT | Clientes | Navegador / curl | Captura [E] | PENDIENTE |
| P-13 | VPN docente → 172.16.40.10: acceso a la plataforma → Responde | Tabla 48 | Regla 9 + UFW (→ DISC-06) | Cliente VPN docente | curl/navegador | Captura [E] | PENDIENTE |
| P-14 | VPN docente → VLAN 50: alcance a la estación de administración → Sin respuesta | Tabla 48 | Regla 12 | Cliente VPN docente | ping/nmap | Captura [E] | PENDIENTE |
| P-15 | Todas → obtención de dirección por DHCP → Recibe dirección del ámbito correcto | Tabla 48 | DHCP + relay (aplica a VLAN 10, 20, 30; las VLAN 40 y 50 usan IP fijas) | Clientes | `ipconfig /all` por VLAN | Capturas [E] | PENDIENTE |

## B.14 Documentación, evidencias y gestión

| ID | Especificación | Fuente en PDF | Qué debe implementarse | Componente | Cómo se verificará | Evidencia requerida | Estado |
| -- | -------------- | ------------- | ---------------------- | ---------- | ------------------ | ------------------- | ------ |
| DOC-01 | Anexos B (programación), C (Linux), D (AD), E (red y configuración), F (actas Scrum), G (DER y script de BD) | Tabla 52 (p. 79) | Carpetas de evidencia con índice | `docs/evidencias/` | Índice completo | Los anexos | PENDIENTE |
| DOC-02 | Definición de terminado: funciona, está documentada, tiene evidencia, la revisó otro integrante, está en el tablero | §22.6 (p. 26) | Checklist por entregable | Proceso | Checklist firmada | Checklist | PENDIENTE |
| DOC-03 | Control de versiones con Git/GitHub; repositorio Git como entregable del Hito 2 | Tabla 8 (p. 26); Tabla 18 (p. 44) | Repositorio `SVinas73/tesis` organizado | GitHub | Historial | Log de Git | PENDIENTE |
| DOC-04 | Hito 2 (23/10/2026): prototipo o avance funcional validado; Hito 3 (20/11/2026): proyecto consolidado y documentado | Tabla 9 (p. 28) | Plan alineado a esas fechas | Plan (I) | Fechas | — | PENDIENTE |
| DOC-05 | Sprints 2–5 con sus objetivos | Tabla 10 (p. 28–29) | Plan alineado (→ DISC-23) | Plan (I) | — | — | PENDIENTE |
| DOC-06 | Métricas: tiempo de respuesta, disponibilidad, % de actividades bien registradas, precisión de las recomendaciones, tiempo de recuperación, % de respaldos exitosos, detección de eventos de seguridad, rendimiento de la infraestructura | §12 (p. 10–11) | Método de medición por métrica (→ AMB-28) | Informe final | Informe | Informe | PENDIENTE |
| DOC-07 | Límites: solo el ITI; no diagnostica; prototipo académico; sin sincronización con servicios externos; IA clásica; LLM de terceros solo para redactar | §18 (p. 13–14); H5 (p. 91–92); H.2.6 (p. 93) | Respetar los límites en el diseño | Todo | Revisión | — | PENDIENTE |
| DOC-08 | Tratamiento de datos conforme a la Ley 18.331 | §25.4 (p. 39); H5 (p. 92) | Minimización, anonimización hacia el LLM, datos de prueba sintéticos | Todo | Revisión | Diccionario + política | PENDIENTE |
| DOC-09 | Manual de operación con el procedimiento `chattr -i` para cambiar la configuración | §28.3 (p. 53) | Manual de operación | Documentación | Revisión | Manual | PENDIENTE |
| DOC-10 | Documentación técnica como parte del resultado esperado | §16 (p. 12) | Reporte final, manual de redes, manual de operación | Documentación | Revisión | Documentos | PENDIENTE |

## B.15 Funciones de la propuesta V1 sin requisito formal

Aparecen en §5 (p. 7–8) o §2 (p. 5–6) pero no tienen RF, ficha en el Anexo H ni tabla en el modelo de datos. No se implementan hasta que decidas qué hacer con ellas (ver G y J).

| ID | Especificación | Fuente en PDF | Qué debe implementarse | Componente | Cómo se verificará | Evidencia requerida | Estado |
| -- | -------------- | ------------- | ---------------------- | ---------- | ------------------ | ------------------- | ------ |
| FUN-01 | Estudiante: "Adaptación progresiva de las actividades" | §5 (p. 7) | Sin definición operativa (→ AMB-09) | — | — | — | PENDIENTE (bloqueado por decisión) |
| FUN-02 | Estudiante: "Acceso a material de estudios" | §5 (p. 7) | Sin RF ni tabla (→ AMB-09, PR-05) | — | — | — | PENDIENTE (bloqueado por decisión) |
| FUN-03 | Administrador: "Administración de servidores, Monitoreo, Backups" | §5 (p. 7–8) | En V2 el administrador de ATLAS es de coordinación (p. 37, H4); la infraestructura se administra con cuentas del SO y de AD (→ DISC-17, PR-06) | — | — | — | PENDIENTE (bloqueado por decisión) |

## Resumen del inventario

| Bloque | Cantidad |
| --- | --- |
| Objetivos (OBJ) | 12 |
| Requisitos funcionales (RF) | 20 |
| Requisitos no funcionales (RNF) | 15 |
| Arquitectura y aplicación (ARQ) | 13 |
| Motor de análisis (ANA) | 16 |
| Base de datos (BD) | 11 |
| Linux (LNX) | 21 |
| Windows (WIN) | 15 |
| Red (RED) | 14 |
| Firewall y NAT (FW) | 19 |
| VPN | 9 |
| Monitoreo (MON) | 8 |
| Pruebas de red (P) | 15 |
| Documentación (DOC) | 10 |
| Funciones V1 sin RF (FUN) | 3 |
| **Total** | **201** |
