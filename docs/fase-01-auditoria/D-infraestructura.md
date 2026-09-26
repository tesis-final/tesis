# D. Infraestructura identificada

## D.1 Inventario

| Equipo | Nombre | Función | Entorno | IP | Fuente |
| --- | --- | --- | --- | --- | --- |
| Servidor Linux | atlas-srv01 | Aplicación (contenedores), BD, Samba, SSH | VirtualBox | 172.16.40.10/24, VLAN 40 | Tabla 24 (p. 50); Tabla 40 (p. 65) |
| Servidor Windows | atlas-dc01 | Controlador de dominio atlas.local, DNS, DHCP, GPO | VirtualBox | 172.16.40.20/24, VLAN 40 | Tabla 31 (p. 58); Tabla 40 |
| Switch de capa 2 | atlas-sw01 | VLAN y troncal hacia el router | Packet Tracer (luego GNS3) | Gestión en VLAN 50 (IP no definida, → AMB-12) | Tabla 42 (p. 67); Tabla 41 (p. 66) |
| Router de capa 3 | atlas-rt01 | Enrutamiento entre VLAN, ACL, DHCP relay | Packet Tracer (luego GNS3) | Gateways .1 de cada VLAN | Tabla 42; Tabla 38 (p. 63) |
| Firewall perimetral | atlas-fw01 | Filtrado con estado, NAT hacia Internet, terminación de la VPN | Máquina virtual (producto y SO no definidos, → AMB-11) | No definida (→ AMB-11) | Tabla 42; Figura 1 (p. 65) |
| Estación de administración | — (sin nombre) | Administración de la infraestructura | No definido | VLAN 50, IP fija no definida (→ AMB-12) | Tabla 41 (Fa0/23) |
| Clientes de prueba | — | Equipos de las VLAN 10, 20 y 30; al menos un Windows unido al dominio | No definido | DHCP | H6 (p. 93); §29.2 (p. 59) (→ AMB-27) |

## D.2 atlas-srv01 (Linux, §28, págs. 50–57)

### Sistema y servicios (Tabla 24)

Ubuntu Server 24.04 LTS, sin entorno gráfico. Servicios según la Tabla 24: Apache (→ DISC-01), PHP, MySQL, Samba y SSH. Según §25.5, la aplicación y la BD corren en contenedores Docker sobre este servidor (→ DISC-02). Samba no es necesario para ATLAS: se incluye para demostrar la integración y mover respaldos (p. 50).

### Usuarios y grupos (Tablas 25 y 26)

| Grupo | GID | Para qué | Usuario | UID | Shell |
| --- | --- | --- | --- | --- | --- |
| atlas-admin | 5001 | Administrar el servidor | atlasadmin | 5001 | /bin/bash |
| atlas-web | 5002 | Servicio web | atlasweb | 5002 | /usr/sbin/nologin |
| atlas-db | 5003 | Base de datos | atlasdb | 5003 | /usr/sbin/nologin |
| atlas-backup | 5004 | Respaldos | atlasbkp | 5004 | /usr/sbin/nologin |
| atlas-audit | 5005 | Leer registros de auditoría | **(ninguno definido)** | — | — |

Separación explícita (§28.2): los usuarios del SO son cuentas técnicas; los usuarios de ATLAS viven en la BD. Un docente no tiene cuenta en Linux.

### Permisos efectivos pedidos (Tabla 27) y jerarquía (§28.3)

| Recurso | Dueño:grupo y modo (§28.3) | admin | web | db | backup | audit |
| --- | --- | --- | --- | --- | --- | --- |
| /srv/atlas/ | atlasadmin:atlas-admin 750 | — | — | — | — | — |
| /srv/atlas/web/ | atlasweb:atlas-web 750 (public/ 755, app/ 750) | rwx | r-x | — | r-- | — |
| /srv/atlas/datos/ | atlasdb:atlas-db 770 | rwx | — | rwx | r-- | — |
| /srv/atlas/logs/ | atlasadmin:atlas-admin 770 | rwx | -wx | -wx | r-- | r-- |
| /srv/atlas/scripts/ | atlasadmin:atlas-admin 750 | rwx | — | — | r-x | — |
| /srv/atlas/backups/ | atlasbkp:atlas-backup 700 | r-x | — | — | rwx | — |
| /srv/atlas/config/ | atlasadmin:atlas-admin 750 | rwx | r-- | r-- | r-- | — |

Las columnas admin…audit son la Tabla 27. **Los modos de §28.3 más las ACL definidas no producen esa matriz** (→ DISC-07). Por ejemplo, con `/srv/atlas` en 750, ni atlasweb ni atlasdb ni atlasbkp pueden atravesar el directorio padre.

Decisiones deliberadas del PDF (p. 52):

- El usuario de respaldo puede leer todo, pero solo escribe en `backups/`.
- El administrador no puede escribir en `backups/` (→ AMB-21).

### ACL y atributos (págs. 52–53)

```
setfacl -m u:atlasbkp:rx /srv/atlas/datos
setfacl -m u:atlasweb:rwx /srv/atlas/logs
setfacl -d -m u:atlasweb:rwx /srv/atlas/logs
setfacl -m g:atlas-audit:rx /srv/atlas/logs
setfacl -d -m g:atlas-audit:rx /srv/atlas/logs
chattr +i /srv/atlas/config/atlas.conf
chattr +a /srv/atlas/logs/auditoria.log
```

### Acceso al servidor (§28.4, págs. 53–54)

| Capa | Configuración |
| --- | --- |
| SSH (`/etc/ssh/sshd_config`) | PermitRootLogin no · PasswordAuthentication no · PubkeyAuthentication yes · AllowGroups atlas-admin · AllowUsers atlasadmin@172.16.50.\* · MaxAuthTries 3 |
| TCP Wrappers | `/etc/hosts.deny`: `ALL: ALL` · `/etc/hosts.allow`: `sshd: 172.16.50.0/255.255.255.0` (el `openssh-server` de Ubuntu 24.04 sigue enlazado a libwrap0: verificado) |
| UFW | default deny incoming · default allow outgoing · 22/tcp desde 172.16.50.0/24 · 80,443/tcp desde 172.16.20.0/24 y 172.16.30.0/24 · 139,445/tcp desde 172.16.40.0/24 · logging on (→ DISC-06) |
| MySQL | Sin regla; solo interfaz local |

### Respaldo y recuperación (§28.5, págs. 54–56)

| Tipo | Frecuencia | Retención | Destino |
| --- | --- | --- | --- |
| Completo | Domingos 02:00 | 4 semanas | Local + Windows |
| Incremental | Todos los días 02:00 | 7 días | Local |
| Configuraciones | Cada vez que cambian | 10 versiones | Local + Windows |

- Criterio 3-2-1: la copia fuera del servidor va al servidor Windows por SMB.
- Qué se respalda (Tabla 28): BD, configuraciones, usuarios/grupos/ACL, código y logs.
- Comandos: `mysqldump --single-transaction --routines --triggers | gzip`, `tar --acls --xattrs`, `getent passwd/group`, `getfacl -R`.
- Restauración en 7 pasos.
- Objetivos: RPO 24 h y RTO 4 h.
- Verificación: integridad diaria, restauración de prueba mensual en entorno aparte, revisión trimestral.
- Problemas detectados: → DISC-10, DISC-11, AMB-22.

## D.3 atlas-dc01 (Windows, §29, págs. 58–62)

### Dominio y estructura (§29.2, p. 58; verificado sobre la imagen de la página)

```
atlas.local
├── OU=ATLAS
│   ├── OU=Administracion ── Usuarios, Equipos
│   ├── OU=Docentes ─────── Usuarios, Equipos
│   ├── OU=Estudiantes ──── Usuarios, Equipos
│   ├── OU=Servidores
│   └── OU=ServiciosTI
└── OU=Grupos                      ← en la raíz del dominio, al mismo nivel que OU=ATLAS
    ├── GG_Administracion
    ├── GG_Docentes
    ├── GG_Estudiantes
    └── GG_SoporteTI
```

Las OU siguen la división de las VLAN. Los equipos de las VLAN 10, 20 y 30 se unen al dominio y quedan en el contenedor "Equipos" de su OU. Eso habilita las GPO y es el motivo de la regla 2 (p. 59).

### Seguridad (Tabla 32, p. 59)

- Contraseñas: mínimo 10 caracteres, complejidad, historial de 5, vencen a los 90 días.
- Bloqueo de cuenta: a los 5 intentos fallidos, durante 15 minutos.
- Cuentas administrativas separadas de las de uso diario.
- Administrator renombrada; Guest deshabilitada.
- Auditoría de logins, cambios en el directorio y accesos a recursos.
- Delegación acotada por OU, sin privilegios de dominio.

### GPO (Tabla 33, págs. 59–60)

| GPO | Dónde | Qué hace |
| --- | --- | --- |
| GPO_Seguridad_Base | Todo el dominio | Contraseñas, bloqueo, auditoría |
| GPO_Estudiantes | OU Estudiantes | No pueden instalar software; unidades de red mapeadas (→ DISC-09) |
| GPO_Docentes | OU Docentes | Acceso a recursos compartidos e impresoras (→ DISC-09) |
| GPO_Servidores | OU Servidores | Endurecimiento y actualizaciones controladas |
| GPO_Auditoria | Todo el dominio | Registro detallado de eventos |

### DNS y DHCP (§29.4, págs. 60–61)

- **DNS**: integrado con AD. Zona directa atlas.local, zona inversa para 172.16.0.0/16 (`16.172.in-addr.arpa`), reenviadores (no especificados, → AMB-18), registro de atlas-srv01.
- **DHCP**: VLAN 10 172.16.10.100–.200; VLAN 20 172.16.20.100–.200; VLAN 30 172.16.30.100–.250; VLAN 40 y 50 con IP fijas. Cada ámbito entrega puerta de enlace, DNS del dominio y sufijo.
- **Reenvío DHCP**: en el router de capa 3. Cada interfaz de VLAN reenvía al servidor como tráfico dirigido, y el router indica de qué VLAN vino el pedido (campo giaddr) para que el DHCP elija el ámbito (regla 4).

### Integración con Linux (Tabla 35, p. 61; Tabla 36, p. 62)

| Qué | Cómo |
| --- | --- |
| Resolución de nombres | atlas-srv01 registrado en el DNS del dominio |
| Autenticación centralizada | atlas-srv01 unido al dominio con SSSD/Kerberos (→ DISC-24) |
| Recursos compartidos | Samba en Linux, accesible desde las máquinas del dominio |
| Correspondencia de identidades | GG_SoporteTI → atlas-admin; GG_Docentes y GG_Estudiantes → sin grupo POSIX (solo web) (→ DISC-08) |
| Destino de respaldos | Carpeta compartida **en el servidor Windows** (→ PR-02) |
| Hora | NTP desde el controlador de dominio (Kerberos tolera hasta 5 minutos de diferencia) (→ DISC-20) |

### Firewall del host

Firewall de Windows Defender "configurado según las secciones 28.4 y 29.3" (p. 72). La §29.3 no define reglas (→ AMB-19).

## D.4 atlas-fw01 (firewall perimetral)

| Aspecto | Definido en el PDF | No definido |
| --- | --- | --- |
| Función | Filtrado con estado, NAT de origen, terminación de la VPN WireGuard (Tabla 42, Figura 1, §30.1 p. 67) | — |
| Plataforma | "Máquina virtual" (p. 66) | Producto o SO (pfSense, OPNsense, Linux + nftables…) (→ AMB-11) |
| Interfaces | Una hacia Internet y una hacia atlas-rt01 (Figura 1) | Direcciones, red de tránsito, gateway WAN (→ AMB-11) |
| Reglas | Tabla 44: las que atraviesan el perímetro (5, 7, 8, 9, 10, 12) + NAT | Reparto exacto entre router y firewall (→ DISC-04) |
| VPN | UDP 51820, 10.8.0.0/24 en dos /25 | Ubicación contradictoria en §30.4 (→ DISC-03) |

## D.5 VPN (§30.4, pág. 71)

WireGuard. Túnel 10.8.0.0/24 dividido en administradores (10.8.0.0/25, .1–.126) y docentes (10.8.0.128/25, .129–.254). Puerto UDP 51820. Una clave pública por dispositivo.

- El perfil de administrador llega a VLAN 50 (regla 8).
- El perfil de docente llega solo a HTTPS de 172.16.40.10 (regla 9).
- El firewall distingue el perfil por la IP de origen.
- Entrar por VPN no da acceso a toda la red.

## D.6 Monitoreo (§30.5, págs. 71–74)

| Herramienta | Para qué |
| --- | --- |
| Zabbix | Disponibilidad y recursos de los servidores (ubicación no definida, → AMB-13) |
| Logs de ufw | Ver qué tráfico se bloquea |
| Visor de eventos | Eventos de seguridad del dominio |
| journalctl / rsyslog | Logs centralizados del lado Linux |
| Wireshark | Diagnóstico |
| ping, traceroute, nmap | Verificar conectividad y probar políticas |

Metas (Tabla 47):

- Disponibilidad ≥ 99 % durante las pruebas.
- Tiempo de respuesta ≤ 3 s.
- Accesos denegados revisados una vez por semana.
- Alerta al 80 % de CPU, memoria y disco.

## D.7 Entorno de laboratorio (§30.1, pág. 67; Tabla 51, pág. 77)

| Herramienta | Qué se hace ahí según el PDF | Límite técnico real |
| --- | --- | --- |
| Cisco Packet Tracer | Switch, router, VLAN, troncal 802.1Q, enrutamiento entre VLAN, ACL (Hito 1) | No ejecuta VM reales, WireGuard, Docker ni Zabbix, y no se conecta con VirtualBox. Sirve para validar el diseño de capa 2/3 y las ACL, no para P-01..P-15 de punta a punta |
| VirtualBox | atlas-srv01, atlas-dc01 (dominio, Samba, VPN según §30.1) y atlas-fw01 | Requiere RAM suficiente para todas las VM a la vez (→ R-05) |
| GNS3 | Migración en el Sprint 2, cuando red y servidores deban funcionar integrados | Necesita imágenes de Cisco (IOSv / IOSvL2 u otra) y la GNS3 VM; los nombres de interfaz cambian respecto de la Tabla 41 (→ DISC-22) |
