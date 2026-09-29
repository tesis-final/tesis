# ATLAS — Reporte de avance del Hito 1 (Fases 1 a 8)

**Grupo Error404 · TC4 ITI-CETP/UTU · 27/09/2026**

Este reporte cuenta, fase por fase, qué hicimos, por qué lo hicimos así y cómo sabemos que funciona. Está pensado para estudiar: cada fase termina con las ideas que conviene tener claras para la defensa y al final hay preguntas de repaso con sus respuestas.

> **Sobre el nombre "Hito 1".** En el calendario del PDF (Tabla 9), el Hito 1 fue la entrega del plan (18/09) y la próxima entrega formal es el **Hito 2, el 23/10** ("prototipo o avance funcional validado"). Lo que se cuenta acá es nuestro **primer corte de implementación** y lo vamos a ir mejorando en los hitos siguientes. En la defensa conviene usar las fechas de la Tabla 9 para no confundir al tribunal.

---

## Cómo leer este reporte

- Si tienen poco tiempo: lean **"ATLAS en dos minutos"**, el **mapa de fases** y **"Qué necesitamos de ustedes"**.
- Para estudiar un tema: vayan a su fase. Cada una tiene la misma estructura: *qué es*, *qué hicimos*, *qué decidimos*, *cómo lo comprobamos*, *qué falta* y *para la defensa*.
- Las siglas raras (DEC-07, CT-05, DISC-10…) son identificadores de nuestros documentos. No hace falta memorizarlas; sirven para encontrar el detalle en el repositorio.

---

## ATLAS en dos minutos

ATLAS es una plataforma web para un centro educativo. Tiene tres tipos de usuario:

- **Estudiante**: resuelve actividades (preguntas de opción múltiple) y ve su resultado.
- **Docente**: crea actividades, las manda a aprobar, las publica en sus grupos y, sobre todo, ve **qué le está pasando a cada estudiante**: quién necesita ayuda, qué preguntas cuestan más, y por qué el sistema recomienda lo que recomienda.
- **Administrador**: es alguien de coordinación. Gestiona usuarios, grupos, aprueba actividades, ajusta las reglas del motor y revisa la auditoría.

Lo que hace especial a ATLAS es el **motor de análisis**, que tiene tres niveles:

1. **Reglas** (Nivel 1): ocho reglas simples y explicables. Ejemplo: "si el puntaje del último intento es menor a 50, reforzar con otra actividad de la misma categoría". Cada recomendación dice qué regla la produjo y con qué datos.
2. **Aprendizaje automático** (Nivel 2): agrupa estudiantes con comportamientos parecidos y estima riesgo. Solo se activa si hay datos suficientes; si no, lo dice.
3. **Asistente conversacional** (Nivel 3): el docente pregunta en lenguaje natural ("¿quiénes tuvieron dificultades esta semana?") y un modelo de lenguaje (Groq) redacta la respuesta **sin recibir nunca nombres ni datos personales**.

Por debajo hay una infraestructura completa, que es la otra mitad del proyecto:

| Pieza | Qué es | Dónde |
| --- | --- | --- |
| atlas-srv01 | Servidor Linux (Ubuntu 24.04) que corre ATLAS en contenedores | VLAN 40, 172.16.40.10 |
| atlas-dc01 | Servidor Windows (2022): dominio atlas.local, DNS, DHCP, políticas | VLAN 40, 172.16.40.20 |
| atlas-sw01 | Switch que separa la red en VLAN | Packet Tracer / GNS3 |
| atlas-rt01 | Router que comunica las VLAN y decide qué se permite | Packet Tracer / GNS3 |
| atlas-fw01 | Firewall perimetral: salida a Internet y VPN | Máquina virtual |

Y cinco VLAN: 10 Administración, 20 Docentes, 30 Estudiantes, 40 Servidores, 50 Gestión.

---

## El mapa de fases

Dividimos el trabajo en 17 fases. Las primeras ocho están hechas en esta entrega.

| Fase | Tema | Estado |
| --- | --- | --- |
| 1 | Auditoría del PDF | Terminada |
| 2 | Arquitectura y decisiones | Terminada |
| 3 | Plan maestro | Terminada |
| 4 | Aplicación (PHP + interfaz + análisis en Python) | Terminada y probada |
| 5 | Base de datos | Terminada y probada |
| 6 | Servidor Linux | Scripts listos y probados en Ubuntu real; falta correrlos en la VM |
| 7 | Servidor Windows | Scripts listos y validados; falta correrlos en la VM |
| 8 | Redes (VLAN, troncal, enrutamiento, DHCP) | Configuraciones listas y validadas; falta armarlo en Packet Tracer |
| 9 | Firewall y NAT | Próxima |
| 10 | VPN | Pendiente |
| 11 | Monitoreo | Pendiente |
| 12 | Respaldos | Pendiente |
| 13 | Integración | Pendiente |
| 14 | Pruebas P-01 a P-15 | Pendiente |
| 15 | Evidencias | Pendiente |
| 16 | Auditoría final | Pendiente |
| 17 | Reportes finales y manuales | Pendiente |

---

## Cómo trabajamos (y por qué importa en la defensa)

Tres reglas guiaron todo:

1. **Manda el PDF.** Si algo está en el documento, se hace así. Cuando el PDF se contradice a sí mismo, manda lo más nuevo y específico (Anexo H > Parte II > Parte I). Cada decisión queda anotada con su motivo.
2. **No inventamos.** Si un dato no está (por ejemplo, la IP de gestión del switch), lo marcamos como **propuesto** y queda pendiente de que lo confirmemos. Si una prueba no se pudo correr, dice **NO EJECUTADA — requiere laboratorio**, nunca "OK".
3. **Cada cosa tiene su prueba y su evidencia.** La cadena es: *requisito → implementación → configuración → prueba → evidencia*. Las evidencias son archivos de texto con la salida real de las pruebas, en `docs/evidencias/`.

Para no mezclar lo que existe en papel con lo que funciona, usamos cuatro palabras:

| Palabra | Significa | Ejemplo |
| --- | --- | --- |
| **Diseñado** | Está descrito en un documento | La matriz de la Tabla 43 |
| **Configurado** | El archivo o script existe y está completo | `atlas-sw01.txt` |
| **Ejecutado** | Se corrió | Se pegó la configuración en Packet Tracer |
| **Verificado** | Se corrió, se comprobó y la salida está guardada | E-BD-001: 45 pruebas de la base en PASS |

Si en la defensa alguien pregunta "¿esto funciona?", la respuesta honesta es una de esas cuatro palabras, con la evidencia en la mano.

---

## Fase 1 — Auditoría del PDF

### Qué es

Antes de programar nada, leímos las 123 páginas del PDF como lo haría un revisor: buscando qué pide exactamente, qué se contradice y qué falta. Es como revisar los planos de una casa antes de empezar a construir: es mucho más barato encontrar un error en el plano que con la pared levantada.

### Qué hicimos

| Resultado | Cantidad |
| --- | --- |
| Requisitos identificados y numerados | **201** |
| Contradicciones internas del PDF | **24** |
| Ambigüedades o vacíos | **30** |
| Riesgos técnicos | **27** |

Algunos hallazgos importantes (hay que saber explicarlos):

- **Apache o Nginx.** El PDF dice Apache en cinco lugares, pero la tabla de contenedores (Tabla 15) usa Nginx.
- **Dónde termina la VPN.** Una sección dice "en el servidor Linux"; la topología (Figura 1) la pone en el firewall.
- **Las ocho reglas del motor no estaban escritas.** El PDF dice "ocho reglas documentadas" pero no las enumera.
- **Docker saltea el firewall del servidor.** Los puertos que publica Docker no pasan por UFW. Si no se corrige, el firewall parece cerrado y no lo está.
- **Los permisos de Linux no cierran.** Con `/srv/atlas` en 750, los servicios no podían ni entrar a sus propias carpetas.
- **El respaldo no cumplía el objetivo de 24 horas** si se perdía el servidor, porque los incrementales quedaban solo en local.

### Para la defensa

- Una auditoría no es "criticar el documento": es encontrar los puntos donde, si implementamos al pie de la letra, algo no funcionaría.
- Cada contradicción tiene una propuesta y una decisión (Fase 2). Nada quedó "a criterio" sin registrar.

---

## Fase 2 — Arquitectura y decisiones

### Qué es

Convertimos los 24 problemas y los 30 vacíos en **decisiones concretas**, cada una con su motivo y sus consecuencias. Aprobamos todas las recomendadas el 26/09.

### Las decisiones que más conviene saber

| Tema | Qué decidimos | Por qué (en una línea) |
| --- | --- | --- |
| Servidor web | **Nginx** delante de PHP-FPM | La tabla que define los contenedores (la más concreta) usa Nginx |
| Base de datos | **MySQL en contenedor**, sin puerto publicado, en una red interna sin salida | Nadie desde la red puede llegar al 3306 |
| VPN | Termina en **atlas-fw01** (Ubuntu + WireGuard) | Es lo que muestra la topología; el servidor no queda expuesto |
| Filtrado entre VLAN | **Firewall por zonas (ZBF)** en el router | Las listas de acceso comunes no recuerdan conexiones; el ZBF sí |
| Firewall del servidor (UFW) | Alineado con la **Tabla 44** | Tal como estaba escrito, dos pruebas del propio PDF iban a fallar |
| Permisos de Linux | La **Tabla 27 es el objetivo**; se logra con ACL | Los modos solos no alcanzaban |
| SSH | Soporte TI entra con su **cuenta del dominio**; atlasadmin queda de emergencia | Así la integración Linux–Windows sirve para algo real |
| Respaldos | El incremental **también se copia a Windows**, y desde Linux **no se puede borrar** esa copia | Para cumplir las 24 horas y resistir un ataque |
| Certificados | **CA propia** (ATLAS-CA) en el dominio | HTTPS sin advertencias y sin comprar certificados |
| Motor de reglas | Las **8 reglas** R01–R08, editables por el administrador | El PDF las exigía pero no las definía |
| Modelo de lenguaje | **Groq** (gratis por ahora), cambiable por configuración | Decisión del equipo |

También agregamos cuatro tablas que el PDF necesitaba y no tenía (por ejemplo, el historial de aprobaciones de una actividad) y una tabla de categorías.

### Para la defensa

- Si nos preguntan "¿por qué no hicieron lo que dice la página X?", la respuesta está en el registro de decisiones: dónde se contradecía, qué se eligió y por qué.
- **Regla de desempate**: cuando el PDF se contradice, manda el Anexo H (versión 2.2), después la Parte II y después la Parte I.

---

## Fase 3 — Plan maestro

### Qué es

El orden de trabajo: qué se hace primero, quién lo hace (lo que escribimos nosotros en código y lo que el equipo ejecuta en el laboratorio) y cómo se nombran las evidencias (E-APP, E-BD, E-LNX, E-WIN, E-RED, E-MON, E-BKP).

### La idea principal

Empezamos por lo que no depende del laboratorio (base de datos y aplicación) y dejamos los scripts de infraestructura listos para que, cuando estén las máquinas virtuales, sea "correr y verificar".

También definimos los **diferenciales**, que no son funciones nuevas sino *la forma* de cumplir lo que pide el PDF:

- **"¿Dónde intervenir hoy?"**: lo primero que ve el docente es a quién ayudar y por qué.
- **"¿Por qué?"**: cada recomendación muestra la regla, su versión y los datos exactos.
- **Honestidad del aprendizaje automático**: si no hay datos suficientes, se dice cuántos faltan.
- **Privacidad verificable**: el docente puede ver exactamente qué se le mandó al modelo de lenguaje.
- **Funciona sin Internet**: si se cae la conexión o Groq, ATLAS sigue funcionando.

---

## Fase 5 — Base de datos

(La hicimos antes que la Fase 4 porque la aplicación depende de ella.)

### Qué es

El lugar donde vive toda la información: usuarios, actividades, intentos, resultados, recomendaciones, auditoría. Una buena base de datos no solo guarda: **se defiende sola** de datos inválidos.

### Qué hicimos

| Elemento | Cantidad | Para qué sirve |
| --- | --- | --- |
| Tablas | 29 | El PDF pide al menos 15 |
| Claves foráneas | 43 | Que no pueda existir, por ejemplo, un intento de un usuario que no existe |
| Restricciones CHECK | 35 | Que un puntaje no pueda ser 150 |
| Triggers | 17 | Reglas automáticas: calcular el resultado al finalizar, impedir saltearse la aprobación, que la auditoría no se pueda modificar |
| Vistas | 5 | Consultas listas y sin datos personales |
| Procedimiento almacenado | 1 | El análisis grupal |
| Usuarios de MySQL | 5 | Cada componente con el mínimo permiso que necesita |

Los cinco usuarios de MySQL son una buena pregunta de defensa:

| Usuario | Quién lo usa | Qué puede |
| --- | --- | --- |
| atlas_app | La aplicación | Leer y escribir datos, **agregar** a la auditoría, nunca modificarla |
| atlas_read | Reportes | Solo las vistas |
| atlas_analysis | El servicio de Python | Leer datos **sin nombres ni correos** y escribir solo resultados del análisis |
| atlas_backup | Los respaldos | Leer todo, no escribir datos |
| atlas_admin | Mantenimiento | Todo, pero solo desde dentro del contenedor |

### Cómo lo comprobamos

45 pruebas automáticas contra un MySQL 8.0 real: **45 de 45 en PASS** (evidencia E-BD-001). Por ejemplo: que la auditoría no se pueda borrar ni siquiera como root, que un intento abandonado no genere resultado, que el servicio de análisis no pueda leer correos.

### Para la defensa

- **Integridad referencial**: la base rechaza datos que apuntan a algo que no existe.
- **Principio de mínimo privilegio**: cada usuario de MySQL puede hacer solo lo que necesita. Si alguien roba la contraseña del servicio de análisis, no obtiene nombres ni correos.
- **Auditoría inmutable**: se puede agregar, no modificar ni borrar. Lo garantizan los triggers y los permisos.

---

## Fase 4 — La aplicación

### Qué es

ATLAS propiamente dicho: el programa que usan estudiantes, docentes y administradores desde el navegador (también desde el celular).

### Cómo está construida

Pensémoslo como un restaurante:

- **La interfaz** (HTML, CSS y JavaScript) es el salón: lo que ve el cliente.
- **El servidor web** (Nginx) es la puerta: recibe los pedidos y solo deja pasar lo que corresponde.
- **La aplicación PHP** es la cocina, organizada en capas: el *controlador* toma el pedido, el *servicio* hace el trabajo y el *repositorio* va a buscar los ingredientes a la base de datos.
- **Los "middleware"** son los controles de la puerta, en orden: ¿tiene sesión? (si no, 401) → ¿tiene permiso? (si no, 403 y queda registrado) → ¿los datos son válidos? (si no, 422) → se registra en la auditoría.

Y hay un segundo programa en **Python** (carpeta `atlas-analysis/`) para el aprendizaje automático y la conexión con Groq.

### Lo que hace

- Inicio de sesión con bloqueo tras 3 intentos fallidos (15 minutos) y un mensaje que no revela qué dato estaba mal.
- Ciclo completo de una actividad: borrador → pendiente → aprobada o rechazada → publicada.
- El estudiante resuelve y **cada clic queda registrado** (se guarda en el navegador y se envía por lotes, así no se pierde nada si la conexión es mala).
- El motor de reglas genera recomendaciones con su "¿por qué?".
- El panel del docente muestra "¿dónde intervenir hoy?", el análisis de cada grupo y los reportes.
- El asistente responde preguntas del docente **anonimizando todo** antes de consultar a Groq: los nombres se cambian por seudónimos (E1, E2…) y se vuelven a poner recién en la respuesta.

### Cómo lo comprobamos

| Prueba | Resultado |
| --- | --- |
| Pruebas unitarias (PHP) | 26/26 |
| Pruebas de la API contra MySQL real | 58/58 |
| Pruebas en un navegador real, en 5 tamaños de pantalla | 17/17 |
| Pruebas del servicio de Python | 23/23 |
| Estándar de código PSR-12 | 0 errores, 0 advertencias |

Todo corriendo con los cuatro contenedores reales (web, PHP, base de datos y análisis).

### Qué falta

- Probar con la clave real de Groq (a propósito no hay ninguna clave en el repositorio).
- El aprendizaje automático necesita al menos 20 estudiantes con 5 intentos: con los datos de demostración (12 estudiantes) responde, con razón, "datos insuficientes".

### Para la defensa

- **¿Cómo se evita la inyección SQL?** Nunca se pega un dato del usuario dentro de una consulta: se usan consultas preparadas.
- **¿Qué pasa si se cae Internet?** Las reglas corren en PHP y la base es local: todo sigue funcionando. Solo el texto redactado por Groq se reemplaza por los datos verificados.
- **¿Cómo sabemos que no mandamos datos personales a Groq?** Anonimizador, una barrera final que rechaza correos y cédulas (en PHP y otra vez en Python) y el registro de exactamente qué se envió. Hay una prueba que busca los nombres reales en lo enviado y exige cero coincidencias.
- **¿Por qué el aprendizaje automático dice "datos insuficientes"?** Porque un modelo entrenado con pocos datos no vale nada y mostrarlo sería engañar.

---

## Fase 6 — Servidor Linux (atlas-srv01)

### Qué es

La máquina donde corre ATLAS. La preparamos como pide el §28 del PDF: sin entorno gráfico, con cuentas técnicas, permisos muy precisos y varias capas de seguridad.

### Qué hicimos

Doce scripts que se corren en orden (y se pueden repetir sin romper nada) más un verificador que revisa todo y dice PASS o FAIL por ítem:

1. Sistema base e IP fija 172.16.40.10.
2. Grupos y usuarios de las Tablas 25 y 26 (atlasadmin, atlasweb, atlasdb, atlasbkp) con sus números exactos. Las cuentas de servicio no pueden iniciar sesión.
3. Carpetas de `/srv/atlas` con dueños, permisos, **ACL** y **atributos** (`chattr`).
4. SSH endurecido y TCP Wrappers.
5. Firewall UFW y la cadena **DOCKER-USER**.
6. Docker.
7. Puesta en marcha de ATLAS: genera las contraseñas al azar, el pedido de certificado y deja ATLAS como servicio del sistema.
8. Hora sincronizada con el servidor Windows.
9. Unión al dominio con SSSD.
10. Samba (carpetas compartidas para Administración y Docentes).
11. Registros y auditoría del sistema.
12. `sudo` acotado: el administrador opera ATLAS sin ser root.

### Tres ideas para entender bien

**1. Permisos con ACL.** Los permisos comunes de Linux solo distinguen dueño, grupo y "el resto". La Tabla 27 le da permisos distintos a cinco perfiles sobre la misma carpeta; eso solo se puede expresar con ACL. Ejemplo: en `logs/`, el servicio web puede escribir pero no listar lo que escribieron otros (`-wx`), y el auditor puede leer pero no modificar.

**2. Atributos.** `chattr +i` hace un archivo inmutable (ni root lo cambia sin sacar el atributo primero) y `chattr +a` hace que solo se pueda agregar al final. Lo usamos en el archivo de secretos y en el de auditoría. Además, **sacar un atributo queda registrado** (auditd), tal como promete el PDF.

**3. Defensa en capas.** Para entrar por SSH hay que pasar cuatro controles: el firewall de la red, UFW, TCP Wrappers y la configuración de SSH. Si uno falla, los otros siguen.

### El caso DOCKER-USER (buena historia para la defensa)

Docker abre los puertos de los contenedores por un camino que UFW no ve. O sea: UFW podía decir "cerrado" y el puerto 443 igual estar abierto para cualquiera. Lo demostramos con una prueba:

- Con nuestra configuración, la VLAN 30 llega a ATLAS y la VLAN 50 no (como pide la Tabla 44).
- Si borramos la cadena DOCKER-USER, **la VLAN 50 pasa a llegar**. El riesgo era real.
- Al recargar el firewall, la VLAN 50 vuelve a quedar bloqueada.

### Cómo lo comprobamos

No tenemos todavía la VM del laboratorio, pero sí pudimos correr los scripts en un **Ubuntu 24.04 real** (dentro de un contenedor) con un disco ext4 y redes simuladas. Resultado (evidencia E-LNX-001):

- La matriz de permisos de la Tabla 27, **medida celda por celda como cada usuario**: 30 de 30 celdas correctas.
- `chattr`: ni root puede vaciar el log de auditoría ni tocar el archivo de secretos.
- **Conexiones SSH reales**: atlasadmin desde "VLAN 50" entra; un miembro de Soporte TI entra y recibe los grupos correctos; root, un usuario cualquiera y cualquiera desde "VLAN 30", no.
- UFW, DOCKER-USER, sudo (atlasadmin no puede abrir una shell de root) y Samba.

Las pruebas encontraron dos errores nuestros, que corregimos antes de entregar: el verificador leía mal los permisos cuando hay ACL, y el archivo de parámetros pisaba una variable, lo que hacía que el filtro de Docker mirara la interfaz equivocada.

### Qué falta

Correr los scripts en la VM del laboratorio y guardar la salida del verificador (E-LNX-002). La unión al dominio y Samba con usuarios reales necesitan el servidor Windows funcionando.

### Para la defensa

- **¿Por qué las cuentas de servicio tienen `nologin`?** Porque son de procesos, no de personas: aunque alguien robe la contraseña, no puede abrir una sesión.
- **¿Por qué el administrador no puede escribir en `backups/`?** Porque lo primero que hace un atacante es borrar los respaldos.
- **¿Por qué `ls -l` muestra 770 si el PDF dice 750?** Con ACL, `ls` muestra la "máscara" en lugar del grupo. El permiso real se ve con `getfacl`.

---

## Fase 7 — Servidor Windows (atlas-dc01)

### Qué es

El servidor que maneja las identidades de todos (el dominio `atlas.local`), el DNS, el DHCP y las políticas que se aplican a cada equipo.

### Qué hicimos

Doce scripts de PowerShell, un verificador con más de 60 comprobaciones y un script para unir equipos al dominio. En orden:

1. IP fija 172.16.40.20 y nombre atlas-dc01.
2. Crear el dominio atlas.local.
3. La estructura de **OU** del §29.2 (una por área, cada una con Usuarios y Equipos), los grupos GG_Administracion, GG_Docentes, GG_Estudiantes y GG_SoporteTI, la cuenta de servicio de respaldos y la **delegación**: Soporte TI administra usuarios y equipos sin ser administrador del dominio.
4. Seguridad de la Tabla 32: contraseñas de 10 caracteres con complejidad, historial de 5, vencen a los 90 días; bloqueo a los 5 intentos por 15 minutos; la cuenta Administrator renombrada y Guest deshabilitada; auditoría.
5. DNS: zona inversa y registros de los dos servidores.
6. DHCP: los tres ámbitos de la Tabla 34.
7. Las GPO de la Tabla 33 (estudiantes sin instalar programas y con unidad S:, docentes con unidad T:, servidores endurecidos).
8. Carpetas compartidas: la de estudiantes y la de **respaldos**, donde la cuenta de respaldos puede crear archivos pero **no borrarlos**.
9. y 10. Una autoridad certificadora propia (ATLAS-CA) y la firma del certificado de ATLAS.
11. Firewall de Windows, fuente de hora y rango de puertos RPC.
12. Cuentas de personas desde un CSV, con **cuentas administrativas separadas** para Soporte TI.

### Dos ideas para entender bien

**OU y grupos no son lo mismo.** La OU es una carpeta para *ordenar y aplicar políticas*; el grupo sirve para *dar permisos*. Por eso una máquina de la VLAN 30 va a la OU Estudiantes (recibe sus políticas) y un estudiante está en el grupo GG_Estudiantes (tiene acceso a su carpeta).

**Cómo le llega una IP a un equipo de la VLAN 30.** El equipo pregunta a los gritos "¿alguien me da una IP?". Ese grito no sale de su VLAN. El router lo escucha, lo reenvía al servidor Windows y le agrega "esto vino de la red 172.16.30.1" (el campo *giaddr*). El servidor mira ese dato y elige el ámbito de la VLAN 30.

### Cómo lo comprobamos

Un Windows Server no se puede levantar en nuestro entorno de trabajo, así que lo que verificamos es (evidencia E-WIN-001):

- Los 18 archivos de PowerShell: **0 errores de sintaxis** y **0 hallazgos** del analizador oficial de Microsoft (PSScriptAnalyzer).
- **14 pruebas** de la lógica más delicada (contraseñas aleatorias que cumplen la complejidad, cómo se registran las políticas en las GPO).
- Que todos los archivos estén guardados de forma que Windows lea bien los acentos (un error que habría roto los mensajes en español).

### Qué falta

Correr los scripts en la VM (tres etapas, por dos reinicios obligatorios) y guardar la salida del verificador (E-WIN-002). Falta definir los reenviadores DNS (sin ellos igual funciona).

### Para la defensa

- **¿Por qué dos cuentas para Soporte TI?** Si alguien roba la sesión de uso diario, no obtiene privilegios.
- **¿Qué pasa si un estudiante quiere instalar un programa?** No puede: lo bloquea GPO_Estudiantes y su cuenta no es administradora del equipo.
- **¿Por qué la carpeta de respaldos no deja borrar?** Si alguien toma el servidor Linux, puede agregar archivos pero no eliminar las copias que ya están en Windows.
- **Hallazgo propio**: la Tabla 33 aplica GPO_Servidores a la OU Servidores, pero ahí no hay ningún servidor Windows (el controlador de dominio tiene que estar en "Domain Controllers", y srv01 es Linux). La vinculamos también a Domain Controllers.

---

## Fase 8 — Redes

### Qué es

La red que conecta todo: el switch separa los equipos en VLAN, el router las comunica y reenvía los pedidos de DHCP, y a los equipos de red solo se entra por SSH desde la VLAN de Gestión.

### Qué hicimos

- **Configuración completa del switch** (Catalyst 2960 en Packet Tracer): las VLAN, cada puerto de la Tabla 41, el troncal con VLAN nativa 999, los puertos libres apagados y SSH solo desde la VLAN 50.
- **Configuración base del router** (ISR 2911): una subinterfaz por VLAN con su gateway, `ip helper-address` para el DHCP, las rutas hacia el firewall y SSH solo desde la VLAN 50.
- **Una maqueta del firewall** para Packet Tracer (que no puede correr la VM real) con una "Internet simulada".
- La **versión para GNS3**, con la tabla de correspondencia de puertos.
- Un **manual paso a paso** para armarlo en Packet Tracer, con 14 verificaciones y lo que tiene que salir en cada una.

### Cómo lo comprobamos

**Revisor automático** (E-RED-001): un programa lee las configuraciones y las compara con las tablas del PDF (VLAN, cada puerto, el troncal, cada subinterfaz, dónde va el helper, que no haya contraseñas escritas). Resultado: **81 de 81**. Para saber que el revisor no aprueba cualquier cosa, le metimos cuatro errores a propósito: **los encontró todos**.

**Gemelo de red** (E-RED-002): armamos la topología completa en Linux, con equipos que piden IP, hacen ping y resuelven nombres. Resultado: **27 de 27**:

- Los equipos de VLAN 10, 20 y 30 reciben IP del ámbito correcto, con su gateway, DNS y sufijo.
- Una captura de paquetes en el servidor muestra el giaddr de cada VLAN.
- Un equipo de la VLAN 30 que se inventa una IP de la VLAN 20 no llega a nadie.
- En el puerto libre no hay DHCP ni salida, aunque alguien lo encienda.

Límite honesto: el sistema donde probamos no soporta etiquetas 802.1Q, así que el troncal en sí se comprueba en Packet Tracer.

### Valores propuestos (el PDF no los define)

| Dato | Propuesta |
| --- | --- |
| IP de gestión del switch | 172.16.50.2 |
| IP de la estación de administración | 172.16.50.10 |
| Red entre el router y el firewall | 172.16.255.0/30 |

Tenemos que confirmarlos (o cambiarlos) como equipo.

### Importante

En esta fase **todavía no hay filtrado entre VLAN**: el router deja pasar todo. Eso llega en la Fase 9 (firewall por zonas). No hay que presentar la Fase 8 sola como "la red segura".

### Para la defensa

- **¿Qué es una VLAN?** Un switch dividido en varios switches lógicos: los equipos de VLAN distintas no se ven sin pasar por el router.
- **¿Qué es un troncal?** Un solo cable que lleva todas las VLAN, cada trama con una etiqueta que dice a cuál pertenece.
- **¿Por qué la VLAN nativa es la 999?** Porque sus tramas van sin etiqueta. Si fuera la VLAN 1, alguien podría usarla para saltar a otra VLAN. La 999 no tiene equipos ni IP: no hay a dónde saltar.
- **¿Por qué solo SSH y solo desde la VLAN 50?** Telnet manda la contraseña en texto plano, y la VLAN de Gestión es la única desde la que se administra la infraestructura.

---

## Los números del avance

| Área | Qué se probó | Resultado | Evidencia |
| --- | --- | --- | --- |
| Base de datos | Esquema, integridad, triggers, privilegios | 45/45 | E-BD-001 |
| Aplicación | Unitarias | 26/26 | E-APP-001 |
| Aplicación | API contra MySQL real | 58/58 | E-APP-002 |
| Aplicación | Navegador real, 5 tamaños de pantalla | 17/17 | E-APP-003 |
| Análisis (Python) | Modelos, anonimización, API | 23/23 | E-APP-004 |
| Código | PSR-12 | 0 errores, 0 advertencias | E-APP-005 |
| Linux | Scripts en Ubuntu 24.04 real | 84 comprobaciones en PASS (el único FAIL esperado es un servicio que el contenedor no puede arrancar) | E-LNX-001, E-LNX-003 |
| Windows | Análisis estático y lógica | 0 errores · 0 hallazgos · 14/14 | E-WIN-001 |
| Redes | Revisión contra el PDF | 81/81 (y detecta los errores sembrados) | E-RED-001 |
| Redes | Gemelo de red | 27/27 | E-RED-002 |

---

## Qué necesitamos de ustedes

### Datos que faltan (sin esto no podemos cerrar las fases de red)

- Sistema operativo y direcciones del firewall (la red hacia el router y la salida a Internet).
- Confirmar o cambiar las IP propuestas (switch 172.16.50.2, estación 172.16.50.10, red de tránsito 172.16.255.0/30).
- Versión de Packet Tracer que vamos a usar.
- Reenviadores DNS del servidor Windows (si no hay, funciona igual).
- Hardware del laboratorio (RAM disponible: son tres máquinas virtuales a la vez).
- Imágenes de Cisco para GNS3 e ISO de Windows Server 2022.
- Quién saca las capturas de pantalla para las evidencias.

### Tareas de laboratorio (lo que se ejecuta con las VM)

1. Crear la VM de atlas-srv01 y correr los scripts de `infra/linux/` (manual en `docs/fase-06-linux/`).
2. Crear la VM de atlas-dc01 y correr los scripts de `infra/windows/` en tres etapas (manual en `docs/fase-07-windows/`).
3. Armar la red en Packet Tracer con `infra/red/packet-tracer/` y sacar las 14 capturas R-01 a R-14 (manual en `docs/fase-08-redes/`).
4. Guardar la salida de cada verificador en `docs/evidencias/`.

---

## Qué sigue y qué vamos a mejorar

| Fase | Qué es |
| --- | --- |
| 9 | Firewall por zonas en el router (la Tabla 44 completa) y el firewall perimetral con NAT |
| 10 | VPN WireGuard con los dos perfiles (administradores y docentes) |
| 11 | Monitoreo con Zabbix y revisión de registros |
| 12 | Respaldos completos e incrementales, copia a Windows y prueba de restauración |
| 13 | Todo junto en GNS3 con las VM reales |
| 14 | Las 15 pruebas del PDF (P-01 a P-15) |
| 15–17 | Evidencias, auditoría final, manuales y el "Manual y reporte de redes y seguridad" |

En los próximos hitos también vamos a mejorar lo que ya está: pasar de "probado en contenedor" a "verificado en la VM", confirmar los valores propuestos y cerrar la lista de pendientes.

---

## Glosario

| Término | En pocas palabras |
| --- | --- |
| ACL (Linux) | Permisos extra para usuarios o grupos que no son el dueño de un archivo |
| ACL (Cisco) | Lista de reglas que dice qué tráfico pasa y cuál no |
| Anonimizar | Reemplazar nombres y datos personales por seudónimos antes de mandar algo afuera |
| API REST | La forma en que la interfaz le pide datos al servidor (por ejemplo, `GET /api/v1/reportes`) |
| Argon2id | Algoritmo para guardar contraseñas de forma que no se puedan recuperar |
| chattr | Comando que pone atributos a un archivo: inmutable (+i) o solo agregar (+a) |
| Contenedor | Un programa empaquetado con todo lo que necesita, aislado del resto |
| CSP | Regla del navegador que impide ejecutar código que no sea de nuestro servidor |
| DHCP | Servicio que reparte IP automáticamente |
| DNS | Servicio que traduce nombres (atlas-srv01.atlas.local) a IP |
| Dominio / AD | Base central de usuarios y equipos de Windows (Active Directory) |
| DOCKER-USER | Cadena del firewall donde se filtra lo que Docker publica |
| GPO | Política que se aplica automáticamente a usuarios o equipos de una OU |
| giaddr | Dato que agrega el router al reenviar un DHCP para decir de qué red vino |
| Kerberos | Sistema de "entradas" (tickets) para autenticarse en el dominio sin mandar la contraseña |
| Middleware | Control que se ejecuta antes de atender cada pedido (sesión, permisos, validación) |
| OU | Carpeta del directorio para ordenar objetos y aplicar políticas |
| SSSD | Programa que une un Linux a un dominio de Windows |
| Subinterfaz | Una interfaz "virtual" del router por cada VLAN, sobre un mismo cable |
| Trigger | Regla automática de la base de datos que se ejecuta ante un cambio |
| Troncal (trunk) | Enlace que transporta varias VLAN con etiquetas 802.1Q |
| UFW | El firewall del servidor Linux |
| VLAN | Red separada dentro de un mismo switch |
| VLAN nativa | La VLAN que viaja sin etiqueta por el troncal (la nuestra es la 999) |
| ZBF | Firewall por zonas del router: recuerda las conexiones y permite las respuestas |

---

## Preguntas de repaso (con respuesta)

**1. ¿Qué significa que una prueba diga "NO EJECUTADA — requiere laboratorio"?**
Que la configuración existe, pero la prueba necesita las máquinas del laboratorio y todavía no se corrió. Nunca se marca como aprobada algo que no se ejecutó.

**2. ¿Por qué usamos Nginx si el PDF menciona Apache?**
Porque el PDF se contradice y la tabla que define los contenedores (Tabla 15), que es la más concreta, usa Nginx con PHP-FPM.

**3. ¿Cómo evita la base de datos que alguien borre la auditoría?**
Con triggers que rechazan modificar o borrar filas de auditoría y con permisos: la aplicación solo puede agregar.

**4. ¿Qué hace el usuario de MySQL atlas_analysis y qué no puede hacer?**
Lee los datos de intentos para el aprendizaje automático y escribe resultados de análisis. No puede leer nombres ni correos.

**5. Nombren los cuatro controles del middleware en orden.**
Autenticación (401), permisos (403 y registro), validación (422) y auditoría.

**6. ¿Qué pasa con ATLAS si se corta Internet?**
Sigue funcionando: las reglas corren en PHP y la base es local. Solo el asistente pierde la redacción del modelo y responde con los datos verificados.

**7. ¿Por qué hace falta la cadena DOCKER-USER?**
Porque Docker abre los puertos por un camino que UFW no ve. Sin DOCKER-USER, el 443 quedaría abierto para redes que la Tabla 44 no permite. Lo demostramos con una prueba.

**8. ¿Para qué sirve `chattr +a` en el log de auditoría?**
Para que se puedan agregar líneas pero no borrar las anteriores, ni siquiera como root, sin sacar primero el atributo (y sacarlo queda registrado).

**9. ¿Qué diferencia hay entre una OU y un grupo en Active Directory?**
La OU ordena y sirve para aplicar políticas (GPO); el grupo sirve para dar permisos.

**10. ¿Cómo le llega una IP por DHCP a un equipo de la VLAN 30 si el servidor está en la VLAN 40?**
El router tiene `ip helper-address 172.16.40.20`: reenvía el pedido al servidor y agrega el giaddr (172.16.30.1) para que el servidor elija el ámbito correcto.

**11. ¿Por qué la VLAN nativa es la 999?**
Porque viaja sin etiqueta. Si fuera la VLAN 1, se podría usar para saltar a otra VLAN; la 999 no tiene equipos ni IP.

**12. ¿Por qué Soporte TI tiene dos cuentas en el dominio?**
Para separar el uso diario de la administración: si roban la cuenta diaria, no obtienen privilegios.

**13. ¿Qué garantiza que la carpeta de respaldos en Windows sobreviva a un ataque al servidor Linux?**
La cuenta que escribe los respaldos puede crear archivos pero no borrarlos, ni cambiar sus permisos, ni apropiarse de ellos.

**14. En la Fase 8, ¿un estudiante puede llegar a la VLAN de Administración?**
Sí, porque todavía no hay filtrado. Eso se corrige en la Fase 9 con el firewall por zonas. La Fase 8 deja la red *funcionando*; la Fase 9 la deja *segura*.

**15. ¿Qué valores de la red son propuestos y no del PDF?**
La IP de gestión del switch (172.16.50.2), la de la estación de administración (172.16.50.10) y la red entre el router y el firewall (172.16.255.0/30).

---

## Dónde está cada cosa

| Qué | Dónde |
| --- | --- |
| El PDF (fuente de todo) | `docs/especificacion/` |
| Auditoría, decisiones y plan | `docs/fase-01-auditoria/`, `docs/fase-02-arquitectura/`, `docs/fase-03-plan/` |
| Aplicación y base de datos | `atlas/` y `atlas-analysis/` (servicio Python) |
| Probar todo en tu PC | `./probar-local.sh` (ver el README de la raíz) |
| Manual de cada fase | `docs/fase-04-aplicacion/` … `docs/fase-08-redes/` |
| Scripts de Linux, Windows y red | `infra/linux/`, `infra/windows/`, `infra/red/` |
| Evidencias | `docs/evidencias/` (B aplicación, C Linux, D Windows, E redes, G base de datos) |
