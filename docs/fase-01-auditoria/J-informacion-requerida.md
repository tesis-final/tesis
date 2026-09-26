# J. Información que necesito para empezar la implementación real

## Regla vigente (indicada por el usuario el 26/09/2026)

> **Siempre manda el PDF.** El prompt inicial solo define el método de trabajo.

Consecuencias:

- Las diferencias entre el prompt y el PDF (G.3, PR-01..06) quedan **resueltas a favor del PDF**.
- No se agregan reglas de firewall, tablas ni funciones que el PDF no pida, salvo que sean necesarias para cumplir un requisito del propio PDF. En ese caso se piden como decisión.
- Solo quedan como decisiones: (a) los puntos donde **el PDF dice dos cosas distintas** y (b) los valores que **el PDF deja sin definir** y que no se pueden inventar.

## J.0 Ya resuelto por la regla "manda el PDF" (no requiere decisión)

| # | Qué queda así | Fuente |
| -- | --- | --- |
| R1 | OU=Grupos en la raíz del dominio, al mismo nivel que OU=ATLAS | §29.2 (p. 58) |
| R2 | Respaldos: Linux escribe en una carpeta compartida del servidor Windows. Samba en Linux es para las máquinas del dominio | Tabla 35 (p. 61); Tabla 29 (p. 55) |
| R3 | MySQL `mysql:8.0`, como dice la Tabla 15. Queda documentado que está fuera de soporte desde abril de 2026 (R-02) | Tabla 15 (p. 40) |
| R4 | ATLAS autentica contra su propia BD (contraseñas con hash), no contra AD | §27.5 (p. 48); Tabla 14 (p. 34) |
| R5 | La salida del servicio de análisis hacia el LLM está cubierta por la regla 7 (HTTPS desde VLAN 40); no cambia ninguna regla | Tabla 44 (p. 70) |
| R6 | Material de estudio y adaptación progresiva no se implementan: no tienen requisito en el Anexo H | §5 (p. 7); Anexo H |
| R7 | Respaldo del lado Windows (System State, GPO, DHCP) no se implementa: el PDF solo define el respaldo de Linux | §28.5 |
| R8 | No se agregan reglas fuera de la Tabla 44. Consecuencias documentadas: el DC usa su reloj como fuente de hora del dominio (sin NTP externo); la VLAN 50 administra por IP (no tiene DNS); las denegaciones quedan registradas en cada equipo (router, fw01, UFW), no en un colector central | Tabla 44 |
| R9 | "Negar entrante / permitir saliente" (§30.3) se aplica a los firewalls de host (es literalmente el UFW de §28.4); el reenvío entre redes sigue la Tabla 44 con la regla 12. Así se cumplen ambas frases del PDF, que en §30.5 define dos capas distintas | §28.4; §30.3; §30.5 (p. 72) |

## J.1 Decisiones que necesito

Formato de respuesta: podés contestar "acepto todas las recomendadas" o "acepto todas salvo 5 y 13" y explicar solo esas.

### Regla de desempate

| # | Decisión | Recomendación |
| -- | --- | --- |
| 0 | Cuando el PDF se contradice consigo mismo, ¿manda lo más nuevo y específico? Orden: Anexo H (V2.2) > Parte II (V2) > Parte I (V1) | **Sí.** Con esto se resuelve que: los usuarios los registra el administrador (H9, no autorregistro de §5); el estudiante ve solo su resultado, no su perfil ni recomendaciones (H4, contra el diagrama de §25.3); el administrador de ATLAS es un perfil de coordinación que no maneja servidores (H4, contra §5) |

### El PDF dice dos cosas distintas

| # | Decisión | Lado A | Lado B | Recomendación |
| -- | --- | --- | --- | --- |
| 1 | Servidor web | Apache 2.4 (§25.1, Tabla 16, Tabla 24, §26.2, §28.5) | Nginx (Tabla 15, `docker/nginx/default.conf`) | **Nginx**: es lo único que define el despliegue concreto y encaja con `php:8.3-fpm` |
| 2 | MySQL | Contenedor atlas-db (Tabla 15, §25.5) | Servicio systemd con bind 127.0.0.1 (Tabla 22) | **Contenedor** sin publicar el 3306, en red interna: cumple "no accesible desde la red" |
| 3 | Dónde termina WireGuard | atlas-fw01 (Tabla 42, Figura 1, §30.1) | "Sobre el servidor Linux" (§30.4) | **atlas-fw01** (VM Linux): evita DNAT hacia un servidor, que §30.3 prohíbe |
| 4 | "Firewall con estado" para el tráfico entre VLAN, que solo pasa por el router | El firewall mantiene estado (Tablas 43 y 44) | Las ACL del router no tienen estado (Figura 1, Tabla 42) | **Firewall por zonas (ZBF) en el router**; si el modelo de PT no lo soporta, ACL con `established` |
| 5 | UFW de atlas-srv01 | UFW de §28.4: sin VLAN 10 ni VPN docentes para HTTPS, Samba solo para VLAN 40 | Tabla 44 y pruebas P-07/P-13 | **Ajustar UFW a la Tabla 44**; si no, P-07 y P-13 fallan |
| 6 | Permisos de `/srv/atlas` | Matriz de la Tabla 27 | Modos y ACL de §28.3 (no producen esa matriz; los servicios no pueden entrar a sus directorios) | **La Tabla 27 manda** y se completa con las ACL que faltan |
| 7 | SSH para Soporte TI | Solo `atlasadmin` (§28.4, AllowUsers) | GG_SoporteTI administra el servidor (Tabla 36) | **Soporte TI entra con su cuenta de AD** (Kerberos) desde VLAN 50; atlasadmin queda de emergencia |
| 8 | Unidad de red de estudiantes | GPO_Estudiantes mapea una unidad (Tabla 33) | La VLAN 30 no llega a Samba de srv01 (regla 3) | **La unidad va en una carpeta del DC** (el SMB al DC ya está permitido). Las impresoras de GPO_Docentes quedan fuera: no hay ninguna en el inventario |
| 9 | Respaldo incremental | Solo local (Tabla 29) | Perder como máximo 24 h (§28.5, Tabla 5) | **Copiar también el incremental a Windows**; el domingo solo corre el completo |
| 10 | Privilegios de `atlas_backup` | SELECT, LOCK TABLES, SHOW VIEW (Tabla 21) | El comando exige triggers y rutinas (§28.5) | **Agregar TRIGGER y SHOW_ROUTINE**; si no, el respaldo sale incompleto |
| 11 | Dónde se calculan los indicadores | PHP, clases propias (§25.2, §25.4) | Procedimientos almacenados (Tabla 20) | **PHP**; los procedimientos quedan para los agregados del análisis grupal |
| 12 | Paso de APROBADA a PUBLICADA | 5 estados distintos (RF-17, H25) | El diagrama va de "aprueba" a "publicada" (§25.3) sin decir quién publica | **Publica el docente autor**, eligiendo los grupos. Una actividad rechazada vuelve a borrador con las observaciones |
| 13 | Samba + SSSD | SSSD para unirse al dominio (Tabla 35) | Samba como servidor de archivos del dominio (Tabla 35) funciona oficialmente con winbind | **Prueba temprana con SSSD**; si falla, winbind, con tu aprobación |
| 14 | Repositorio del servicio de análisis | "Repositorio aparte" (§26.2) | Hoy hay un solo repositorio (tesis) | **Fiel al PDF: crear el repositorio `atlas-analysis`** y darme acceso. Alternativa más simple: carpeta dentro de tesis |

### El PDF lo necesita pero no lo define

| # | Decisión | Por qué hace falta | Recomendación |
| -- | --- | --- | --- |
| 15 | Cuatro tablas que el PDF exige pero no nombra: actividad↔grupo, regla↔recomendación, historial de estados y registro de respaldos | RF-04 ("sus grupos"), la Tabla 19 (N:M), RF-17 (autor de cada transición) y §7 ("backups") | **Agregarlas** (modelo de 28 tablas) |
| 16 | Categoría de la actividad (por ejemplo "resolución de problemas") | La consulta de ejemplo del PDF ("¿Cómo viene el grupo 3A en resolución de problemas?") y RF-12 (recomendar actividades) no se pueden cumplir sin eso | **Agregar un catálogo de categorías** |
| 17 | Rango de puertos RPC del DC | La nota a de la Tabla 44 dice que "se fija en el controlador de dominio", sin valor | **49152–65535** (el de Windows por defecto), fijado y documentado |
| 18 | ¿Quién lee los logs de auditoría en Linux? | El grupo atlas-audit (Tabla 25) no tiene ningún miembro | **GG_SoporteTI** |
| 19 | Dónde corre Zabbix | Tabla 46: no dice dónde | **Contenedores en atlas-srv01**: los agentes quedan dentro de VLAN 40 y no hacen falta reglas nuevas |
| 20 | Certificado HTTPS | §25.1 exige HTTPS, pero no dice de dónde sale el certificado | **CA interna propia**, distribuida por GPO a los equipos del dominio |
| 21 | sudo de `atlasadmin` | El PDF dice que el administrador no puede escribir en backups (p. 52); con sudo total, sí podría | **sudo acotado** |
| 22 | Puertos del switch en GNS3 | La Tabla 41 usa nombres de Packet Tracer (Fa0/1…); en GNS3 los puertos se llaman distinto | **Tabla de correspondencia** solo para los puertos que se usan |

### Definiciones del motor de análisis

| # | Decisión | Recomendación |
| -- | --- | --- |
| 23 | El PDF exige al menos 8 reglas pero no las enumera. Tampoco define la fórmula de eficiencia, los umbrales y la etiqueta del ML, el período de recálculo, "atención prioritaria", la duración del bloqueo de login ni qué cuenta como pausa o abandono. ¿Me las dan ustedes o les propongo un borrador para aprobar? | **Te propongo un borrador en la Fase 2**, marcado como PROPUESTA, basado solo en los 4 indicadores del §25.4 |
| 24 | ¿Qué proveedor de LLM usan? | Lo definís vos |

## J.2 Datos técnicos que el PDF no define

1. **atlas-fw01**: sistema operativo (recomendado Ubuntu Server 24.04, coherente con §30.4), IP hacia el router y del router hacia fw01 (red de tránsito), y cómo sale a Internet en el laboratorio (IP WAN).
2. **IP de gestión** en VLAN 50: del switch, del router (¿172.16.50.1?) y de la estación de administración (y su sistema operativo).
3. **Modelos** del router y del switch en Packet Tracer, y versión de Packet Tracer.
4. **Reenviadores DNS** del DC.
5. **Nombres de cuentas técnicas** del dominio: administrador renombrado, cuenta de servicio para respaldos.

## J.3 Recursos del laboratorio

1. Hardware del equipo anfitrión: CPU, RAM y disco; uno o varios equipos.
2. Imágenes de Cisco para GNS3 (IOSv, IOSvL2, IOU) y versión de GNS3.
3. ISO disponibles: Ubuntu Server 24.04, Windows Server 2022 y un cliente Windows Pro o Enterprise (H6 pide al menos uno unido al dominio).
4. Clientes de prueba posibles por VLAN.
5. Quién del equipo ejecuta el laboratorio y toma las capturas.

## J.4 Secretos y cuentas

**No los pegues en el chat ni en el repositorio.** El repo tendrá `.env.example` con nombres de variables; los valores reales van solo en el `.env` de cada servidor. Las claves privadas de WireGuard se generan en cada dispositivo y no salen de ahí.

## J.5 Otros

1. ¿Querés un commit por fase en esta rama y un PR al cierre de cada fase?
2. Idioma: se propone español en la BD y el dominio (como el PDF: `actividades`, `intentos`…) y los nombres de carpetas técnicas de §26.2 tal cual (`Controllers`, `Repositories`).
3. Disponibilidad de docentes para la prueba de uso (RNF-11).

## Correspondencia con los IDs anteriores

La primera versión de este documento listaba D-01..D-38. Así quedaron:

| Numeración nueva | IDs anteriores |
| --- | --- |
| Resueltas en J.0 | D-06 (R9), D-03, D-21, D-23, D-24, D-28, D-29, D-30, D-32, D-34, D-36 |
| Resueltas por la regla 0 | D-17, D-19, D-20 |
| Siguen siendo decisiones (1..24) | D-01, D-02, D-04, D-05, D-07, D-08, D-09, D-10, D-11, D-12, D-13, D-14, D-15, D-16, D-18, D-22, D-25, D-27, D-31, D-33, D-35, D-37, D-38 |
| D-26 (alcance del Hito 2) | Se propone en la Fase 3 |
