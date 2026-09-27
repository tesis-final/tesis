# Plan de direccionamiento de ATLAS (Fase 8)

**Origen de cada valor.** *PDF* = está en el documento, con su tabla. *Derivado* = sale directamente de una regla del PDF. *Propuesto* = el PDF no lo fija; lo proponemos para poder configurar y **queda pendiente de confirmación del equipo (J.2)**. Cambiarlo es editar un solo valor en cada archivo de configuración.

## Redes

| VLAN | Nombre | Red | Gateway (rt01) | DHCP (atlas-dc01) | Origen |
| --- | --- | --- | --- | --- | --- |
| 10 | Administracion | 172.16.10.0/24 | 172.16.10.1 | .100 – .200 | PDF Tabla 38, Tabla 34 |
| 20 | Docentes | 172.16.20.0/24 | 172.16.20.1 | .100 – .200 | PDF Tabla 38, Tabla 34 |
| 30 | Estudiantes | 172.16.30.0/24 | 172.16.30.1 | .100 – .250 | PDF Tabla 38, Tabla 34 |
| 40 | Servidores | 172.16.40.0/24 | 172.16.40.1 | IP fijas | PDF Tabla 38, Tabla 34 |
| 50 | Gestion | 172.16.50.0/24 | 172.16.50.1 | IP fijas | PDF Tabla 38, Tabla 34 |
| 999 | Sin_uso_nativa | — (sin IP, sin enrutamiento) | — | — | PDF p. 66 |
| — | Tránsito rt01 ↔ fw01 | 172.16.255.0/30 | — | — | **Propuesto** (CT-17) |
| — | Túnel VPN | 10.8.0.0/24 (admin .0/25, docentes .128/25) | fw01 10.8.0.1 | — | PDF Tabla 45; CT-08 |
| — | Redes internas de Docker (solo dentro de srv01) | 192.168.250.0/24, 192.168.251.0/24 | — | — | CT-07, CT-16 |

## Equipos con IP fija

| Equipo | Interfaz | IP | Origen |
| --- | --- | --- | --- |
| atlas-srv01 | VLAN 40 (sw01 Fa0/21) | 172.16.40.10/24, gw .1, DNS 172.16.40.20 | PDF Tabla 40 |
| atlas-dc01 | VLAN 40 (sw01 Fa0/22) | 172.16.40.20/24, gw .1, DNS 127.0.0.1 | PDF Tabla 40 |
| atlas-rt01 Gi0/0.10 … .50 | Subinterfaces | 172.16.{10,20,30,40,50}.1/24 | PDF Tabla 38 |
| atlas-rt01 (gestión) | Gi0/0.50 | 172.16.50.1 | Derivado (p. 67: la gestión del router está en VLAN 50) |
| atlas-rt01 Gi0/1 | Tránsito | 172.16.255.1/30 | **Propuesto** |
| atlas-fw01 (interna) | Tránsito | 172.16.255.2/30 | **Propuesto** |
| atlas-fw01 (WAN) | Hacia Internet | Según el laboratorio (p. ej., DHCP del adaptador NAT de VirtualBox) | **Pendiente J.2** (Fase 9) |
| atlas-sw01 (gestión) | Vlan50 | 172.16.50.2/24, gw 172.16.50.1 | **Propuesto** |
| Estación de administración | VLAN 50 (sw01 Fa0/23) | 172.16.50.10/24, gw .1 | **Propuesto** |

¿Por qué la red de tránsito dentro de 172.16.0.0/16? Así "red interna" sigue siendo exactamente 172.16.0.0/16 en todas las reglas (Tabla 44: "hacia fuera de 172.16.0.0/16"), no choca con ninguna VLAN (usa el tercer octeto 255, que no es una VLAN) ni con la VPN ni con Docker.

## Puertos del switch (Tabla 41)

| Puerto | Modo | VLAN | Conecta |
| --- | --- | --- | --- |
| Fa0/1 – Fa0/4 | Acceso | 10 | Equipos de Administración |
| Fa0/5 – Fa0/10 | Acceso | 20 | Equipos de Docentes |
| Fa0/11 – Fa0/20 | Acceso | 30 | Equipos de Estudiantes |
| Fa0/21 | Acceso | 40 | atlas-srv01 |
| Fa0/22 | Acceso | 40 | atlas-dc01 |
| Fa0/23 | Acceso | 50 | Estación de administración |
| Fa0/24 | Deshabilitado | 999 | Sin uso |
| Gi0/1 | Troncal 802.1Q (nativa 999) | 10, 20, 30, 40, 50 | atlas-rt01 Gi0/0 |
| Gi0/2 | Deshabilitado | 999 | Reserva |
