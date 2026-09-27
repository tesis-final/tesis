# Fase 8 — Redes: VLAN, troncal, enrutamiento y reenvío DHCP

| Campo | Valor |
| --- | --- |
| Fecha | 27/09/2026 |
| Estado | **CONFIGURADO y validado**: revisor automático contra el PDF + gemelo de red funcionando en Linux. Falta EJECUTAR en Packet Tracer y en el laboratorio |
| PDF | §30.1 (págs. 63–67): Tabla 38–42, Figura 1; §29.4 (reenvío DHCP) |
| Decisiones | DEC-22, DEC-R8, CT-17 (red de tránsito propuesta) |
| Configuraciones | [`infra/red/`](../../infra/red/) |
| Evidencias | E-RED-001 (revisión de configuraciones), E-RED-002 (gemelo de red) en `docs/evidencias/E/` |

> **Alcance de esta fase.** Acá se arma la red para que *todo se pueda comunicar*: VLAN, troncal, enrutamiento entre VLAN, reenvío DHCP y gestión segura de los equipos de red. **El filtrado entre VLAN (Tabla 43/44) es la Fase 9.** Mientras la Fase 9 no esté aplicada, el router deja pasar todo entre VLAN: es un estado de construcción, no de operación.

## 1. Qué hace esta fase, en una frase

Deja la red de la Figura 1 funcionando: el switch separa los equipos en las VLAN de la Tabla 41, el router los comunica con los gateways de la Tabla 38 y reenvía los pedidos de DHCP al servidor Windows, y a los equipos de red solo se entra por SSH desde la VLAN de Gestión.

## 2. Archivos

| Archivo | Qué es |
| --- | --- |
| `packet-tracer/atlas-sw01.txt` | Configuración completa del switch (Catalyst 2960-24TT) |
| `packet-tracer/atlas-rt01-base.txt` | Configuración base del router (ISR 2911): subinterfaces, reenvío DHCP, rutas, SSH |
| `packet-tracer/atlas-fw01-maqueta.txt` | Router que **representa** a atlas-fw01 en Packet Tracer (solo rutas + "Internet simulada") |
| `plan-direccionamiento.md` | Todas las direcciones, con su origen (PDF, derivado o propuesto) |
| `gns3/correspondencia-puertos.md` y `gns3/atlas-sw01-iosvl2.txt` | Lo mismo para GNS3 (DEC-22) |
| `pruebas/revisar_configuraciones.py` | Compara las configuraciones con el PDF antes de pegarlas |
| `pruebas/gemelo-red.sh` | La topología recreada en Linux para probar el diseño funcionando |

### Valores que el PDF no fija (pendientes de J.2)

| Dato | Valor propuesto | Por qué este |
| --- | --- | --- |
| IP de gestión de atlas-sw01 | 172.16.50.2/24 | Primera libre en VLAN 50 después del gateway |
| IP de la estación de administración | 172.16.50.10/24 | Fija en VLAN 50 (Tabla 41, Fa0/23) |
| Red de tránsito rt01 ↔ fw01 | 172.16.255.0/30 (rt01 .1, fw01 .2) | Queda dentro de 172.16.0.0/16 (así "interno" sigue siendo 172.16.0.0/16 en todas las reglas) sin chocar con ninguna VLAN |
| IP WAN de atlas-fw01 | Según el laboratorio | Se define en la Fase 9 |
| Modelos de Packet Tracer | Catalyst 2960-24TT y ISR 2911 | El 2960-24TT tiene exactamente los puertos de la Tabla 41; el 2911 soporta subinterfaces y firewall por zonas |

La IP de gestión del router, 172.16.50.1, **no** es una propuesta: sale del PDF (p. 67: la gestión del router está en VLAN 50, y su IP en esa VLAN es el gateway de la Tabla 38).

## 3. Manual: armar la red en Packet Tracer

### 3.1 Equipos

| Equipo en PT | Modelo | Nombre |
| --- | --- | --- |
| Switch | 2960-24TT | atlas-sw01 |
| Router | 2911 | atlas-rt01 |
| Router | 1941 | atlas-fw01-maqueta |
| Servidor | Server-PT | atlas-srv01 |
| Servidor | Server-PT | atlas-dc01 |
| Servidor | Server-PT | internet-sim |
| PC | PC-PT | PC-ADM1, PC-DOC1, PC-EST1, PC-EST2, PC-GESTION |

### 3.2 Cableado (cable de cobre directo; PT ajusta el cruzado solo)

| Desde | Puerto | Hasta | Puerto |
| --- | --- | --- | --- |
| PC-ADM1 | Fa0 | atlas-sw01 | Fa0/1 |
| PC-DOC1 | Fa0 | atlas-sw01 | Fa0/5 |
| PC-EST1 | Fa0 | atlas-sw01 | Fa0/11 |
| PC-EST2 | Fa0 | atlas-sw01 | Fa0/12 |
| atlas-srv01 | Fa0 | atlas-sw01 | Fa0/21 |
| atlas-dc01 | Fa0 | atlas-sw01 | Fa0/22 |
| PC-GESTION | Fa0 | atlas-sw01 | Fa0/23 |
| atlas-sw01 | Gi0/1 | atlas-rt01 | Gi0/0 |
| atlas-rt01 | Gi0/1 | atlas-fw01-maqueta | Gi0/0 |
| atlas-fw01-maqueta | Gi0/1 | internet-sim | Fa0 |

Fa0/24 y Gi0/2 del switch quedan **sin cable** (y apagados por configuración).

### 3.3 Configurar el switch y los routers

1. Abrir `atlas-sw01.txt` en un editor y reemplazar `<ENABLE_SECRET>` y `<CLAVE_ADMIN_RED>` por las contraseñas del equipo (10 caracteres o más). **No** guardar el archivo con las contraseñas en el repositorio.
2. En Packet Tracer: atlas-sw01 → pestaña *CLI* → `enable` → `configure terminal` → pegar todo.
3. Si la línea `crypto key generate rsa general-keys modulus 2048` da error, escribir `crypto key generate rsa` y responder `2048`.
4. `end` y `copy running-config startup-config`.
5. Repetir con `atlas-rt01-base.txt` en atlas-rt01 y con `atlas-fw01-maqueta.txt` en la maqueta.

Antes de pegar, conviene correr el revisor, que avisa si algo no coincide con el PDF:

```bash
python3 infra/red/pruebas/revisar_configuraciones.py
```

### 3.4 Configurar los equipos finales (pestaña *Desktop* / *Services*)

| Equipo | Configuración |
| --- | --- |
| atlas-srv01 | IP fija 172.16.40.10 / 255.255.255.0, gateway 172.16.40.1, DNS 172.16.40.20. *Services → HTTP/HTTPS*: encendidos (página "ATLAS (maqueta)") |
| atlas-dc01 | IP fija 172.16.40.20 / 255.255.255.0, gateway 172.16.40.1, DNS 172.16.40.20. *Services → DNS*: encendido, registro A `atlas-srv01.atlas.local` → 172.16.40.10. *Services → DHCP*: encendido, con los tres pools de abajo |
| internet-sim | IP 203.0.113.10 / 255.255.255.0, gateway 203.0.113.1. HTTP/HTTPS encendidos |
| PC-GESTION | IP fija 172.16.50.10 / 255.255.255.0, gateway 172.16.50.1, DNS 172.16.40.20 |
| PC-ADM1, PC-DOC1, PC-EST1, PC-EST2 | *IP Configuration → DHCP* |

Pools de DHCP en atlas-dc01 (Tabla 34):

| Pool | Default Gateway | DNS Server | Start IP | Subnet Mask | Max Users |
| --- | --- | --- | --- | --- | --- |
| VLAN10 | 172.16.10.1 | 172.16.40.20 | 172.16.10.100 | 255.255.255.0 | 101 |
| VLAN20 | 172.16.20.1 | 172.16.40.20 | 172.16.20.100 | 255.255.255.0 | 101 |
| VLAN30 | 172.16.30.1 | 172.16.40.20 | 172.16.30.100 | 255.255.255.0 | 151 |

`Max Users` es la cantidad de direcciones: de .100 a .200 son 101; de .100 a .250 son 151. Packet Tracer no permite borrar el pool `serverPool`: se deja, porque en la VLAN 40 no hay equipos pidiendo IP. Packet Tracer tampoco entrega la opción 015 (sufijo DNS); en el Windows real sí (Fase 7).

## 4. Verificación en Packet Tracer (lo que el equipo tiene que capturar)

Cada fila es una prueba. La columna "Salida esperada" dice qué hay que ver; la captura de pantalla de lo que realmente salió va a `docs/evidencias/E/` con el nombre indicado.

| # | Dónde | Comando | Salida esperada | Captura |
| --- | --- | --- | --- | --- |
| R-01 | atlas-sw01 | `show vlan brief` | VLAN 10: Fa0/1–4 · 20: Fa0/5–10 · 30: Fa0/11–20 · 40: Fa0/21–22 · 50: Fa0/23 · 999: Fa0/24, Gi0/2 | E-RED-003a |
| R-02 | atlas-sw01 | `show interfaces trunk` | Gi0/1, modo *on*, 802.1q, **Native vlan 999**, permitidas 10,20,30,40,50 | E-RED-003b |
| R-03 | atlas-sw01 | `show interfaces status` | Fa0/24 y Gi0/2 en *disabled* | E-RED-003c |
| R-04 | atlas-rt01 | `show ip interface brief` | Gi0/0.10 … .50 *up/up* con 172.16.X.1; Gi0/1 172.16.255.1; Gi0/2 *administratively down* | E-RED-003d |
| R-05 | atlas-rt01 | `show ip route` | 5 redes C de las VLAN + 172.16.255.0/30; `S* 0.0.0.0/0 [1/0] via 172.16.255.2`; `S 10.8.0.0/24 via 172.16.255.2` | E-RED-003e |
| R-06 | PC-EST1 | `ipconfig /all` (tras pedir DHCP) | IP entre 172.16.30.100 y .250, máscara 255.255.255.0, gateway 172.16.30.1, DNS 172.16.40.20 | E-RED-003f |
| R-07 | PC-ADM1 y PC-DOC1 | `ipconfig` | .10.100–.200 con gateway .10.1 · .20.100–.200 con gateway .20.1 | E-RED-003g |
| R-08 | PC-EST1 | `ping 172.16.40.10` | Responde (en la Fase 8 todavía no hay filtrado) | E-RED-003h |
| R-09 | PC-EST1 | `tracert 203.0.113.10` | 1: 172.16.30.1 · 2: 172.16.255.2 · 3: 203.0.113.10 | E-RED-003i |
| R-10 | PC-EST1 | `nslookup atlas-srv01.atlas.local` | 172.16.40.10 (responde 172.16.40.20) | E-RED-003j |
| R-11 | PC-GESTION | `ssh -l admin-red 172.16.50.2` y `172.16.50.1` | Entra al switch y al router | E-RED-003k |
| R-12 | PC-EST1 | `ssh -l admin-red 172.16.50.1` | **Rechazado** (el router solo acepta SSH desde 172.16.50.0/24); en el router, `show access-lists` muestra coincidencias en `deny any log` | E-RED-003l |
| R-13 | PC nuevo en Fa0/24 | Pedir DHCP | **No** obtiene IP (puerto apagado, VLAN 999) | E-RED-003m |
| R-14 | atlas-sw01 | `show running-config` | Coincide con `atlas-sw01.txt` | E-RED-003n |

Estado actual de R-01 a R-14: **NO EJECUTADA — requiere Packet Tracer** (lo hace el equipo; J.3: quién toma las capturas).

## 5. Lo que ya se validó sin Packet Tracer

### 5.1 Revisor de configuraciones (E-RED-001): 81 PASS · 0 FAIL

Comprueba, línea por línea, que las configuraciones dicen lo mismo que el PDF: las 6 VLAN con sus nombres, los 25 puertos del switch con su modo, VLAN y estado, el troncal (nativa 999, permitidas 10–50, sin DTP), las 5 subinterfaces con su IP, el `ip helper-address` **solo** en .10/.20/.30, la VLAN nativa sin IP, las rutas, que la gestión sea solo por SSH desde VLAN 50 y que no haya ninguna contraseña escrita.

Para comprobar que el revisor no da "PASS" por las dudas, se le sembraron cuatro errores en una copia (puertos de docentes en la VLAN equivocada, VLAN nativa 1, un helper que falta, una contraseña en claro): los detectó todos.

### 5.2 Gemelo de red (E-RED-002): 27 PASS · 0 FAIL

La topología completa de la Figura 1 recreada en Linux, con equipos que realmente piden IP, hacen ping y resuelven nombres:

| Prueba | Resultado |
| --- | --- |
| Los PC de VLAN 10, 20 y 30 reciben IP del ámbito correcto de la Tabla 34, con su gateway, DNS y sufijo | PASS (4 equipos) |
| El DC recibe los pedidos con el campo giaddr de cada VLAN (captura de paquetes en el DC) | PASS (10.1, 20.1, 30.1) |
| `atlas-srv01.atlas.local` resuelve a 172.16.40.10 | PASS |
| Enrutamiento entre VLAN y salida por la ruta por defecto (saltos 172.16.30.1 → 172.16.255.2) | PASS |
| Un equipo de VLAN 30 que se pone una IP de VLAN 20 no llega a nadie de la VLAN 20 | PASS |
| Fa0/24 sin enlace; y aunque alguien lo encienda, en VLAN 999 no hay DHCP ni gateway | PASS |
| La estación de gestión llega al switch (172.16.50.2) y al router (172.16.50.1) | PASS |

**Límite honesto del gemelo:** el kernel de este entorno no tiene soporte para etiquetas 802.1Q, así que cada VLAN se representa como un dominio de difusión separado (que es lo que una VLAN es) y el troncal como un enlace por VLAN. El etiquetado real del troncal y la sintaxis de IOS se comprueban en Packet Tracer (R-02, R-14).

Un dato que salió de la captura: los pedidos reenviados llegan al DC **desde 172.16.40.1** (la IP del router en la VLAN del servidor), aunque el giaddr diga 172.16.30.1. Por eso el firewall del DC acepta DHCP desde las cuatro IP del router, incluida la .40.1 (Fase 7).

## 6. Trazabilidad

| Requisito | Implementación | Prueba | Evidencia | Estado |
| --- | --- | --- | --- | --- |
| Tabla 38: 5 VLAN, /24, gateway .1 | sw01 (VLAN) + rt01 (subinterfaces) | Revisor (11 ítems) · gemelo (DHCP y ping) · R-01, R-04 | E-RED-001, E-RED-002 | PASS (revisión y gemelo); PT pendiente |
| Tabla 41: puertos del switch | `atlas-sw01.txt` | Revisor (25 puertos) · R-01, R-03 | E-RED-001 | PASS (revisión); PT pendiente |
| p. 66: VLAN 999 nativa y en puertos sin uso | sw01 Gi0/1, Fa0/24, Gi0/2; rt01 Gi0/0.999 | Revisor · gemelo (aislamiento de VLAN 999) · R-02, R-13 | E-RED-001, E-RED-002 | PASS; PT pendiente |
| p. 66: troncal 802.1Q con 10–50 | sw01 Gi0/1 | Revisor · R-02 | E-RED-001 | PASS (revisión); PT pendiente |
| Tabla 42: enrutamiento entre VLAN | rt01 subinterfaces | Gemelo · R-05, R-08 | E-RED-002 | PASS (gemelo); PT pendiente |
| §29.4 / regla 4: reenvío DHCP con giaddr | `ip helper-address 172.16.40.20` en .10/.20/.30 | Revisor · gemelo (captura del giaddr) · R-06, R-07 | E-RED-001, E-RED-002 | PASS; PT pendiente |
| Tabla 34: ámbitos | DC (Fase 7); pools en PT | Gemelo (4 clientes) · R-06, R-07 | E-RED-002 | PASS (gemelo); PT pendiente |
| p. 67: gestión solo desde VLAN 50 | SVI 50 + VTY con ACL + SSH v2 | Revisor · gemelo · R-11, R-12 | E-RED-001, E-RED-002 | PASS; PT pendiente |
| Figura 1: ruta hacia fw01 | Ruta por defecto + 10.8.0.0/24 | Revisor · gemelo (saltos) · R-05, R-09 | E-RED-001, E-RED-002 | PASS; PT pendiente |
| DEC-22: GNS3 | `gns3/` | — | — | CONFIGURADO |

## 7. Problemas comunes

| Síntoma | Causa probable | Qué hacer |
| --- | --- | --- |
| Un PC queda con 169.254.x.x | No llega al DHCP: falta el helper en la subinterfaz, el pool está mal, o el DHCP del servidor está apagado | `show run interface Gi0/0.30` en el router; revisar *Services → DHCP* en atlas-dc01 |
| El PC recibe IP de otra VLAN | Está en un puerto de otra VLAN | `show vlan brief`; mover el cable al puerto que dice la Tabla 41 |
| `show interfaces trunk` no muestra Gi0/1 | El puerto no está en modo troncal o está apagado | `show run interface Gi0/1`; `no shutdown` |
| Mensaje "%CDP-4-NATIVE_VLAN_MISMATCH" | El router no tiene la subinterfaz nativa 999 | Verificar `encapsulation dot1Q 999 native` en Gi0/0.999 |
| Una subinterfaz aparece *down* | La interfaz física Gi0/0 está apagada | `interface Gi0/0` → `no shutdown` |
| `ping` entre VLAN no funciona | El PC no tiene gateway, o la subinterfaz tiene otra IP | `ipconfig` en el PC; `show ip interface brief` en el router |
| `tracert` se corta después de 172.16.255.2 | La maqueta no tiene la ruta de vuelta a 172.16.0.0/16 | `show ip route` en la maqueta |
| SSH rechazado desde PC-GESTION | Faltan las claves RSA o el usuario local | `show ip ssh` (debe decir *version 2.0 enabled*); `crypto key generate rsa` |
| SSH aceptado desde otra VLAN | Falta `access-class` en las VTY | `show run | section line vty` |
| No se puede pegar la configuración | Algún comando no existe en esa versión de PT | Pegar por bloques y leer el mensaje; avisar para ajustar el archivo |

## 8. Hallazgos de esta fase

| ID | Hallazgo | Qué se hizo |
| --- | --- | --- |
| H8-01 | El PDF no fija la IP de gestión del switch, la de la estación ni la red de tránsito hacia fw01 | Valores propuestos, marcados como tales en `plan-direccionamiento.md` y en cada archivo (CT-17). Pendiente J.2 |
| H8-02 | El reenvío DHCP llega al servidor desde la IP del router en la VLAN 40 (172.16.40.1), no desde la VLAN del cliente | Confirmado con captura en el gemelo; el firewall del DC ya acepta las cuatro IP del router |
| H8-03 | Packet Tracer no entrega la opción 015 (sufijo DNS) ni permite borrar `serverPool` | Documentado; en el Windows real sí se entrega (Fase 7) |
| H8-04 | El kernel del entorno de trabajo no tiene 802.1Q | El gemelo modela cada VLAN como dominio separado; el troncal se valida en PT |
| H8-05 | Packet Tracer no puede ejecutar la VM de fw01 | Maqueta con ruta de vuelta e "Internet simulada" (RFC 5737); la VM real llega en la Fase 9 |

## 9. Para la defensa oral

- **¿Qué es una VLAN?** Un switch dividido en varios switches lógicos. Los equipos de VLAN distintas no se ven entre sí aunque estén en el mismo aparato; para hablar, tienen que pasar por el router, y ahí se decide qué se permite (Fase 9).
- **¿Qué es un troncal?** El único cable entre el switch y el router lleva las cinco VLAN a la vez. Cada trama viaja con una etiqueta 802.1Q que dice a qué VLAN pertenece.
- **¿Por qué la VLAN nativa es la 999 y no la 1?** Las tramas de la VLAN nativa viajan *sin* etiqueta. Si fuera la VLAN 1 (la de fábrica), alguien podría fabricar tramas con doble etiqueta para saltar a otra VLAN. La 999 no tiene equipos, ni IP, ni enrutamiento: no hay a dónde saltar (p. 66).
- **¿Por qué se apagan los puertos libres?** Para que enchufar un cable a un puerto libre no dé acceso a la red. Además quedan en la VLAN 999 por si alguien los enciende (p. 66). El gemelo lo prueba: aun encendido, en ese puerto no hay DHCP ni gateway.
- **¿Qué es "router on a stick"?** Un router con un solo cable físico hacia el switch y una subinterfaz por VLAN (Gi0/0.10, .20, …). Cada subinterfaz es el gateway de su VLAN.
- **¿Cómo le llega el DHCP a un equipo de otra VLAN?** El `ip helper-address` convierte la difusión en un mensaje dirigido al DC y le agrega el giaddr (de qué red vino). Lo vimos en la captura: `Gateway-IP 172.16.30.1`.
- **¿Por qué solo SSH y solo desde VLAN 50?** Telnet manda la contraseña en texto plano. Y la VLAN de Gestión es la única desde la que se administra la infraestructura (Tabla 43): a la línea VTY se le pone una lista de acceso que rechaza todo lo demás y lo registra.
