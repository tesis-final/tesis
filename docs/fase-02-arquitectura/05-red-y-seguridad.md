# 05 — Red y seguridad: diseño final por dispositivo

Aplica la Tabla 44 (orden y acciones sin cambios) a cada equipo según la topología de la Figura 1 y las decisiones DEC-03, DEC-04, DEC-05, DEC-17 y DEC-R8/R9.

Los valores que faltan se escriben como `‹PENDIENTE: …›`: **no se inventan** y se piden en J.2.

## 1. Direccionamiento final

| Elemento | Valor | Fuente |
| --- | --- | --- |
| VLAN 10/20/30/40/50 | 172.16.{10,20,30,40,50}.0/24, gateway .1 | Tabla 38 |
| VLAN 999 | Nativa del troncal y puertos deshabilitados; sin subinterfaz ni IP | Tabla 41, p. 66 |
| atlas-srv01 | 172.16.40.10/24, gw 172.16.40.1, DNS 172.16.40.20 | Tabla 40 |
| atlas-dc01 | 172.16.40.20/24, gw 172.16.40.1, DNS 127.0.0.1 + reenviadores ‹PENDIENTE: reenviadores› | Tabla 40, §29.4 |
| DHCP | VLAN 10 .100–.200 · VLAN 20 .100–.200 · VLAN 30 .100–.250; opciones 003 (gw), 006 (172.16.40.20), 015 (atlas.local) | Tabla 34 |
| atlas-rt01 subinterfaces | Gi‹PENDIENTE: modelo›.10/.20/.30/.40/.50 con 172.16.X.1; `ip helper-address 172.16.40.20` en .10, .20 y .30 | Tabla 38, §29.4 |
| atlas-rt01 ↔ atlas-fw01 | ‹PENDIENTE: red de tránsito e IP de cada extremo› | Figura 1 |
| atlas-fw01 WAN | ‹PENDIENTE: IP/gateway según el laboratorio› | Figura 1 |
| atlas-fw01 wg0 | 10.8.0.1/24 (CT-08) | Tabla 45 |
| VPN administradores | Clientes 10.8.0.2 – 10.8.0.126 (/32 cada uno) | Tabla 45 |
| VPN docentes | Clientes 10.8.0.129 – 10.8.0.254 (/32 cada uno) | Tabla 45 |
| Gestión del switch | SVI VLAN 50 ‹PENDIENTE: IP›, gw 172.16.50.1 | p. 67 |
| Gestión del router | ‹PENDIENTE: confirmar 172.16.50.1› | p. 67 |
| Estación de administración | ‹PENDIENTE: IP fija en 172.16.50.0/24 y SO› | Tabla 41 (Fa0/23) |

Rutas:

- **atlas-rt01**: ruta por defecto → fw01; 10.8.0.0/24 → fw01.
- **atlas-fw01**: 172.16.0.0/16 → rt01; ruta por defecto → gateway WAN.

## 2. atlas-sw01 (Tabla 41, literal)

- VLAN 10, 20, 30, 40, 50 y 999 creadas y con nombre.
- Accesos: Fa0/1–4 → 10; Fa0/5–10 → 20; Fa0/11–20 → 30; Fa0/21–22 → 40; Fa0/23 → 50. Todos con `switchport mode access`, `switchport nonegotiate` y PortFast.
- Fa0/24 y Gi0/2: `switchport access vlan 999` + `shutdown`.
- Gi0/1: `switchport mode trunk`, `switchport trunk native vlan 999`, `switchport trunk allowed vlan 10,20,30,40,50`, `switchport nonegotiate`.
- VLAN 1 sin IP y en shutdown.
- Gestión: SVI VLAN 50 con SSH v2, VTY `access-class` que solo acepta 172.16.50.0/24, `transport input ssh`.
- En GNS3 se aplica la misma lógica con la tabla de correspondencia de puertos (DEC-22), que se publica en la Fase 8.

## 3. atlas-rt01: firewall por zonas (DEC-04)

Zonas: `Z_ADM` (.10), `Z_DOC` (.20), `Z_EST` (.30), `Z_SRV` (.40), `Z_GES` (.50), `Z_EXT` (interfaz hacia fw01: Internet y VPN) y la zona `self` (el propio router).

Por defecto, ZBF descarta todo lo que no tenga un par de zonas con política, lo que equivale a la regla 12. Toda política termina con `class-default → drop log`, así cada denegación queda registrada (reglas 10–12).

| Par de zonas (origen → destino) | Se inspecciona (estado), en este orden | Regla |
| --- | --- | --- |
| Z_ADM, Z_DOC, Z_EST → Z_SRV | 1) TCP 3306 a .10 → **drop log** (explícito). 2) TCP 443 a 172.16.40.10. 3) Servicios de dominio a 172.16.40.20 (DEC-17). 4) Solo Z_ADM y Z_DOC: TCP 445 a 172.16.40.10 | 10, 1, 2, 3 |
| Z_ADM, Z_DOC, Z_EST, Z_GES → Z_EXT | TCP 80 y 443 hacia fuera de 172.16.0.0/16 | 5 |
| Z_EST → Z_ADM, Z_DOC, Z_GES | **drop log** (explícito) | 11 |
| Z_ADM ↔ Z_DOC; Z_ADM, Z_DOC → Z_EST, Z_GES | Sin política → drop log | 12 |
| Z_GES → Z_ADM, Z_DOC, Z_EST, Z_SRV | TCP 22 y 3389 | 6 |
| Z_SRV → Z_EXT | TCP 80/443 desde 172.16.40.0/24; TCP/UDP 53 solo desde 172.16.40.20 | 7 |
| Z_SRV → Z_ADM, Z_DOC, Z_EST, Z_GES | Sin política → drop log (los servidores no inician hacia usuarios) | 12, P-09 |
| Z_EXT → Z_GES | Todo desde 10.8.0.0/25 | 8 |
| Z_EXT → Z_SRV | 1) TCP 3306 → drop log. 2) TCP 443 desde 10.8.0.128/25 a 172.16.40.10 | 10, 9 |
| Z_EXT → otras zonas | Sin política → drop log | 12, P-14 |
| self ↔ Z_SRV | DHCP relay: UDP 67 entre el router y 172.16.40.20 (pass en ambos sentidos) | 4 |
| Z_GES → self | SSH al router (gestión, p. 67) | p. 67 |

- **Servicios de dominio (regla 2, DEC-17)**: TCP/UDP 53 · TCP/UDP 88 · TCP/UDP 464 · TCP/UDP 389 · TCP 636 · TCP 3268–3269 · TCP 445 · UDP 123 · TCP 135 · TCP 49152–65535, todo hacia 172.16.40.20.
- **Plan B (sin ZBF en el modelo de PT)**: ACL extendidas entrantes por subinterfaz con el mismo orden. El retorno TCP se permite con `established`; el retorno UDP del DC (53, 88, 123, 389, 464, 67), con entradas por puerto de origen. Se documenta como "estado emulado".
- **Registro**: `drop log` / `log` en las ACE, y syslog local (`logging buffered`) del router. No se configura un servidor syslog externo, porque exigiría una regla fuera de la Tabla 44 (DEC-R8). La evidencia es `show logging` más los contadores de la política.

## 4. atlas-fw01 (Ubuntu Server 24.04 + nftables + WireGuard) (DEC-03, DEC-R9)

| Cadena | Política | Reglas, en orden |
| --- | --- | --- |
| input | drop | ct established,related accept · lo accept · UDP 51820 en WAN accept (VPN-05) · TCP 22 desde 172.16.50.0/24 accept (gestión desde VLAN 50) · log prefix "FW01-IN-DROP" |
| output | accept | (DEC-R9: permitir saliente en el propio equipo) |
| forward | drop | ct established,related accept · (regla 5) 172.16.{10,20,30,50}.0/24 → WAN TCP 80,443 accept · (regla 7) 172.16.40.0/24 → WAN TCP 80,443 accept; 172.16.40.20 → WAN TCP/UDP 53 accept · (regla 8) wg0 10.8.0.0/25 → 172.16.50.0/24 accept · (regla 9) wg0 10.8.0.128/25 → 172.16.40.10 TCP 443 accept · (regla 10) → 172.16.40.10 TCP 3306 log prefix "ATLAS-R10 " drop · (regla 12) log prefix "ATLAS-R12 " drop |
| postrouting (nat) | — | 172.16.0.0/16 saliendo por WAN → masquerade (FW-17). **Sin NAT para 10.8.0.0/24** (VPN-09: el origen se conserva) |
| prerouting (nat) | — | **Vacía**: no hay DNAT hacia servidores (§30.3) |

La regla 11 (VLAN 30 → VLAN 10/20/50) no atraviesa fw01: se aplica en rt01.

WireGuard: `wg0` escucha en 51820. Hay un `[Peer]` por dispositivo, con `AllowedIPs` /32 dentro del segmento de su perfil. Las claves privadas de los clientes se generan en cada dispositivo. Del lado cliente, los `AllowedIPs` son: administrador 172.16.50.0/24; docente 172.16.40.10/32.

## 5. atlas-srv01: UFW + DOCKER-USER (DEC-05, CT-04)

```
ufw default deny incoming
ufw default allow outgoing
ufw allow from 172.16.50.0/24 to any port 22 proto tcp
ufw allow from 172.16.10.0/24 to any port 443 proto tcp
ufw allow from 172.16.20.0/24 to any port 443 proto tcp
ufw allow from 172.16.30.0/24 to any port 443 proto tcp
ufw allow from 10.8.0.128/25  to any port 443 proto tcp
ufw allow from 172.16.10.0/24 to any port 445 proto tcp
ufw allow from 172.16.20.0/24 to any port 445 proto tcp
ufw allow from 172.16.40.20   to any port 445 proto tcp
ufw logging on
```

- Como Docker publica 443 y 80 por fuera de UFW, la cadena `DOCKER-USER` repite el filtro: acepta 443 hacia atlas-web solo desde las cuatro redes anteriores y descarta con log el resto (incluido el 80 desde la red).
- MySQL y Zabbix no se publican (DEC-02, DEC-19).
- TCP Wrappers y sshd según §28.4, con el ajuste de DEC-07.

## 6. atlas-dc01: Firewall de Windows Defender (AMB-19, sin reglas nuevas de red)

| Entrada permitida | Origen |
| --- | --- |
| Servicios de dominio (lista de DEC-17) | 172.16.10.0/24, 172.16.20.0/24, 172.16.30.0/24, 172.16.40.10 |
| DHCP UDP 67 | IP del router: 172.16.10.1, 172.16.20.1, 172.16.30.1, 172.16.40.1 |
| RDP 3389 | 172.16.50.0/24 |
| Agente Zabbix TCP 10050 | 172.16.40.10 |
| Todo lo demás | Bloqueado (perfil de dominio) |

La carpeta `\\atlas-dc01\atlas-backups` recibe SMB desde 172.16.40.10: esa conexión va dentro de VLAN 40, sin router, y ya está cubierta por "servicios de dominio" (TCP 445).

## 7. Servicios de dominio y hora

- DNS integrado en AD: zona `atlas.local`, zona inversa `16.172.in-addr.arpa`, registros A y PTR de ambos servidores.
- Hora: el DC (emulador PDC) es la fuente confiable con su reloj (`w32tm /config /reliable:yes`) (DEC-R8). srv01 usa chrony apuntando al DC; los clientes del dominio, NT5DS.

## 8. Qué se prueba y dónde

| Prueba | Evidencia principal |
| --- | --- |
| P-01, P-13 | `curl -v https://172.16.40.10/api/v1/health` + certificado de ATLAS-CA |
| P-02, P-03 | `nmap -Pn -p22,3306 172.16.40.10` desde VLAN 30 + `show logging` / contadores de ZBF en rt01 (+ `ufw.log` si llegara al host) |
| P-04, P-05, P-08, P-09, P-14 | `ping` y `nmap` sin respuesta + drop log |
| P-06 | `nslookup atlas-srv01.atlas.local 172.16.40.20` |
| P-07 | `\\atlas-srv01\docentes` desde VLAN 20 |
| P-10, P-11 | SSH y RDP desde la estación de VLAN 50 |
| P-12 | `curl -I https://…` hacia Internet desde VLAN 10, 20 y 30 |
| P-15 | `ipconfig /all` por VLAN + concesiones en la consola DHCP |
