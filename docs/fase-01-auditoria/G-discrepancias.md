# G. Registro de discrepancias

Reglas de este registro:

- **No se modifica el PDF.**
- Cada discrepancia queda con una **propuesta** de resolución, su justificación y lo que afecta.
- **Ninguna propuesta se aplica hasta que la apruebes** (ver J.1). Mientras tanto, rige el PDF y la parte afectada queda bloqueada.

Contenido:

- G.1 Contradicciones internas del PDF (DISC-01..24)
- G.2 Ambigüedades y vacíos (AMB-01..30)
- G.3 Diferencias entre tu prompt y el PDF (PR-01..06)
- G.4 Observaciones editoriales (ED-01..08)

## G.1 Contradicciones internas del PDF

| ID | Sección | Especificación A | Especificación B | Problema | Impacto | Decisión necesaria |
| -- | ------- | ---------------- | ---------------- | -------- | ------- | ------------------ |
| DISC-01 | §25.1, §26.1–26.2, §28.1, §28.5 contra §25.5 | Servidor web **Apache 2.4**: diagrama §25.1 (p. 35), Tabla 16 (p. 41), "Si Apache queda mal configurado" (p. 42), Tabla 24 (p. 50), "Parar Apache y MySQL" (p. 56) | Contenedor **atlas-web `nginx:alpine`** (Tabla 15, p. 40) y `docker/nginx/default.conf` (p. 42) | Dos servidores web distintos para la misma función | Contenedor web, TLS, integración con PHP, restauración, manual | Elegir el servidor web |
| DISC-02 | Tabla 15, §25.5, H5 contra Tabla 22, §27.5, Tabla 24 | MySQL en contenedor **atlas-db `mysql:8.0`**, puerto interno; "se despliega en contenedores" (p. 40, p. 91) | MySQL **gestionado por systemd**, usuario `mysql`, `bind-address = 127.0.0.1`, datos en `/srv/atlas/datos` del grupo atlas-db (p. 48) | Con bind 127.0.0.1 dentro del contenedor, atlas-php y atlas-analysis no pueden conectarse; el usuario `mysql` no coincide con `atlasdb` (Tabla 26); systemd no gestiona procesos dentro de Docker | BD, Docker, permisos, respaldos | Confirmar el contenedor y la forma de cumplir "no accesible desde la red" |
| DISC-03 | §30.4 contra Tabla 42, Figura 1, §30.1 | "WireGuard, **sobre el servidor Linux**" (p. 71). §30.1 (p. 67) dice además que en VirtualBox "se configuran los servicios de dominio, Samba y la VPN" | **atlas-fw01**: "terminación de la VPN" (Tabla 42, p. 67); "VPN WireGuard" en fw01 (Figura 1, p. 65); "el filtrado con estado y la VPN corresponden al firewall perimetral" (p. 67) | Dos ubicaciones posibles | fw01, srv01, UFW, reglas 8 y 9, NAT | Confirmar la terminación en fw01 |
| DISC-04 | Figura 1 y §30.5 contra notas de las Tablas 43 y 44 | El router L3, **debajo** del firewall, enruta entre VLAN (Figura 1); las reglas se aplican "en el router y en el firewall" (p. 72); el router es de Packet Tracer (Tabla 42) | "El firewall mantiene el estado de las conexiones… las respuestas no requieren regla propia" aplicado a toda la matriz (p. 68, p. 70) | El tráfico entre VLAN nunca pasa por fw01. En el router, las ACL extendidas **no tienen estado**: hay que permitir las respuestas explícitamente (TCP `established`, UDP por puerto de origen) o usar un firewall basado en zonas (ZBF) | Toda la configuración de ACL; P-01..P-11 | Elegir cómo se implementa el "estado" en el router |
| DISC-05 | §30.3 contra Tabla 44 | "La política base es negar el tráfico entrante y **permitir el tráfico saliente**" (p. 69) | Regla 12 "Cualquiera → Cualquiera → Todo → Negar"; regla 5 solo 80/443 hacia Internet; regla 7 solo 80/443/53 desde VLAN 40 (p. 70) | En el firewall de red, la salida **no** está permitida en general: está restringida | Configuración de fw01 y del router | Confirmar a qué aplica cada política |
| DISC-06 | §28.4 (UFW) contra Tabla 44 y Tabla 48 | UFW: 80,443 solo desde 172.16.20.0/24 y 172.16.30.0/24; 139,445 solo desde 172.16.40.0/24 (p. 54) | Regla 1: HTTPS también desde **VLAN 10**; regla 9: HTTPS desde **10.8.0.128/25**; regla 3: SMB desde **VLAN 10 y 20**; P-07 y P-13 esperan "Accede" / "Responde" | Con UFW tal como está escrito, **P-07 y P-13 fallarían**, y VLAN 10 no llegaría a la web; UFW abre 80 y 139, que la red no permite | UFW de srv01; P-01, P-07, P-13 | Alinear UFW con la Tabla 44 |
| DISC-07 | Tabla 27 contra §28.3 | Matriz de permisos efectivos por recurso y rol (p. 51–52) | Dueños y modos (750/770/700) + 5 ACL (p. 52–53) | 1) `/srv/atlas` en 750 atlasadmin:atlas-admin: web, db y backup **no pueden atravesarlo**. 2) web/: la Tabla 27 da admin rwx, pero con 750 atlasweb:atlas-web el admin no tiene acceso. 3) logs/: la ACL da atlasweb rwx y atlas-audit rx, contra -wx y r-- en la tabla; faltan ACL para db (-wx) y backup (r--). 4) scripts/, backups/ y config/ no tienen las ACL que la tabla exige. 5) "r--" en un directorio no permite leer los archivos de adentro (falta x). 6) atlas-audit no tiene ningún usuario | Seguridad de srv01, contenedores, respaldos | Aceptar que la Tabla 27 es el objetivo y completarla con ACL |
| DISC-08 | §28.4 contra Tabla 36 y Tabla 35 | `AllowUsers atlasadmin@172.16.50.*` y `PasswordAuthentication no` (p. 53) | GG_SoporteTI → atlas-admin "Administrar el servidor"; autenticación centralizada con SSSD (p. 61–62) | Con AllowUsers, **ningún usuario de AD puede entrar por SSH**, aunque esté en atlas-admin; sin contraseña, los usuarios de AD necesitarían clave SSH o Kerberos (GSSAPI) | sshd, SSSD, OBJ-08 | Definir si Soporte TI entra con sus cuentas de AD |
| DISC-09 | Tabla 33 contra Tabla 44 y Tabla 42 | GPO_Estudiantes: "unidades de red mapeadas"; GPO_Docentes: "…e impresoras" (p. 59) | La VLAN 30 no tiene SMB hacia srv01 (regla 3 solo VLAN 10 y 20); no hay impresoras ni servidor de impresión en el inventario | La unidad de estudiantes no puede estar en Samba de srv01; las impresoras no existen | GPO | Definir dónde está la unidad de estudiantes y qué se hace con las impresoras |
| DISC-10 | Tabla 29 contra §28.5 y Tabla 5 | Incremental diario **solo local**; completo semanal local + Windows; ambos a las 02:00 (p. 55) | "Perder como máximo 24 h de datos" (p. 56; Tabla 5 obj. 11) | Si falla el disco o la VM de srv01, la última copia fuera del servidor puede tener **hasta 7 días**, lo que viola el RPO. Además: el domingo coinciden completo e incremental; no hay mecanismo para el incremental (los comandos son todos completos); el `tar` no incluye `/srv/atlas/logs` ni la configuración del sistema (`/etc`) aunque la Tabla 28 los pide | Esquema de respaldos, OBJ-11 | Decidir la copia externa del incremental y la mecánica |
| DISC-11 | Tabla 21 contra §28.5 | `atlas_backup`: SELECT, LOCK TABLES, SHOW VIEW (p. 48) | `mysqldump --single-transaction --routines --triggers` (p. 55) | En MySQL 8.0, `--triggers` necesita el privilegio TRIGGER y `--routines` necesita SHOW_ROUTINE; sin PROCESS hay que usar `--no-tablespaces`. Sin esos privilegios, el dump falla u omite triggers y procedimientos, que son parte del diseño (Tabla 20) | Respaldos, RNF-05 | Ampliar los privilegios mínimos de `atlas_backup` |
| DISC-12 | §25.2, §25.4 contra Tabla 20 | Nivel 1 "en PHP, en clases propias" (p. 35, p. 37) | "Procedimientos almacenados: cálculo de indicadores y análisis grupal" (p. 47) | Dos lugares distintos para la misma lógica | Motor de análisis, BD, trazabilidad | Definir qué se calcula dónde |
| DISC-13 | RF-17 / H25 / Tabla 5 contra §25.3 | 5 estados distintos, incluidos APROBADA y PUBLICADA; "una actividad recorre sus cinco estados" (p. 22, p. 113) | Diagrama: "Aprueba → PUBLICADA" (sin paso intermedio); "Rechaza → vuelve al docente con observaciones" (p. 36) | No se define quién pasa de APROBADA a PUBLICADA, qué pasa tras RECHAZADA (¿vuelve a BORRADOR?), si una publicada se puede retirar ni dónde se guardan las observaciones y el historial | Máquina de estados, BD, OBJ-02 | Aprobar el diagrama de transiciones |
| DISC-14 | §25.3 contra H4 | Diagrama: "PERFIL + RECOMENDACIONES → DOCENTE y **ESTUDIANTE**" (p. 36) | H4: el estudiante "**no accede a información de análisis** ni de otros estudiantes" (p. 90) | ¿El estudiante ve su perfil y recomendaciones o no? | Panel del estudiante, permisos | Confirmar H4 |
| DISC-15 | §27.1 contra Tabla 19, más RF-04, RF-17 y §7 | §27.1 lista `rol_permiso`, `usuario_grupo`, `niveles_dificultad` (p. 45) | Tabla 19 no las lista y agrega `conversaciones` y `agrupamientos` (p. 46) | La unión da 24 tablas. Además, relaciones exigidas **sin tabla**: actividad↔grupo (RF-04 "de sus grupos"), regla↔recomendación (N:M en Tabla 19), historial de transiciones con autor y observaciones (RF-17), registro de respaldos ("backups" en §7) | Script SQL, DER | Aprobar el modelo final |
| DISC-16 | §5 contra H9 | "Para estudiantes: **Registro** e inicio de sesión" (p. 7) | RF-01: precondición "El **administrador** ha iniciado sesión y cuenta con permisos de gestión" (p. 97) | ¿Autorregistro o alta por el administrador? | Módulo de usuarios | Confirmar H9 |
| DISC-17 | §5 contra §25.3 y H4 | Administradores: "Administración de servidores, Monitoreo, Backups" (p. 7–8) | El administrador es "alguien de coordinación del centro, no necesariamente un perfil técnico" (p. 37); H4: gestiona usuarios, instituciones, permisos y auditoría (p. 91) | ¿El rol Administrador de ATLAS maneja la infraestructura? | Alcance del panel administrativo | Confirmar H4 |
| DISC-18 | Tabla 43 contra RF-20, Tabla 44 | Matriz: VLAN 40 → Internet = "**actualizaciones**" (p. 68) | RF-20 usa un LLM de terceros por API (p. 116) desde atlas-analysis (VLAN 40); la regla 7 permite HTTPS en general (p. 70) | La matriz no contempla la salida al LLM, aunque la regla la permite | Regla 7 y documentación | Confirmar que la regla 7 cubre la API del LLM |
| DISC-19 | Tabla 43 nota a, Tabla 44 nota a contra Tabla 32 | Servicios de dominio: DNS 53, Kerberos 88, LDAP 389, LDAPS 636, SMB 445, NTP 123 + RPC 135 + rango dinámico "a fijar en el Sprint 2" (p. 69–70) | Las contraseñas vencen a los 90 días (p. 59), así que los usuarios deben poder cambiarlas desde los clientes | Faltan puertos que AD usa con clientes Windows: **Kerberos 464** (cambio de contraseña), **Global Catalog 3268/3269**, DNS por TCP y LDAP/Kerberos por UDP (localizador de DC); y el rango RPC no tiene valor | Regla 2, unión al dominio, cambio de contraseña, P-06 | Definir la lista completa y el rango RPC |
| DISC-20 | Tabla 35 contra regla 7 | "Hora: NTP desde el controlador de dominio" (p. 61) | La regla 7 no permite NTP (UDP 123) desde VLAN 40 hacia Internet (p. 70) | El DC no tiene fuente de hora externa | Kerberos, logs, TLS | Elegir la fuente de hora del DC |
| DISC-21 | Tabla 44 contra la operación de VLAN 50 | Regla 5: VLAN 50 → Internet solo HTTP/HTTPS; regla 6: VLAN 50 → VLAN 40 solo SSH/RDP; reglas 1 y 2 no incluyen VLAN 50 (p. 69–70) | "Gestión llega a todos lados" (p. 69); la VLAN 50 administra la infraestructura | La VLAN 50 **no tiene DNS** (no puede resolver nombres de Internet, así que la regla 5 solo sirve por IP), no puede unirse al dominio ni abrir la interfaz web de ATLAS o Zabbix | Operación diaria, monitoreo | Decidir si se agregan DNS/HTTPS desde VLAN 50 |
| DISC-22 | Tabla 41 contra §30.1 (migración a GNS3) | Puertos Fa0/1–Fa0/24 y Gi0/1–Gi0/2 (Catalyst 2960 de Packet Tracer) (p. 66) | Migración a GNS3 en el Sprint 2 para integrar red y VM (p. 67) | En GNS3, las imágenes de Cisco L2 (IOSvL2) nombran los puertos Gi0/0–Gi3/3 (16 puertos); la asignación literal de la Tabla 41 no se puede reproducir. Además, fw01 (VM) no se puede conectar a un router de Packet Tracer | Configuración del switch, pruebas | Aprobar una tabla de correspondencia de puertos para GNS3 |
| DISC-23 | Tabla 10 contra H30, Tabla 14 y Tabla 49 | Sprint 2: ciclo de aprobación; Sprint 3: registro del estudiante; Sprint 4: motor, panel docente, seguridad perimetral y VPN (p. 28–29) | H30: RF-06..09, RF-11, RF-18 en Sprint 2; RF-17 en Sprint 3 (p. 121–122). Tabla 14: RF-02 en Sprint 1. Tabla 49: firewall, VPN y monitoreo en Hito 2 | Cronogramas incompatibles entre sí | Plan de fases (I) | Definir qué entra en el Hito 2 |
| DISC-24 | Tabla 35 contra la tecnología | atlas-srv01 se une "con **SSSD**/Kerberos" y ofrece **Samba** a las máquinas del dominio, con grupos AD mapeados (p. 61) | Samba como servidor de archivos miembro de AD se apoya oficialmente en **winbind**; con SSSD solo funciona con limitaciones (backend `idmap_sss`) | Posible incompatibilidad técnica que el PDF no menciona | Integración Linux–Windows, OBJ-08 | Aprobar una prueba de concepto temprana y un plan B |

### Propuestas de resolución (G.1)

**DISC-01 — Propuesta: Nginx (`nginx:alpine`) como atlas-web, con `php:8.3-fpm`.**
- Por qué: la Tabla 15 es la única que define el despliegue concreto (imagen, contenedor y puerto) y coincide con `php:8.3-fpm`, que necesita un servidor FastCGI delante. La estructura `docker/nginx/default.conf` confirma que el diseño de contenedores se pensó con Nginx. Las menciones a Apache son justificaciones narrativas ("se lleva bien con PHP") que no detallan configuración.
- Afecta: `docker-compose.yml`, `docker/nginx/default.conf`, la restauración (paso 2: "parar atlas-web y atlas-db") y el manual de operación.
- Alternativa: Apache con `php:8.3-apache` (se pierde el contenedor atlas-php separado de la Tabla 15).

**DISC-02 — Propuesta: MySQL en el contenedor atlas-db (Tabla 15).**
- Datos en `/srv/atlas/datos` montado en el contenedor, con el proceso corriendo como `atlasdb` (UID/GID 5003) para respetar "grupo atlas-db, 770".
- La red Docker de la BD se declara **interna** y el puerto 3306 **no se publica**. Así MySQL escucha en la red de contenedores pero no es alcanzable desde ninguna VLAN, que es la finalidad de `bind-address = 127.0.0.1` y de "no accesible desde la red" (H5).
- systemd gestiona Docker y una unidad `atlas.service` que levanta la pila.
- Por qué: es lo único compatible con §25.5, la Tabla 15 y H5 a la vez, y mantiene la intención de seguridad de la Tabla 22.
- Afecta: la Tabla 22 (el usuario de servicio pasa a ser `atlasdb`), el script de respaldo (`docker exec` o conexión por socket) y P-03.

**DISC-03 — Propuesta: WireGuard termina en atlas-fw01, que es una VM Linux.**
- Por qué: 3 de las 4 menciones (Tabla 42, Figura 1, §30.1 "corresponden al firewall perimetral") lo ubican en fw01. Terminar en srv01 obligaría a hacer DNAT de UDP 51820 hacia un servidor, y §30.3 dice explícitamente "no hacemos traducción de destino hacia los servidores". En fw01, el firewall ve directamente el origen 10.8.0.x y puede aplicar las reglas 8 y 9.
- La frase "sobre el servidor Linux" es compatible si fw01 es un Linux, que es lo que sugiere el propio §30.4 ("viene incluido en el kernel de Linux desde la 5.6").
- Afecta: el SO de fw01 (ver AMB-11). WireGuard no se instala en srv01.

**DISC-04 — Propuesta: firewall basado en zonas (ZBF) en atlas-rt01 para el tráfico entre VLAN.**
- ZBF es stateful. Packet Tracer lo soporta en routers ISR con licencia de seguridad, y GNS3 con IOSv también.
- Si el modelo de router de Packet Tracer no lo soporta, el plan B son ACL extendidas con `established` para TCP y entradas de retorno explícitas para UDP (53, 88, 123, 389, 67), documentadas como "el estado se emula".
- fw01 (stateful real, Linux) aplica las reglas del perímetro y el NAT.
- Por qué: es la única forma de cumplir "el firewall mantiene el estado" sin cambiar la topología de la Figura 1.
- Afecta: la configuración de rt01 y el manual de redes.

**DISC-05 — Propuesta: "negar entrante / permitir saliente" aplica a los firewalls de host.**
- Aplica a UFW en srv01 (es literalmente el comando de §28.4) y a las cadenas INPUT/OUTPUT del propio fw01.
- El **reenvío** (FORWARD) de fw01 y las ACL del router siguen la Tabla 44 con negación final (regla 12).
- Por qué: es la única lectura que no contradice las reglas 5, 7 y 12.
- Afecta: la política por defecto de fw01.

**DISC-06 — Propuesta: alinear UFW con la Tabla 44.**
- 443/tcp desde 172.16.10.0/24, 172.16.20.0/24, 172.16.30.0/24 y 10.8.0.128/25.
- 445/tcp desde 172.16.10.0/24, 172.16.20.0/24 y 172.16.40.20 (DC, para "recursos accesibles entre ambos", OBJ-08).
- 22/tcp desde 172.16.50.0/24.
- No abrir 139 (la red no lo permite). El puerto 80 solo como redirección a 443 y solo desde las VLAN que ya tienen 443 (o no abrirlo).
- Controlar los puertos publicados por Docker en la cadena DOCKER-USER (ver R-01).
- Por qué: la Tabla 44 es la política de referencia (§30.5), y UFW es la "segunda capa" que la replica; no puede ser más restrictivo que las pruebas esperadas.
- Afecta: UFW, P-01, P-07 y P-13.

**DISC-07 — Propuesta: la Tabla 27 es el resultado a lograr.**
- Se mantienen los dueños y modos de §28.3, se agregan `--x` por ACL en `/srv/atlas` para atlasweb, atlasdb, atlasbkp y atlas-audit, y se completan las ACL que faltan.
- "r--" en directorios se lee como "r-x" (lectura efectiva).
- Se agrega un usuario técnico o un grupo AD mapeado para atlas-audit (definir quién audita).
- Por qué: la Tabla 27 expresa la intención ("quién puede hacer qué"), y §28.3 dice "así lo configuraríamos", en condicional.
- Afecta: el script de permisos de srv01 y el script de verificación celda por celda.

**DISC-08 — Propuesta:**
- `AllowGroups atlas-admin gg_soporteti` (nombre del grupo de AD como lo expone SSSD) más `Match Address 172.16.50.0/24`, en lugar de `AllowUsers` a un solo usuario. Se conservan `PasswordAuthentication no` y `GSSAPIAuthentication yes` (ticket Kerberos del dominio) para las cuentas de AD, y la cuenta local atlasadmin queda como acceso de emergencia.
- Alternativa: dejar solo atlasadmin, y el mapeo GG_SoporteTI→atlas-admin sirve solo para sudo y archivos.
- Afecta: sshd, SSSD y la prueba de OBJ-08.

**DISC-09 — Propuesta:**
- La unidad mapeada de estudiantes apunta a una carpeta compartida **en atlas-dc01** (el SMB hacia el DC ya está permitido como servicio de dominio). La de docentes, a Samba en srv01 (regla 3).
- Las impresoras quedan fuera de alcance salvo que el equipo defina una.
- Afecta: GPO_Estudiantes, GPO_Docentes y los recursos compartidos.

**DISC-10 — Propuesta:**
- Incremental de lunes a sábado a las 02:00 y completo los domingos a las 02:00 (sin incremental ese día).
- El incremental se copia también a la carpeta de Windows, para cumplir el RPO de 24 h ante la pérdida del servidor.
- Mecánica: MySQL con binlog (el incremental son los binlogs del día) y archivos con `tar --listed-incremental`.
- Se agregan al respaldo `/srv/atlas/logs` y `/etc` relevante (ssh, ufw, samba, sssd, netplan, compose).
- Configuraciones versionadas con Git (etckeeper o repositorio propio), disparado por unidades `.path` de systemd, con retención de 10 versiones.
- Afecta: la Tabla 29 (destino del incremental: se propone local + Windows) y los scripts.

**DISC-11 — Propuesta: `atlas_backup` = SELECT, LOCK TABLES, SHOW VIEW, TRIGGER, SHOW_ROUTINE (y EVENT si se usan eventos), con `--no-tablespaces`.**
- Por qué: es el mínimo para que el comando de p. 55 produzca un respaldo completo.
- Afecta: BD-07 y el script de respaldo.

**DISC-12 — Propuesta:**
- Indicadores y reglas del Nivel 1 en PHP (`Services/Analysis`), porque es donde se garantiza la trazabilidad "qué regla, con qué datos" y la independencia de framework que pide la rúbrica.
- Procedimientos almacenados solo para agregaciones pesadas del análisis grupal y vistas para el panel, invocados desde PHP.
- Triggers para `resultados` y auditoría automática.
- Afecta: la Tabla 20 (alcance de los procedimientos).

**DISC-13 — Propuesta de transiciones:**
- BORRADOR → PENDIENTE (docente autor; requiere ≥ 1 pregunta, cada una con ≥ 2 opciones y exactamente 1 correcta).
- PENDIENTE → APROBADA (administrador).
- PENDIENTE → RECHAZADA (administrador; observaciones obligatorias).
- RECHAZADA → BORRADOR (docente edita y vuelve a enviar).
- APROBADA → PUBLICADA (docente autor, eligiendo los grupos).
- Ninguna otra transición, y ninguna edición del contenido después de APROBADA.
- Historial en una tabla de transiciones (origen, destino, autor, fecha, observaciones).
- **Punto a decidir**: quién publica, el docente autor (propuesto) o el administrador.

**DISC-14 — Propuesta: se aplica H4.** El estudiante ve sus actividades y su resultado (RF-07), no su perfil ni las recomendaciones. Por qué: H4 es la especificación IEEE 830, más precisa y más reciente, y es coherente con "no etiquetar" (§18).

**DISC-15 — Propuesta: modelo de 28 tablas.**
- Las 24 de la unión, más `actividad_grupo`, `recomendacion_regla`, `transiciones_actividad` y `registro_respaldos` (esta última alimenta la métrica "% de respaldos exitosos" de §12).
- Todo en 3FN salvo la excepción documentada de `resultados`.

**DISC-16 — Propuesta: alta por el administrador (H9).** Sin autorregistro.

**DISC-17 — Propuesta: se aplica H4.** La infraestructura (servidores, monitoreo, respaldos) se administra con cuentas del SO y de AD desde VLAN 50, no desde la web de ATLAS. El panel de administración de ATLAS no controla servidores.

**DISC-18 — Propuesta: sí, la regla 7 (HTTPS desde VLAN 40) cubre la API del LLM.** Se documenta en la matriz como "actualizaciones y API del LLM". No cambia ninguna regla.

**DISC-19 — Propuesta de servicios de dominio completos (regla 2):**
- TCP/UDP 53, TCP/UDP 88, TCP/UDP 464, TCP/UDP 389, TCP 636, TCP 3268–3269, TCP 445, UDP 123, TCP 135.
- Rango RPC dinámico con dos opciones:
  - **A (recomendada)**: fijar y documentar el rango por defecto de Windows Server 2022, TCP 49152–65535, verificándolo con `netsh int ipv4 show dynamicport tcp`. Máxima compatibilidad.
  - **B**: acotar los puertos RPC a un rango corto (por ejemplo 50000–50199) con la clave `HKLM\SOFTWARE\Microsoft\Rpc\Internet` (método documentado por Microsoft para firewalls). Más restrictivo, más riesgo de fallas.

**DISC-20 — Propuesta sin cambiar las reglas:** el DC (emulador PDC) se configura como fuente de hora confiable del dominio con su reloj local (`w32tm /config /reliable:yes`), y el resto sincroniza contra él. Kerberos solo exige coherencia interna. **Alternativa**: agregar a la regla 7 "UDP 123 desde 172.16.40.20" (cambia la Tabla 44; requiere aprobación).

**DISC-21 — Propuesta (cambia la Tabla 44, requiere aprobación):**
- Agregar "VLAN 50 → 172.16.40.20 DNS 53" (resolución de nombres) y "VLAN 50 → 172.16.40.10 HTTPS 443" (interfaz de ATLAS y de Zabbix).
- **Alternativa sin cambios**: operar por IP y usar túneles SSH hacia srv01; la VLAN 50 no resuelve nombres de Internet.

**DISC-22 — Propuesta:**
- En Packet Tracer se respeta la Tabla 41 literalmente.
- En GNS3 se usa una imagen L2 de Cisco y se publica una **tabla de correspondencia** puerto de la Tabla 41 → puerto de GNS3, solo para los puertos realmente conectados. Los no usados quedan deshabilitados en VLAN 999, igual que en el diseño.
- En la etapa Packet Tracer, fw01 se representa con un equipo marcado como "maqueta del firewall" (solo para la ruta por defecto), sin simular funciones que PT no tiene.

**DISC-23 — Propuesta: la Tabla 10 manda para las fechas** (es el cronograma). El detalle de qué entra en el Hito 2 se fija en la Fase 3 con tu aprobación (ver I).

**DISC-24 — Propuesta:**
- Hacer en la Fase 6 una prueba de concepto de Samba + SSSD (`idmap_sss`) en srv01.
- Si no permite acceso a los recursos con usuarios de AD, el plan B es winbind para Samba y SSSD solo para el login del SO, o winbind para ambos. Esto reemplaza tecnología y **requiere tu aprobación**.

## G.2 Ambigüedades y vacíos

| ID | Tema | Fuente | Qué falta | Propuesta (no se aplica sin aprobación) |
| -- | --- | --- | --- | --- |
| AMB-01 | **Ocho reglas del motor** | Tabla 5 obj. 5 (p. 22); §25.4 (p. 37) | El PDF exige "al menos ocho reglas documentadas" pero **no enumera ninguna** | El equipo las define. Si no están, en la Fase 2 propongo un borrador de 8 reglas basado solo en los 4 indicadores del §25.4, marcado como PROPUESTA |
| AMB-02 | Fórmula de eficiencia | §25.4 (p. 37) | "Relaciona el puntaje con el tiempo respecto al promedio del grupo" sin fórmula | `eficiencia = puntaje / (tiempo_estudiante / tiempo_promedio_grupo)`, acotada a un rango para el CHECK |
| AMB-03 | Parámetros de ML | §25.4 (p. 38); H27 | Umbral de "volumen suficiente"; K de K-means; duración del "período"; **variable objetivo de la regresión logística** (es supervisada: necesita una etiqueta) | Proponer en la Fase 2: umbral mínimo de estudiantes e intentos por grupo; K elegido por silueta en un rango chico; período semanal o mensual; etiqueta definida con datos observables (por ejemplo, caída de puntaje o abandono en la actividad siguiente) |
| AMB-04 | "Estudiantes que requieren atención prioritaria" | H26 (p. 115) | Criterio | Derivarlo de las reglas del Nivel 1 (un estudiante es prioritario si dispara reglas de riesgo), para que sea explicable |
| AMB-05 | Bloqueo de login en ATLAS | H10 (p. 99); Tabla 14 (p. 34) | Duración ("temporalmente", "por un rato"); por cuenta o por IP; política de contraseñas de ATLAS | 3 fallos por cuenta → 15 min (igual que AD, Tabla 32); contraseñas de ≥ 10 caracteres |
| AMB-06 | "Pausa" (RF-06) y "abandonado" (RF-07/08) | H14, H15, H16 | Umbrales | Pausa: pestaña oculta o inactividad ≥ N s; abandonado: sin actividad ≥ M min o salida explícita sin finalizar |
| AMB-07 | Campos del usuario | H9 (p. 97) | "Datos requeridos para su identificación" sin lista; RNF-14 exige el mínimo | Nombre, apellido, correo (único), rol, institución, grupos; sin cédula salvo que el equipo la exija |
| AMB-08 | Categoría o competencia de la actividad | §2 (p. 5–6); §6 (p. 8); consulta "resolución de problemas" (p. 38) | El modelo no tiene dónde guardar si una actividad es de "resolución de problemas", "visual", etc.; RF-12 recomienda "actividades" sin criterio de coincidencia | Agregar un catálogo `categorias` (1:N con actividades). Cambia el modelo; requiere aprobación |
| AMB-09 | Material de estudio y adaptación progresiva | §5 (p. 7) | Sin RF, sin ficha, sin tabla | Fuera de alcance salvo que el equipo agregue un RF (el Anexo H es la especificación de requisitos) |
| AMB-10 | LLM | §18; Tabla 16; H6 | Proveedor, modelo, clave, costo; cómo se interpreta la pregunta sin enviar nombres | Intérprete local determinista de la pregunta + seudónimos; el proveedor lo definís vos |
| AMB-11 | atlas-fw01 | Tabla 42; Figura 1 | Producto/SO; interfaces; red de tránsito rt01↔fw01; WAN; rutas | Ubuntu Server 24.04 + nftables + WireGuard (coherente con §30.4); red de tránsito a definir |
| AMB-12 | IP de gestión | §30.1 (p. 67) | SVI del switch en VLAN 50; gestión del router; IP y SO de la estación de administración | Las definís vos (ver J.2) |
| AMB-13 | Zabbix | Tabla 46 (p. 72) | Dónde corre el servidor; BD; puertos 10050/10051 en las reglas; acceso a la interfaz | Servidor Zabbix en contenedores en srv01 (agentes pasivos dentro de VLAN 40, sin cruzar el router); acceso a la interfaz según DISC-21 |
| AMB-14 | Registro de denegaciones de red | P-02, P-03; reglas 10–12 | A dónde van los logs del router y de fw01 | rsyslog en srv01 recibiendo syslog del router y de fw01 (requiere una regla nueva) o registro local en cada equipo más captura |
| AMB-15 | "Rechazada" y "Sin respuesta" | Tabla 48 | Un router Cisco que deniega por ACL responde ICMP "administratively prohibited" (el cliente ve un rechazo); UFW descarta en silencio (el cliente ve timeout) | Criterio de aprobado: "rechazada" = conexión no establecida y evento en el log; "sin respuesta" = el host destino no contesta (una respuesta ICMP del router cuenta como no alcanzado). Se documenta |
| AMB-16 | Certificado TLS | §25.1 HTTPS | Qué CA emite el certificado de atlas-web | CA interna propia (o AD CS, fuera de lo listado) distribuida por GPO a los clientes del dominio; autofirmado como mínimo |
| AMB-17 | Recursos compartidos | Tabla 35; GPO | Nombres, rutas y permisos de Samba; nombre de la carpeta de Windows para respaldos; cuenta que usa srv01 para escribir | Proponer en la Fase 7: `\\atlas-srv01\docentes`, `\\atlas-srv01\administracion`, `\\atlas-dc01\atlas-backups` con una cuenta de servicio en OU=ServiciosTI |
| AMB-18 | Reenviadores DNS | §29.4 (p. 60) | Cuáles | Los define la red del laboratorio o de la institución |
| AMB-19 | Firewall de Windows Defender | §30.5 (p. 72) remite a §29.3, que no tiene reglas | Reglas del DC | Permitir servicios de dominio desde VLAN 10, 20 y 30; RDP solo desde 172.16.50.0/24; agente Zabbix desde srv01 |
| AMB-20 | Respaldo del lado Windows | §28.5 solo cubre Linux | System State del DC, GPO, DHCP | Agregar `wbadmin` System State + exportación de GPO y DHCP. No lo pide el PDF; requiere aprobación |
| AMB-21 | "El administrador no puede escribir en backups" | p. 52 | Si atlasadmin tiene sudo sin restricciones, sí puede | sudo acotado para atlasadmin, o aceptar que la protección real es la copia fuera del servidor |
| AMB-22 | "Configuraciones: cada vez que cambian, 10 versiones" | Tabla 29 | Mecanismo | Git + unidades `.path` de systemd (ver DISC-10) |
| AMB-23 | Alcance de la VPN de administradores | Tabla 45; §28.4 | ¿Los administradores por VPN administran switch y router directamente (VLAN 50 = "todo") o saltan por la estación? El sshd de srv01 solo acepta 172.16.50.\* | Salto obligatorio por la estación de VLAN 50; VTY de switch y router solo desde 172.16.50.0/24 |
| AMB-24 | atlas-analysis como "repositorio aparte" | §26.2 (p. 42) | Hay un solo repositorio (tesis) | Monorepo con carpetas `atlas/` y `atlas-analysis/` independientes (cada una con su README y sus tests) |
| AMB-25 | Ventanas de prueba y consultas más frecuentes | RNF-02, RNF-03 | Cuáles son; ¿la consulta al LLM entra en los 3 s? | Definir las ventanas; RNF-03 medido sobre login, listado de actividades, panel docente y panel grupal; la consulta al LLM se mide aparte (depende de un tercero) |
| AMB-26 | ¿El login de ATLAS usa AD? | Tabla 36 ("solo entrar a ATLAS por web") contra §28.2 y §27.5 | Si ATLAS autentica contra AD o contra su BD | Contra su BD (hash), según §27.5 y Tabla 14; AD es para el SO y la red |
| AMB-27 | Clientes de prueba | H6 (p. 93) | Cuántos, qué SO, en qué VLAN | Mínimo: 1 Windows unido al dominio (VLAN 20 o 30), 1 cliente liviano por VLAN 10, 20, 30 y 50, 1 cliente VPN |
| AMB-28 | "Precisión de las recomendaciones" | §12 (p. 10) | Cómo se mide | Proponer en la Fase 3 (por ejemplo, valoración del docente sobre una muestra) |
| AMB-29 | Router en Packet Tracer | Tabla 42 | Modelo e interfaces | Lo definís vos (condiciona ZBF, ver DISC-04) |
| AMB-30 | Auditoría: tabla o archivo | §27 `auditoria`; §28.3 `auditoria.log` con `+a` | Qué va a cada lugar; `+a` impide la rotación | Ambos: la tabla es la fuente consultable (solo INSERT); el archivo es la copia append-only; rotación manual documentada (quitar `+a`, rotar, volver a ponerlo, y queda registrado) |

## G.3 Diferencias entre tu prompt y el PDF

**Resueltas (26/09/2026):** el usuario indicó que **siempre manda el PDF** y que el prompt solo define el método de trabajo. Todas se resuelven a favor del PDF (ver J.0).

| ID | Tu prompt | El PDF | Resolución |
| -- | --- | --- | --- |
| PR-01 | §17: OU "Grupos" dentro de OU=ATLAS | **OU=Grupos en la raíz del dominio**, al mismo nivel que OU=ATLAS (p. 58, verificado sobre la imagen) | Raíz del dominio |
| PR-02 | §27: "Windows debe poder utilizar el recurso [Samba] definido como destino de backup" | El destino de los respaldos es **una carpeta compartida en el servidor Windows**; Linux escribe ahí por SMB (Tabla 35 p. 61; Tabla 29 p. 55; §28.5 p. 55). Samba en Linux es para las máquinas del dominio | Linux → carpeta compartida del DC |
| PR-03 | §25: "Implementar política deny incoming / allow outgoing" para el firewall | Esa política existe (§30.3), pero choca con las reglas 5, 7 y 12 (DISC-05) | Propuesta de DISC-05 |
| PR-04 | §11: "Implementá al menos las ocho reglas documentadas en la especificación" | Las ocho reglas **no están en el PDF** (AMB-01) | Bloqueado hasta que el equipo las defina o apruebe un borrador |
| PR-05 | §8: el estudiante puede "consultar el material permitido" | Solo en §5 V1, sin RF ni tabla (AMB-09) | No se implementa hasta que decidas |
| PR-06 | §8: el administrador puede "administrar infraestructura según los permisos definidos" | En V2 el administrador de ATLAS es de coordinación (p. 37, H4) (DISC-17) | Se aplica H4 |

## G.4 Observaciones editoriales (no afectan la implementación)

| ID | Dónde | Observación |
| -- | --- | --- |
| ED-01 | Tabla 31 (p. 58) | El título dice "Estructura de unidades organizativas y grupos de AD", pero el contenido son las características del servidor |
| ED-02 | Tabla 33 (p. 59) | El título dice "Configuración de DNS del dominio", pero el contenido son las GPO |
| ED-03 | §24.2 (p. 32) y Tabla 13 | Dice que se agregan RNF-11 a RNF-14, pero existe RNF-15; su nombre varía entre "servidores externos" (Tabla 13) y "servicios externos" (H29) |
| ED-04 | §24.1 (p. 30) | Dice que se agregan RF-16 a RF-18, pero no explica el origen de RF-19 y RF-20 |
| ED-05 | §20.2 (p. 17) | "Cuestionario de diez preguntas", pero la Tabla 4 y el formulario incluyen una pregunta 11 |
| ED-06 | §11 (p. 10) contra §25.1 | Orden de capas distinto; rige §25 (V2) |
| ED-07 | §28.1 (p. 50) | "La plataforma no de él": falta una palabra ("no depende de él") |
| ED-08 | Tabla 39 (p. 64) | "dispónibles" (errata) |
