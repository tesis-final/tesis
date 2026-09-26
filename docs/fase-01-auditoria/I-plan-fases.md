# I. Plan de implementación por fases

Se respetan las 17 fases que pediste. Cada fase tiene:

- **criterio de salida**: no se avanza con errores críticos abiertos;
- **quién ejecuta**: "Claude" = lo produzco y lo pruebo en este entorno; "Equipo" = requiere tu laboratorio;
- **qué bloquea**: decisiones de J.1 que tienen que estar resueltas antes.

## I.1 Qué puedo verificar yo y qué no

| Puedo hacer y verificar en este entorno | No puedo ejecutar (requiere tu laboratorio) |
| --- | --- |
| Código PHP (hay PHP 8.4 CLI) y Python 3.11 con tests unitarios; análisis estático; linters | Packet Tracer, GNS3, VirtualBox |
| Script SQL: puedo validarlo si levanto MySQL (el cliente Docker está, el daemon no está corriendo; lo intentaré) | Windows Server, AD, GPO, DHCP real |
| Archivos de configuración completos (Cisco, nftables, WireGuard, UFW, sshd, Samba, SSSD, netplan, compose) con validación de sintaxis donde haya herramienta | Pruebas P-01..P-15 y capturas reales |
| Scripts de respaldo, verificación y validación automática | Tiempos reales de restauración (RTO) y disponibilidad (Zabbix) |
| Manuales y reportes | Prueba de uso con docentes (RNF-11) |

**Regla**: todo lo que figure como probado tendrá su salida real adjunta. Lo que no pueda ejecutar se marca **NO EJECUTADA — requiere laboratorio**.

## I.2 Ajuste de orden propuesto

- **Fase 5 (Base de datos) antes, o junto con, la Fase 4 (Aplicación)**: repositorios, servicios y controladores dependen del esquema (DEP-21). El propio PDF pone "base de datos funcionando" en el Sprint 2, junto con el ciclo de aprobación (Tabla 10). Propongo **4 y 5 como un bloque**, empezando por el esquema.
- En el orden de red (tu punto 36), dos ajustes:
  - DHCP relay (paso 10) se configura antes, pero **se prueba** después de DHCP (paso 14).
  - La instalación de paquetes en Linux (paso 15) necesita salida a Internet antes de que existan fw01 y NAT (pasos 20–21). Se resuelve con un adaptador NAT temporal de VirtualBox, documentado y retirado después (R-27).
  - El resto de tu orden coincide con las dependencias (F).

## I.3 Fases

| Fase | Objetivo | Entradas (PDF) | Entregables | Quién | Criterio de salida | Bloqueada por |
| --- | --- | --- | --- | --- | --- | --- |
| 1. Auditoría | Leer y auditar el PDF | Todo | Esta carpeta (A–J) | Claude | Tu revisión | — |
| 2. Arquitectura final + discrepancias | Resolver DISC/AMB/PR y fijar la arquitectura definitiva | G, J.1 | `docs/fase-02/`: registro de decisiones (una por DISC/AMB), arquitectura final, modelo de datos final (28 tablas propuestas), matriz de puertos final, borrador de las 8 reglas si hace falta, estructura del repositorio | Claude + tus decisiones | Todas las decisiones críticas aprobadas y registradas | J.1 |
| 3. Plan maestro | WBS, orden, alcance del Hito 2 y del Hito 3, plan de evidencias | Tablas 9–10, H30 | `docs/fase-03/`: plan por Sprint con fechas, IDs de evidencias (E-APP, E-BD, E-LNX, E-WIN, E-RED…), plantillas de prueba (ID, objetivo, origen, destino, comando, esperado, obtenido, evidencia, estado) | Claude | Alcance del Hito 2 aprobado | Fase 2 |
| 5 + 4. BD + Aplicación | Esquema, migraciones, seeds, privilegios; app PHP por capas; servicio Python; frontend responsivo | §25–§27, RF-01..20, Anexo H | `atlas/` y `atlas-analysis/` completos, `docker-compose.yml`, tests; DER y diccionario (Anexo G) | Claude (código y tests) / Equipo (revisión) | Tests en verde con salida adjunta; linters sin errores; cada RF trazado a código y test | DISC-01, 02, 12–17; AMB-01..10 |
| 6. Linux/POSIX | atlas-srv01 completo | §28 | Scripts de aprovisionamiento idempotentes (usuarios, grupos, directorios, ACL, atributos, sshd, TCP Wrappers, UFW + DOCKER-USER, rsyslog, SSSD, Samba), script de verificación de la Tabla 27, manual paso a paso | Claude (scripts) / Equipo (ejecución y capturas) | Script de verificación en PASS en la VM real | DISC-06, 07, 08, 24 |
| 7. Windows Server | atlas-dc01 completo | §29 | Scripts PowerShell (AD DS, OU, grupos, GPO, políticas, DNS, DHCP, auditoría, firewall de host, carpeta de respaldos), manual paso a paso | Claude (scripts) / Equipo (ejecución y capturas) | `Get-AD*`, `gpresult` y leases verificados | DISC-09, 19, 20; AMB-17..19 |
| 8. Redes | Switch, router, VLAN, troncal, gestión, relay; primero PT y después GNS3 | §30.1–30.2 | Configuraciones Cisco completas (sw01, rt01), archivo .pkt, guía de GNS3 con la tabla de correspondencia, manual de implementación de redes desde cero | Claude (configs y manual) / Equipo (laboratorio) | `show` esperados + P-04, P-05, P-08, P-09, P-15 | DISC-04, 22; AMB-11, 12, 29 |
| 9. Firewall/NAT | fw01 + ACL/ZBF del router según la Tabla 44 | §30.3 | Configuración de fw01 (nftables), ACL/ZBF de rt01, orden de reglas, logs | Claude / Equipo | P-01..P-12 según la matriz | DISC-04, 05, 21 |
| 10. VPN | WireGuard con dos perfiles | §30.4 | Configuración del servidor en fw01, plantillas de cliente sin claves, script de alta de pares, reglas 8 y 9 | Claude / Equipo | P-13, P-14 + prueba de administrador | DISC-03 |
| 11. Monitoreo | Zabbix + logs | §30.5 | Compose de Zabbix, agentes, plantillas, triggers al 80 %, web scenario de 3 s, rsyslog | Claude / Equipo | Alerta forzada capturada; disponibilidad medida | AMB-13, 14 |
| 12. Backups | Esquema completo + restauración | §27.7, §28.5 | Scripts (completo, incremental, configuraciones, verificación, restauración), timers, montaje CIFS, acta de restauración | Claude / Equipo | Restauración real cronometrada < 4 h | DISC-10, 11; AMB-20..22 |
| 13. Integración | Todo como un único sistema | Todo | Despliegue de la app en srv01 real, integración con AD, DNS y certificado | Equipo con mi guía | Flujo de punta a punta en el laboratorio | Fases 4–12 |
| 14. Pruebas | Funcionales, de seguridad y de red | Tabla 5, Anexo H, Tabla 48, tu punto 32 | Planillas con resultado **obtenido real**, PASS/FAIL/NO EJECUTADA | Claude (automatizables) / Equipo (laboratorio) | Todas ejecutadas o justificadas | Fase 13 |
| 15. Evidencias | Anexos B, C, D, E, G | Tabla 52 | `docs/evidencias/` con índice exhaustivo (E-RED-001…) | Equipo (capturas) / Claude (índice y control) | Cada requisito con su evidencia | Fase 14 |
| 16. Auditoría final | Checklist de cumplimiento y matriz final de red | B | Checklist final (Implementado / Probado / Evidencia / Resultado) y matriz final de red | Claude | Sin requisitos sin evidencia (o justificados) | Fase 15 |
| 17. Reporte final | Reporte técnico completo, manual y reporte de redes y seguridad, manual de operación, guía de defensa oral | Todo | Documentos finales | Claude | Tu revisión | Fase 16 |

## I.4 Alineación con el calendario del PDF (propuesta; se fija en la Fase 3)

| Período | Sprint (Tabla 10) | Fases |
| --- | --- | --- |
| 26/09 – 09/10 | Sprint 2 (en curso) | 2, 3; inicio de 5 + 4 (esquema, autenticación, roles, actividades, ciclo); scripts de las Fases 6 y 7; el equipo instala las VM |
| 13/10 – 23/10 → **Hito 2 (23/10)** | Sprint 3 | 5 + 4 (resolución, registro, resultados); 6, 7 y 8 ejecutadas en el laboratorio; primeras pruebas P-xx |
| 27/10 – 13/11 | Sprint 4 | Motor de reglas y panel (4); ML (4); 9, 10, 11, 12 |
| 17/11 – 20/11 → **Hito 3 (20/11)** | Sprint 5 | Asistente (4); 13, 14, 15, 16, 17 |

## I.5 Lo que haré cuando apruebes esta fase

Arranco la **Fase 2**:

1. Registro de decisiones con tus respuestas a J.1.
2. Arquitectura final.
3. Modelo de datos final.
4. Matriz de puertos definitiva.
5. Estructura del repositorio.

No escribo código de aplicación ni configuraciones hasta cerrar la Fase 2.
