# Hito 2 de Testing — Implementación y ejecución de pruebas

| Campo | Valor |
| --- | --- |
| Fecha | 30/10/2026 |
| Qué pide el hito | Desarrollo de scripts y automatización de pruebas · Ejecución de pruebas y reporte de incidencias · Ajustes y mejoras derivadas de los resultados |
| Entregable | Resultados de pruebas, reportes y scripts implementados |
| Contra qué se prueba | PDF V2.2: Tabla 5 (verificación de los objetivos), Tabla H29 (criterios de los requisitos no funcionales), §30.5 (plan de pruebas de red) |
| Dónde se ejecutó | Entorno de pruebas (contenedores Docker con MySQL 8.0 real). Lo del laboratorio Proxmox sale del informe del Hito 2 de Redes (22 y 23/10) |

**Cómo se informa cada resultado.** *Aprobada*: se ejecutó y dio lo esperado. *Fallada*: se ejecutó y dio otra cosa. *No ejecutada*: no se pudo correr, con el motivo. Una prueba que pasó en el entorno de pruebas no se presenta como si hubiera pasado en el laboratorio.

## 1. Resumen

El 30/10 se ejecutaron todas las pruebas automáticas que no necesitan el laboratorio: 11 conjuntos, todos aprobados. Además, el informe de Redes dejó 9 fallas del producto encontradas en el laboratorio; las 9 están corregidas en esta rama, 6 con una prueba que lo confirma y 3 que solo se pueden confirmar en las VM.

| Conjunto | Resultado del 30/10 | Evidencia |
| --- | --- | --- |
| Unitarias (PHP) | 37 de 37 | [E-TST-002/unit](../evidencias/H/E-TST-002-ejecucion-2026-10-30/unit.txt) |
| Estándar PSR-12 | Sin errores ni advertencias | [psr12](../evidencias/H/E-TST-002-ejecucion-2026-10-30/psr12.txt) |
| Base de datos (MySQL 8.0 real) | 58 de 58 | [bd](../evidencias/H/E-TST-002-ejecucion-2026-10-30/bd.txt) |
| API (Laravel + MySQL real) | 71 de 71 | [api](../evidencias/H/E-TST-002-ejecucion-2026-10-30/api.txt) |
| Servicio de análisis (Python) | 23 de 23 | [analisis](../evidencias/H/E-TST-002-ejecucion-2026-10-30/analisis.txt) |
| Interfaz en Chromium | 29 de 29 (2 nuevas) | [E-TST-005](../evidencias/H/E-TST-005-interfaz.txt) |
| Tiempo de respuesta (RNF-03) | 7 de 7 consultas bajo 3 s (la más lenta, 71 ms en el percentil 95) | [E-TST-006](../evidencias/H/E-TST-006-rendimiento.txt) |
| Firewall de router-lab (tráfico real) | 36 de 36 (2 nuevas) | [firewall](../evidencias/H/E-TST-002-ejecucion-2026-10-30/firewall.txt) |
| Lógica de los scripts del DC | 25 de 25 (11 nuevas) | [windows](../evidencias/H/E-TST-002-ejecucion-2026-10-30/windows.txt) |
| Scripts del servidor Linux en Ubuntu 24.04 | 84 PASS y 1 FAIL esperado (`smbd activo`: un contenedor no tiene systemd) | [linux](../evidencias/H/E-TST-002-ejecucion-2026-10-30/linux.txt) |
| Gemelo de red | 27 de 27 | [gemelo](../evidencias/H/E-TST-002-ejecucion-2026-10-30/gemelo.txt) |
| Configuraciones Cisco del Hito 1 | 81 de 81 | [cisco](../evidencias/H/E-TST-002-ejecucion-2026-10-30/cisco.txt) |

Del laboratorio (informe de Redes): Tabla 8.4 con 14 pruebas aprobadas de 17 (3 no ejecutadas: VPN y acceso desde afuera); `verificar-dc01.ps1` 63 PASS y 5 FAIL, los 5 falsos (INC-06 e INC-07); `verificar.sh` en srv01 59 PASS y 39 FAIL, que corresponden a los pasos 8 a 12 todavía no ejecutados.

## 2. Scripts y automatización

| Conjunto | Dónde está | Cómo se corre |
| --- | --- | --- |
| Unitarias, base de datos, API | `atlas/tests/Unit`, `atlas/tests/Database`, `atlas/tests/Api` | `vendor/bin/phpunit --testsuite unit` · `tests/Database/run.sh` · `ATLAS_TEST_SUITES=api tests/Database/run.sh` |
| Interfaz | `atlas/tests/e2e/interfaz.py` | Playwright contra `./probar-local.sh` con datos recién cargados (ver §6) |
| Tiempo de respuesta (nuevo) | `atlas/tests/rendimiento/medir.py` | `python3 medir.py https://localhost <clave demo> 30` |
| Servicio de análisis | `atlas-analysis/tests` | `python -m pytest` |
| Firewall de router-lab | `infra/red/pruebas/probar-router-lab.sh` | `sudo bash …` |
| Gemelo de red | `infra/red/pruebas/gemelo-red.sh` | Contenedor privilegiado |
| Scripts del servidor Linux | `infra/linux/pruebas/probar-en-contenedor.sh` | Contenedor Ubuntu 24.04 |
| Lógica de los scripts del DC | `infra/windows/pruebas/probar-modulo.ps1` | `pwsh -File …` |
| Configuraciones Cisco | `infra/red/pruebas/revisar_configuraciones.py` | `python3 …` |
| **Todo junto (nuevo)** | `probar-todo.sh` | `sudo ./probar-todo.sh` → tabla final y salidas en `resultados-pruebas/<fecha>/` |
| **En cada pull request (nuevo)** | `.github/workflows/pruebas.yml` | Automático en GitHub. Configurado; su primera corrida es en el pull request de este hito |

## 3. Cumplimiento de los criterios del PDF

| Criterio (PDF) | Cómo se comprueba | Estado |
| --- | --- | --- |
| Obj. 1: tres roles acceden solo a lo suyo, con diez casos documentados | `ControlAccesoTest`, casos C01 a C10 | Aprobada |
| Obj. 2: la actividad recorre sus cinco estados con registro | `CicloActividadTest`, `CicloAprobacionApiTest` | Aprobada |
| Obj. 3: 50 resoluciones, 100 % con respuestas, tiempo e intentos | API: "Cincuenta resoluciones quedan completamente registradas" | Aprobada |
| Obj. 4: base en 3FN, 15 tablas o más, integridad y privilegios por rol | `EsquemaTest`, `IntegridadTest`, `PrivilegiosTest` | Aprobada |
| Obj. 5: al menos ocho reglas, cada recomendación rastreable | `MotorReglasTest`, `MotorAnalisisApiTest`, interfaz "¿por qué?" | Aprobada |
| Obj. 6: perfil individual y grupal | `PanelGrupalTest`, `ResumenGrupalTest`, interfaz | Aprobada |
| Obj. 7: cinco intentos no autorizados rechazados y registrados | C01 a C10 (diez intentos, cada uno en la auditoría) | Aprobada |
| Obj. 8: autenticación centralizada y recursos compartidos Linux–Windows | Laboratorio: cliente unido al dominio con su GPO (aprobado); srv01 al dominio y Samba con cuentas del dominio | Parcial: lo de srv01 no ejecutado |
| Obj. 9 / RNF-08 / RNF-09: VLAN operativas, cada segmento con su direccionamiento, plan §30.5 | Laboratorio: Tabla 8.4 (14 de 17), DHCP en VLAN 20 y 30; entorno de pruebas: firewall 36/36 y gemelo 27/27 | Parcial: VLAN 10 sin equipo en el laboratorio; 3 pruebas no ejecutadas |
| Obj. 10: firewall, VPN y monitoreo con registro | Firewall con registro por regla (laboratorio) | Parcial: VPN y monitoreo no ejecutados |
| Obj. 11 / RNF-05: restauración de prueba con verificación | E-BD-005, E-BD-009 (entorno de pruebas) y E-BD-014 (laboratorio) | Aprobada · el respaldo automatizado (RNF-04) es del Hito 3 |
| RNF-01: acceso cruzado entre roles devuelve error y queda registrado | C01 a C10 | Aprobada |
| RNF-02 y RNF-10: disponibilidad 99 % y alertas | Requiere la herramienta de monitoreo | No ejecutada (Hito 3) |
| RNF-03: 3 s o menos en las consultas más frecuentes | `medir.py`: percentil 95 entre 28 y 71 ms | Aprobada en el entorno de pruebas; falta medir en el laboratorio |
| RNF-07: despliegue en los servidores definidos | Laboratorio: ATLAS en atlas-srv01, VLAN 40 | Aprobada |
| RNF-11: uso sin ayuda por docentes | Sesión con docentes | No ejecutada (Hito 3) |
| RNF-12: tres puntos de corte sin desplazamiento horizontal | Interfaz: 5 anchos, de 375 a 1366 px | Aprobada |
| RNF-13: estructura y criterios de desarrollo | PSR-12 sin errores | Aprobada |
| RNF-14: solo los datos necesarios (Ley 18.331) | Anonimización antes del LLM: `test_no_envia_si_hay_un_correo`, `…_una_cedula` | Parcial: la revisión de los datos guardados frente a la finalidad es documental y no se hizo |
| RNF-15: sin LLM ni análisis, el registro y la consulta siguen | `AsistenteApiTest` sin LLM, interfaz "asistente sin LLM" | Aprobada |

## 4. Reporte de incidencias

### 4.1 Fallas del producto encontradas en el laboratorio (22 y 23/10)

| ID | Qué se vio | Causa | Gravedad | Qué se hizo | Estado |
| --- | --- | --- | --- | --- | --- |
| INC-01 | ATLAS no arrancó sin Internet | `atlas.service` usaba `--build` y consultaba Docker Hub en cada arranque | Alta | `--no-build --pull never`; imágenes en la instalación; `atlas-ctl reconstruir` | Corregida y verificada ([E-TST-003](../evidencias/H/E-TST-003-arranque-sin-internet.txt)); falta en srv01 |
| INC-02 | "El administrador ya se había creado" con `usuarios` vacía | Solo lo creaba si en esa corrida se generaba `atlas.conf` | Alta | Se crea si su contraseña inicial sigue en `atlas.conf`; el paso se detiene si ATLAS no responde | Corregida, sin verificar en el laboratorio |
| INC-03 | `atlas-db` en bucle: "CPU does not support x86-64-v2" | `qm create` sin `--cpu` usa kvm64 | Alta | `--cpu x86-64-v2-AES` (o `CPU=host`) en `03-crear-vms.sh` | Corregida, sin verificar en el laboratorio |
| INC-04 | La WAN de router-lab sin dirección | El script solo pedía DHCP | Media | `WAN_IP` y `WAN_GW` | Corregida y verificada (2 pruebas) |
| INC-05 | Caída del enlace al usar `vmbr0` | Probable: el adaptador USB no tolera otra MAC (sin confirmar) | Alta | `WAN_INTERNA=si` en `01-redes.sh` crea `vmbr2` con NAT | Corregida y verificada en contenedor ([E-TST-004](../evidencias/H/E-TST-004-redes-vmbr2.txt)) |
| INC-06 | 4 falsos FAIL de auditoría en el DC | `auditpol` traduce los encabezados del CSV en un Windows en español | Media | `ConvertFrom-AtlasAuditpol` lee por posición | Corregida y verificada (6 pruebas, la primera reproduce la falla) |
| INC-07 | Falso FAIL de escritorio remoto en el DC | Windows devuelve la red como `/255.255.255.0` | Media | `Test-AtlasSoloDesdeRed` acepta las dos formas | Corregida y verificada (5 pruebas) |
| INC-08 | `atlas-ctl: command not found` | Lo instalaba el paso 12 y la guía lo usaba antes | Baja | Se instala en el paso 7 | Corregida, sin verificar en el laboratorio |
| INC-09 | Publicar: "Los datos enviados no son válidos" (422) sin grupos para elegir | La docente no estaba en ningún grupo y la pantalla no lo decía | Media | Aviso claro, botón deshabilitado y control antes de enviar | Corregida y verificada (2 pruebas de interfaz, [captura](../evidencias/H/capturas/E-TST-005-docente-sin-grupo-1024.png)) |

Las incidencias del laboratorio que no eran fallas del producto (consola noVNC, uso compartido de Windows, cuenta renombrada, etc.) están en el informe de Redes, sección 13.

### 4.2 Fallas encontradas en pruebas anteriores (ya corregidas)

| ID | Qué pasó | Qué se hizo | Evidencia |
| --- | --- | --- | --- |
| INC-H1 | Un logout podía deshacerse con peticiones simultáneas (3 de 16 sesiones seguían activas) | Bloqueo de sesión de Laravel (0 de 16) | E-APP-011 |
| INC-H2 | Una pantalla lenta se dibujaba encima de la siguiente | Se descartan lecturas viejas y se recarga al entrar o salir | E-APP-009 |
| INC-H3 | Las fechas de Consultas no se ocultaban | CSS | E-APP-009 |
| INC-H4 | El código de habilidad aceptaba minúsculas | `REGEXP_LIKE` con `'c'` | E-BD-007 |
| INC-H5 | `v_preguntas_error` tarda ~490 ms con muchos datos | Consulta por grupo (~41 ms) | E-BD-006 |
| INC-H6 | `mysql:8.0` no trae `mysqlbinlog` | Imagen auxiliar para la restauración incremental | E-BD-005 |
| INC-H7 | El análisis no se conectaba a MySQL 8 | Librería `cryptography` | E-APP-006 |

### 4.3 De la ejecución del 30/10

| ID | Qué pasó | Qué se hizo | Estado |
| --- | --- | --- | --- |
| INC-T1 | Docker Hub respondió 429 (límite de descargas) | Imágenes desde `mirror.gcr.io` | Del entorno |
| INC-T2 | La prueba de interfaz falla si se corre dos veces sobre los mismos datos | Se corre con datos recién cargados | Abierta (baja) |
| INC-T3 | La prueba nueva confundía el campo `#correo` de la pantalla de usuarios con el del login | Espera la recarga del logout | Corregida antes de la corrida final |
| INC-T4 | `pip` en contenedor no confiaba en el certificado del proxy del entorno | Opción `CA_EXTRA` en `probar-todo.sh` | Del entorno |

## 5. Ajustes y mejoras

Archivos tocados por las correcciones: `infra/linux/archivos/atlas.service`, `infra/linux/07-atlas.sh`, `infra/linux/archivos/atlas-ctl`, `infra/proxmox/01-redes.sh`, `03-crear-vms.sh`, `04-router-lab.sh`, `infra/windows/AtlasComun.psm1`, `verificar-dc01.ps1`, `atlas/public/js/vistas/docente.js`. Pruebas nuevas: 2 de netplan, 11 del verificador del DC, 2 de interfaz y la medición de RNF-03. Ninguna cambia la forma del JSON de la API, el esquema de la base ni las reglas del firewall.

Propuestas que quedan: que la prueba de interfaz prepare sus propios datos (INC-T2), confirmar la causa de INC-05 con `dmesg`, y rotar las contraseñas que quedaron escritas en la sesión del laboratorio.

## 6. Lo que falta ejecutar en el laboratorio

| Prueba | Confirma | Estado |
| --- | --- | --- |
| `verificar-dc01.ps1` de nuevo (se espera 68 PASS, 0 FAIL) | INC-06, INC-07 | No ejecutada |
| `git pull` + `07-atlas.sh` en srv01, reiniciar sin Internet y abrir ATLAS desde el cliente | INC-01, INC-08 | No ejecutada |
| Instalación nueva de srv01 cortada en el paso 7 | INC-02 | No ejecutada |
| VM creada con el script nuevo: `qm config <id> \| grep cpu` | INC-03 | No ejecutada |
| Circuito completo en el laboratorio (E-APP-014) | Programación en srv01 | No ejecutada (Hito 3) |
| Pruebas 14, 15 y 16 de la Tabla 8.4 | Firewall desde afuera y VPN | No ejecutadas |
| RNF-03 medido en el laboratorio | Tiempo de respuesta real | No ejecutada |

## 7. Cómo repetir

```bash
sudo ./probar-todo.sh                 # todo lo que no necesita el laboratorio
sudo ./probar-todo.sh unit api        # solo algunos conjuntos
```

Interfaz y tiempo de respuesta (con ATLAS levantado y datos recién cargados):

```bash
./probar-local.sh borrar && ./probar-local.sh
docker run --rm --network atlas_front -v "$PWD/atlas/tests/e2e:/e2e:ro" -v "$PWD/capturas:/capturas" \
  mcr.microsoft.com/playwright/python:v1.48.0-jammy \
  bash -c 'pip install -q playwright==1.48.0 && python /e2e/interfaz.py https://atlas-web /capturas "<clave demo>"'
python3 atlas/tests/rendimiento/medir.py https://localhost "<clave demo>" 30
```

La clave de demostración está en `atlas/local/atlas.conf` (`ATLAS_DEMO_CONTRASENA`) y no se escribe en ningún documento.
