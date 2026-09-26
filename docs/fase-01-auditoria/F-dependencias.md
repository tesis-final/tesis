# F. Dependencias entre componentes

El objetivo es detectar qué partes, si se construyen por separado, pueden quedar incompatibles con otras. Cada cadena se lee de izquierda a derecha: lo de la izquierda tiene que existir (o estar decidido) antes que lo de la derecha.

## F.1 Matriz de dependencias

| ID | Cadena de dependencia | Riesgo de incompatibilidad si se construye aislado | Bloqueada por |
| -- | --- | --- | --- |
| DEP-01 | RF-02 → tabla `usuarios` (hash, estado activo, contador de fallos, bloqueo hasta) → `roles` → sesión PHP → middleware [1] → `auditoria` (inicio de sesión, fallido) → bloqueo tras 3 fallos → pruebas OBJ-01 y OBJ-07 | Si el bloqueo se implementa solo en memoria o por IP, no cumple "a los tres intentos" por cuenta ni queda auditado | AMB-05 |
| DEP-02 | RF-03 / RNF-01 → `roles`, `permisos`, `rol_permiso` → middleware [2] (403 + auditoría) → alcance por grupo (`usuario_grupo`) → RF-11 y RF-13 (solo grupos propios) | Si los permisos se codifican en los controladores, se rompe §26.3 y se pierde el registro automático | — |
| DEP-03 | RF-05 `niveles_dificultad` → RF-16 `actividades`, `preguntas`, `opciones` (una correcta) → validación "sin preguntas no se envía" → RF-17 máquina de estados + historial → asignación actividad↔grupo → RF-04 visibilidad para el estudiante | Sin tabla actividad↔grupo, RF-04 ("de sus grupos") no se puede cumplir | DISC-13, DISC-15 |
| DEP-04 | RF-04 → RF-08 `intentos` (en curso / finalizado / abandonado) → RF-06 eventos JS (cambio de opción, pausa, navegación, con marca temporal) → `interacciones` → `respuestas` → RF-09 tiempos por pregunta y total → transacción única → RF-07 `resultados` (trigger) | Si el cliente JS no manda los eventos con el formato que espera la API, RF-06 queda incompleto; si no hay transacción, se pueden perder resoluciones (Tabla 20) | AMB-06 |
| DEP-05 | RF-07 → ANA-01..04 (indicadores) → `reglas_analisis` (≥ 8) → ANA-05 intérprete → `recomendaciones` + relación con la regla y los datos → RF-10 perfil → RF-11 panel → RF-12 "¿por qué?" → RF-13 reportes | Sin reglas definidas no hay recomendaciones, y la trazabilidad exige guardar los datos de entrada al generar | AMB-01, AMB-02, DISC-12 |
| DEP-06 | RF-07 + `respuestas` → vistas / procedimientos de agregación → `atlas_read` → RF-18 análisis grupal (promedios, distribución, preguntas con más error, atención prioritaria) → panel docente (vista grupal prioritaria) | "Atención prioritaria" depende de las reglas del Nivel 1: si se define aparte, puede contradecir las recomendaciones | AMB-04 |
| DEP-07 | Datos de intentos → `features.py` (6 variables) → privilegios de `atlas_analysis` → umbral de volumen → K-means / regresión logística → `agrupamientos` (grupo + período) → API FastAPI → cliente PHP con timeout → UI | Sin variable objetivo definida, la regresión logística no se puede entrenar; sin umbral no se cumple "no presentar ML sobre pocos datos" | AMB-03, DISC-11 |
| DEP-08 | RF-20: pregunta del docente → **intérprete local** (entidades: estudiante, grupo, período, tipo) → indicadores N1/N2 desde la BD → anonimizador (seudónimos) → `atlas-analysis/llm/client.py` → salida HTTPS desde VLAN 40 (regla 7, DNS vía DC) → API del LLM (clave en `.env`) → re-identificación en PHP → `conversaciones` | Si se manda la pregunta cruda al LLM ("…para Juan") se viola H28; si el firewall no permite la salida, RF-20 no funciona | AMB-10, DISC-18 |
| DEP-09 | Docker: `atlas-web` (certificado TLS) ↔ `atlas-php` (FastCGI 9000) ↔ `atlas-db` (red interna) ↔ `atlas-analysis`; los UID de los contenedores ↔ usuarios POSIX (atlasweb 5002, atlasdb 5003) ↔ bind mounts en `/srv/atlas/*` ↔ ACL ↔ respaldos | Si los contenedores corren con sus UID por defecto (nginx 101, www-data 33, mysql 999), la matriz POSIX de la Tabla 27 no se aplica y los respaldos fallan por permisos | DISC-01, DISC-02, DISC-07 |
| DEP-10 | UFW ↔ iptables de Docker ↔ reglas 1, 3 y 9 | Docker saltea UFW en los puertos publicados: UFW aparenta restringir 80/443 pero no lo hace | DISC-06, R-01 |
| DEP-11 | Red de capa 2: VLAN en sw01 → puertos de acceso → troncal (nativa 999, permitidas 10–50) → subinterfaces en rt01 (gateways .1) → `ip helper-address` → DC con DHCP autorizado en AD → los clientes reciben IP → DNS del DC → unión al dominio (puertos de la regla 2 + RPC) → GPO → P-06 y P-15 | La nativa distinta en cada extremo rompe el troncal; sin el helper, P-15 falla; sin los puertos RPC, la unión al dominio falla | DISC-19 |
| DEP-12 | DC (DNS con registros A/PTR de srv01 y registros SRV) → NTP desde el DC → srv01 se une con SSSD/Kerberos → Samba como miembro → mapeo de grupos AD→POSIX → sshd (AllowGroups) → montaje CIFS de la carpeta de respaldos del DC | Kerberos falla con más de 5 minutos de diferencia o sin DNS; Samba + SSSD tiene limitaciones de soporte; AllowUsers bloquea a los usuarios de AD | DISC-08, DISC-20, DISC-24 |
| DEP-13 | atlas-fw01 (WAN) → NAT → reglas 5 y 7 → reenviadores DNS del DC (DNS 53 hacia afuera solo desde el DC) → srv01 resuelve vía el DC → apt, Docker Hub y LLM | Sin fw01 y sin DNS del DC, **srv01 no puede instalar paquetes ni descargar imágenes**. En el laboratorio hay que prever una salida temporal para la instalación inicial | AMB-11, AMB-18 |
| DEP-14 | WireGuard en fw01 → un par por dispositivo → IP por perfil (/25) → reglas 8 y 9 (sin NAT del túnel antes de filtrar) → ruta a 10.8.0.0/24 en rt01 → UFW de srv01 permite 443 desde 10.8.0.128/25 → P-13 y P-14 | Si fw01 enmascara el túnel, srv01 ve la IP del firewall y UFW no distingue perfiles; si falta la ruta de retorno, no hay respuesta | DISC-03, DISC-06 |
| DEP-15 | Ubicación del servidor Zabbix → agentes (srv01, dc01) → reglas de host (UFW, Windows Defender) y de red para 10050/10051 → umbrales al 80 % → disponibilidad ≥ 99 % (RNF-02) → informe OBJ-12 | Si Zabbix queda en VLAN 50, los agentes activos violan "nadie llega a Gestión"; si queda en srv01, la interfaz web no es accesible desde VLAN 50 con las reglas actuales | AMB-13, DISC-21 |
| DEP-16 | Privilegios de `atlas_backup` → `mysqldump --routines --triggers` → `/srv/atlas/backups` (atlasbkp, ACL de lectura) → montaje CIFS de la carpeta del DC (cuenta de servicio de AD, SMB 445 dentro de VLAN 40) → retención → verificación por checksum → restauración de prueba → RNF-04/05, OBJ-11 | Con los privilegios de la Tabla 21, el dump falla o sale sin triggers ni procedimientos, que son parte del diseño (Tabla 20) | DISC-10, DISC-11, AMB-17 |
| DEP-17 | Middleware [4] + triggers → `auditoria` (solo INSERT para la app) → `auditoria.log` (`chattr +a`) → ACL de lectura para atlas-audit → rotación de logs → respaldo de logs | `chattr +a` impide que logrotate rote o trunque; si la app tiene UPDATE sobre `auditoria`, se viola H23 | AMB-30, DISC-07 |
| DEP-18 | Denegaciones en rt01 / fw01 → destino de syslog → "registrada" en P-02, P-03 y reglas 10–12 → revisión semanal de denegados (Tabla 47) | Sin un colector definido, "registrada" no se puede evidenciar | AMB-14 |
| DEP-19 | P-01..P-15 → GNS3 con VM integradas → clientes de prueba en VLAN 10, 20, 30 y 50 → cliente VPN docente → fw01 operativo | En Packet Tracer solo no se pueden ejecutar las pruebas de punta a punta | DISC-22, AMB-27 |
| DEP-20 | Certificado TLS → atlas-web → HTTPS (P-01, P-13) → confianza en los clientes (distribución por GPO si es una CA interna) | Con un certificado autofirmado, P-01 "responde" con advertencia; conviene definir el criterio de aprobado | AMB-16 |
| DEP-21 | Esquema de BD (Fase 5) → Repositories → Services → Controllers → frontend (Fase 4) | Programar la aplicación antes del esquema obliga a rehacer los repositorios. Por eso se propone hacer la Fase 5 antes o junto con la 4 (ver I) | — |

## F.2 Dependencias de decisiones (qué decisión bloquea qué construcción)

| Decisión pendiente | Bloquea |
| --- | --- |
| DISC-01 (Apache / Nginx) | `docker-compose.yml`, configuración TLS, procedimiento de restauración, manual de operación |
| DISC-02 (MySQL en contenedor) | `docker-compose.yml`, `/srv/atlas/datos`, usuarios POSIX, respaldos |
| DISC-03 (dónde termina WireGuard) | Configuración de fw01 y srv01, UFW, reglas 8 y 9 |
| DISC-04 (firewall con estado entre VLAN) | Configuración completa de ACL del router |
| DISC-07 (permisos) | Script de permisos de srv01, bind mounts |
| DISC-13, DISC-15 (ciclo y modelo) | Script SQL, máquina de estados |
| AMB-01 (ocho reglas) | Motor Nivel 1, seeds de `reglas_analisis`, RF-12 |
| AMB-03 (umbral, etiqueta, período) | Servicio de análisis Nivel 2 |
| AMB-10 (LLM) | RF-20 completo |
| AMB-11, AMB-12 (IP faltantes) | Configuración Cisco completa y fw01 |
