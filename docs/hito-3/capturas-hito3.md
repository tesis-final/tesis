# Hito 3 · Capturas que hay que sacar en el laboratorio

Lista completa de las capturas del Hito 3, en el orden en que salen al seguir el plan
[`plan-redes-laboratorio.md`](plan-redes-laboratorio.md) (pasos R-0 a R-12). Son solo las del Hito 3:
las del Hito 2 ya están en el informe de Redes (Anexo E) y no se repiten.

## Antes de empezar

- **Nombre de cada archivo:** el de la columna «Archivo» (por ejemplo `H3-07-srv01-salud.png`). Con ese
  nombre las ubico en el documento sin confundirme.
- **En las terminales:** escribí `date` antes del comando, así la captura muestra el día y la hora.
- **Que se lea:** pantalla completa de la ventana (no del escritorio entero), letra grande (Ctrl + rueda o
  Ctrl + «+»). Si la salida es larga, sacá dos capturas (`-a` y `-b`).
- **Nunca una contraseña:** si un comando pide contraseña, la captura va **después** de escribirla (no se ve,
  pero igual revisá). No captures la pantalla de edición del túnel WireGuard: ahí se ve la clave privada. No
  captures `monitoreo.conf`, `atlas.conf` ni `/etc/atlas/respaldo-smb.cred`.
- **Datos de personas:** en ATLAS usá las cuentas de prueba (Ana González, Luis Pérez, etc.).
- **Cómo llegar a cada máquina:**
  - **Proxmox:** desde la PC, `https://192.168.2.2:8006` → nodo → **Shell**.
  - **router-lab (VM 110):** desde la Shell de Proxmox, `ssh instalador@172.16.50.1`.
  - **atlas-srv01 (VM 130):** desde la Shell de Proxmox, `ssh -i ~/.ssh/atlas_admin atlasadmin@172.16.40.10`.
  - **atlas-dc01 (VM 120) y cliente-doc (VM 140):** en Proxmox, la VM → **Console**.
  - **PC Windows:** directamente.

En total son 74 capturas. Las marcadas *(opcional)* suman, pero el hito queda completo sin ellas.

---

## 1. Proxmox: preparación (R-0, R-1, R-2)

| N.º | Archivo | Dónde | Qué hacer | Qué tiene que verse |
|---|---|---|---|---|
| 1 | `H3-01-proxmox-snapshots.png` | Shell de Proxmox | `for id in 110 120 130 140; do qm listsnapshot $id; done` (después de crear `hito3_inicio`) | Las cuatro VM con el snapshot `hito3_inicio` |
| 2 | `H3-02-proxmox-config-vm.png` | Shell de Proxmox | `for id in 110 120 130 140; do echo "== $id"; qm config $id \| grep -E '^(cpu\|memory\|ide)'; done` | `cpu: host` en las cuatro, `memory: 4096` en la 130 y solo `ide3` en la 120 y la 140 |
| 3 | `H3-03-proxmox-iso-repo.png` | Shell de Proxmox | `bash /root/tesis/infra/proxmox/02-iso-repo.sh` | El final: el MSI de Zabbix en `extras/` y la ISO regenerada |
| 4 | `H3-04-proxmox-vm-encendidas.png` | Interfaz web de Proxmox | Panel izquierdo con las cuatro VM encendidas (ícono verde) y el resumen del nodo | Las cuatro VM en marcha y el uso de memoria del nodo |
| 5 | `H3-05-dc-scripts-copiados.png` | atlas-dc01 (consola) | PowerShell: `Get-ChildItem C:\ATLAS\1?-*.ps1` | Aparecen `13-retencion-respaldos.ps1` y `14-agente-zabbix.ps1` |

## 2. atlas-srv01 al día (R-3)

| N.º | Archivo | Dónde | Qué hacer | Qué tiene que verse |
|---|---|---|---|---|
| 6 | `H3-06-srv01-instalar-5-7.png` | atlas-srv01 | `cd /opt/atlas/tesis && sudo git pull` y `cd infra/linux && sudo ./instalar.sh 5 7` | El final del paso 7 sin errores |
| 7 | `H3-07-srv01-salud.png` | atlas-srv01 | `sudo atlas-ctl estado` y `sudo atlas-ctl salud` | Los cuatro contenedores sanos y `"estado":"ok"` |
| 8 | `H3-08-srv01-ufw.png` | atlas-srv01 | `sudo ufw status numbered` | Las reglas, incluida `10050/tcp ALLOW IN 192.168.250.64/28` |
| 9 | `H3-09-srv01-sin-internet.png` | atlas-srv01 | Con el iPhone **desconectado**: `ping -c 2 1.1.1.1`, `sudo systemctl restart atlas.service`, esperar un minuto, `sudo atlas-ctl salud` | El ping falla (sin Internet) y la salud responde `ok` igual |

## 3. Dominio, hora, Samba y certificado (R-4)

| N.º | Archivo | Dónde | Qué hacer | Qué tiene que verse |
|---|---|---|---|---|
| 10 | `H3-10-srv01-union-dominio.png` | atlas-srv01 | Después de `sudo ATLAS_USUARIO_UNION=adm.prueba.soporte ./instalar.sh 9 12`: `realm list` | `atlas.local` como dominio configurado |
| 11 | `H3-11-srv01-hora-dc.png` | atlas-srv01 | `chronyc sources` y `timedatectl` | La fuente de hora es el DC (172.16.40.20) y el reloj sincronizado |
| 12 | `H3-12-srv01-verificar-integracion.png` | atlas-srv01 | `sudo ./verificar.sh hora dominio samba registros sudo` | Las cinco secciones en PASS |
| 13 | `H3-13-dc-firma-certificado.png` | atlas-dc01 (consola) | `C:\ATLAS\10-certificado-srv01.ps1 -Csr C:\ATLAS\atlas.csr` | El certificado emitido con la IP 172.16.40.10 en el SAN |
| 14 | `H3-14-srv01-instalar-certificado.png` | atlas-srv01 | `sudo /opt/atlas/tesis/infra/linux/instalar-certificado.sh /tmp/atlas-srv01.cer /tmp/ATLAS-CA.cer` | Las comprobaciones en orden y el emisor ATLAS-CA |
| 15 | `H3-15-cliente-certificado-valido.png` | cliente-doc | Navegador en `https://172.16.40.10`, clic en el candado → «La conexión es segura» → ver certificado | Sin aviso de seguridad; emitido por ATLAS-CA |

## 4. Respaldos automáticos con copia al DC (R-5)

| N.º | Archivo | Dónde | Qué hacer | Qué tiene que verse |
|---|---|---|---|---|
| 16 | `H3-16-dc-svc-rotada.png` | atlas-dc01 (consola) | **Después** de rotar la contraseña (no captures la contraseña): `Get-ADUser svc_atlas_backup -Properties PasswordLastSet \| Select-Object Name,Enabled,PasswordLastSet` | La fecha de cambio es la de hoy |
| 17 | `H3-17-srv01-instalar-13.png` | atlas-srv01 | `sudo ./instalar.sh 13 13` (la captura, después de escribir la contraseña) | Respaldo completo verificado y «Copia a Windows: OK» |
| 18 | `H3-18-srv01-respaldo-estado.png` | atlas-srv01 | `sudo atlas-respaldo estado` | Últimos respaldos y su verificación |
| 19 | `H3-19-srv01-temporizadores.png` | atlas-srv01 | `systemctl list-timers 'atlas-respaldo*' --no-pager` | Los cuatro temporizadores con su próxima ejecución |
| 20 | `H3-20-dc-carpeta-backups.png` | atlas-dc01 (consola) | Explorador de archivos en `C:\ATLAS\atlas-backups` | Los archivos `atlas-srv01_atlas_…` recién copiados |
| 21 | `H3-21-srv01-no-puede-borrar.png` | atlas-srv01 | Los dos comandos `smbclient … -c ls` y `-c "del $F"` del paso R-5.3 del plan | El listado y `NT_STATUS_ACCESS_DENIED` al borrar (CT-05) |
| 22 | `H3-22-srv01-prueba-restauracion.png` | atlas-srv01 | `sudo atlas-respaldo probar-restauracion` | `Tablas: 32` y `Resultado: 11 de 11` |
| 23 | `H3-23-dc-retencion.png` | atlas-dc01 (consola) | `C:\ATLAS\13-retencion-respaldos.ps1` | La tarea instalada y la simulación «qué se borraría hoy» |
| 24 | `H3-24-dc-tarea-programada.png` | atlas-dc01 (consola) | Programador de tareas → Biblioteca → carpeta **ATLAS** | La tarea «ATLAS - Retencion de respaldos», diaria 05:00, como SYSTEM |
| 25 | `H3-25-dc-evento-retencion.png` *(opcional)* | atlas-dc01 (consola) | Clic derecho en la tarea → **Ejecutar**; después Visor de eventos → Registros de Windows → Aplicación, origen `ATLAS-Respaldos` | El evento 1300 con el resumen de la retención |

## 5. Monitoreo con Zabbix (R-6)

| N.º | Archivo | Dónde | Qué hacer | Qué tiene que verse |
|---|---|---|---|---|
| 26 | `H3-26-srv01-instalar-14.png` | atlas-srv01 | `sudo ./instalar.sh 14 14` | Contenedores levantados y la configuración por la API |
| 27 | `H3-27-srv01-zabbix-contenedores.png` | atlas-srv01 | `docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'` y `ss -ltn '( sport = :8080 or sport = :10050 )'` | Los cuatro de Zabbix y la interfaz solo en `127.0.0.1:8080` |
| 28 | `H3-28-dc-agente-zabbix.png` | atlas-dc01 (consola) | El comando del paso R-6.2 del plan (14-agente-zabbix.ps1) | Servicio en marcha, 10050 escuchando y la regla solo desde 172.16.40.10 |
| 29 | `H3-29-srv01-atlas-ctl-monitoreo.png` | atlas-srv01 | `sudo atlas-ctl monitoreo` | Los dos agentes responden, chequeo web OK en menos de 3 s, SLA definido |
| 30 | `H3-30-zabbix-hosts.png` | PC (navegador, con el túnel del paso R-6.4) | `http://127.0.0.1:8080` → Monitoring → **Hosts** | atlas-srv01 y atlas-dc01 con el agente en verde (ZBX) |
| 31 | `H3-31-zabbix-ultimos-datos.png` | PC (navegador) | Monitoring → **Latest data**, filtrar por los dos hosts | CPU, memoria y disco con valores actuales |
| 32 | `H3-32-zabbix-web.png` | PC (navegador) | Monitoring → **Web** → atlas-salud | Estado OK y tiempo de respuesta |
| 33 | `H3-33-zabbix-alerta.png` | PC (navegador) | En srv01: `sudo atlas-ctl detener`; esperar 3 minutos; Monitoring → **Problems** | El problema «ATLAS no responde» |
| 34 | `H3-34-zabbix-alerta-resuelta.png` | PC (navegador) | En srv01: `sudo atlas-ctl iniciar`; esperar 2 minutos; Problems con «Show: History» | El mismo problema en estado RESOLVED |
| 35 | `H3-35-zabbix-sla.png` | PC (navegador) | Services → **SLA report** | El SLA «ATLAS · disponibilidad (RNF-02)» con su porcentaje |

## 6. VPN y pruebas 14, 15 y 16 (R-7)

| N.º | Archivo | Dónde | Qué hacer | Qué tiene que verse |
|---|---|---|---|---|
| 36 | `H3-36-router-vpn-alta.png` | router-lab | `sudo bash ~/05-vpn.sh agregar docente '<clave pública>' 10.8.0.130 pc-docente` | El par agregado y el túnel para el cliente (solo claves públicas) |
| 37 | `H3-37-pc-wireguard-activo.png` | PC | Aplicación WireGuard, pantalla **principal** del túnel `atlas-docente` activo (no la de edición) | Estado «Activo», endpoint 10.99.0.2:51820, último handshake |
| 38 | `H3-38-pc-ruta.png` | PC (PowerShell admin) | `route print 10.99.0.0` | La ruta a 10.99.0.0/24 por 192.168.2.2 |
| 39 | `H3-39-pc-prueba15-443.png` | PC (PowerShell) | Con el túnel activo: `Test-NetConnection 172.16.40.10 -Port 443` | `TcpTestSucceeded : True` (prueba 15) |
| 40 | `H3-40-pc-prueba15-navegador.png` | PC (navegador) | Con el túnel activo: `https://172.16.40.10` | La pantalla de ingreso de ATLAS por la VPN |
| 41 | `H3-41-router-wg-show.png` | router-lab | `sudo wg show` | El par 10.8.0.130 con handshake reciente y bytes en los dos sentidos |
| 42 | `H3-42-pc-prueba16-22.png` | PC (PowerShell) | Con el túnel activo: `Test-NetConnection 172.16.40.10 -Port 22` | `TcpTestSucceeded : False` (prueba 16) |
| 43 | `H3-43-router-registro-prueba16.png` | router-lab | Mientras repetís la 42: `sudo journalctl -k -f \| grep ATLAS-R12` | `ATLAS-R12 IN=wg0 SRC=10.8.0.130 … DPT=22` |
| 44 | `H3-44-srv01-vpn-sin-nat.png` | atlas-srv01 | `sudo atlas-ctl logs atlas-web 50 \| grep 10.8.0.130` | Las peticiones de la prueba 15 con origen 10.8.0.130 (VPN-09) |
| 45 | `H3-45-proxmox-prueba14.png` | Shell de Proxmox | Túnel apagado. Los tres comandos del paso R-7.8 (ruta temporal, `curl`, borrar la ruta) | `rc=28` (tiempo agotado) |
| 46 | `H3-46-router-registro-prueba14.png` | router-lab | Mientras corrés la 45: `sudo journalctl -k -f \| grep ATLAS-R12` | `ATLAS-R12 IN=ens19 SRC=10.99.0.1 … DPT=443` |
| 47 | `H3-47-router-vpn-estado.png` | router-lab | `sudo bash ~/05-vpn.sh estado` | La lista de pares y las reglas de wg0 |
| 48 | `H3-48-pc-vpn-admin.png` *(opcional)* | PC (PowerShell) | Con el túnel `atlas-admin` (paso R-7.9): `Test-NetConnection 172.16.50.10 -Port 8006` | `True`: el perfil de administración llega a la VLAN 50 |

## 7. Circuito completo de ATLAS (R-8)

Todo en **cliente-doc (VM 140)**, en el navegador, entrando a `https://172.16.40.10`.

| N.º | Archivo | Dónde | Qué hacer | Qué tiene que verse |
|---|---|---|---|---|
| 49 | `H3-49-app-ingreso.png` | cliente-doc | Pantalla de ingreso | El logotipo y el formulario |
| 50 | `H3-50-app-coordinacion-grupos.png` | cliente-doc (coordinación) | Grupos → miembros del Grupo 1 | Ana González (docente) y Luis Pérez (estudiante) en el grupo |
| 51 | `H3-51-app-docente-inicio.png` | cliente-doc (docente) | Menú **Dónde intervenir** | El panel inicial del docente |
| 52 | `H3-52-app-editor.png` | cliente-doc (docente) | Mis actividades → Nueva actividad, con la pregunta, la habilidad tildada y la opción correcta marcada | El editor completo |
| 53 | `H3-53-app-aviso-motivo.png` | cliente-doc (docente) | Antes de marcar la correcta: Guardar borrador → Publicar | El aviso con el motivo («Pregunta 1: …») y la pregunta marcada en rojo |
| 54 | `H3-54-app-publicada.png` | cliente-doc (docente) | Ya corregida: Guardar borrador → Publicar en el Grupo 1 | El aviso «Actividad publicada», el estado Publicada y el historial |
| 55 | `H3-55-cliente-vlan30.png` | cliente-doc (después de pasarlo a la VLAN 30, paso R-8.3) | `ipconfig` | Dirección 172.16.30.x |
| 56 | `H3-56-cliente-445-vlan30.png` | cliente-doc (VLAN 30) | `Test-NetConnection 172.16.40.10 -Port 445` | `False` |
| 57 | `H3-57-router-registro-445.png` | router-lab | Mientras corrés la 56: `sudo journalctl -k -f \| grep "DPT=445"` | La línea `ATLAS-R12 … DPT=445` desde la VLAN 30 |
| 58 | `H3-58-app-estudiante-inicio.png` | cliente-doc (Luis Pérez, VLAN 30) | Inicio del estudiante | La actividad publicada disponible |
| 59 | `H3-59-app-estudiante-cambio.png` | cliente-doc (estudiante) | En la pregunta 1, elegí una opción incorrecta y después la correcta | La pregunta con la opción corregida |
| 60 | `H3-60-app-estudiante-confirmacion.png` *(opcional)* | cliente-doc (estudiante) | Si dejás una pregunta sin responder y tocás Finalizar | La confirmación con el diseño de ATLAS |
| 61 | `H3-61-app-estudiante-resultado.png` | cliente-doc (estudiante) | Al finalizar | Puntaje, tiempo total y tiempo activo |
| 62 | `H3-62-app-docente-grupo.png` | cliente-doc (docente, de nuevo en VLAN 20) | Dónde intervenir → el Grupo 1 | Análisis del grupo: atención prioritaria, errores por pregunta, habilidades |
| 63 | `H3-63-app-docente-estudiante.png` | cliente-doc (docente) | Clic en Luis Pérez | Perfil con su evolución y la recomendación |
| 64 | `H3-64-app-docente-por-que.png` | cliente-doc (docente) | Botón **¿Por qué?** | La regla, su versión y los datos |
| 65 | `H3-65-app-docente-consultas.png` | cliente-doc (docente) | Consultas → Grupo 1, período actual, «Acierto por habilidad» | El resultado de la consulta guiada |
| 66 | `H3-66-app-docente-reportes.png` | cliente-doc (docente) | Reportes → Consultar | El intento de Luis Pérez con puntaje, tiempo total y tiempo activo |
| 67 | `H3-67-app-celular.png` | cliente-doc | En el navegador: F12 → Ctrl+Shift+M → «iPhone SE» (375 px), en el inicio del docente o del estudiante | La interfaz adaptada a celular |
| 68 | `H3-68-app-tema-oscuro.png` | cliente-doc | Botón de la luna, en el inicio del docente | La interfaz en tema oscuro |
| 69 | `H3-69-app-auditoria.png` | cliente-doc (coordinación) | Menú **Auditoría** | La publicación y los ingresos registrados con su autor |

## 8. Base de datos en el laboratorio (R-9)

| N.º | Archivo | Dónde | Qué hacer | Qué tiene que verse |
|---|---|---|---|---|
| 70 | `H3-70-srv01-seguir-intento.png` (`-a` y `-b`) | atlas-srv01 | `sudo /opt/atlas/tesis/atlas/database/tools/seguir_intento.sh` | `-a`: respuestas finales e interacciones con el `CAMBIO_OPCION`. `-b`: un solo resultado y «RESULTADO: OK» |
| 71 | `H3-71-srv01-restaurar-intento.png` (`-a` y `-b`) | atlas-srv01 | `sudo /opt/atlas/tesis/atlas/database/tools/restaurar_intento.sh` | Las huellas iguales, los conteos de tablas y los tiempos frente al RPO y RTO |
| 72 | `H3-72-srv01-metricas.png` | atlas-srv01 | `sudo /opt/atlas/tesis/atlas/database/tools/metricas.sh` | La tabla M1 a M11, ahora con respaldos (M10 y M11) |

## 9. Respaldo de la VM y verificación final (R-10, R-11)

| N.º | Archivo | Dónde | Qué hacer | Qué tiene que verse |
|---|---|---|---|---|
| 73 | `H3-73-proxmox-vzdump.png` (`-a` y `-b`) | Shell de Proxmox | `-a`: `time vzdump 130 …` del paso R-10. `-b`: `time qmrestore …` y la VM 930 arrancada con `docker ps` en su consola | El respaldo terminado y la restauración con sus tiempos |
| 74 | `H3-74-verificacion-final.png` (`-a`, `-b` y `-c`) | `-a`: atlas-srv01 (`sudo ./verificar.sh`, el final). `-b`: atlas-dc01 (`C:\ATLAS\verificar-dc01.ps1`, el final). `-c`: router-lab (`sudo nft list ruleset \| head -60`) | Las dos verificaciones sin FAIL y el firewall con las reglas de wg0 |

---

## Cuando las tengas

Pasámelas todas juntas, con estos nombres. Con ellas rehago el documento integrador:

- reemplazo las capturas de desarrollo por las del laboratorio;
- cambio cada «No ejecutada» por el resultado real (o lo dejo como está si algo no salió, con su motivo);
- actualizo las tablas de pruebas, métricas y estado;
- publico la versión 3.1, manteniendo las normas APA.

Si alguna captura no sale como dice la columna «Qué tiene que verse», sacala igual y avisame qué salió:
también es evidencia, y lo documento tal cual.
