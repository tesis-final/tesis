# E. Diseño de red identificado

Todo lo que figura aquí sale literalmente del PDF. Lo que el PDF **no** define está al final (E.12) y se pide en J. No se inventó ningún valor.

## E.1 Direccionamiento

**Tabla 38 (p. 63): VLAN, red y gateway**

| VLAN | Área | Red | Gateway | Máscara |
| --- | --- | --- | --- | --- |
| 10 | Administración | 172.16.10.0/24 | 172.16.10.1 | 255.255.255.0 |
| 20 | Docentes | 172.16.20.0/24 | 172.16.20.1 | 255.255.255.0 |
| 30 | Estudiantes | 172.16.30.0/24 | 172.16.30.1 | 255.255.255.0 |
| 40 | Servidores | 172.16.40.0/24 | 172.16.40.1 | 255.255.255.0 |
| 50 | Gestión | 172.16.50.0/24 | 172.16.50.1 | 255.255.255.0 |
| 999 | Nativa del troncal y puertos sin uso | — (sin enrutamiento ni servicios) | — | — |

Por qué 172.16.0.0/16 (p. 63): para reducir el solapamiento con redes hogareñas cuando alguien entra por VPN.

**Tabla 39 (p. 64): equipos simultáneos estimados**

| VLAN | Equipos | Ocupación |
| --- | --- | --- |
| 10 | 12 | 5 % |
| 20 | 25 | 10 % |
| 30 | 120 | 47 % |
| 40 | 2 | 1 % |
| 50 | 3 | 1 % |

Se mantiene /24 en todas; VLSM se evaluó y se descartó.

**Tabla 40 (p. 65): IP fijas**

| Equipo | IP |
| --- | --- |
| atlas-srv01 | 172.16.40.10 |
| atlas-dc01 | 172.16.40.20 |

**Tabla 34 (p. 60): ámbitos DHCP**

| VLAN | Rango |
| --- | --- |
| 10 | 172.16.10.100 – 172.16.10.200 |
| 20 | 172.16.20.100 – 172.16.20.200 |
| 30 | 172.16.30.100 – 172.16.30.250 |
| 40 | IP fijas, sin DHCP |
| 50 | IP fijas, sin DHCP |

**Tabla 45 (p. 71): VPN**

| Segmento | Red | Rango de hosts |
| --- | --- | --- |
| Administradores | 10.8.0.0/25 | 10.8.0.1 – 10.8.0.126 |
| Docentes | 10.8.0.128/25 | 10.8.0.129 – 10.8.0.254 |

## E.2 Topología (Figura 1, p. 65; transcripción de la imagen)

```
                         Internet
                            │
            ┌───────────────┴───────────────┐        UDP 51820      ┌────────────────────────────┐
            │ atlas-fw01                     │◄ - - - - - - - - - - -│ Clientes VPN               │
            │ Firewall perimetral            │                       │ 10.8.0.0/25 administradores│
            │ NAT de origen · VPN WireGuard  │                       │ 10.8.0.128/25 docentes     │
            └───────────────┬───────────────┘                       └────────────────────────────┘
            ┌───────────────┴───────────────┐
            │ atlas-rt01 — Router de capa 3  │
            │ Enrutamiento entre VLAN · ACL · DHCP relay
            └───────────────┬───────────────┘
                            │ Troncal 802.1Q — Gi0/1 · VLAN permitidas: 10, 20, 30, 40, 50 · nativa: 999
┌───────────────────────────┴───────────────────────────────────────────────────────────────┐
│ atlas-sw01 — Switch de capa 2 · puertos sin uso (Fa0/24, Gi0/2) deshabilitados en VLAN 999 │
└──┬──────────────┬──────────────┬──────────────────────┬─────────────────────┬─────────────┘
 VLAN 10        VLAN 20        VLAN 30               VLAN 40               VLAN 50
 Administración Docentes       Estudiantes           Servidores            Gestión
 172.16.10.0/24 172.16.20.0/24 172.16.30.0/24        172.16.40.0/24        172.16.50.0/24
 GW .10.1       GW .20.1       GW .30.1              GW .40.1              GW .50.1
 Fa0/1–Fa0/4    Fa0/5–Fa0/10   Fa0/11–Fa0/20         srv01 .10 Fa0/21      Fa0/23
 DHCP .100–.200 DHCP .100–.200 DHCP .100–.250        dc01  .20 Fa0/22      IP fijas
                                                     IP fijas
```

Lectura técnica de la topología:

- El router está **debajo** del firewall. Todo el tráfico entre VLAN se enruta en atlas-rt01 y **no atraviesa atlas-fw01**. Solo el tráfico hacia o desde Internet y la VPN pasa por el firewall (→ DISC-04).
- La Figura 1 no muestra ningún enlace de atlas-rt01 hacia VLAN 999 (correcto: sin enrutamiento).

## E.3 Switch atlas-sw01 (Tabla 41, p. 66)

| Puertos | Modo | VLAN | Conecta |
| --- | --- | --- | --- |
| Fa0/1 – Fa0/4 | Acceso | 10 | Equipos de Administración |
| Fa0/5 – Fa0/10 | Acceso | 20 | Equipos de Docentes |
| Fa0/11 – Fa0/20 | Acceso | 30 | Equipos de Estudiantes |
| Fa0/21 | Acceso | 40 | atlas-srv01 (Linux) |
| Fa0/22 | Acceso | 40 | atlas-dc01 (Windows Server) |
| Fa0/23 | Acceso | 50 | Estación de administración |
| Fa0/24 | Deshabilitado | 999 | Sin uso |
| Gi0/1 | Troncal 802.1Q | 10, 20, 30, 40, 50 | Router de capa 3 |
| Gi0/2 | Deshabilitado | 999 | Reserva |

- **Puertos sin uso** (p. 66): deshabilitados y en VLAN 999, que no tiene enrutamiento ni servicios, para que nadie obtenga conectividad enchufando un cable.
- **VLAN nativa** (p. 66): 999 en el troncal, que no coincide con ninguna VLAN en uso. Evita el ataque de doble etiquetado sobre la VLAN 1.
  - Observación técnica: la 999 es a la vez la nativa y la VLAN de los puertos deshabilitados. El riesgo de doble etiquetado queda mitigado porque la 999 **no está en la lista de VLAN permitidas del troncal** (Tabla 41: solo 10, 20, 30, 40, 50). Se mantiene tal cual el PDF.
- **VLAN de gestión** (p. 67): las interfaces de administración del switch y del router pertenecen a la VLAN 50.

## E.4 Router atlas-rt01

Funciones (Tabla 42, p. 67; Figura 1): enrutamiento entre VLAN, listas de control de acceso, reenvío de DHCP.

Lo que se deduce sin inventar: el switch conecta su Gi0/1 en troncal al router, así que el router se implementa como *router-on-a-stick*, con una subinterfaz 802.1Q por VLAN (10, 20, 30, 40, 50) cuya IP es el gateway .1 de la Tabla 38. La nativa 999 debe coincidir en ambos extremos. El `ip helper-address 172.16.40.20` va en las subinterfaces de las VLAN 10, 20 y 30 (§29.4, p. 61).

Quedan sin definir en el PDF (→ AMB-29, AMB-11):

- el modelo del router en Packet Tracer y los nombres de sus interfaces;
- la interfaz y la red de tránsito hacia atlas-fw01;
- la ruta por defecto hacia atlas-fw01;
- la ruta de retorno a 10.8.0.0/24 vía atlas-fw01.

## E.5 VLAN de gestión (50)

- Única VLAN desde la que se administra la infraestructura; ninguna otra llega a ella (§30.1 p. 67; §30.2 p. 69).
- Excepción explícita: la VPN de administradores (10.8.0.0/25) llega a VLAN 50 con "todo" (regla 8).
- El SSH de atlas-srv01 solo acepta a atlasadmin desde 172.16.50.\* (§28.4).

## E.6 Matriz de comunicación (Tabla 43, págs. 68–69; verificada sobre la imagen)

| Desde ↓ / Hacia → | V10 | V20 | V30 | V40 | V50 | Internet |
| --- | --- | --- | --- | --- | --- | --- |
| V10 Administración | — | no | no | dominioᵃ, webᵇ, SMBᶜ | no | sí |
| V20 Docentes | no | — | no | dominioᵃ, webᵇ, SMBᶜ | no | sí |
| V30 Estudiantes | no | no | — | dominioᵃ, webᵇ | no | sí |
| V40 Servidores | no | no | no | — | no | actualizaciones |
| V50 Gestión | SSH/RDP | SSH/RDP | SSH/RDP | SSH/RDP | — | sí |
| VPN admin (10.8.0.0/25) | no | no | no | no | todo | — |
| VPN docente (10.8.0.128/25) | no | no | no | webᵇ | no | — |

- ᵃ Servicios de dominio hacia 172.16.40.20: DNS (53), Kerberos (88), LDAP (389), LDAPS (636), SMB (445) y NTP (123).
- ᵇ HTTPS (443) hacia 172.16.40.10.
- ᶜ SMB (445) hacia 172.16.40.10, para los recursos de Samba de §29.5.
- Nota del PDF: el tráfico dentro de una misma VLAN no atraviesa el firewall. El firewall mantiene estado, así que las respuestas no requieren regla propia.

## E.7 Reglas de firewall (Tabla 44, págs. 69–70)

| # | Desde | Hacia | Qué | Acción |
| --- | --- | --- | --- | --- |
| 1 | VLAN 10, 20, 30 | 172.16.40.10 | HTTPS 443 | Permitir |
| 2 | VLAN 10, 20, 30 | 172.16.40.20 | Servicios de dominioᵃ | Permitir |
| 3 | VLAN 10, 20 | 172.16.40.10 | SMB 445 | Permitir |
| 4 | Router L3 (relay) | 172.16.40.20 | DHCP UDP 67 | Permitir |
| 5 | VLAN 10, 20, 30, 50 | Internet | HTTP 80, HTTPS 443 | Permitir |
| 6 | VLAN 50 | VLAN 10, 20, 30, 40 | SSH 22, RDP 3389 | Permitir |
| 7 | VLAN 40 | Internet | HTTP 80, HTTPS 443, DNS 53ᵇ | Permitir |
| 8 | 10.8.0.0/25 | VLAN 50 | Todo | Permitir |
| 9 | 10.8.0.128/25 | 172.16.40.10 | HTTPS 443 | Permitir |
| 10 | Cualquiera | 172.16.40.10 | MySQL 3306 | Negar y registrar |
| 11 | VLAN 30 | VLAN 10, 20, 50 | Todo | Negar y registrar |
| 12 | Cualquiera | Cualquiera | Todo | Negar y registrar |

- ᵃ DNS (53), Kerberos (88), LDAP (389), LDAPS (636), SMB (445) y NTP (123). La unión al dominio usa además RPC (135) y un rango dinámico de puertos altos, que "se fija en el controlador de dominio y se documenta al implementarlo en el Sprint 2" (→ DISC-19).
- ᵇ DNS hacia Internet únicamente desde el controlador de dominio, para los reenviadores.
- Las reglas se evalúan en orden y se aplica la primera que coincide. El firewall mantiene estado.
- La regla 10 es lógicamente redundante con la 12, pero se mantiene para dejar la decisión explícita y generar un registro específico (p. 70).

**Dónde se aplica cada control** (§30.5, p. 72): las reglas de la Tabla 44 se implementan "en el router y en el firewall perimetral". Además, cada servidor tiene su firewall de host (ufw en srv01, Windows Defender en dc01).

El PDF no asigna cada regla a un dispositivo. Por la topología (E.2), el reparto que resulta **inevitable** es el siguiente. Es una deducción que la Fase 2 debe confirmar (→ DISC-04):

| Regla | Tráfico | Pasa por | Dispositivo que puede aplicarla |
| --- | --- | --- | --- |
| 1, 2, 3, 6, 11 | Entre VLAN | atlas-rt01 | atlas-rt01 (ACL) |
| 4 | Generado por el propio router | atlas-rt01 | atlas-rt01 (y firewall de host del DC) |
| 5, 7 | VLAN → Internet | rt01 → fw01 | atlas-rt01 (paso hacia fw01) + atlas-fw01 (filtrado con estado + NAT) |
| 8, 9 | VPN → interno | fw01 → rt01 | atlas-fw01 (identifica el perfil por el origen) |
| 10, 12 | Cualquiera | Ambos | Ambos (cada uno registra lo que deniega) |

## E.8 NAT (§30.3, p. 70)

Traducción de origen (SNAT/masquerade) para el tráfico que sale a Internet. **Sin traducción de destino** hacia los servidores: el prototipo no expone nada a Internet, y el acceso externo es solo por VPN.

## E.9 VPN (Tabla 45, p. 71)

| Parámetro | Valor |
| --- | --- |
| Tecnología | WireGuard |
| Red del túnel | 10.8.0.0/24 en 2 segmentos |
| Administradores | 10.8.0.0/25 → alcance VLAN 50 (regla 8) |
| Docentes | 10.8.0.128/25 → HTTPS a 172.16.40.10 (regla 9) |
| Puerto | UDP 51820 |
| Autenticación | Claves públicas, una por dispositivo |
| Terminación | atlas-fw01 según Tabla 42, Figura 1 y §30.1; "sobre el servidor Linux" según §30.4 (→ DISC-03) |

## E.10 Servicios y puertos que menciona el PDF

| Servicio | Puerto | Servidor | Quién lo usa según el PDF |
| --- | --- | --- | --- |
| HTTPS (ATLAS) | TCP 443 | 172.16.40.10 | VLAN 10, 20, 30, VPN docente |
| HTTP | TCP 80 | 172.16.40.10 (publicado por atlas-web) | Solo en UFW (VLAN 20, 30); no en la Tabla 44 (→ DISC-06) |
| SMB (Samba) | TCP 445 (+139 en UFW) | 172.16.40.10 | VLAN 10, 20 (regla 3); 172.16.40.0/24 (UFW) |
| SSH | TCP 22 | 172.16.40.10 | VLAN 50 |
| RDP | TCP 3389 | 172.16.40.20 y clientes | VLAN 50 |
| DNS | TCP/UDP 53 | 172.16.40.20 | VLAN 10, 20, 30; DC → Internet |
| Kerberos | 88 | 172.16.40.20 | VLAN 10, 20, 30 |
| LDAP / LDAPS | 389 / 636 | 172.16.40.20 | VLAN 10, 20, 30 |
| SMB (DC: SYSVOL/NETLOGON) | TCP 445 | 172.16.40.20 | VLAN 10, 20, 30 (incluido en "dominio") |
| NTP | UDP 123 | 172.16.40.20 | VLAN 10, 20, 30; srv01 |
| RPC endpoint mapper + dinámicos | TCP 135 + rango a fijar | 172.16.40.20 | Unión al dominio (→ DISC-19) |
| DHCP | UDP 67/68 | 172.16.40.20 | Relay desde rt01 |
| MySQL | TCP 3306 | Solo local | Nadie desde la red (regla 10) |
| WireGuard | UDP 51820 | atlas-fw01 | Clientes VPN |
| Zabbix | TCP 10050/10051 | No definido | **No figura en ninguna regla** (→ AMB-13) |
| Syslog | UDP/TCP 514 | No definido | **No figura** (→ AMB-14) |

## E.11 Plan de pruebas de red (Tabla 48, págs. 73–74)

| # | Desde | Hacia | Prueba | Esperado |
| --- | --- | --- | --- | --- |
| P-01 | VLAN 30 | 172.16.40.10 | Acceso a la plataforma por navegador | Responde |
| P-02 | VLAN 30 | 172.16.40.10 | Conexión al puerto 22 | Rechazada y registrada |
| P-03 | VLAN 30 | 172.16.40.10 | Conexión al puerto 3306 | Rechazada y registrada |
| P-04 | VLAN 30 | VLAN 10 | Alcance a un equipo de Administración | Sin respuesta |
| P-05 | VLAN 30 | VLAN 50 | Alcance a la estación de administración | Sin respuesta |
| P-06 | VLAN 30 | 172.16.40.20 | Resolución de nombres del dominio | Responde |
| P-07 | VLAN 20 | 172.16.40.10 | Acceso al recurso compartido de Samba | Accede |
| P-08 | VLAN 10 | VLAN 20 | Alcance a un equipo de Docentes | Sin respuesta |
| P-09 | VLAN 40 | VLAN 30 | Conexión iniciada hacia un equipo de Estudiantes | Sin respuesta |
| P-10 | VLAN 50 | 172.16.40.10 | Administración remota por consola | Accede |
| P-11 | VLAN 50 | 172.16.40.20 | Administración remota por escritorio | Accede |
| P-12 | VLAN 10, 20, 30 | Internet | Navegación web | Responde |
| P-13 | VPN docente | 172.16.40.10 | Acceso a la plataforma | Responde |
| P-14 | VPN docente | VLAN 50 | Alcance a la estación de administración | Sin respuesta |
| P-15 | Todas | — | Obtención de dirección por DHCP | Recibe dirección del ámbito correcto |

Resultado: "se completa durante el Sprint 3"; capturas al Anexo E (p. 74).

Pruebas que se pueden ejecutar en cada entorno:

| Entorno | Pruebas posibles | Por qué |
| --- | --- | --- |
| Packet Tracer solo | Validación de VLAN, troncal, gateways, ACL con hosts genéricos de PT; P-04, P-05, P-08, P-09 aproximadas con ping; P-15 con un servidor DHCP de PT | PT no tiene los servidores reales, ni fw01, ni WireGuard |
| GNS3 + VirtualBox | P-01..P-15 completas | Red y VM integradas (lo que prevé la migración del Sprint 2) |

## E.12 Valores de red que el PDF no define (sin inventar; se piden en J)

| Falta | Por qué hace falta |
| --- | --- |
| IP de la SVI de gestión del switch (VLAN 50) | Administrar atlas-sw01 desde VLAN 50 (§30.1 p. 67) |
| IP de gestión del router (¿172.16.50.1?) | Administrar atlas-rt01 |
| IP fija de la estación de administración y su SO | Fa0/23, P-10, P-11 |
| Red de tránsito atlas-rt01 ↔ atlas-fw01 e interfaces | Enlace de la Figura 1 |
| Dirección WAN de atlas-fw01 y su gateway | NAT y VPN (UDP 51820) |
| Producto o SO de atlas-fw01 | Toda la configuración de firewall, NAT y VPN |
| Ruta por defecto del router y ruta a 10.8.0.0/24 | Salida a Internet y retorno de la VPN |
| Reenviadores DNS del DC | §29.4 y regla 7 |
| Rango RPC dinámico | Regla 2 (el PDF lo difiere al Sprint 2) |
| Destino de los logs de red (syslog) | "Registrada" en P-02, P-03 y las reglas 10–12 |
| Modelo de router y switch en PT e imágenes en GNS3 | Nombres de interfaz y comandos disponibles |
