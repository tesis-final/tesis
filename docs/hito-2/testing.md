# Hito 2 de Testing — Implementación y ejecución de pruebas

| Campo | Valor |
| --- | --- |
| Fecha | 30/10/2026 |
| Qué pide el hito | Desarrollo de scripts y automatización de pruebas · Ejecución de pruebas y reporte de incidencias · Ajustes y mejoras derivadas de los resultados |
| Entregable | Resultados de pruebas, reportes y scripts implementados |
| Contra qué se prueba | Documento de ATLAS V2.2: Tabla 5 (verificación de los objetivos), Tabla H29 (criterios de los requisitos no funcionales) y plan de pruebas de las políticas de red |
| Dónde se ejecutó | Entorno de pruebas (contenedores Docker con MySQL 8.0 real), GitHub Actions y, para lo que viene del Hito 2 de Redes, el laboratorio Proxmox con las 4 VM |

El informe completo, con las figuras, es el documento del Hito 2 de Testing. Acá queda el resumen para el repositorio.

**Cómo se informa cada resultado.** *Aprobada*: se ejecutó y dio lo esperado. *Fallada*: se ejecutó y dio otra cosa. *No ejecutada*: no se pudo correr, con el motivo. Una prueba que pasó en el entorno de pruebas no se presenta como si hubiera pasado en el laboratorio.

## 1. Resultados del 30/10

| Conjunto | Resultado | Evidencia |
| --- | --- | --- |
| Unitarias (PHP) | 37 de 37 | [unit](../evidencias/H/E-TST-002-ejecucion-2026-10-30/unit.txt) |
| Estándar PSR-12 | Sin errores ni advertencias | [psr12](../evidencias/H/E-TST-002-ejecucion-2026-10-30/psr12.txt) |
| Base de datos (MySQL 8.0 real) | 58 de 58 | [bd](../evidencias/H/E-TST-002-ejecucion-2026-10-30/bd.txt) |
| API (Laravel + MySQL real) | 71 de 71 | [api](../evidencias/H/E-TST-002-ejecucion-2026-10-30/api.txt) |
| Servicio de análisis (Python) | 23 de 23 | [analisis](../evidencias/H/E-TST-002-ejecucion-2026-10-30/analisis.txt) |
| Firewall de router-lab (tráfico real) | 36 de 36 | [firewall](../evidencias/H/E-TST-002-ejecucion-2026-10-30/firewall.txt) |
| Scripts de atlas-dc01 | 25 de 25 | [windows](../evidencias/H/E-TST-002-ejecucion-2026-10-30/windows.txt) |
| Scripts de atlas-srv01 en Ubuntu 24.04 | 84 PASS y 1 FAIL esperado (`smbd activo`: un contenedor no tiene systemd) | [linux](../evidencias/H/E-TST-002-ejecucion-2026-10-30/linux.txt) |
| Ajustes del laboratorio (scripts de Proxmox y `verificar.sh`) | 18 de 18 | [laboratorio](../evidencias/H/E-TST-002-ejecucion-2026-10-30/laboratorio.txt) |
| Interfaz en Chromium | 29 de 29 | [E-TST-004](../evidencias/H/E-TST-004-interfaz.txt) |
| Tiempo de respuesta (RNF-03) | 7 de 7 consultas bajo 3 s (la más lenta, 71 ms en el percentil 95) | [E-TST-005](../evidencias/H/E-TST-005-rendimiento.txt) |

Del laboratorio (informe del Hito 2 de Redes, `Hito2_Redes_ATLAS_v2.pdf`): Tabla 8.4 con 14 pruebas aprobadas de 17 (las 3 restantes, VPN y acceso desde afuera, no ejecutadas); `verificar-dc01.ps1` 63 PASS y 5 FAIL, los 5 falsos (INC-06 e INC-07); `verificar.sh` en srv01 59 PASS y 39 FAIL, casi todos de los pasos 8 a 12 todavía no ejecutados, más un falso FAIL (INC-10).

## 2. Scripts y automatización

| Conjunto | Dónde está |
| --- | --- |
| Unitarias, base de datos, API | `atlas/tests/Unit`, `atlas/tests/Database`, `atlas/tests/Api` |
| Interfaz | `atlas/tests/e2e/interfaz.py` |
| Tiempo de respuesta (nuevo) | `atlas/tests/rendimiento/medir.py` |
| Servicio de análisis | `atlas-analysis/tests` |
| Firewall de router-lab | `infra/red/pruebas/probar-router-lab.sh` |
| Scripts de atlas-srv01 | `infra/linux/pruebas/probar-en-contenedor.sh` |
| Scripts de atlas-dc01 | `infra/windows/pruebas/probar-modulo.ps1` |
| Ajustes del laboratorio (nuevo) | `infra/pruebas/probar-ajustes-laboratorio.sh` |
| Todo junto (nuevo) | `probar-todo.sh` → tabla final y salidas en `resultados-pruebas/<fecha>/` |
| En cada pull request (nuevo) | `.github/workflows/pruebas.yml` |

## 3. Incidencias

### 3.1 Fallas del producto encontradas en el laboratorio (22 y 23/10)

| ID | Síntoma | Causa | Solución | Estado |
| --- | --- | --- | --- | --- |
| INC-01 | ATLAS no arrancó sin Internet | `atlas.service` usaba `--build` y consultaba Docker Hub en cada arranque | `--no-build --pull never`; imágenes en el paso 7; `atlas-ctl reconstruir` | Corregida y verificada ([E-TST-003](../evidencias/H/E-TST-003-arranque-sin-internet.txt)); falta en srv01 |
| INC-02 | "El administrador ya se había creado" con `usuarios` vacía | Solo lo creaba si en esa corrida se generaba `atlas.conf` | Se crea si su contraseña inicial sigue en `atlas.conf`; el paso se detiene si ATLAS no responde | Corregida, sin verificar en el laboratorio |
| INC-03 | `atlas-db` en bucle: "CPU does not support x86-64-v2" | `qm create` sin `--cpu` usa kvm64 | `--cpu x86-64-v2-AES` (o `CPU=host`) en `03-crear-vms.sh` | Corregida y verificada con un `qm` de prueba; falta en Proxmox |
| INC-04 | La WAN de router-lab sin dirección; netplan duplicado | El script solo pedía DHCP | `WAN_IP` y `WAN_GW`; otros netplan se guardan aparte | Corregida y verificada (4 pruebas) |
| INC-05 | Caída del enlace al usar `vmbr0` | Probable: el adaptador USB no tolera otra MAC (sin confirmar) | `WAN_INTERNA=si` en `01-redes.sh` y `PUENTE_WAN=vmbr2` en `03-crear-vms.sh` | Corregida y verificada (10 pruebas) |
| INC-06 | 4 falsos FAIL de auditoría en el DC | `auditpol` traduce los encabezados del CSV en un Windows en español | `ConvertFrom-AtlasAuditpol` lee por posición | Corregida y verificada (6 pruebas) |
| INC-07 | Falso FAIL de escritorio remoto en el DC | Windows devuelve la red como `/255.255.255.0` | `Test-AtlasSoloDesdeRed` acepta las dos formas | Corregida y verificada (5 pruebas) |
| INC-08 | `atlas-ctl: command not found` | Lo instalaba el paso 12 y la guía lo usaba antes | Se instala en el paso 7 | Corregida, sin verificar en el laboratorio |
| INC-09 | Publicar: "Los datos enviados no son válidos" (422) | La docente no estaba en ningún grupo y la pantalla no lo decía | Aviso claro, botón deshabilitado y control antes de enviar | Corregida y verificada (2 pruebas de interfaz) |
| INC-10 | `verificar.sh`: FAIL en "atlas.conf modo 640" | Con las ACL de la Tabla 27 el archivo se ve 660 | Se comprueba el dueño y que otros no tengan permisos | Corregida y verificada (4 pruebas) |

### 3.2 Fallas encontradas en pruebas anteriores (ya corregidas)

| ID | Síntoma | Solución | Evidencia |
| --- | --- | --- | --- |
| INC-H1 | Un logout podía deshacerse con peticiones simultáneas | Bloqueo de sesión de Laravel | E-APP-011 |
| INC-H2 | Una pantalla lenta se dibujaba encima de la siguiente | Se descartan lecturas viejas y se recarga al entrar o salir | E-APP-009 |
| INC-H3 | Las fechas de Consultas no se ocultaban | CSS | E-APP-009 |
| INC-H4 | El código de habilidad aceptaba minúsculas | `REGEXP_LIKE` con `'c'` | E-BD-007 |
| INC-H5 | `v_preguntas_error` tarda ~490 ms con muchos datos | Consulta por grupo (~41 ms) | E-BD-006 |
| INC-H6 | `mysql:8.0` no trae `mysqlbinlog` | Imagen auxiliar para la restauración incremental | E-BD-005 |
| INC-H7 | El análisis no se conectaba a MySQL 8 | Librería `cryptography` | E-APP-006 |

### 3.3 De la ejecución del 30/10 (entorno de pruebas, no del producto)

| ID | Síntoma | Solución | Estado |
| --- | --- | --- | --- |
| INC-T1 | Docker Hub respondió 429 | Imágenes oficiales desde `mirror.gcr.io` | Resuelta |
| INC-T2 | La prueba de interfaz falla si se corre dos veces sobre los mismos datos | Se corre con datos recién cargados | Abierta |
| INC-T3 | La prueba nueva confundía el campo `#correo` de la pantalla de usuarios con el del login | Espera la recarga del cierre de sesión | Resuelta |
| INC-T4 | `pip` en contenedor no confiaba en el certificado del proxy del entorno | Opción `CA_EXTRA` en `probar-todo.sh` | Resuelta |

## 4. Lo que falta ejecutar en el laboratorio

| Prueba | Confirma | Estado |
| --- | --- | --- |
| `verificar-dc01.ps1` de nuevo (se espera 68 PASS, 0 FAIL) | INC-06, INC-07 | No ejecutada |
| `git pull` + `07-atlas.sh` en srv01, reiniciar sin Internet y abrir ATLAS desde cliente-doc; `sudo atlas-ctl estado`; `sudo ./verificar.sh atlas` | INC-01, INC-08, INC-10 | No ejecutada |
| Instalación nueva de srv01 cortada en el paso 7 | INC-02 | No ejecutada |
| VM creada con el script nuevo: `qm config <id> \| grep cpu` | INC-03 | No ejecutada |
| `medir.py` contra `https://172.16.40.10` | RNF-03 en el laboratorio | No ejecutada |
| Circuito completo en el laboratorio | Programación en srv01 | No ejecutado (Hito 3) |
| Pruebas 14, 15 y 16 de la Tabla 8.4 | Firewall desde afuera y VPN | No ejecutadas |

## 5. Evidencias

| Evidencia | Qué muestra |
| --- | --- |
| [E-TST-001](../evidencias/H/E-TST-001-resumen-ejecucion.txt) | Tabla final de la corrida completa del 30/10 |
| [E-TST-002](../evidencias/H/E-TST-002-ejecucion-2026-10-30/) | Salida completa de cada conjunto |
| [E-TST-003](../evidencias/H/E-TST-003-arranque-sin-internet.txt) | Arranque de ATLAS sin Internet: falla reproducida y corrección |
| [E-TST-004](../evidencias/H/E-TST-004-interfaz.txt) | Prueba de interfaz (29/29) y capturas `E-TST-004a` a `E-TST-004d` |
| [E-TST-005](../evidencias/H/E-TST-005-rendimiento.txt) | Tiempo de respuesta (RNF-03) |

## 6. Cómo repetir

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
