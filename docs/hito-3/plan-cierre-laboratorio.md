# Hito 3 · Plan para cerrar el laboratorio (VPN, monitoreo y DC)

Lo que quedó pendiente después de la jornada del 19/11/2026 y que pesa en la devolución de Gestión:
la **VPN probada con un cliente real**, el **monitoreo con Zabbix** y el **DC con los scripts nuevos**.
Son unas **2 h 30 min**. Al final me pasás las capturas y actualizo el documento.

| Bloque | Qué | Máquinas | Tiempo |
|---|---|---|---|
| 0 | Preparación | PC y Proxmox | 10 min |
| A | DC al día: CD nuevo, scripts nuevos y retención | Proxmox y atlas-dc01 | 25 min |
| B | VPN: pruebas 14, 15 y 16 | router-lab, PC, Proxmox y srv01 | 60 min |
| C | Monitoreo con Zabbix y alerta real | srv01, DC y PC | 45 min |
| D | Verificaciones finales | srv01 y DC | 10 min |

## Reglas para las capturas (las mismas de siempre)

- Guardalas con el nombre de la columna «Archivo». Si una sale distinto de lo esperado, sacala igual y avisame.
- En las terminales escribí `date` antes del comando, así se ve la fecha y la hora.
- **Nunca una contraseña en pantalla.** Ojo con el bloque C: el comando que muestra la contraseña de Zabbix no se captura.
  En la aplicación WireGuard no captures la pantalla de **edición** del túnel, porque ahí se ve la clave privada.

## Cómo llegar a cada máquina

- **Proxmox:** en la PC, `https://192.168.2.2:8006` → nodo `pve` → **Shell**.
- **router-lab:** desde la Shell de Proxmox, `ssh instalador@172.16.50.1`.
- **atlas-srv01:** desde la Shell de Proxmox, `ssh -i ~/.ssh/atlas_admin atlasadmin@172.16.40.10`.
- **atlas-dc01:** desde la Shell de Proxmox con `vm 120 -- …` (como se indica en cada paso) o en la VM → **Console**.

---

## Bloque 0 · Preparación (10 min)

1. **PC:** el iPhone conectado y el uso compartido de Internet activo (`ncpa.cpl`). En el bloque C, srv01 baja las
   imágenes de Zabbix de Internet.
2. **Proxmox:** las cuatro VM encendidas (110, 120, 130 y 140).
3. **Shell de Proxmox:** que srv01 tenga 4 GB de RAM, porque Zabbix los necesita:
   ```bash
   qm config 130 | grep memory
   ```
   Si dice `memory: 3072`: apagá la 130 (`qm shutdown 130`), corré `qm set 130 --memory 4096` y prendela (`qm start 130`).
   Esperá dos minutos a que arranque ATLAS.
4. **Shell de Proxmox:** un punto de vuelta por si algo sale mal:
   ```bash
   qm snapshot 110 antes_cierre; qm snapshot 130 antes_cierre
   ```

---

## Bloque A · DC al día (25 min)

**A1. Repositorio y CD nuevos** (Shell de Proxmox):
```bash
date
bash /root/tesis/infra/proxmox/02-iso-repo.sh
qm set 120 --ide3 local:iso/atlas-repo.iso,media=cdrom
```
Tiene que terminar con el MSI `zabbix_agent2-7.0.32-windows-amd64-openssl.msi` en `/root/tesis/extras/` y la ISO
regenerada. Si avisa que no pudo bajar el MSI: en la PC, bajalo de la página oficial de Zabbix (Download → Zabbix agent →
Windows, agente 2, 7.0 LTS, MSI). Después copialo con `scp archivo.msi root@192.168.2.2:/root/tesis/extras/` y volvé a
correr el script.

| Archivo | Qué se tiene que ver |
|---|---|
| `H3-03-proxmox-iso-repo.png` | El final del script: el MSI en `extras/` y la ISO regenerada |

**A2. Copiar los scripts nuevos al DC** (Shell de Proxmox, en una sola línea):
```bash
vm 120 --timeout 0 -- powershell.exe -NoProfile -Command '$cd=(Get-Volume -FileSystemLabel ATLAS).DriveLetter; Get-ChildItem ($cd+":\infra\windows") -Exclude parametros.psd1 | Copy-Item -Destination C:\ATLAS -Recurse -Force; attrib -r C:\ATLAS\*.ps* ; Get-ChildItem C:\ATLAS\1?-*.ps1 | Select-Object Name'
```
Así se reemplaza el verificador viejo que dio 63/5. `parametros.psd1` no se toca.

| Archivo | Qué se tiene que ver |
|---|---|
| `H3-05-dc-scripts-copiados.png` | En la lista aparecen `13-retencion-respaldos.ps1` y `14-agente-zabbix.ps1` |

**A3. Retención de respaldos en el DC** (Shell de Proxmox):
```bash
vm 120 --timeout 0 -- powershell.exe -NoProfile -File C:\ATLAS\13-retencion-respaldos.ps1
```
Instala la tarea programada y muestra qué se borraría hoy. Como todavía no llegaron respaldos de srv01, lo normal es que
no haya nada para borrar.

| Archivo | Qué se tiene que ver |
|---|---|
| `H3-23-dc-retencion.png` | La tarea instalada y la simulación de lo que se borraría |
| `H3-24-dc-tarea-programada.png` | En la **consola del DC**: Programador de tareas → Biblioteca → carpeta **ATLAS**. La tarea «ATLAS - Retencion de respaldos», diaria a las 05:00, como SYSTEM |

---

## Bloque B · VPN: pruebas 14, 15 y 16 (60 min)

**B1. Script de la VPN en router-lab** (Shell de Proxmox):
```bash
scp /root/tesis/infra/proxmox/05-vpn.sh instalador@172.16.50.1:~
```

**B2. Túnel en la PC.**
1. Instalá **WireGuard para Windows** desde wireguard.com (Download → Windows).
2. **Agregar túnel → Agregar túnel vacío**, con el nombre `atlas-docente`.
3. La aplicación genera la clave privada, que no sale de la PC, y muestra la **clave pública**. Copiá **solo la pública** y
   dejá la ventana abierta.

**B3. Dar de alta la PC en router-lab** (desde la Shell de Proxmox: `ssh instalador@172.16.50.1`):
```bash
date
sudo bash ~/05-vpn.sh agregar docente 'PEGAR_ACÁ_LA_CLAVE_PÚBLICA_DE_LA_PC' 10.8.0.130 pc-docente
```
El script muestra el túnel que va en la PC. En la ventana de WireGuard **dejá la línea `PrivateKey` que ya está** y
completá el resto con lo que mostró el script:
```
Address = 10.8.0.130/32

[Peer]
PublicKey = (la clave pública del router que mostró el script)
AllowedIPs = 172.16.40.10/32
Endpoint = 10.99.0.2:51820
PersistentKeepalive = 25
```
Guardá. Si el script dice que faltan las reglas R8/R9, volvé a cargar el firewall:
`sudo WAN_IP=10.99.0.2/24 WAN_GW=10.99.0.1 bash 04-router-lab.sh`. Después repetí el alta.

| Archivo | Qué se tiene que ver |
|---|---|
| `H3-36-router-vpn-alta.png` | La salida del alta en router-lab (solo hay claves públicas) |

**B4. Camino de la PC hacia la WAN del router.** En la PC abrí **PowerShell como administrador**:
```powershell
route add 10.99.0.0 mask 255.255.255.0 192.168.2.2
route print 10.99.0.0
```
Después, en WireGuard, **Activar** el túnel `atlas-docente`.

| Archivo | Qué se tiene que ver |
|---|---|
| `H3-38-pc-ruta.png` | La ruta a 10.99.0.0/24 por 192.168.2.2 |
| `H3-37-pc-wireguard-activo.png` | La **pantalla principal** de WireGuard (no la de edición): túnel «Activo», endpoint 10.99.0.2:51820 y el último handshake |

**B5. Prueba 15: con VPN, el docente llega a ATLAS.** En PowerShell de la PC, con el túnel activo:
```powershell
date
Test-NetConnection 172.16.40.10 -Port 443
```
Después abrí `https://172.16.40.10` en el navegador de la PC y entrá hasta la pantalla de ingreso.
En router-lab: `date; sudo wg show`.

| Archivo | Qué se tiene que ver |
|---|---|
| `H3-39-pc-prueba15-443.png` | `TcpTestSucceeded : True` |
| `H3-40-pc-prueba15-navegador.png` | La pantalla de ingreso de ATLAS abierta desde la PC por la VPN |
| `H3-41-router-wg-show.png` | El par 10.8.0.130 con «latest handshake» reciente y bytes en los dos sentidos |

**B6. Prueba 16: con VPN, el docente NO llega al SSH del servidor.**
1. En router-lab, dejá corriendo: `sudo journalctl -k -f | grep ATLAS-R12`
2. En PowerShell de la PC: `date; Test-NetConnection 172.16.40.10 -Port 22`
3. Volvé a router-lab y cortá con Ctrl+C después de ver las líneas.

| Archivo | Qué se tiene que ver |
|---|---|
| `H3-42-pc-prueba16-22.png` | `TcpTestSucceeded : False` |
| `H3-43-router-registro-prueba16.png` | Líneas `ATLAS-R12 IN=wg0 … SRC=10.8.0.130 … DPT=22` |

**B7. Sin NAT en la VPN: el servidor ve la dirección del docente.** Desde la Shell de Proxmox, entrá a srv01
(`ssh -i ~/.ssh/atlas_admin atlasadmin@172.16.40.10`):
```bash
date
sudo atlas-ctl logs atlas-web 50 | grep 10.8.0.130
```

| Archivo | Qué se tiene que ver |
|---|---|
| `H3-44-srv01-vpn-sin-nat.png` | Peticiones de la prueba 15 con origen 10.8.0.130 |

**B8. Prueba 14: desde afuera y sin VPN, ATLAS no responde.**
1. En la PC, **desactivá** el túnel en WireGuard.
2. En router-lab, dejá corriendo: `sudo journalctl -k -f | grep ATLAS-R12`
3. En **otra** pestaña de la Shell de Proxmox (no en la de router-lab), corré los tres comandos seguidos:
   ```bash
   date
   ip route add 172.16.40.10/32 via 10.99.0.2
   curl -sk -m 5 https://172.16.40.10/api/v1/health; echo "rc=$?"
   ip route del 172.16.40.10/32 via 10.99.0.2
   ```
   **El tercer comando es obligatorio.** Mientras esa ruta exista, Proxmox no llega a srv01 por SSH.

| Archivo | Qué se tiene que ver |
|---|---|
| `H3-45-proxmox-prueba14.png` | `rc=28` (tiempo agotado) y la ruta borrada |
| `H3-46-router-registro-prueba14.png` | Líneas `ATLAS-R12 IN=ens19 SRC=10.99.0.1 DST=172.16.40.10 … DPT=443` |

**B9. Estado de la VPN** (router-lab):
```bash
date
sudo bash ~/05-vpn.sh estado
```

| Archivo | Qué se tiene que ver |
|---|---|
| `H3-47-router-vpn-estado.png` | La lista de pares (pc-docente, 10.8.0.130) y las reglas de wg0 |

---

## Bloque C · Monitoreo con Zabbix (45 min)

**C1. Paso 14 en srv01** (sesión SSH en srv01; necesita Internet por el iPhone):
```bash
date
cd /opt/atlas/tesis && sudo git pull
cd infra/linux && sudo ./instalar.sh 14 14
```
Tarda unos minutos la primera vez porque baja las imágenes. Al final, atlas-dc01 aparece sin respuesta: es lo esperado
hasta el paso C3. Después:
```bash
date
sudo docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
sudo ss -ltn '( sport = :8080 or sport = :10050 )'
```

| Archivo | Qué se tiene que ver |
|---|---|
| `H3-26-srv01-instalar-14.png` | El final del paso 14: contenedores levantados y configuración por la API |
| `H3-27-srv01-zabbix-contenedores.png` | zabbix-db, zabbix-server, zabbix-web y zabbix-agent arriba; la interfaz solo en `127.0.0.1:8080` |

**C2. Agente de Zabbix en el DC** (Shell de Proxmox, en una sola línea):
```bash
vm 120 --timeout 0 -- powershell.exe -NoProfile -Command '$cd=(Get-Volume -FileSystemLabel ATLAS).DriveLetter; & C:\ATLAS\14-agente-zabbix.ps1 -Msi ($cd+":\extras\zabbix_agent2-7.0.32-windows-amd64-openssl.msi")'
```

| Archivo | Qué se tiene que ver |
|---|---|
| `H3-28-dc-agente-zabbix.png` | Servicio «Zabbix Agent 2» en marcha, el 10050 escuchando y la regla del firewall solo desde 172.16.40.10 |

**C3. Estado del monitoreo** (srv01, esperá dos minutos después de C2):
```bash
date
sudo atlas-ctl monitoreo
```

| Archivo | Qué se tiene que ver |
|---|---|
| `H3-29-srv01-atlas-ctl-monitoreo.png` | Los dos agentes responden, el chequeo web OK en menos de 3 s y el SLA definido |

**C4. Entrar a la interfaz web de Zabbix desde la PC.** La interfaz solo escucha dentro de srv01, así que se entra con
dos túneles SSH, cada uno en su terminal y abiertos durante todo el bloque:
- **Shell de Proxmox** (pestaña nueva):
  `ssh -i ~/.ssh/atlas_admin -N -L 127.0.0.1:8080:127.0.0.1:8080 atlasadmin@172.16.40.10`
- **PowerShell de la PC** (ventana nueva): `ssh -N -L 8080:127.0.0.1:8080 root@192.168.2.2`

Para ver la contraseña de Admin, en la sesión de srv01 corré `sudo grep ZBX_ADMIN /srv/atlas/config/monitoreo.conf`.
**No captures esa pantalla.** Copiá la contraseña y limpiá la terminal con `clear`.

En la PC abrí `http://127.0.0.1:8080` y entrá con el usuario `Admin` y esa contraseña.

| Archivo | Dónde, en Zabbix | Qué se tiene que ver |
|---|---|---|
| `H3-30-zabbix-hosts.png` | Monitoring → **Hosts** | atlas-srv01 y atlas-dc01 con el ícono ZBX en verde |
| `H3-31-zabbix-ultimos-datos.png` | Monitoring → **Latest data**, filtrando por los dos hosts | CPU, memoria y disco con valores actuales |
| `H3-32-zabbix-web.png` | Monitoring → **Web** → atlas-salud | Estado OK y tiempo de respuesta |

**C5. Alerta real: se apaga ATLAS y Zabbix avisa.**
1. En srv01: `date; sudo atlas-ctl detener`
2. Esperá **3 minutos**. En Zabbix: Monitoring → **Problems**.
3. En srv01: `date; sudo atlas-ctl iniciar`
4. Esperá **2 minutos**. En Problems, poné «Show: **History**» y aplicá.
5. Services → **SLA report**.

| Archivo | Qué se tiene que ver |
|---|---|
| `H3-33-zabbix-alerta.png` | El problema «ATLAS no responde» activo |
| `H3-34-zabbix-alerta-resuelta.png` | El mismo problema en estado RESOLVED |
| `H3-35-zabbix-sla.png` | El SLA «ATLAS · disponibilidad (RNF-02)» con su porcentaje |

Al terminar, cerrá los dos túneles con Ctrl+C.

---

## Bloque D · Verificaciones finales (10 min)

**D1. DC con el verificador nuevo** (Shell de Proxmox):
```bash
date
vm 120 --timeout 0 -- powershell.exe -NoProfile -Command 'C:\ATLAS\verificar-dc01.ps1 | Tee-Object C:\ATLAS\E-WIN-005-verificacion-hito3.txt | Select-Object -Last 20'
```
Con los scripts nuevos tiene que dar 73 controles y ningún FAIL en la Fase 12. Si queda algún FAIL, no lo corrijas a
mano: capturalo, porque se documenta tal cual.

| Archivo | Qué se tiene que ver |
|---|---|
| `H3-74d-dc-verificar-nuevo.png` | Las últimas líneas: la sección de la Fase 12 y el resultado |

**D2. srv01: verificación del monitoreo** (sesión de srv01):
```bash
date
cd /opt/atlas/tesis/infra/linux && sudo ./verificar.sh monitoreo firewall
```

| Archivo | Qué se tiene que ver |
|---|---|
| `H3-74e-srv01-verificar-monitoreo.png` | Las secciones monitoreo y firewall en PASS |

**D3. Limpieza** (no lleva captura):
- PC: `route delete 10.99.0.0` y el túnel de WireGuard desactivado.
- Si todo salió bien, en la Shell de Proxmox borrá los puntos de vuelta: `qm delsnapshot 110 antes_cierre; qm delsnapshot 130 antes_cierre`.

---

## Qué me pasás al final

Las capturas con estos nombres: **H3-03, 05, 23, 24, 26 a 47 (salvo la 48) y H3-74d y 74e**. Si no te da el tiempo
para todo, el orden de prioridad es **B (VPN)**, después **D1 con A2 (DC)** y por último **C (Zabbix)**. Con lo que
llegues a hacer actualizo el documento, y lo que no se haga sigue como *No ejecutada*.
