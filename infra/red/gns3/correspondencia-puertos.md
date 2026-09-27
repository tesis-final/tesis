# GNS3: correspondencia de puertos (DEC-22, DISC-22)

En el Sprint 2 la red pasa de Packet Tracer a GNS3 (PDF p. 67) para conectarla con las VM reales. Las imágenes de Cisco para GNS3 no tienen los mismos puertos que el Catalyst 2960 de Packet Tracer: IOSvL2 trae 16 puertos Gigabit (Gi0/0 – Gi3/3). Por eso se usa esta tabla, **solo para los puertos que se conectan**. La lógica de la Tabla 41 no cambia: mismo modo, misma VLAN, los que sobran apagados en la VLAN 999.

## atlas-sw01 (IOSvL2)

| Tabla 41 (Packet Tracer) | GNS3 (IOSvL2) | Modo / VLAN | Conecta |
| --- | --- | --- | --- |
| Gi0/1 | **Gi0/0** | Troncal 802.1Q, nativa 999, permite 10,20,30,40,50 | atlas-rt01 Gi0/0 |
| Fa0/1 (Fa0/1–4) | **Gi0/1** | Acceso 10 | PC de Administración |
| Fa0/5 (Fa0/5–10) | **Gi0/2** | Acceso 20 | PC de Docentes |
| Fa0/11 (Fa0/11–20) | **Gi0/3** | Acceso 30 | PC de Estudiantes |
| Fa0/21 | **Gi1/0** | Acceso 40 | atlas-srv01 (VM de VirtualBox) |
| Fa0/22 | **Gi1/1** | Acceso 40 | atlas-dc01 (VM de VirtualBox) |
| Fa0/23 | **Gi1/2** | Acceso 50 | Estación de administración |
| Fa0/24, Gi0/2 y el resto | **Gi1/3, Gi2/0–2/3, Gi3/0–3/3** | Acceso 999, **apagados** | Sin uso |

Configuración lista: [`atlas-sw01-iosvl2.txt`](atlas-sw01-iosvl2.txt). Diferencias con la de Packet Tracer: los nombres de puerto, `switchport trunk encapsulation dot1q` (IOSvL2 lo pide antes de `mode trunk`) y `spanning-tree portfast edge` (sintaxis de IOS 15.2).

## atlas-rt01 (IOSv)

IOSv tiene Gi0/0 – Gi0/3, igual que el ISR 2911 de Packet Tracer en los puertos que usamos, así que **`atlas-rt01-base.txt` sirve sin cambios**. IOSv además soporta el firewall por zonas completo (Fase 9).

| Puerto | Conecta |
| --- | --- |
| Gi0/0 | Troncal hacia atlas-sw01 Gi0/0 |
| Gi0/1 | atlas-fw01 (VM Ubuntu de VirtualBox, interfaz interna) |
| Gi0/2, Gi0/3 | Sin uso (apagados) |

## Cómo se conectan las VM en GNS3

1. En GNS3: *Edit → Preferences → VirtualBox VMs → New* y elegir atlas-srv01, atlas-dc01 y atlas-fw01. Marcar "Allow GNS3 to use any configured VirtualBox adapter".
2. Arrastrar las VM al proyecto y cablearlas según las tablas de arriba.
3. atlas-fw01 lleva **dos** adaptadores: uno hacia atlas-rt01 Gi0/1 y otro hacia un nodo *NAT* o *Cloud* de GNS3 (la salida a Internet del laboratorio).
4. Imágenes necesarias (pendiente J.3): IOSvL2 e IOSv (Cisco VIRL/CML) y la GNS3 VM.
