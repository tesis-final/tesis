# J. Información que necesito para empezar la implementación real

Para agilizar: en J.1 cada decisión trae una **opción recomendada**. Podés responder "acepto todas las recomendadas salvo D-xx, D-yy" y explicar solo las excepciones.

## J.1 Decisiones sobre discrepancias (bloquean la Fase 2)

| # | Tema | Referencia | Opción recomendada | Alternativa |
| -- | --- | --- | --- | --- |
| D-01 | Servidor web | DISC-01 | Nginx (`nginx:alpine`) + `php:8.3-fpm` | Apache 2.4 (`php:8.3-apache`) |
| D-02 | MySQL | DISC-02 | Contenedor atlas-db, red interna sin publicar 3306, datos en `/srv/atlas/datos` con UID 5003 | MySQL nativo con systemd (contradice §25.5) |
| D-03 | Versión de MySQL | R-02 | Mantener `mysql:8.0` (fiel al PDF) documentando el fin de soporte | `mysql:8.4` LTS |
| D-04 | Terminación de WireGuard | DISC-03 | atlas-fw01 (VM Linux) | atlas-srv01 (requiere DNAT, contradice §30.3) |
| D-05 | Estado en el router | DISC-04 | ZBF en atlas-rt01; plan B ACL con `established` | Solo ACL sin estado |
| D-06 | Política "negar entrante / permitir saliente" | DISC-05, PR-03 | Aplica a firewalls de host y al propio fw01; el reenvío sigue la Tabla 44 | — |
| D-07 | UFW | DISC-06 | Alinear con la Tabla 44 (VLAN 10 y VPN docentes a 443; VLAN 10 y 20 a 445; sin 139) + DOCKER-USER | Mantener §28.4 literal (P-07 y P-13 fallarían) |
| D-08 | Permisos POSIX | DISC-07 | La Tabla 27 es el objetivo; completar con ACL | — |
| D-09 | ¿Quién es miembro de atlas-audit? | DISC-07 | Un grupo de AD mapeado (por ejemplo GG_SoporteTI) o una cuenta técnica de auditoría | — |
| D-10 | SSH con cuentas de AD | DISC-08 | AllowGroups atlas-admin + gg_soporteti desde 172.16.50.0/24 con Kerberos (GSSAPI); atlasadmin como emergencia | Solo atlasadmin |
| D-11 | Unidad mapeada de estudiantes | DISC-09 | Carpeta compartida en atlas-dc01 | Quitarla de GPO_Estudiantes |
| D-12 | Impresoras en GPO_Docentes | DISC-09 | Fuera de alcance | Definir una impresora o servidor de impresión |
| D-13 | Incremental y RPO | DISC-10 | Incremental de lunes a sábado también copiado a Windows; binlog + `tar --listed-incremental`; incluir logs y `/etc` | Mantener el incremental solo local y documentar que el RPO de 24 h no cubre la pérdida del servidor |
| D-14 | Privilegios de atlas_backup | DISC-11 | Agregar TRIGGER y SHOW_ROUTINE, con `--no-tablespaces` | — |
| D-15 | Dónde se calculan los indicadores | DISC-12 | PHP (Nivel 1); procedimientos solo para agregaciones del análisis grupal | Procedimientos almacenados |
| D-16 | Ciclo de estados | DISC-13 | Transiciones de G.1 DISC-13; **publica el docente autor** | Publica el administrador |
| D-17 | ¿El estudiante ve perfil y recomendaciones? | DISC-14 | No (H4): solo su resultado | Sí (§25.3) |
| D-18 | Modelo de datos | DISC-15 | 28 tablas (24 + actividad_grupo, recomendacion_regla, transiciones_actividad, registro_respaldos) | — |
| D-19 | Registro de usuarios | DISC-16, AMB-07 | Solo por el administrador; campos: nombre, apellido, correo único, rol, institución, grupos | Autorregistro de estudiantes |
| D-20 | Rol administrador de ATLAS | DISC-17, PR-06 | Coordinación (H4), sin control de infraestructura desde la web | — |
| D-21 | Salida al LLM | DISC-18 | La regla 7 la cubre; solo se documenta | — |
| D-22 | Servicios de dominio y rango RPC | DISC-19 | Lista completa de G.1 + rango 49152–65535 fijado y documentado | Rango acotado (ej. 50000–50199) |
| D-23 | Hora del DC | DISC-20 | DC como fuente confiable con reloj local (sin cambiar reglas) | Agregar UDP 123 desde el DC a la regla 7 |
| D-24 | DNS/HTTPS desde VLAN 50 | DISC-21 | Agregar "VLAN 50 → DC DNS 53" y "VLAN 50 → srv01 HTTPS 443" | Sin cambios (operar por IP y túnel SSH) |
| D-25 | Puertos en GNS3 | DISC-22 | Tabla de correspondencia solo para puertos usados | — |
| D-26 | Alcance del Hito 2 | DISC-23 | Lo propongo en la Fase 3 según la Tabla 10 | — |
| D-27 | Samba + SSSD | DISC-24 | Prueba de concepto; si falla, winbind (con aprobación) | Winbind desde el inicio |
| D-28 | OU=Grupos | PR-01 | En la raíz del dominio (como el PDF) | Dentro de OU=ATLAS (como tu prompt) |
| D-29 | Destino de los respaldos | PR-02 | Carpeta compartida del DC, escrita desde Linux (como el PDF) | La que indica tu prompt |
| D-30 | Material de estudio y adaptación progresiva | AMB-09, PR-05 | Fuera de alcance (sin RF) | Agregar RF y tabla nuevos |
| D-31 | Categoría de actividad | AMB-08 | Agregar catálogo `categorias` para soportar "resolución de problemas" y recomendaciones de actividades | Sin categoría (la consulta de ejemplo no se podría responder) |
| D-32 | Respaldo del lado Windows | AMB-20 | Agregar System State + exportación de GPO y DHCP | Fuera de alcance |
| D-33 | Repositorio | AMB-24 | Monorepo con `atlas/`, `atlas-analysis/`, `infra/`, `docs/` | Dos repositorios |
| D-34 | ATLAS contra AD | AMB-26 | ATLAS autentica contra su propia BD | LDAP contra AD |
| D-35 | Zabbix | AMB-13 | Contenedores en atlas-srv01 | Otra VM o la estación de VLAN 50 |
| D-36 | Registro de denegaciones de red | AMB-14 | rsyslog en srv01 recibe syslog de rt01 y fw01 (requiere una regla nueva) | Log local en cada equipo + captura |
| D-37 | Certificado TLS | AMB-16 | CA interna propia distribuida por GPO | Autofirmado |
| D-38 | Sudo de atlasadmin | AMB-21 | sudo acotado | sudo total, con la limitación documentada |

## J.2 Datos técnicos que el PDF no define

1. **atlas-fw01**
   - Producto y SO: se recomienda Ubuntu Server 24.04 + nftables + WireGuard.
   - IP de la interfaz hacia atlas-rt01 y de la interfaz del router hacia fw01 (red de tránsito, por ejemplo un /30; no la invento).
   - Cómo sale a Internet en el laboratorio (NAT de VirtualBox, bridge, nube NAT de GNS3) y su IP WAN.
2. **IP de gestión**:
   - SVI de atlas-sw01 en VLAN 50;
   - IP de gestión de atlas-rt01 (¿la 172.16.50.1 de la subinterfaz?);
   - IP fija y SO de la estación de administración (Fa0/23).
3. **Modelos** del router y del switch en Packet Tracer, y **versión de Packet Tracer**.
4. **Reenviadores DNS** que usará el DC.
5. **Nombres de cuentas técnicas**: administrador renombrado del dominio, cuenta de servicio para respaldos, cuentas administrativas separadas.
6. **Recursos compartidos**: nombres y a qué grupos van, o aceptar la propuesta de AMB-17.

## J.3 Recursos del laboratorio

1. **Hardware anfitrión**: CPU, RAM y disco libre, y si son uno o varios equipos (R-05).
2. ¿Tienen **imágenes de Cisco para GNS3** (IOSv, IOSvL2, IOU) con licencia? ¿Qué versión de GNS3? (R-04)
3. **ISO** disponibles: Ubuntu Server 24.04, Windows Server 2022 (¿evaluación?), un cliente Windows Pro o Enterprise (H6).
4. ¿Qué **clientes de prueba** pueden correr por VLAN? (AMB-27)
5. ¿Quién del equipo ejecuta el laboratorio y toma las capturas?

## J.4 Definiciones del motor de análisis

1. **Las 8 reglas** (AMB-01). Si no están definidas, confirmá que propongo un borrador basado en los 4 indicadores para que el equipo lo apruebe.
2. Fórmula de **eficiencia** (AMB-02) o aceptación de la propuesta.
3. **ML** (AMB-03): umbral mínimo de datos, período de recálculo y criterio de "dificultad creciente" (la etiqueta de la regresión logística); o aceptación de que lo proponga en la Fase 2.
4. Criterio de **atención prioritaria** (AMB-04).
5. **Bloqueo de login** (AMB-05): duración y criterio.
6. Umbrales de **pausa** y **abandono** (AMB-06).
7. **Proveedor del LLM** y modelo (AMB-10).

## J.5 Secretos y cuentas (cómo pasarlos)

**No los pegues en el chat ni en el repositorio.** El repo tendrá `.env.example` con nombres de variables y valores de ejemplo. Los valores reales van solo en el `.env` de cada servidor, fuera de Git. Esto aplica a contraseñas de BD, clave del LLM, claves WireGuard y cuentas de AD. Las claves privadas de WireGuard se generan en cada dispositivo y nunca salen de ahí.

## J.6 Otros

1. ¿Querés que haga un **commit por fase** en la rama `claude/intelligent-cannon-iecvmy` y que abra un PR al final de cada fase?
2. ¿Idioma del código? Se propone código e identificadores en inglés o español; comentarios y documentación en español. Como el modelo de datos del PDF está en español (`actividades`, `intentos`…), se propone **español en BD y dominio, inglés en la infraestructura del código** (Controllers, Repositories), igual que la estructura de §26.2.
3. ¿Los docentes para la prueba de uso (RNF-11) están disponibles? ¿En qué fechas?
