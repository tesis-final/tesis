# Fase 6 — Servidor Linux (atlas-srv01)

| Campo | Valor |
| --- | --- |
| Fecha | 27/09/2026 |
| Estado | **CONFIGURADO y probado en Ubuntu 24.04 real (contenedor)**. Falta EJECUTAR en la VM del laboratorio |
| PDF | §28 (págs. 50–57), Tabla 24–30, Tabla 35–36, §25.5 |
| Decisiones | DEC-02, DEC-05, DEC-06, DEC-07, DEC-13, DEC-18, DEC-19, DEC-20, DEC-21, DEC-R8, CT-03, CT-04, CT-12, CT-14, CT-16 |
| Scripts | [`infra/linux/`](../../infra/linux/) |
| Evidencias | E-LNX-001 (prueba de los scripts), E-LNX-003 (configuración de ATLAS) en `docs/evidencias/C/` |

> **Qué quiere decir cada estado.** *Configurado*: los scripts y archivos existen y están completos. *Probado en contenedor*: se ejecutaron en un Ubuntu 24.04 real dentro de Docker y pasaron. *Ejecutado en la VM*: lo hace el equipo en VirtualBox siguiendo este manual; hasta que no esté la captura, figura como **NO EJECUTADA — requiere laboratorio**.

## 1. Qué hace esta fase, en una frase

Deja atlas-srv01 como lo pide el §28: un Ubuntu Server sin entorno gráfico, con las cuentas técnicas de la Tabla 26, la jerarquía de carpetas y permisos de §28.3 que produce exactamente la Tabla 27, SSH solo desde la VLAN de Gestión, firewall alineado con la Tabla 44, ATLAS corriendo en contenedores como un servicio del sistema, y unido al dominio de Windows.

## 2. Los scripts

Cada script hace una sola cosa, se puede correr más de una vez sin romper nada y dice qué parte del PDF cumple.

| Paso | Script | Qué hace | PDF / decisión |
| --- | --- | --- | --- |
| 1 | `01-sistema-base.sh` | Nombre, zona horaria, paquetes, parches automáticos de seguridad, IP fija con netplan | Tabla 24 |
| 2 | `02-usuarios-grupos.sh` | 5 grupos y 4 usuarios con sus GID/UID/shell; clave pública de atlasadmin | Tabla 25, Tabla 26 |
| 3 | `03-directorios-permisos.sh` | Árbol `/srv/atlas`, dueños y modos, ACL, `chattr +i/+a` | §28.3, Tabla 27, DEC-06 |
| 4 | `04-acceso-ssh.sh` | sshd endurecido + TCP Wrappers | §28.4, DEC-07 |
| 5 | `05-firewall.sh` | UFW + cadena DOCKER-USER | §28.4, DEC-05, CT-04 |
| 6 | `06-docker.sh` | Docker Engine configurado | §25.5, DEC-02, DEC-21 |
| 7 | `07-atlas.sh` | `atlas.conf` con secretos aleatorios, certificado, copia de la app, `atlas.service`, primer administrador | CT-03, CT-12, DEC-20 |
| 8 | `08-hora.sh` | chrony contra el DC | Tabla 35, DEC-R8 |
| 9 | `09-dominio.sh` | Unión al dominio con SSSD; GG_SoporteTI → atlas-admin | Tabla 35, Tabla 36, DEC-13, DEC-18 |
| 10 | `10-samba.sh` | `\\atlas-srv01\administracion` y `\\atlas-srv01\docentes` | Tabla 35, CT-10 |
| 11 | `11-registros.sh` | journald persistente, auditd, logrotate | §28.3, §30.5 |
| 12 | `12-sudo.sh` | sudo acotado + `atlas-ctl` | DEC-21 |
| — | `instalar.sh` | Corre los pasos en orden (`sudo ./instalar.sh 3 5` corre solo del 3 al 5) | — |
| — | `verificar.sh` | Revisa todo y escribe PASS/FAIL por ítem (evidencia) | todas |
| — | `instalar-certificado.sh` | Instala el certificado firmado por ATLAS-CA | DEC-20 |
| — | `desplegar-app.sh` | Copia la aplicación a `/srv/atlas/web` y reaplica las ACL | fase-02 §3 |
| — | `pruebas/probar-en-contenedor.sh` | Prueba los scripts en un Ubuntu 24.04 real antes de ir a la VM | — |

`parametros.conf` tiene todos los valores (IP, dominio, redes). **No tiene ninguna contraseña**: los secretos se generan en el servidor y quedan solo en `/srv/atlas/config/atlas.conf`.

## 3. Manual paso a paso (VM en VirtualBox)

### 3.1 Crear la VM

| Opción | Valor | Por qué |
| --- | --- | --- |
| Nombre | atlas-srv01 | Tabla 24 |
| Sistema | Ubuntu Server 24.04 LTS (ISO oficial) | Tabla 24 |
| CPU / RAM / disco | Recomendado: 2 vCPU, 4 GB, 30 GB (ext4) | MySQL + PHP + Python en contenedores. **El hardware real del laboratorio sigue pendiente (J.3)** |
| Adaptador 1 | Durante la instalación: **NAT** (para bajar paquetes). Después: la red del laboratorio (red interna/GNS3 hacia el puerto Fa0/21 de atlas-sw01) | Tabla 41 |

Durante la instalación de Ubuntu:

1. Elegir "Ubuntu Server (minimized)" **no**; la instalación normal sin entorno gráfico está bien.
2. Crear el usuario del instalador, por ejemplo `instalador`. Esta cuenta queda como **acceso de emergencia por consola** (tiene sudo completo, pero SSH no la deja entrar).
3. Marcar "Install OpenSSH server".
4. Disco: ext4 (los atributos `chattr` necesitan ext4; no usar un sistema de archivos que no los soporte).

### 3.2 Traer los repositorios

```bash
sudo apt update && sudo apt install -y git
sudo git clone https://github.com/SVinas73/tesis /opt/atlas/tesis
sudo git clone https://github.com/SVinas73/atlas-analysis /opt/atlas/atlas-analysis
cd /opt/atlas/tesis/infra/linux
```

### 3.3 La clave pública de atlasadmin

En la **estación de administración** (VLAN 50), no en el servidor:

```bash
ssh-keygen -t ed25519 -C "atlasadmin@estacion-gestion"
```

Copiar **solo** el archivo `.pub` al servidor como `/root/atlasadmin.pub` (por ejemplo con un pendrive o pegando el contenido). La clave privada nunca sale de la estación.

### 3.4 Correr los pasos

Mientras la VM está en NAT, la IP fija todavía no sirve (no hay router). Por eso el paso 1 se corre primero sin tocar la red:

```bash
sudo ATLAS_APLICAR_RED=no ./instalar.sh 1 7     # sistema, usuarios, permisos, SSH, firewall, Docker, ATLAS
```

Mientras no exista la IP del laboratorio, el paso 7 la agrega un momento en la interfaz `lo` para poder levantar y probar ATLAS dentro de la VM (se avisa en pantalla).

Después se apaga la VM, se cambia el adaptador a la red del laboratorio y:

```bash
sudo ./01-sistema-base.sh                        # ahora sí aplica 172.16.40.10/24
sudo reboot                                      # Docker vuelve a publicar 443 sobre la IP real
sudo ./instalar.sh 8 8                           # hora (necesita el DC encendido)
sudo ATLAS_USUARIO_UNION=<cuenta de Soporte TI> ./instalar.sh 9 12
sudo ./verificar.sh | tee /tmp/E-LNX-002-verificacion-vm.txt
```

El paso 7 muestra **una sola vez** la contraseña del primer administrador de ATLAS. Guardarla en el gestor de contraseñas del equipo.

### 3.5 Certificado de ATLAS-CA (después de la Fase 7)

1. Copiar `/srv/atlas/config/tls/atlas.csr` al DC.
2. En el DC: `10-certificado-srv01.ps1` (Fase 7) devuelve `atlas-srv01.cer` y `ATLAS-CA.cer`.
3. En srv01: `sudo ./instalar-certificado.sh atlas-srv01.cer ATLAS-CA.cer`.

El script comprueba que el certificado corresponde a la clave del servidor, que lo firmó ATLAS-CA y que tiene la IP 172.16.40.10 en el SAN; si algo no coincide, no instala nada.

## 4. Permisos: cómo se llega a la Tabla 27

El PDF da dos cosas que no coinciden del todo (DISC-07): los dueños y modos de §28.3, y la matriz de la Tabla 27. La decisión DEC-06 fue: **la Tabla 27 es el resultado a lograr**, sin cambiar los dueños ni los modos de §28.3. Eso se logra con ACL.

| Recurso | Dueño y modo (§28.3) | ACL que agrega el script | Resultado medido (admin · web · db · backup · audit) |
| --- | --- | --- | --- |
| `/srv/atlas/` | atlasadmin:atlas-admin 750 | `--x` para atlas-web, atlas-db, atlas-backup, atlas-audit (solo atravesar) | — |
| `web/` | atlasweb:atlas-web 750 | atlas-admin `rwx`, atlas-backup `r-x` | rwx · rwx\* · --- · r-x · --- |
| `datos/` | atlasdb:atlas-db 770 | atlas-admin `rwx`, atlas-backup `r-x` (§28.3: `u:atlasbkp:rx`) | rwx · --- · rwx · r-x · --- |
| `logs/` | atlasadmin:atlas-admin 770 | atlas-web `-wx`, atlas-db `-wx`, atlas-backup `r-x`, atlas-audit `r-x` | rwx · -wx · -wx · r-x · r-x |
| `scripts/` | atlasadmin:atlas-admin 750 | atlas-backup `r-x` | rwx · --- · --- · r-x · --- |
| `backups/` | atlasbkp:atlas-backup 700 | atlas-admin `r-x` (el admin **no** escribe acá, p. 52) | r-x · --- · --- · rwx · --- |
| `config/` | atlasadmin:atlas-admin 750 | atlas-web, atlas-db, atlas-backup `r-x` | rwx · r-x · r-x · r-x · --- |

Tres reglas para leer la tabla:

- **"r--" sobre una carpeta se implementa como r-x.** Sin la `x` no se puede abrir nada de lo que hay adentro, así que "puede leer" no se cumpliría.
- **La columna "admin" es el grupo atlas-admin**, no solo el usuario atlasadmin. Así también vale para Soporte TI, que entra a ese grupo por la Tabla 36.
- **\* web/ para el servicio web.** §28.3 hace a atlasweb dueño de `web/` (el dueño siempre tiene rwx en 750), pero la Tabla 27 pide r-x. Se cumplen las dos cosas: en disco atlasweb sigue siendo el dueño, y los contenedores montan el código **en solo lectura** (`:ro` en `docker-compose.yml`). El servicio web no puede modificar su propio código aunque lo ataquen (CT-14). `verificar.sh` comprueba las dos cosas.

Un detalle que confunde la primera vez: cuando una carpeta tiene ACL, `ls -l` muestra un `+` y en el lugar del grupo muestra la **máscara** de la ACL, no el permiso del grupo dueño. Por eso `ls -l /srv/atlas` puede decir `drwxr-x---+` o `drwxrwx---+`. El modo real de §28.3 se ve con `getfacl /srv/atlas` (líneas `user::`, `group::`, `other::`), y así lo mide `verificar.sh`.

### Atributos

| Archivo | Atributo | Qué significa | Cómo se cambia legítimamente |
| --- | --- | --- | --- |
| `config/atlas.conf` | `+i` (inmutable) | Nadie, ni root, lo modifica sin sacar primero el atributo | `sudo atlas-ctl desbloquear-config` → editar → `sudo atlas-ctl bloquear-config` |
| `logs/auditoria.log` | `+a` (solo agregar) | Se pueden sumar líneas, no borrarlas ni vaciar el archivo | Ver "Rotar auditoria.log" en §7 |

El PDF dice que sacar el atributo "también queda registrado". Para que eso sea cierto, el paso 11 instala una regla de **auditd** que registra cada uso de `chattr` (`sudo ausearch -k atlas-atributos`).

## 5. Quién puede conectarse (dos capas, más una tercera)

| Capa | Qué deja pasar | Dónde |
| --- | --- | --- |
| Firewall de red (rt01, fw01) | Tabla 44 | Fases 8 y 9 |
| **UFW** en srv01 | 22 desde VLAN 50 · 443 desde VLAN 10, 20, 30 y VPN docentes · 445 desde VLAN 10, 20 y el DC | `05-firewall.sh` |
| **DOCKER-USER** | El 443 que publica Docker, con los mismos orígenes | `05-firewall.sh` |
| **TCP Wrappers** | sshd solo desde 172.16.50.0/24 | `04-acceso-ssh.sh` |
| **sshd** | atlasadmin desde VLAN 50 (§28.4, literal) y, además, GG_SoporteTI desde VLAN 50 (DEC-07). Sin root y sin contraseñas | `04-acceso-ssh.sh` |

**Por qué hace falta DOCKER-USER.** Docker publica los puertos con reglas propias que se ejecutan *antes* que las de UFW. Si solo existiera UFW, el 443 de ATLAS quedaría abierto para cualquier red, por ejemplo la VLAN 50, que según la Tabla 44 no puede entrar por HTTPS. La prueba E-LNX-001 lo demuestra: con DOCKER-USER, la VLAN 50 no llega; si se vacía esa cadena, sí llega. Al recargar UFW, vuelve a quedar bloqueada.

**Diferencias con el texto de §28.4 (DEC-05).** El PDF abre 80 y 139 y deja afuera a la VLAN 10 y a la VPN docente. La Tabla 44 (que define la red completa) no permite 80 ni 139 y sí permite 443 desde VLAN 10 y desde la VPN docente. Se siguió la Tabla 44.

## 6. Trazabilidad

| Requisito | Implementación | Prueba | Evidencia | Estado |
| --- | --- | --- | --- | --- |
| Tabla 24: Ubuntu 24.04, atlas-srv01, 172.16.40.10/24 | `01-sistema-base.sh`, `archivos/netplan-atlas.yaml.tpl` | `hostnamectl`, `ip a`, `ip r` | E-LNX-002 | NO EJECUTADA — requiere laboratorio |
| Tabla 25 y 26: grupos y usuarios | `02-usuarios-grupos.sh` | `verificar.sh usuarios` (12 ítems) | E-LNX-001 | PASS (contenedor) |
| §28.3: árbol, dueños y modos | `03-directorios-permisos.sh` | `verificar.sh permisos` (9 carpetas) | E-LNX-001 | PASS (contenedor) |
| Tabla 27: permisos efectivos | ACL de `03-…` + `:ro` en compose | Matriz medida como cada cuenta, celda por celda (30 celdas) | E-LNX-001 | PASS (contenedor) |
| §28.3: `chattr +i` y `+a` | `03-…` | Root no puede vaciar `auditoria.log` ni tocar `atlas.conf`; sí puede agregar una línea | E-LNX-001 | PASS (ext4 real) |
| §28.3: sacar el atributo queda registrado | `archivos/auditd-atlas.rules` | `ausearch -k atlas-atributos` | E-LNX-002 | NO EJECUTADA — requiere laboratorio |
| §28.4: sshd | `archivos/sshd-10-atlas.conf` | `sshd -T` + conexiones SSH reales: atlasadmin desde VLAN 50 entra; root, un usuario ajeno y cualquiera desde VLAN 30 no | E-LNX-001 | PASS (contenedor) |
| §28.4: TCP Wrappers | `archivos/hosts.allow`, `hosts.deny` | Desde VLAN 30 la conexión se corta antes de autenticar (sin firewall) | E-LNX-001 | PASS (contenedor) |
| §28.4 + DEC-05: UFW | `05-firewall.sh` | `verificar.sh firewall` (14 ítems) + puertos 22/80/139/3306 cerrados desde VLAN 30 | E-LNX-001 | PASS (contenedor) |
| R-01 / CT-04: Docker no saltea el firewall | `archivos/ufw-docker-user.rules.tpl` | Simulación de la DNAT de Docker: VLAN 30 llega a 443, VLAN 50 no; contraprueba sin la cadena | E-LNX-001 | PASS (contenedor) |
| §28.4: MySQL no accesible desde la red | compose sin puerto 3306 + red interna | `verificar.sh atlas` | E-APP-006 (desarrollo), E-LNX-002 | PASS en desarrollo; VM pendiente |
| CT-12: secretos fuera del código | `07-atlas.sh` | 6 contraseñas aleatorias de 32 caracteres, todas distintas; `atlas.conf` 640 | E-LNX-003 | PASS (contenedor) |
| DEC-20: certificado con SAN IP | `07-atlas.sh`, `instalar-certificado.sh` | CSR válido con DNS + IP; rechaza un certificado de otra clave | E-LNX-003 | PASS (contenedor, con CA de prueba) |
| CT-03: ATLAS como servicio | `archivos/atlas.service` | `systemctl is-active atlas` | E-LNX-002 | NO EJECUTADA — requiere laboratorio |
| Tabla 35: hora desde el DC | `08-hora.sh` | `chronyc sources` | E-LNX-002 | NO EJECUTADA — requiere laboratorio |
| Tabla 35/36: dominio con SSSD, GG_SoporteTI → atlas-admin | `09-dominio.sh`, `archivos/sssd.conf.tpl`, `pam-group.conf` | Mapeo probado con un grupo local que representa a GG_SoporteTI: el usuario entra por SSH y recibe atlas-admin y atlas-audit. La unión real al dominio necesita el DC | E-LNX-001 (mapeo), E-LNX-002 (dominio) | Mapeo PASS; dominio NO EJECUTADO |
| Tabla 35: Samba | `10-samba.sh`, `archivos/smb.conf.tpl` | `testparm` sin errores; recursos y sin NetBIOS | E-LNX-001 | PASS (config); acceso con usuarios de AD NO EJECUTADO |
| DEC-21: sudo acotado | `12-sudo.sh`, `archivos/sudoers-atlas`, `atlas-ctl` | atlasadmin no puede abrir una shell de root; `visudo -c` | E-LNX-001 | PASS (contenedor) |

## 7. Operación diaria (manual de operación, parte Linux)

| Tarea | Comando |
| --- | --- |
| Ver si ATLAS está bien | `sudo atlas-ctl estado` · `sudo atlas-ctl salud` |
| Ver los logs de un contenedor | `sudo atlas-ctl logs atlas-php 200` |
| Reiniciar ATLAS | `sudo atlas-ctl reiniciar` |
| Cambiar la configuración | `sudo atlas-ctl desbloquear-config` → editar `/srv/atlas/config/atlas.conf` con tu usuario → `sudo atlas-ctl bloquear-config` |
| Activar el LLM (Groq) | Igual que el anterior, completando `LLM_API_KEY` |
| Ver qué bloqueó el firewall | `sudo journalctl -k | grep -E 'UFW BLOCK|ATLAS DOCKER-USER'` o `/var/log/ufw.log` |
| Ver quién usó chattr | `sudo ausearch -k atlas-atributos -i` |
| Revisar todo | `sudo atlas-verificar` |
| Actualizar ATLAS después de un `git pull` | `sudo /opt/atlas/tesis/infra/linux/desplegar-app.sh /opt/atlas/tesis /opt/atlas/atlas-analysis && sudo atlas-ctl reiniciar` |

**Rotar `auditoria.log`** (por ejemplo, una vez por semestre). Es la única tarea que necesita la cuenta de emergencia, porque implica sacar el `+a`:

1. Desde la consola de VirtualBox, con la cuenta del instalador: `sudo chattr -a /srv/atlas/logs/auditoria.log`
2. `sudo mv /srv/atlas/logs/auditoria.log /srv/atlas/logs/auditoria-$(date +%F).log`
3. `sudo ./03-directorios-permisos.sh` (crea el archivo nuevo con sus ACL y le pone `+a` otra vez)
4. `sudo chattr +a /srv/atlas/logs/auditoria-*.log` (el archivo viejo también queda protegido)
5. Anotarlo en el registro de cambios. auditd ya lo dejó registrado.

## 8. Problemas comunes

| Síntoma | Causa probable | Qué hacer |
| --- | --- | --- |
| `sshd -t` da error y el paso 4 se detiene | Un error de tipeo en `10-atlas.conf` | Leer la línea que indica; el script no recarga sshd con errores, así que la sesión actual no se corta |
| "Permission denied (publickey)" desde VLAN 50 | La clave de la estación no es la que está en `authorized_keys`, o la estación no tiene IP de 172.16.50.0/24 | `ssh -v atlasadmin@172.16.40.10` muestra qué clave ofrece; `ip a` en la estación |
| "Connection reset" o cuelgue desde VLAN 50 | TCP Wrappers o UFW no ven a la estación en 172.16.50.0/24 (¿NAT en el medio?) | `sudo journalctl -u ssh` en srv01 muestra "refused connect from …" con la IP real |
| `ls -l` muestra 770 en lugar de 750 | Es la máscara de la ACL, no un error (ver §4) | `getfacl <carpeta>` |
| `chattr: Operation not supported` | El disco no es ext4 | Reinstalar con ext4 |
| No se puede editar `atlas.conf` ni como root | Tiene `+i`, es lo esperado | `sudo atlas-ctl desbloquear-config` |
| ATLAS responde en la VM pero no desde VLAN 30 | Falta una regla en el router (Fase 9) o DOCKER-USER bloquea porque la interfaz no es la detectada | `sudo iptables -L DOCKER-USER -v -n` (¿suben los contadores de DROP?); revisar `ATLAS_IFACE` |
| `realm join` falla con "Clock skew too great" | Diferencia de hora mayor a 5 minutos con el DC | Paso 8 y `chronyc tracking` |
| `realm join` falla con "Couldn't find a domain controller" | srv01 no usa 172.16.40.20 como DNS | `resolvectl status`; volver a correr el paso 1 |
| SSSD no muestra `gg_soporteti` | Caché o nombre distinto en AD | `sudo sss_cache -E && getent group gg_soporteti`; revisar `/var/log/sssd/` |
| Samba: "NT_STATUS_ACCESS_DENIED" | El usuario no está en el grupo de AD del recurso, o su equipo no está en VLAN 10/20 | `sudo tail /var/log/samba/log.<equipo>` |

## 9. Hallazgos de esta fase

| ID | Hallazgo | Qué se hizo |
| --- | --- | --- |
| H6-01 | Con 750 y dueño atlasweb, `web/` siempre da rwx al servicio web; la Tabla 27 pide r-x | CT-14: montaje de solo lectura en los contenedores (ya estaba en compose); se verifica |
| H6-02 | Con ACL, `stat`/`ls` muestran la máscara en lugar del grupo; la primera versión del verificador daba falsos FAIL | El verificador lee `user::`, `group::`, `other::` de `getfacl` |
| H6-03 | `parametros.conf` pisaba las variables de entorno (`ATLAS_IFACE`, `ATLAS_APLICAR_RED`) | Ahora respetan el valor del entorno; lo detectó la prueba de DOCKER-USER |
| H6-04 | Un editor abierto con sudo permite ejecutar comandos como root | `atlas-ctl` no abre editores: saca y pone el `+i`, y se edita con el usuario propio |
| H6-05 | `journalctl` y `systemctl status` con sudo abren un paginador desde el que se puede lanzar una shell | En sudoers van con `NOEXEC:` |
| H6-06 | Un script privilegiado en `/srv/atlas/scripts` sería editable por atlasadmin y, con sudo, daría root | Las herramientas de sudo están en `/usr/local/sbin` (de root) |
| H6-07 | El PDF dice que sacar un atributo "queda registrado", pero nada lo registraba | Regla de auditd sobre `chattr` |
| H6-08 | Docker elegiría solo sus redes internas | CT-16: `bip` y `default-address-pools` en 192.168.250–251.x |

## 10. Para la defensa oral

- **¿Por qué los usuarios de servicio tienen `/usr/sbin/nologin`?** Porque son cuentas de procesos, no de personas. Aunque alguien consiguiera su contraseña, no podría abrir una sesión (§28.2).
- **¿Por qué el administrador no puede escribir en `backups/`?** Lo primero que hace un atacante que toma la cuenta administrativa es borrar los respaldos. Si esa cuenta no puede escribir ahí, los respaldos sobreviven (p. 52). La copia en Windows tampoco se puede borrar desde Linux (CT-05, Fase 12).
- **¿Qué es una ACL y por qué no alcanza con chmod?** `chmod` distingue solo dueño, grupo y otros. La Tabla 27 le da acceso a cinco perfiles distintos sobre la misma carpeta; eso solo se puede expresar con ACL.
- **¿Para qué el `chattr +a` si ya hay permisos?** Los permisos no frenan a root. El atributo sí: para borrar huellas, un atacante tendría que sacarlo primero, y eso queda registrado por auditd.
- **¿Por qué dos firewalls (UFW y el de red)?** Defensa en profundidad: si alguien cambia por error una regla del router, el servidor igual rechaza lo que no corresponde (§28.4). Y TCP Wrappers y sshd son una tercera capa.
- **¿Qué es DOCKER-USER?** Docker abre sus puertos por un camino que UFW no ve. DOCKER-USER es el lugar que Docker reserva para filtrar antes que él. Lo demostramos con una prueba: sin esa cadena, la VLAN 50 llegaba al 443; con la cadena, no.
- **¿Cómo entra Soporte TI si no hay contraseñas por SSH?** Con su cuenta del dominio y un ticket de Kerberos (GSSAPI). atlasadmin entra con clave pública y queda como acceso de emergencia.
