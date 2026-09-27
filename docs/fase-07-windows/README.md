# Fase 7 — Servidor Windows (atlas-dc01)

| Campo | Valor |
| --- | --- |
| Fecha | 27/09/2026 |
| Estado | **CONFIGURADO y validado sin Windows** (analizador de PowerShell y pruebas de la lógica). Falta EJECUTAR en la VM del laboratorio |
| PDF | §29 (págs. 58–62), Tabla 31–37 |
| Decisiones | DEC-R1, DEC-R2, DEC-R8, DEC-07, DEC-08, DEC-09, DEC-17, DEC-18, DEC-20, CT-05, CT-09, CT-10 |
| Scripts | [`infra/windows/`](../../infra/windows/) |
| Evidencias | E-WIN-001 (análisis estático y pruebas de lógica) en `docs/evidencias/D/` |

> A diferencia de Linux, un Windows Server no se puede levantar dentro de este entorno de trabajo. Por eso lo que se pudo **verificar** acá es: que los 18 archivos de PowerShell no tienen errores de sintaxis, que pasan todas las reglas de PSScriptAnalyzer (la herramienta oficial de Microsoft para revisar scripts) y que la lógica delicada del módulo común funciona. **Todo lo que depende de Active Directory figura como NO EJECUTADO — requiere laboratorio** hasta que el equipo corra `verificar-dc01.ps1` en la VM.

## 1. Qué hace esta fase, en una frase

Convierte una instalación limpia de Windows Server 2022 en atlas-dc01: el controlador del dominio `atlas.local`, con la estructura de OU y grupos del §29.2, las políticas de seguridad de la Tabla 32, las cinco GPO de la Tabla 33, DNS y DHCP según §29.4, carpetas compartidas, una autoridad certificadora interna y el firewall de Windows ajustado a la Tabla 44.

## 2. Los scripts

| Paso | Script | Qué hace | PDF / decisión |
| --- | --- | --- | --- |
| 1 | `01-red-y-nombre.ps1` | IP fija 172.16.40.20/24, zona horaria, nombre atlas-dc01 (reinicia) | Tabla 31, Tabla 40 |
| 2 | `02-promover-dc.ps1` | Crea el bosque y el dominio atlas.local con DNS integrado (reinicia) | §29.1 |
| 3 | `03-estructura-ad.ps1` | OU, grupos GG_\*, cuenta svc_atlas_backup, delegación a GG_SoporteTI | §29.2, Tabla 32, CT-09 |
| 4 | `04-politicas-seguridad.ps1` | GPO_Seguridad_Base y GPO_Auditoria; Administrator renombrada, Guest deshabilitada | Tabla 32, Tabla 33 |
| 5 | `05-dns.ps1` | Zona inversa, registros de srv01 y dc01, reenviadores | §29.4 |
| 6 | `06-dhcp.ps1` | 3 ámbitos con puerta de enlace, DNS y sufijo | Tabla 34 |
| 7 | `07-gpo.ps1` | GPO_Estudiantes, GPO_Docentes, GPO_Servidores | Tabla 33, DEC-08 |
| 8 | `08-recursos-compartidos.ps1` | `\\atlas-dc01\estudiantes` y `\\atlas-dc01\atlas-backups` | DEC-08, CT-05, CT-09 |
| 9 | `09-ca-atlas.ps1` | Autoridad certificadora interna ATLAS-CA | DEC-20 |
| 10 | `10-certificado-srv01.ps1` | Firma el certificado HTTPS de atlas-srv01 | DEC-20 |
| 11 | `11-firewall-y-hora.ps1` | Firewall de Windows, fuente de hora, rango RPC | AMB-19, DEC-R8, DEC-17 |
| 12 | `12-usuarios.ps1` | Cuentas desde un CSV (cuentas administrativas separadas) | Tabla 32 |
| — | `instalar.ps1 -Etapa 1/2/3` | Corre todo en orden, en tres etapas por los reinicios | — |
| — | `verificar-dc01.ps1` | PASS/FAIL por ítem (≈ 70 comprobaciones) | todas |
| — | `clientes/unir-al-dominio.ps1` | Une un equipo de VLAN 10/20/30 en la OU que corresponde según su IP | §29.2 |
| — | `AtlasComun.psm1` | Funciones comunes (plantillas de seguridad de GPO, unidades de red, versiones) | — |
| — | `parametros.psd1` | Todos los valores del PDF. **Sin contraseñas** | — |

Ninguna contraseña está escrita en los scripts: las que hacen falta se piden en pantalla (DSRM) o se generan al azar y se muestran una sola vez (svc_atlas_backup, cuentas nuevas).

## 3. Manual paso a paso (VM en VirtualBox)

### 3.1 Crear la VM

| Opción | Valor | Por qué |
| --- | --- | --- |
| Nombre | atlas-dc01 | Tabla 31 |
| Sistema | Windows Server 2022 Standard, **Experiencia de escritorio** | Tabla 31. La ISO todavía está pendiente (J.3) |
| CPU / RAM / disco | Recomendado: 2 vCPU, 4 GB, 50 GB | AD + DNS + DHCP + CA. **Hardware real pendiente (J.3)** |
| Adaptador | La red del laboratorio hacia el puerto Fa0/22 de atlas-sw01 | Tabla 41 |
| Guest Additions | Instaladas | Además de comodidad, sincronizan el reloj con el equipo anfitrión (ver §5) |

### 3.2 Traer los scripts

Descargar el repositorio como ZIP desde GitHub (`Code → Download ZIP`), descomprimir en `C:\ATLAS\tesis` y, en PowerShell **como administrador**:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Get-ChildItem C:\ATLAS\tesis -Recurse | Unblock-File
cd C:\ATLAS\tesis\infra\windows
```

### 3.3 Correr en tres etapas

```powershell
.\instalar.ps1 -Etapa 1      # IP, nombre → reinicia
.\instalar.ps1 -Etapa 2      # dominio (pide la contraseña DSRM) → reinicia
# Entrar como ATLAS\Administrator
.\instalar.ps1 -Etapa 3      # estructura, seguridad, DNS, DHCP, GPO, carpetas, CA, firewall + verificación
```

En la etapa 3 aparece **una sola vez** la contraseña de `svc_atlas_backup`: se guarda en el gestor de contraseñas del equipo y después se usa en atlas-srv01 (Fase 12).

Desde la etapa 3 la cuenta Administrator pasa a llamarse `atlas.emergencia` y queda **solo para emergencias**.

### 3.4 Cuentas de las personas

Completar un CSV como `usuarios-ejemplo.csv` (el de ejemplo trae cuatro cuentas de prueba, una por perfil) y:

```powershell
.\12-usuarios.ps1 -Csv .\usuarios-ejemplo.csv
```

Cada integrante de Soporte TI recibe **dos** cuentas: la de uso diario (`juan.perez`) y la administrativa (`adm.juan.perez`, en GG_SoporteTI). Eso es "cuentas administrativas separadas de las de uso diario" (Tabla 32). Las contraseñas iniciales quedan en `C:\ATLAS\credenciales-iniciales-*.csv`, que solo los administradores pueden abrir: se entregan y **se borra el archivo**.

Las cuentas del dominio sirven para iniciar sesión en Windows y usar las carpetas compartidas. **Las cuentas de la plataforma ATLAS son otras** y se crean dentro de ATLAS (RF-01, §28.2).

### 3.5 Certificado de atlas-srv01

Cuando atlas-srv01 genere su pedido (Fase 6, paso 7):

```powershell
.\10-certificado-srv01.ps1 -Csr C:\ATLAS\atlas.csr
```

Devuelve `C:\ATLAS\atlas-srv01.cer` y `C:\ATLAS\ATLAS-CA.cer`, que se copian a srv01 para `instalar-certificado.sh`.

### 3.6 Unir los equipos de prueba

En cada cliente Windows de VLAN 10, 20 o 30 (después de recibir IP por DHCP):

```powershell
.\clientes\unir-al-dominio.ps1
```

El script mira la IP y lo deja en `OU=Equipos` de Administración, Docentes o Estudiantes, como pide §29.2. Así le llegan las GPO que corresponden.

### 3.7 Verificar y guardar la evidencia

```powershell
.\verificar-dc01.ps1 | Tee-Object C:\ATLAS\E-WIN-002-verificacion-dc01.txt
```

Un ítem que va a dar FAIL mientras no se complete J.2: **"Reenviadores configurados"**. Sin reenviadores, el DC resuelve Internet con las sugerencias de raíz (la regla 7 le permite DNS hacia afuera), así que funciona igual.

## 4. Qué configura cada parte, explicado

### Estructura del directorio (§29.2)

```
atlas.local
├── OU=ATLAS
│   ├── OU=Administracion ── OU=Usuarios · OU=Equipos
│   ├── OU=Docentes ─────── OU=Usuarios · OU=Equipos
│   ├── OU=Estudiantes ──── OU=Usuarios · OU=Equipos
│   ├── OU=Servidores        ← atlas-srv01 (se une en la Fase 6)
│   └── OU=ServiciosTI       ← cuentas adm.* y svc_atlas_backup
└── OU=Grupos                ← GG_Administracion, GG_Docentes, GG_Estudiantes, GG_SoporteTI
```

Todas las OU quedan protegidas contra borrado accidental.

### Delegación (Tabla 32: "permisos acotados sobre cada OU, sin privilegios de dominio")

| Quién | Sobre qué | Puede |
| --- | --- | --- |
| GG_SoporteTI | OU=ATLAS y todo lo de adentro | Crear, borrar y administrar usuarios y equipos (resetear contraseñas, desbloquear, unir equipos) |
| GG_SoporteTI | OU=Grupos | Cambiar los miembros de los grupos (no crearlos ni borrarlos) |
| GG_SoporteTI | El dominio | **Nada más**: no es Domain Admins (lo comprueba `verificar-dc01.ps1`) |

### Las cinco GPO (Tabla 33)

| GPO | Vinculada a | Contenido |
| --- | --- | --- |
| GPO_Seguridad_Base | Dominio (orden 1) | Contraseñas (10, complejidad, historial 5, 90 días), bloqueo (5 intentos, 15 min), Administrator renombrada, Guest deshabilitada, auditoría de inicios de sesión y de cuentas, svc_atlas_backup sin inicio de sesión interactivo |
| GPO_Auditoria | Dominio | Registro detallado: cambios en el directorio (evento 5136), acceso a recursos compartidos, cambios de directivas, uso de privilegios, integridad del sistema, creación de procesos; registro de seguridad de 512 MB |
| GPO_Estudiantes | OU Estudiantes | Sin instalación de software (Windows Installer y apps de la Store); unidad **S:** → `\\atlas-dc01\estudiantes` |
| GPO_Docentes | OU Docentes | Unidad **T:** → `\\atlas-srv01\docentes`. Impresoras: fuera de alcance (no hay ninguna en el inventario, DEC-08) |
| GPO_Servidores | OU Servidores **y** Domain Controllers | Sin SMBv1, firma SMB obligatoria, solo NTLMv2, LDAP firmado, sin LLMNR, Escritorio remoto con NLA, actualizaciones que se descargan y se instalan en ventana de mantenimiento |

¿Por qué la auditoría está repartida en dos GPO? Porque la Tabla 33 pone "auditoría" en GPO_Seguridad_Base y "registro detallado" en GPO_Auditoria. Se usa la **auditoría avanzada** (por subcategorías) y cada subcategoría está en una sola GPO: Windows combina las dos sin que una pise a la otra.

### DNS y DHCP (§29.4, Tabla 34)

| Qué | Valor |
| --- | --- |
| Zona directa | atlas.local, integrada en AD, actualizaciones solo seguras, sin transferencias |
| Zona inversa | 16.172.in-addr.arpa (172.16.0.0/16) |
| Registros | atlas-srv01 → 172.16.40.10, atlas-dc01 → 172.16.40.20 (con PTR) |
| Reenviadores | **PENDIENTE (J.2)**; mientras tanto, sugerencias de raíz |
| Ámbito VLAN 10 | 172.16.10.100 – .200, puerta de enlace 172.16.10.1 |
| Ámbito VLAN 20 | 172.16.20.100 – .200, puerta de enlace 172.16.20.1 |
| Ámbito VLAN 30 | 172.16.30.100 – .250, puerta de enlace 172.16.30.1 |
| Opciones comunes | 006 DNS = 172.16.40.20 · 015 sufijo = atlas.local |
| VLAN 40 y 50 | Sin DHCP (IP fijas) |

**Cómo llega un pedido de DHCP desde la VLAN 30** (para explicarlo en la defensa): el equipo grita "¿alguien me da una IP?" (difusión). Esa difusión no sale de la VLAN 30. El router tiene configurado `ip helper-address 172.16.40.20` en su interfaz de la VLAN 30: recibe el grito, lo convierte en un mensaje dirigido al DC y le agrega "esto vino de la red 172.16.30.1" (campo *giaddr*). El DC mira ese dato, elige el ámbito de la VLAN 30 y responde por el mismo camino. Por eso existe la regla 4 de la Tabla 44.

### Carpetas compartidas

| Recurso | Quién | Permisos |
| --- | --- | --- |
| `\\atlas-dc01\estudiantes` | GG_Estudiantes | Cada estudiante crea su carpeta y solo el dueño la modifica; nadie ve carpetas ajenas (enumeración por acceso) |
| `\\atlas-dc01\atlas-backups` | svc_atlas_backup | **Crear** archivos sí; **borrarlos, cambiar sus permisos o apropiárselos, no**. SMB cifrado |
| `\\atlas-srv01\administracion` y `\docentes` | GG_Administracion, GG_Docentes | En Samba, Fase 6 |

La carpeta de respaldos está pensada para el peor caso: si alguien toma el control de atlas-srv01 y de la cuenta de respaldos, puede agregar archivos pero **no borrar las copias que ya están afuera** (CT-05). La limpieza de lo viejo la hace una tarea del propio DC (Fase 12).

### Autoridad certificadora ATLAS-CA (DEC-20)

Una CA raíz de empresa integrada con AD. Todos los equipos del dominio reciben su certificado automáticamente por directiva de grupo, así que el navegador confía en `https://atlas-srv01.atlas.local` sin advertencias (P-01, P-13). Los docentes que se conecten por VPN desde un equipo propio tendrán que importar `ATLAS-CA.cer` a mano (manual de la Fase 10).

### Firewall de Windows (sin reglas de red nuevas, DEC-R8)

| Tráfico entrante | Desde |
| --- | --- |
| Servicios de dominio (53, 88, 464, 389, 636, 3268–3269, 445, 123, 135, RPC 49152–65535) | VLAN 10, 20, 30 y 40 |
| DHCP (UDP 67) | Las IP del router (172.16.10.1, .20.1, .30.1, .40.1) |
| Escritorio remoto (3389) y WinRM | Solo VLAN 50 |
| Todo lo demás | Bloqueado y registrado |

Las reglas se identifican por **puerto**, no por nombre: en un Windows en español los nombres de las reglas cambian y el script tiene que funcionar igual.

## 5. Hora del dominio

El DC es la fuente de hora de todo el dominio con su propio reloj (DEC-R8), porque la Tabla 44 no permite NTP hacia Internet. En VirtualBox, las Guest Additions mantienen el reloj de la VM igual al del equipo anfitrión, así que en la práctica la hora es correcta. Lo que importa para Kerberos es que **todos coincidan entre sí** (tolerancia de 5 minutos): atlas-srv01 sincroniza con el DC (chrony, Fase 6) y los equipos del dominio también (automático).

## 6. Trazabilidad

| Requisito | Implementación | Prueba | Evidencia | Estado |
| --- | --- | --- | --- | --- |
| Tabla 31: Windows Server 2022, atlas-dc01, 172.16.40.20/24 | `01-red-y-nombre.ps1` | `verificar-dc01.ps1` (Servidor) | E-WIN-002 | NO EJECUTADA — requiere laboratorio |
| §29.1: dominio atlas.local | `02-promover-dc.ps1` | ídem (Dominio) | E-WIN-002 | NO EJECUTADA — requiere laboratorio |
| §29.2: OU y grupos | `03-estructura-ad.ps1` | 13 OU + 4 grupos | E-WIN-002 | NO EJECUTADA — requiere laboratorio |
| Tabla 32: contraseñas y bloqueo | `04-…` (GptTmpl.inf) | `Get-ADDefaultDomainPasswordPolicy` (6 ítems) | E-WIN-002 | NO EJECUTADA — requiere laboratorio |
| Tabla 32: cuentas por defecto | `04-…` | Administrator renombrada, Guest deshabilitada | E-WIN-002 | NO EJECUTADA — requiere laboratorio |
| Tabla 32: auditoría | `04-…` (audit.csv + SACL) | `auditpol` por GUID (4 ítems) | E-WIN-002 | NO EJECUTADA — requiere laboratorio |
| Tabla 32: cuentas administrativas separadas | `12-usuarios.ps1` | `adm.*` en ServiciosTI con GG_SoporteTI | E-WIN-002 | NO EJECUTADA — requiere laboratorio |
| Tabla 32: delegación acotada | `03-…` (dsacls) | GG_SoporteTI no es Domain Admins | E-WIN-002 | NO EJECUTADA — requiere laboratorio |
| Tabla 33: 5 GPO | `04-…`, `07-gpo.ps1` | Vínculos y valores (10 ítems) | E-WIN-002 | NO EJECUTADA — requiere laboratorio |
| §29.4: DNS | `05-dns.ps1` | Zonas, A, PTR, sin transferencias | E-WIN-002 | NO EJECUTADA — requiere laboratorio |
| Tabla 34: DHCP | `06-dhcp.ps1` | 3 ámbitos + opciones 003/006/015 | E-WIN-002; P-15 (Fase 14) | NO EJECUTADA — requiere laboratorio |
| DEC-08: carpeta de estudiantes | `08-…` | Recurso existe | E-WIN-002 | NO EJECUTADA — requiere laboratorio |
| CT-05: respaldos sin borrado | `08-…` | ACL sin Delete/Modify para la cuenta de servicio | E-WIN-002, E-BKP (Fase 12) | NO EJECUTADA — requiere laboratorio |
| DEC-20: ATLAS-CA | `09-…`, `10-…` | CA instalada; certificado con SAN IP | E-WIN-002; P-01, P-13 | NO EJECUTADA — requiere laboratorio |
| DEC-17, DEC-R8, AMB-19 | `11-…` | RPC, hora, firewall | E-WIN-002 | NO EJECUTADA — requiere laboratorio |
| Calidad de los scripts | todos | Parser + PSScriptAnalyzer: 0 errores, 0 hallazgos; 14 pruebas de lógica | **E-WIN-001** | **PASS** |

## 7. Operación diaria (manual de operación, parte Windows)

| Tarea | Cómo |
| --- | --- |
| Crear cuentas | `12-usuarios.ps1 -Csv archivo.csv` (con la cuenta `adm.*`) |
| Desbloquear una cuenta | `Unlock-ADAccount juan.perez` o la consola "Usuarios y equipos de Active Directory" |
| Ver quién falló el inicio de sesión | Visor de eventos → Seguridad → eventos 4625 (fallo) y 4740 (bloqueo) |
| Ver cambios en el directorio | Visor de eventos → Seguridad → evento 5136 |
| Ver las concesiones de DHCP | `Get-DhcpServerv4Lease -ScopeId 172.16.30.0` |
| Forzar la aplicación de GPO en un cliente | `gpupdate /force` y `gpresult /r` |
| Revisar todo | `.\verificar-dc01.ps1` |

## 8. Problemas comunes

| Síntoma | Causa probable | Qué hacer |
| --- | --- | --- |
| Los acentos se ven como "Ã©" al correr un script | El archivo se guardó sin BOM | Volver a descargar el ZIP del repositorio (los archivos tienen BOM UTF-8) |
| "no se puede cargar el archivo… la ejecución de scripts está deshabilitada" | Política de ejecución | `Set-ExecutionPolicy -Scope Process Bypass` y `Unblock-File` (§3.2) |
| `Install-ADDSForest` falla por la contraseña | La DSRM no cumple la complejidad | 10+ caracteres con mayúsculas, minúsculas, números y símbolos |
| Un cliente de VLAN 30 no recibe IP | Falta `ip helper-address` en el router, o el ámbito no está activo | `show run interface Gi0/0.30` en rt01; `Get-DhcpServerv4Scope` en el DC |
| El cliente recibe IP pero no puede unirse al dominio | No usa 172.16.40.20 como DNS, o la regla 2 no está en el router | `ipconfig /all`; `nslookup -type=srv _ldap._tcp.atlas.local` |
| La unidad S: o T: no aparece | El usuario o el equipo no están en la OU correcta | `gpresult /r` en el cliente |
| atlas-srv01 no se une ("LDAP signing required") | Herramientas que intentan LDAP sin firmar | `realm`/`adcli` usan Kerberos con firma; revisar la hora y el DNS de srv01 |
| El certificado de srv01 no se emite | El CSR no tiene la IP, o la plantilla WebServer no está publicada | El script lo avisa; `certutil -CATemplates` |
| El escritorio remoto no responde desde VLAN 50 | La estación de gestión no está en 172.16.50.0/24 o el router bloquea | `Get-NetFirewallRule` con puerto 3389 y `show logging` en rt01 |

## 9. Hallazgos de esta fase

| ID | Hallazgo | Qué se hizo |
| --- | --- | --- |
| H7-01 | Windows PowerShell 5.1 (el de Windows Server 2022) lee como ANSI los scripts UTF-8 sin BOM: los textos con acentos salían rotos | Todos los `.ps1/.psm1/.psd1` se guardan con BOM; lo comprueba E-WIN-001 |
| H7-02 | La Tabla 33 aplica GPO_Servidores a la OU Servidores, pero atlas-dc01 **no puede** estar ahí (Microsoft exige que los DC queden en "Domain Controllers") y atlas-srv01 es Linux: la GPO no le llegaría a ningún servidor Windows | Se vincula también a "Domain Controllers". Se mantiene el vínculo a OU Servidores, como dice el PDF |
| H7-03 | Configurar contraseñas con `Set-ADDefaultDomainPasswordPolicy` no deja la configuración "en una GPO", como pide la Tabla 33 | La configuración se escribe como plantilla de seguridad de GPO_Seguridad_Base (lo mismo que hace la consola GPMC) |
| H7-04 | "Cambios en el directorio" (Tabla 32) necesita, además de la directiva, una entrada de auditoría (SACL) en el dominio | El paso 4 la agrega |
| H7-05 | Los nombres de grupos y reglas de firewall cambian con el idioma de Windows (la ISO todavía no se definió, J.3) | Se usan SID y números de puerto, que no dependen del idioma |
| H7-06 | La Tabla 32 pide que las contraseñas venzan a los 90 días; una cuenta de servicio con vencimiento dejaría de hacer respaldos sin aviso | svc_atlas_backup no vence, pero no puede iniciar sesión ni local ni por Escritorio remoto; queda documentado como excepción |

## 10. Para la defensa oral

- **¿Qué diferencia hay entre una OU y un grupo?** La OU es una carpeta para *ordenar y aplicar políticas* (una GPO se vincula a una OU). El grupo sirve para *dar permisos* (a una carpeta, a un recurso). Por eso hay OU por área y grupos GG_\* aparte.
- **¿Por qué la OU de estudiantes coincide con la VLAN 30?** Para que lo lógico y lo físico digan lo mismo: una máquina de la VLAN 30 está en la OU Estudiantes y recibe las políticas de ese perfil (§29.2).
- **¿Por qué dos cuentas para cada persona de Soporte TI?** Si alguien roba la sesión del correo o del navegador, obtiene una cuenta sin privilegios. La cuenta administrativa solo se usa para administrar.
- **¿Qué pasa si un estudiante intenta instalar un programa?** Windows Installer y la Store están bloqueados por GPO_Estudiantes y, además, las cuentas de estudiantes no son administradoras del equipo.
- **¿Por qué el servidor de respaldos no deja borrar?** Porque lo primero que hace un atacante es borrar los respaldos para que no puedas recuperarte (p. 52). La cuenta que escribe los respaldos solo puede crear archivos.
- **¿Para qué una CA propia?** Para que HTTPS funcione sin advertencias dentro del instituto sin comprar un certificado, y para que los equipos del dominio la reconozcan solos.
- **¿Qué es el giaddr?** El dato que el router agrega al reenviar un pedido de DHCP para decir de qué red vino; con eso el servidor elige el ámbito correcto.
