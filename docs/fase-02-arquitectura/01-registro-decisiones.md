# 01 — Registro de decisiones

**Aprobación:** el usuario aceptó todas las recomendaciones de J.1 el 26/09/2026 ("acepto todas las recomendadas").
**Regla vigente:** siempre manda el PDF; el prompt define solo el método.

Cada decisión indica la fuente en el PDF, lo decidido, las consecuencias técnicas y los requisitos afectados. Cuando una decisión obliga a un detalle técnico que el PDF no fija, ese detalle aparece como **consecuencia técnica** (CT) y queda visible, no escondido.

## Regla de desempate

| ID | Decisión | Resuelve |
| --- | --- | --- |
| DEC-00 | Si el PDF se contradice consigo mismo, manda lo más nuevo y específico: **Anexo H (V2.2) > Parte II (V2) > Parte I (V1)** | DISC-14, DISC-16, DISC-17 |

Aplicaciones directas de DEC-00:

| ID | Decisión | Fuente que prevalece | Afecta |
| --- | --- | --- | --- |
| DEC-00a | Los usuarios los da de alta el administrador; no hay autorregistro | H9 (p. 97) sobre §5 (p. 7) | RF-01, RF-14 |
| DEC-00b | El estudiante ve sus actividades y su resultado; no ve perfil, indicadores ni recomendaciones | H4 (p. 90) sobre §25.3 (p. 36) | RF-07, RF-10, RF-12, permisos |
| DEC-00c | El Administrador de ATLAS es un perfil de coordinación: usuarios, instituciones, permisos, aprobación, reglas y auditoría. La infraestructura se administra con cuentas del SO y de AD desde VLAN 50 | H4 (p. 91), §25.3 (p. 37) sobre §5 (p. 7–8) | RF-14, FUN-03 |

## Resuelto por "manda el PDF" (J.0)

| ID | Decisión | Fuente |
| --- | --- | --- |
| DEC-R1 | OU=Grupos en la raíz del dominio | §29.2 (p. 58) |
| DEC-R2 | Respaldos: atlas-srv01 escribe en una carpeta compartida de atlas-dc01 | Tabla 35 (p. 61), Tabla 29 (p. 55) |
| DEC-R3 | Imagen `mysql:8.0` (con el riesgo R-02 documentado) | Tabla 15 (p. 40) |
| DEC-R4 | ATLAS autentica contra su propia BD (hash) | §27.5 (p. 48), Tabla 14 (p. 34) |
| DEC-R5 | La salida de atlas-analysis al LLM usa la regla 7 (HTTPS desde VLAN 40) | Tabla 44 (p. 70) |
| DEC-R6 | Sin material de estudio ni adaptación progresiva (no tienen RF) | §5; Anexo H |
| DEC-R7 | Sin respaldo del lado Windows (el PDF solo define el de Linux) | §28.5 |
| DEC-R8 | Ninguna regla de red fuera de la Tabla 44. El DC es fuente de hora con reloj propio; VLAN 50 administra por IP; cada equipo registra sus propias denegaciones | Tabla 44 |
| DEC-R9 | "Negar entrante / permitir saliente" = política de los firewalls de host y de las cadenas INPUT/OUTPUT de fw01; el reenvío sigue la Tabla 44 con la regla 12 | §28.4, §30.3, §30.5 |

## Decisiones sobre contradicciones del PDF

| ID | Tema | Decisión | Consecuencias técnicas | Afecta |
| --- | --- | --- | --- | --- |
| DEC-01 | Servidor web (DISC-01) | **Nginx** (`nginx:alpine`) como atlas-web, delante de `php:8.3-fpm` | Donde el PDF dice "Apache" se lee "servidor web (Nginx)". Restauración, paso 2: "detener atlas-web y atlas-db" | ARQ-09, LNX-01, LNX-16 |
| DEC-02 | MySQL (DISC-02) | **Contenedor atlas-db**; el 3306 no se publica; red Docker interna | CT-01: el proceso corre con UID/GID 5003 (atlasdb/atlas-db) sobre `/srv/atlas/datos` (770), así se respeta la Tabla 22. CT-02: dentro del contenedor MySQL escucha en la red interna, porque `bind-address=127.0.0.1` impediría la conexión desde atlas-php; la finalidad ("no accesible desde la red", H5) se cumple porque esa red no tiene salida ni puerto publicado. CT-03: systemd gestiona `docker.service` y `atlas.service` (la pila) | BD-08, BD-09, ARQ-09 |
| DEC-03 | WireGuard (DISC-03) | **Termina en atlas-fw01**, que es una VM **Ubuntu Server 24.04** con nftables y WireGuard | srv01 no ejecuta WireGuard; no hay ningún DNAT hacia servidores | VPN-01..09, FW-17 |
| DEC-04 | Estado entre VLAN (DISC-04) | **Firewall basado en zonas (ZBF) en atlas-rt01.** Plan B, si el modelo de PT no lo soporta: ACL extendidas con `established` y retornos UDP explícitos, documentado como "estado emulado" | fw01 hace el filtrado stateful del perímetro (nftables) | FW-01..14 |
| DEC-05 | UFW (DISC-06) | **UFW alineado con la Tabla 44** | 443 desde VLAN 10, 20, 30 y 10.8.0.128/25; 445 desde VLAN 10, 20 y desde 172.16.40.20; 22 desde VLAN 50. **No se abren 80 ni 139** (la Tabla 44 no los permite). CT-04: los mismos filtros se aplican en la cadena `DOCKER-USER`, porque Docker saltea UFW (R-01) | LNX-11, P-01, P-07, P-13 |
| DEC-06 | Permisos (DISC-07) | **La Tabla 27 es el resultado a lograr**; dueños y modos de §28.3 + ACL adicionales | "r--" sobre directorios se implementa como r-x. Se agrega `--x` en `/srv/atlas` para atlasweb, atlasdb, atlasbkp y atlas-audit | LNX-05..07 |
| DEC-07 | SSH (DISC-08) | Soporte TI entra con su **cuenta de AD** (Kerberos/GSSAPI) desde VLAN 50; `atlasadmin` con clave pública queda como acceso de emergencia | sshd: `AllowGroups atlas-admin gg_soporteti` dentro de `Match Address 172.16.50.0/24`; se mantienen PermitRootLogin no, PasswordAuthentication no y MaxAuthTries 3 | LNX-09, WIN-11 |
| DEC-08 | GPO (DISC-09) | Unidad de estudiantes en una **carpeta compartida de atlas-dc01**; **impresoras fuera de alcance** | El SMB al DC ya está en "servicios de dominio" (regla 2) | WIN-06 |
| DEC-09 | Respaldos (DISC-10) | El **incremental también se copia a Windows**; el domingo corre solo el completo | Incremental de lunes a sábado 02:00. MySQL con binlog; archivos con `tar --listed-incremental`; se agregan `/srv/atlas/logs` y la configuración del sistema. CT-05: en la carpeta de Windows, la cuenta de servicio puede crear archivos pero **no borrarlos**; la retención la aplica una tarea programada del DC. Así un Linux comprometido no puede borrar las copias externas | LNX-13..18, OBJ-11 |
| DEC-10 | `atlas_backup` (DISC-11) | Se agregan **TRIGGER y SHOW_ROUTINE**; `mysqldump --no-tablespaces` | CT-06: INSERT sobre `registro_respaldos` para registrar cada respaldo (tabla aprobada en DEC-15) | BD-07, LNX-15 |
| DEC-11 | Indicadores (DISC-12) | **PHP** calcula indicadores y reglas (Nivel 1); los procedimientos almacenados solo hacen agregaciones del análisis grupal | — | ANA-01..07, BD-06 |
| DEC-12 | Ciclo (DISC-13) | **Publica el docente autor**, eligiendo los grupos; una actividad rechazada vuelve a borrador con las observaciones | Transiciones en 03-modelo-datos, §3.3 | RF-17, OBJ-02 |
| DEC-13 | Samba + SSSD (DISC-24) | **Prueba de concepto temprana con SSSD** (`idmap_sss`); si falla, winbind, que se presenta para aprobación antes de aplicarlo | — | WIN-10, OBJ-08 |
| DEC-14 | Repositorio de análisis (AMB-24) | **Repositorio aparte `atlas-analysis`**, fiel a §26.2 | Repositorio creado por el usuario el 26/09/2026 y conectado a la sesión | ARQ-08 |

## Decisiones sobre vacíos del PDF

| ID | Tema | Decisión | Consecuencias técnicas | Afecta |
| --- | --- | --- | --- | --- |
| DEC-15 | Tablas que faltan (DISC-15) | Agregar `actividad_grupo`, `recomendacion_regla`, `transiciones_actividad`, `registro_respaldos` | Modelo final de 29 tablas junto con DEC-16 | BD-02, RF-04, RF-17 |
| DEC-16 | Categoría (AMB-08) | Catálogo `categorias` (1:N con actividades) | Permite "¿cómo viene el grupo 3A en resolución de problemas?" y que RF-12 recomiende actividades concretas | ANA-14, RF-12 |
| DEC-17 | Rango RPC (DISC-19) | **TCP 49152–65535**, fijado y documentado en el DC | Servicios de dominio completos: TCP/UDP 53, TCP/UDP 88, TCP/UDP 464, TCP/UDP 389, TCP 636, TCP 3268–3269, TCP 445, UDP 123, TCP 135, TCP 49152–65535 | FW-02, FW-15 |
| DEC-18 | atlas-audit (DISC-07) | Miembros: **GG_SoporteTI** (mapeado por SSSD) | — | LNX-03, LNX-07 |
| DEC-19 | Zabbix (AMB-13) | **Contenedores en atlas-srv01** (proyecto Compose aparte) | Los agentes quedan dentro de VLAN 40 (no cruzan el router). La interfaz web escucha solo en 127.0.0.1 de srv01 y se accede desde VLAN 50 por túnel SSH, porque DEC-R8 no agrega reglas | MON-01, MON-07 |
| DEC-20 | Certificado (AMB-16) | **CA interna propia ("ATLAS-CA")** distribuida por GPO | Certificado de atlas-web con CN `atlas-srv01.atlas.local` y SAN IP 172.16.40.10 (los docentes por VPN entran por IP) | ARQ-02, P-01, P-13 |
| DEC-21 | sudo (AMB-21) | **sudo acotado** para atlasadmin (lista explícita de comandos) | atlasadmin no pertenece al grupo `docker` (equivale a root). La protección real de los respaldos es la copia en Windows sin permiso de borrado (CT-05) | LNX-05, p. 52 |
| DEC-22 | Puertos en GNS3 (DISC-22) | **Tabla de correspondencia** puerto de la Tabla 41 → puerto de GNS3, solo para los puertos usados | Packet Tracer mantiene la Tabla 41 literal | RED-06, RED-11 |
| DEC-23 | Definiciones del motor (AMB-01..06) | **Aprobado por el usuario el 26/09/2026**: 8 reglas, fórmula de eficiencia, atención prioritaria, parámetros de ML, bloqueo, pausa y abandono de 04-motor-analisis | Los umbrales quedan editables por el administrador (§27.3) | ANA-02, ANA-06, ANA-11, RF-02, RF-06..08, RF-18 |
| DEC-24 | Proveedor del LLM (AMB-10) | **Groq** ("por ahora, ya que es gratis", usuario, 26/09/2026) | API compatible con OpenAI (`https://api.groq.com/openai/v1`); modelo configurable (por defecto `llama-3.3-70b-versatile`); clave `LLM_API_KEY` solo en `atlas.conf`. La interfaz sigue siendo independiente del proveedor, así que se puede cambiar sin tocar código. Como es un servicio externo gratuito, la anonimización de H28 es obligatoria y se prueba | RF-20 |

## Consecuencias técnicas nuevas de esta fase

Son valores o elementos que ninguna decisión fija explícitamente, pero que el diseño necesita. Se registran para que queden visibles y se puedan objetar.

| ID | Qué | Por qué | Visible en la red |
| --- | --- | --- | --- |
| CT-07 | Redes Docker con subred explícita: `atlas_front` 192.168.250.0/28, `atlas_back` 192.168.250.16/28 (interna), `atlas_egress` 192.168.250.32/28; Zabbix `zbx_back` 192.168.250.48/28 (interna) | Permite restringir los usuarios MySQL por origen, evita solapes con 172.16.0.0/16 y 10.8.0.0/24 y evita el rango automático de Docker | No: solo existe dentro de atlas-srv01 |
| CT-08 | Dirección del servidor WireGuard: **10.8.0.1/24** en `wg0` de fw01 | La interfaz del túnel necesita una IP dentro de 10.8.0.0/24; usa la primera del segmento de administradores, así que los clientes administradores van de .2 a .126 | Solo dentro del túnel |
| CT-09 | Cuenta de servicio `svc_atlas_backup` en OU=ServiciosTI y carpeta `\\atlas-dc01\atlas-backups` | Destino de los respaldos (DEC-R2, DEC-09) | — |
| CT-10 | Carpetas compartidas: `\\atlas-srv01\administracion` (GG_Administracion), `\\atlas-srv01\docentes` (GG_Docentes), `\\atlas-dc01\estudiantes` (GG_Estudiantes) | Samba en Linux para las máquinas del dominio (Tabla 35) y unidad de estudiantes (DEC-08) | — |
| CT-11 | atlas-analysis corre como UID 65534 (`nobody`) | No escribe archivos; la Tabla 26 no define un usuario para el servicio de análisis y no se inventa uno | — |
| CT-13 | `atlas_app` tiene DELETE solo sobre `preguntas` y `opciones`, y un trigger lo limita a actividades en BORRADOR | RF-16 exige poder editar el contenido de un borrador (quitar preguntas u opciones); la Tabla 21 no incluye DELETE. Surgió en la Fase 5 | No |
| CT-12 | El archivo de secretos de la pila es `/srv/atlas/config/atlas.conf` (el mismo que §28.3 protege con `chattr +i`) | El PDF ya define ese archivo protegido; se usa como `.env` de producción | — |

## Pendientes que no son decisiones

- Datos de J.2: IP de fw01 (red de tránsito y WAN), IP de gestión (switch, router, estación), modelos de PT, reenviadores DNS.
- Recursos de J.3: hardware, imágenes de GNS3, ISO de Windows, quién ejecuta el laboratorio.
