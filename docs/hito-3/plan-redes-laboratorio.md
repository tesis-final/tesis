# Hito 3 · Plan de trabajo de Redes en el laboratorio Proxmox

Equipo Error404 · ATLAS · versión del 12/11/2026 · entrega del Hito 3: viernes 20/11/2026

Este plan arranca donde terminó el laboratorio del Hito 2 (informe `Hito2_Redes_ATLAS_v2.pdf`, secciones 15 a 17)
y usa lo que se agregó al repositorio para el Hito 3. Cada paso dice **en qué máquina** se hace, **qué se escribe**,
**qué tiene que salir** y **qué evidencia se guarda**. Nada de esto está ejecutado todavía en el laboratorio: hasta que
se corra, cada prueba es *No ejecutada*.

## 1. Dónde estamos parados

| Área | Hecho en el Hito 2 (laboratorio) | Falta (sección 15 del informe) | Qué hay nuevo en el repositorio |
|---|---|---|---|
| Proxmox | vmbr1 con VLAN, vmbr2 con NAT, 4 VM, 8 snapshots | CPU host en 110/120/140, sacar ISO, upgrade, causa de la caída del enlace | `02-iso-repo.sh` baja también el instalador del agente de Zabbix |
| router-lab | Tabla 44 en nftables, NAT, relay DHCP; 14 de 17 pruebas aprobadas | Pruebas 14, 15 y 16 (afuera y VPN); registro del 445 desde VLAN 30 | `05-vpn.sh` (perfiles admin y docente de la Tabla 45), probado con tráfico real (E-RED-011, 46/46) |
| atlas-dc01 | Dominio, DNS, DHCP, GPO, recursos, CA; 63 PASS y 5 falsos FAIL | `verificar-dc01` corregido sin volver a correr; rotar `svc_atlas_backup` | `13-retencion-respaldos.ps1`, `14-agente-zabbix.ps1`, verificador con la Fase 12 (E-WIN-004, 52/52) |
| atlas-srv01 | Pasos 1 a 7, ATLAS andando en la VLAN 40 | Pasos 8 a 12, certificado de ATLAS-CA, arranque sin Internet, `atlas-ctl` | Paso 13 (respaldos automáticos) y paso 14 (monitoreo con Zabbix), `atlas-ctl respaldos` y `monitoreo` |
| ATLAS | Login y borrador de la actividad desde cliente-doc | Publicar (422), resolver desde VLAN 30, indicadores | Aviso y control del grupo al publicar (INC-09), interfaz nueva, `seguir_intento.sh` |
| Base de datos | Conteos y una restauración (E-BD-013 parcial, E-BD-014) | Repetir después del circuito; respaldo de la VM (E-BD-015) | `restaurar_intento.sh`, `seguir_intento.sh`, `metricas.sh` |

### ¿Hace falta algo físico?

No. Lo físico ya quedó armado en el Hito 2: la PC (192.168.2.1), el Proxmox (192.168.2.2) con el adaptador USB y el
iPhone compartiendo Internet. No hay que cablear nada nuevo ni comprar nada. Lo que sí hace falta:

- **Internet durante la primera parte** (pasos R-2 a R-6) para `git pull`, las imágenes de Zabbix (unos 300 a 400 MB),
  el instalador del agente para Windows, `wireguard-tools` en router-lab, `smbclient` en srv01 y la aplicación
  WireGuard en la PC. Si se puede, hacerlo con una red sin límite de datos y no con el iPhone.
- **Memoria**: el host tiene 15 GiB y las VM suman 9 GB. Zabbix agrega cerca de 1,4 GB como máximo en srv01, así que
  srv01 pasa de 3 a 4 GB (paso R-1). Queda margen.
- **Tiempo**: entre 6 y 8 horas en total, mejor repartido en dos jornadas (R-0 a R-6 y R-7 a R-12).

### Reparto sugerido (Tabla 3 del documento integrador)

| Paso | Responsable | Apoyo |
|---|---|---|
| R-0, R-1, R-2, R-10 | Juan Pablo Beracochea (Redes MS y Conectividad) | Santiago Viñas (capturas y registro) |
| R-3, R-4, R-5 (srv01), R-6 (srv01) | Sergio Rodríguez (POSIX) | Juan Pablo |
| R-5 (DC), R-6 (DC) | Juan Pablo | Sergio |
| R-7 (VPN), R-11 (router) | Juan Pablo | Santiago |
| R-8 (circuito) | Aaron Britos (Programación) | Santiago (capturas) |
| R-9 (base de datos) | Brian Reyes (Base de Datos) | Aaron |
| R-12 (cierre) | Santiago | Todos |

## 2. Antes de empezar

- Los cambios del Hito 3 tienen que estar en `main` del repositorio que clona el laboratorio
  (`https://github.com/tesis-final/tesis`, sección 4.4 del informe). Si el laboratorio clona otro, usar ese.
- En Proxmox existe el atajo `vm` (`/usr/local/bin/vm`, informe sección 12.1) para correr comandos en las VM con el agente
  de QEMU y ver la salida limpia. Se usa abajo.
- Ninguna contraseña se escribe en un comando ni aparece en una captura. Cuando un script pide una, la pide sin eco.

## 3. Pasos

### R-0 · Arranque y snapshots (Proxmox, 15 min)

1. En la PC, revisar en `ncpa.cpl` que el uso compartido de Internet siga activo (se desarma al reconectar el iPhone).
2. Con las cuatro VM **apagadas**, en la Shell de Proxmox:
   ```bash
   for id in 110 120 130 140; do qm snapshot $id hito3_inicio --description "Antes del Hito 3"; done
   qm listsnapshot 130
   ```
   Sale: `hito3_inicio` en las cuatro. Es el punto de vuelta si algo se rompe.

### R-1 · Ajustes de las VM (Proxmox, 10 min) — pendientes del Hito 2

```bash
qm set 110 --cpu host; qm set 120 --cpu host; qm set 140 --cpu host     # la 130 ya está en host
qm set 130 --memory 4096                                                 # Zabbix en srv01
qm set 110 --ide2 none,media=cdrom; qm set 130 --ide2 none,media=cdrom   # ISO de instalación de Ubuntu
qm set 120 --ide2 none,media=cdrom --ide0 none,media=cdrom               # Windows Server y virtio
qm set 140 --ide2 none,media=cdrom --ide0 none,media=cdrom               # Windows 10 y virtio
for id in 110 120 130 140; do echo "== $id"; qm config $id | grep -E '^(cpu|memory|ide)'; done
```
Sale: `cpu: host` en las cuatro, `memory: 4096` en la 130 y solo `ide3` (el CD `atlas-repo.iso`) en la 120 y la 140.
Prender en orden: 110 (router), 120 (DC, esperar a que termine de arrancar), 130 y 140.

Ponerle frase de paso a la clave `atlas_admin` de Proxmox (pendiente de seguridad del informe):
```bash
ssh-keygen -p -f ~/.ssh/atlas_admin
```

### R-2 · Repositorio y CD actualizados (Proxmox, 10 min)

```bash
bash /root/tesis/infra/proxmox/02-iso-repo.sh
qm set 120 --ide3 local:iso/atlas-repo.iso,media=cdrom     # el DC vuelve a leer el CD nuevo
```
Sale: `git pull` sin errores, el MSI `zabbix_agent2-7.0.32-windows-amd64-openssl.msi` en `/root/tesis/extras/` y la ISO
regenerada. Si avisa que no pudo bajar el MSI, bajarlo en la PC desde la página oficial de agentes de Zabbix (Windows,
agente 2, 7.0 LTS, MSI), pasarlo con `scp` a `/root/tesis/extras/` y volver a correr el script.

Copiar los scripts nuevos al DC (como en la sección 7.2 del informe). Se deja afuera `parametros.psd1`, porque el del DC
tiene los reenviadores DNS que se cargaron a mano en el Hito 2, y no se tocan las carpetas de datos de `C:\ATLAS`:
```bash
vm 120 --timeout 0 -- powershell.exe -NoProfile -Command '$cd=(Get-Volume -FileSystemLabel ATLAS).DriveLetter; Get-ChildItem ($cd+":\infra\windows") -Exclude parametros.psd1 | Copy-Item -Destination C:\ATLAS -Recurse -Force; attrib -r C:\ATLAS\*.ps* ; Get-ChildItem C:\ATLAS\1?-*.ps1 | Select-Object Name'
```
Sale: la lista incluye `13-retencion-respaldos.ps1` y `14-agente-zabbix.ps1`.

### R-3 · atlas-srv01 al día (srv01 por SSH, 30 min) — INC-01, INC-02, INC-08 e interfaz nueva

Desde la Shell de Proxmox (VLAN 50):
```bash
ssh -i ~/.ssh/atlas_admin atlasadmin@172.16.40.10
cd /opt/atlas/tesis && sudo git pull
cd infra/linux && sudo ./instalar.sh 5 7
sudo atlas-ctl estado && sudo atlas-ctl salud
sudo ./verificar.sh atlas firewall docker
```
Sale: `atlas-ctl` existe (INC-08), los cuatro contenedores sanos, `{"estado":"ok",...}` y UFW con la regla nueva
`10050/tcp ALLOW 192.168.250.64/28` (agente de monitoreo). El paso 7 vuelve a copiar la aplicación con la interfaz
nueva y deja `atlas.service` sin `--build`.

**Arranque sin Internet (INC-01, E-TST-006):** desconectar el iPhone, `sudo systemctl restart atlas.service`,
esperar un minuto y `sudo atlas-ctl salud`. Tiene que responder `ok`. Volver a conectar el iPhone.

### R-4 · Pasos 8 a 12 y certificado (srv01 y DC, 45 min)

1. En el DC, que `adm.prueba.soporte` no tenga el cambio de contraseña obligatorio (incidencia del Hito 2):
   ```bash
   vm 120 -- powershell.exe -NoProfile -Command 'Set-ADUser adm.prueba.soporte -ChangePasswordAtLogon $false; Get-ADUser adm.prueba.soporte -Properties pwdLastSet | Select-Object SamAccountName,Enabled'
   ```
2. En srv01 (pide la contraseña de `adm.prueba.soporte` sin eco):
   ```bash
   cd /opt/atlas/tesis/infra/linux
   sudo ./instalar.sh 8 8
   sudo ATLAS_USUARIO_UNION=adm.prueba.soporte ./instalar.sh 9 12
   sudo ./verificar.sh hora dominio samba registros sudo
   ```
3. Certificado de ATLAS-CA (DEC-20), desde la Shell de Proxmox:
   ```bash
   cd /root/tesis/infra/proxmox
   bash copiar.sh leer 130 /srv/atlas/config/tls/atlas.csr > /root/atlas.csr
   bash copiar.sh escribir 120 'C:\ATLAS\atlas.csr' /root/atlas.csr
   vm 120 --timeout 0 -- powershell.exe -NoProfile -File C:\ATLAS\10-certificado-srv01.ps1 -Csr C:\ATLAS\atlas.csr
   # certutil guarda el de la CA en binario y copiar.sh es para texto: se pasa a base64 antes de copiarlo
   vm 120 -- certutil.exe -f -encode C:\ATLAS\ATLAS-CA.cer C:\ATLAS\ATLAS-CA.pem
   bash copiar.sh leer 120 'C:\ATLAS\atlas-srv01.cer' > /root/atlas-srv01.cer
   bash copiar.sh leer 120 'C:\ATLAS\ATLAS-CA.pem'    > /root/ATLAS-CA.cer
   bash copiar.sh escribir 130 /tmp/atlas-srv01.cer /root/atlas-srv01.cer
   bash copiar.sh escribir 130 /tmp/ATLAS-CA.cer    /root/ATLAS-CA.cer
   ```
   Y en srv01: `sudo /opt/atlas/tesis/infra/linux/instalar-certificado.sh /tmp/atlas-srv01.cer /tmp/ATLAS-CA.cer`.
   Sale: en cliente-doc, `https://172.16.40.10` abre sin aviso de certificado (la CA llega por GPO).

### R-5 · Respaldos automáticos con copia al DC (DC y srv01, 40 min) — RNF-04, Tabla 29

1. **Rotar `svc_atlas_backup`** (quedó expuesta en el Hito 2). La nueva se genera al azar y se muestra **una sola vez**;
   no capturarla ni pegarla en ningún lado:
   ```bash
   vm 120 -- powershell.exe -NoProfile -Command 'Import-Module C:\ATLAS\AtlasComun.psm1; $c=Get-AtlasContrasenaAleatoria -Largo 20; Set-ADAccountPassword svc_atlas_backup -Reset -NewPassword (ConvertTo-AtlasSecureString -Texto $c); $c'
   ```
2. En srv01, el paso 13 (pide esa contraseña sin eco y la guarda en `/etc/atlas/respaldo-smb.cred`, root 600):
   ```bash
   cd /opt/atlas/tesis/infra/linux && sudo ./instalar.sh 13 13
   sudo atlas-respaldo estado
   sudo ./verificar.sh respaldos
   ```
   Después, en Proxmox: `history -c` (el comando del punto 1 mostró la contraseña).
3. **CT-05 en la práctica** (E-LNX-007): srv01 puede subir pero no borrar.
   ```bash
   F=$(sudo smbclient //atlas-dc01.atlas.local/atlas-backups -A /etc/atlas/respaldo-smb.cred -m SMB3 -e -c ls | awk '/atlas-srv01_atlas_/ {print $1; exit}')
   sudo smbclient //atlas-dc01.atlas.local/atlas-backups -A /etc/atlas/respaldo-smb.cred -m SMB3 -e -c "del $F"
   ```
   Sale: la lista tiene los archivos del primer respaldo y el borrado responde `NT_STATUS_ACCESS_DENIED`.
4. **Retención en el DC** (E-WIN-006):
   ```bash
   vm 120 --timeout 0 -- powershell.exe -NoProfile -File C:\ATLAS\13-retencion-respaldos.ps1
   ```
   Sale: la tarea `\ATLAS\ATLAS - Retencion de respaldos` en estado `Ready` y la simulación de hoy sin nada vencido.
5. Restauración de prueba con el respaldo automático: `sudo atlas-respaldo probar-restauracion` (tiene que decir
   `Tablas: 32` y `Resultado: 11 de 11`).

### R-6 · Monitoreo centralizado (srv01 y DC, 40 min) — §30.5, Tablas 46 y 47

1. En srv01:
   ```bash
   cd /opt/atlas/tesis/infra/linux && sudo ./instalar.sh 14 14
   ```
   Sale: los cuatro contenedores de Zabbix arriba, la configuración por la API y el estado inicial con atlas-dc01 todavía
   sin respuesta (es lo esperado hasta el punto 2).
2. En el DC (la letra del CD la busca el propio comando):
   ```bash
   vm 120 --timeout 0 -- powershell.exe -NoProfile -Command '$cd=(Get-Volume -FileSystemLabel ATLAS).DriveLetter; & C:\ATLAS\14-agente-zabbix.ps1 -Msi ($cd+":\extras\zabbix_agent2-7.0.32-windows-amd64-openssl.msi")'
   ```
3. En srv01, a los dos minutos: `sudo atlas-ctl monitoreo > ~/E-RED-015-monitoreo-lab.txt`. Todo en PASS: los dos
   agentes responden, el chequeo de `/api/v1/health` en menos de 3 s y el SLA definido.
4. **Interfaz web** (capturas): la interfaz solo escucha en 127.0.0.1 de srv01; se entra con un túnel SSH desde la
   VLAN 50. En dos terminales:
   ```bash
   # Shell de Proxmox
   ssh -i ~/.ssh/atlas_admin -N -L 127.0.0.1:8080:127.0.0.1:8080 atlasadmin@172.16.40.10
   # PowerShell de la PC
   ssh -N -L 8080:127.0.0.1:8080 root@192.168.2.2
   ```
   Abrir `http://127.0.0.1:8080` en la PC, usuario `Admin`; la contraseña está en srv01:
   `sudo grep ZBX_ADMIN /srv/atlas/config/monitoreo.conf` (no capturarla). Capturas: Monitoring → Hosts, Web, Problems
   y Services → SLA report.
5. **Alerta real**: `sudo atlas-ctl detener`, esperar 3 minutos, ver el problema «ATLAS no responde» en Problems,
   `sudo atlas-ctl iniciar` y ver que se resuelve. Captura de los dos momentos.

### R-7 · VPN WireGuard: pruebas 14, 15 y 16 (router-lab, PC y Proxmox, 60 min) — Tabla 45

1. Pasar el script a router-lab, desde la Shell de Proxmox:
   ```bash
   scp /root/tesis/infra/proxmox/05-vpn.sh instalador@172.16.50.1:~
   ```
   Si al correrlo dice que faltan las reglas R8/R9, volver a cargar el firewall con el script del repositorio (ya
   acepta la WAN fija): `sudo WAN_IP=10.99.0.2/24 WAN_GW=10.99.0.1 bash 04-router-lab.sh`.
2. En la PC: instalar WireGuard para Windows, **Agregar túnel → Agregar túnel vacío**, nombre `atlas-docente`. La
   aplicación genera la clave privada (no sale de la PC) y muestra la pública: copiarla.
3. En router-lab (`ssh instalador@172.16.50.1` desde Proxmox):
   ```bash
   sudo bash ~/05-vpn.sh agregar docente '<clave pública de la PC>' 10.8.0.130 pc-docente
   ```
   Muestra el túnel para el cliente. En la aplicación, dejar la línea `PrivateKey` que puso la aplicación y completar
   el resto con lo que mostró el script (`Address = 10.8.0.130/32`, `PublicKey` del router, `AllowedIPs = 172.16.40.10/32`,
   `Endpoint = 10.99.0.2:51820`, `PersistentKeepalive = 25`).
4. En la PC (PowerShell como administrador), el camino hacia la WAN de router-lab, que está detrás de Proxmox:
   ```powershell
   route add 10.99.0.0 mask 255.255.255.0 192.168.2.2
   ```
   Activar el túnel.
5. **Prueba 15 (E-RED-008a)**: `Test-NetConnection 172.16.40.10 -Port 443` da `True` y el navegador abre
   `https://172.16.40.10`. En router-lab, `sudo wg show` muestra el último handshake y bytes en los dos sentidos.
6. **Prueba 16 (E-RED-008b)**: con el túnel activo, `Test-NetConnection 172.16.40.10 -Port 22` da `False`. En
   router-lab, mientras se repite: `sudo journalctl -k -f | grep ATLAS-R12` muestra `IN=wg0 SRC=10.8.0.130 ... DPT=22`.
7. **VPN-09, sin NAT (E-RED-008c)**: en srv01, `sudo atlas-ctl logs atlas-web 50 | grep 10.8.0.130`. Las peticiones de
   la prueba 15 aparecen con el origen 10.8.0.130 (la dirección del perfil, no la del router).
8. **Prueba 14, afuera sin VPN (E-RED-014)**: apagar el túnel. Desde la Shell de Proxmox, que tiene una pata en la
   «Internet» de router-lab (vmbr2, 10.99.0.1), mandar el pedido por la WAN:
   ```bash
   ip route add 172.16.40.10/32 via 10.99.0.2
   curl -sk -m 5 https://172.16.40.10/api/v1/health; echo "rc=$?"
   ip route del 172.16.40.10/32 via 10.99.0.2
   ```
   Sale: `rc=28` (tiempo agotado) y en router-lab `ATLAS-R12 IN=ens19 SRC=10.99.0.1 DST=172.16.40.10 ... DPT=443`.
   Mientras la ruta temporal está puesta, el SSH de Proxmox a srv01 tampoco anda: por eso se borra enseguida.
9. **Perfil administración (opcional, R8)**: segundo túnel `atlas-admin` en la PC y
   `sudo bash ~/05-vpn.sh agregar admin '<clave pública>' 10.8.0.10 pc-admin`. Proxmox necesita saber volver a la VPN:
   `ip route add 10.8.0.0/24 via 172.16.50.1`. Con ese túnel, `Test-NetConnection 172.16.50.10 -Port 8006` da `True`
   (la consola de Proxmox, en la VLAN 50) y `https://172.16.40.10` no entra por el túnel.
10. `sudo bash ~/05-vpn.sh estado` (captura). Para dar de baja un dispositivo: `sudo bash ~/05-vpn.sh quitar '<clave>'`.

### R-8 · Circuito completo de ATLAS (cliente-doc y navegador, 60 min) — E-APP-014

1. Como coordinación (admin de ATLAS) en `https://172.16.40.10`: **Grupos** → asignar a Ana González al Grupo 1.
2. Como Ana González (desde cliente-doc, VLAN 20): recargar, abrir el borrador de la actividad y **Publicar** en el
   Grupo 1. Captura del aviso de publicación correcta.
3. Pasar cliente-doc a la VLAN 30 **sin cambiarle la MAC** (si cambia, el DHCP le da otra dirección y Windows pide
   activar de nuevo): en Proxmox, `qm config 140 | grep net0` y copiar la MAC, y después
   `qm set 140 --net0 e1000=<MAC>,bridge=vmbr1,tag=30`. En cliente-doc: `ipconfig /release` y `ipconfig /renew`
   (tiene que quedar en 172.16.30.x).
4. **Registro del 445 desde la VLAN 30 (E-RED-016)**: en router-lab `sudo journalctl -k -f | grep "DPT=445"` y en
   cliente-doc `Test-NetConnection 172.16.40.10 -Port 445` (da `False`, y aparece la línea `ATLAS-R12`).
5. Como Luis Pérez (estudiante) resolver la actividad con un plan anotado de antemano, por ejemplo: pregunta 1 primero
   una opción incorrecta y después la correcta; pregunta 3 incorrecta; el resto correctas. Anotar el puntaje que
   debería dar y capturar la pantalla de resultado.
6. Volver cliente-doc a la VLAN 20 (`tag=20`, misma MAC) y, como Ana González, ver: inicio, el grupo (lista
   «requieren atención» y errores por pregunta), el estudiante (evolución y recomendación), consultas guiadas y
   reportes. Capturas de cada pantalla.

### R-9 · Base de datos en el laboratorio (srv01, 30 min) — devolución de Base de Datos

Todo en srv01, con `sudo`; las contraseñas las usa el contenedor desde su propio entorno.
```bash
T=/opt/atlas/tesis/atlas/database/tools
sudo $T/seguir_intento.sh        > ~/E-BD-019-seguimiento-intento-lab.txt   # punto 1: el intento del paso R-8.5
sudo $T/restaurar_intento.sh     > ~/E-BD-020-restauracion-intento-lab.txt  # punto 3: respaldo, restauración y comparación
sudo $T/metricas.sh              > ~/E-BD-021-metricas-lab.txt              # métricas de la sección 12
```
Sale:
- E-BD-019: una respuesta final por pregunta, el `CAMBIO_OPCION` de la pregunta 1, **una** fila en `resultados` y
  `RESULTADO: OK` (puntaje guardado igual al recalculado e igual al anotado en R-8.5).
- E-BD-020: el intento recuperado por su número con las cuatro huellas iguales (intento, respuestas, interacciones y
  resultado), los tiempos de respaldo y restauración y el último intento recuperado, comparados con RPO 24 h y RTO 4 h.
- E-BD-013 (repetida): los conteos de tablas que muestra E-BD-020 después del circuito.

El punto 2 de la devolución (puntaje guardado contra calculado y rechazo de `atlas_app`) se corre con datos de
desarrollo (`comparar_puntaje.sh`, evidencia E-BD-017); no hace falta repetirlo acá.

### R-10 · Respaldo de la VM completa (Proxmox, 30 min) — E-BD-015

```bash
df -h /var/lib/vz
time vzdump 130 --mode snapshot --compress zstd --storage local --notes-template "Hito 3 E-BD-015"
ls -lh /var/lib/vz/dump/ | tail -3
```
Prueba de recuperación sin choque de direcciones (la copia arranca con la placa desconectada):
```bash
time qmrestore /var/lib/vz/dump/<archivo de la 130>.vma.zst 930 --unique
qm set 930 --net0 "$(qm config 930 | sed -n 's/^net0: //p'),link_down=1" && qm start 930
```
Ver en la consola de la 930 que arranca y que `docker ps` muestra la pila. Anotar los dos tiempos (respaldo y
restauración) para compararlos con el RTO de 4 h. Al terminar: `qm stop 930 && qm destroy 930`.

### R-11 · Verificaciones finales (las tres máquinas, 30 min)

```bash
# srv01
cd /opt/atlas/tesis/infra/linux && sudo ./verificar.sh > ~/E-LNX-006-verificacion-hito3.txt; tail -1 ~/E-LNX-006-verificacion-hito3.txt
# DC (desde Proxmox)
vm 120 --timeout 0 -- powershell.exe -NoProfile -Command 'C:\ATLAS\verificar-dc01.ps1 | Tee-Object C:\ATLAS\E-WIN-005-verificacion-hito3.txt | Select-Object -Last 1'
# router-lab
sudo nft list ruleset > ~/E-RED-017-ruleset-hito3.txt
```
Sale: en srv01 todas las secciones en PASS (se agregaron `respaldos` y `monitoreo`); en el DC 68 PASS de la Fase 7
más 5 de la Fase 12, sin FAIL. Si queda algún FAIL, no se corrige a mano: se anota con su motivo.

Traer los archivos a Proxmox con `copiar.sh leer` (son de texto) y de ahí a `docs/evidencias/` por pull request.

### R-12 · Cierre (todos, 20 min)

- Rotar lo que quedó expuesto en el Hito 2: contraseña del administrador de ATLAS (`coordinacion@atlas.local`),
  `adm.prueba.soporte` y `prueba.docente`.
- `history -c` en Proxmox y en router-lab.
- Borrar `/root/atlas.csr` y los `.cer` de Proxmox y `/tmp/*.cer` de srv01.
- Revisar la caída del enlace USB: `dmesg -T | grep -iE 'NETDEV WATCHDOG|reset|Link is Down'` en Proxmox.
- Snapshots `hito3_final` de las cuatro VM.
- Revisar las capturas una por una antes de subirlas: ninguna con contraseñas ni hashes.

## 4. Pruebas y evidencias de esta jornada

| Prueba | Qué se espera | Evidencia | Estado al 12/11 |
|---|---|---|---|
| Prueba 14: afuera → ATLAS sin VPN | Bloqueado, registro `ATLAS-R12 IN=ens19` | E-RED-014 | No ejecutada |
| Prueba 15: afuera → ATLAS por VPN docente | Pasa (R9) | E-RED-008a | No ejecutada |
| Prueba 16: VPN docente → SSH de srv01 | Bloqueado (R12) | E-RED-008b | No ejecutada |
| VPN-09: origen sin traducir | 10.8.0.130 en el registro de nginx | E-RED-008c | No ejecutada |
| Monitoreo: agentes, salud, SLA, alerta | Todo en PASS y alerta al detener ATLAS | E-RED-015 + capturas | No ejecutada (en desarrollo: E-RED-012 y E-RED-013) |
| 445 desde VLAN 30 | Bloqueado con registro | E-RED-016 | No ejecutada |
| Arranque sin Internet | `atlas-ctl salud` responde ok | E-TST-006 | No ejecutada (en desarrollo: E-TST-003) |
| Respaldos automáticos y CT-05 | Copia en el DC, borrado denegado | E-LNX-007 | No ejecutada (en desarrollo: probar-respaldos, 17/17) |
| Retención en el DC | Tarea lista, simulación correcta | E-WIN-006 | No ejecutada (lógica: E-WIN-004) |
| Circuito completo | Publicar, resolver desde VLAN 30, indicadores | E-APP-014 | No ejecutada |
| Seguimiento del intento en la base | Un resultado, puntaje igual al esperado | E-BD-019 | No ejecutada (en desarrollo: E-BD-016) |
| Restauración del intento | Huellas iguales, tiempos frente a RPO/RTO | E-BD-020 + E-BD-013 | No ejecutada (en desarrollo: E-BD-018) |
| Respaldo de la VM | Copia y restauración con tiempos | E-BD-015 | No ejecutada |
| Verificación de srv01 y del DC | Sin FAIL | E-LNX-006, E-WIN-005 | No ejecutada |
