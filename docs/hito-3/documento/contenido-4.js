// Parte II: secciones 31 a 34 (estado, continuidad, referencias y anexos).
const L = require('./lib');
const { add, P, H1, H2, H3, Vineta, Salto, Tabla, Figura, Ref } = L;
const R = require('./resultados');

// 31 ------------------------------------------------------------------------------------------
add(H2('31. Estado del proyecto al Hito 3'));
add(H3('31.1 Resumen'));
add(Tabla('resumen', 'Estado por área y entorno', ['Área', 'Repositorio y desarrollo', 'Laboratorio', 'Pendiente'], [
  ['Programación', `Circuito completo, interfaz rediseñada; ${R.interfaz}`, 'Circuito completo el 19/11: el docente crea y publica, el estudiante resuelve desde la VLAN 30 y el docente ve los indicadores', 'Revisar la lista de atención cuando un intento posterior corrige la señal'],
  ['Base de datos', 'Tres comprobaciones de la devolución verificadas (E-BD-016 a 018)', 'Seguimiento del intento, restauración por intento (13 de 13), métricas y respaldo de la VM', 'Cambio de respuesta en el laboratorio; reinicio de contenedores en la VM restaurada'],
  ['Linux', 'Pasos 1 a 14; respaldos y monitoreo probados', 'Pasos 1 a 7 y 14 (Zabbix); verificar.sh con 93 PASS y 24 FAIL', 'Pasos 8 a 13 (R-3 a R-5)'],
  ['Windows', 'Retención y agente de Zabbix (E-WIN-004 y 54 de 54)', 'Dominio, DNS, DHCP, GPO y cliente unido; Fase 12 instalada; verificador con 73 PASS y 0 FAIL', 'Copiar el script de retención corregido (INC-18)'],
  ['Conectividad', 'VPN y firewall en el gemelo (46 de 46); monitoreo (14 de 14)', 'Las 17 pruebas de red ejecutadas: 14 de 17 en el Hito 2 y las 14, 15 y 16 el 20/11; VPN docente y Zabbix funcionando', 'Perfil de administración de la VPN'],
  ['Gestión', 'Métricas, plan de laboratorio, plan de continuidad y anexo de devoluciones', '—', 'Actas de cierre del Sprint 5'],
], [2, 3.8, 3.4, 2.8]));
add(P('La regla de las versiones anteriores se mantiene: lo que se verificó en desarrollo no se presenta como verificado en el laboratorio. Esta versión 3.2 incorpora las dos jornadas de laboratorio, la del 19 y la del 20/11/2026. Con ellas se cerró lo que más pesaba de las devoluciones: el circuito completo y las comprobaciones de base de datos en el servidor real, la VPN con un cliente real y las pruebas 14 a 16, y el monitoreo con Zabbix y su alerta. Siguen sin ejecutarse la integración de srv01 con el dominio y los respaldos automáticos en srv01, y figuran como *No ejecutada*.'));

add(H3('31.2 Respuesta a las devoluciones del Hito 2'));
add(P('El detalle de cada devolución y de lo que se hizo está en el Anexo I. En resumen:'));
add(Tabla('devoluciones', 'Devoluciones del Hito 2 y respuesta', ['Devolución', 'Qué se hizo', 'Estado'], [
  ['Gestión: resolver el 422 y completar el circuito en el laboratorio', 'Causa corregida en la interfaz (INC-09); circuito completo en el laboratorio con auditoría', 'Cumplido el 19/11/2026 (sección 26.6)'],
  ['Gestión: completar VPN, monitoreo y configuraciones del servidor Linux', 'VPN por perfiles, Zabbix, pasos 13 y 14, scripts del DC; todo probado fuera del laboratorio', 'VPN y monitoreo funcionando en el laboratorio el 20/11; de srv01 faltan los pasos 8 a 13'],
  ['Gestión: verificar respaldos, recuperación y controles de acceso', 'Respaldos automáticos con copia al DC que no se puede borrar desde Linux; restauración por intento; rechazos de atlas_app', 'Recuperación verificada en el laboratorio; respaldos automáticos solo en desarrollo (R-5)'],
  ['Gestión: fortalecer actas, seguimiento y evidencias Scrum', 'Registro por pull request (sección 22.9) y formato de acta (Anexo I)', 'Hecho'],
  ['Gestión: entregar las devoluciones de los hitos anteriores', 'Anexo I', 'Hecho'],
  ['Gestión: métricas que verifiquen requisitos y objetivos', 'Sección 31.4, estado por objetivo en la sección 21 y trazabilidad en el Anexo H', 'Hecho'],
  ['Base de datos: seguir un intento de la pantalla a la base y al informe', 'trazar_intento.py en desarrollo y seguir_intento.sh en el laboratorio', 'Verificado en desarrollo (E-BD-016) y en el laboratorio sin cambio de respuesta (E-BD-019)'],
  ['Base de datos: puntaje guardado contra calculado y rechazo de atlas_app', 'comparar_puntaje.sh: mismos valores, tiempos y cinco rechazos conservados', 'Verificado en desarrollo (E-BD-017)'],
  ['Base de datos: restaurar el intento en el laboratorio frente a RPO/RTO', 'restaurar_intento.sh; respaldo de la VM con vzdump', 'Verificado en el laboratorio: 13 de 13 en 1 s (E-BD-020); VM respaldada y restaurada (E-BD-015)'],
], [4.2, 4.8, 3]));

add(H3('31.3 Pruebas automáticas'));
add(P(`probar-todo.sh corre en un solo comando todas las pruebas que no necesitan el laboratorio y guarda la salida completa de cada conjunto. La corrida del ${R.todo.fecha}, con el código de este documento, dio:`));
add(Tabla('todo', 'Resultado de probar-todo.sh', ['Conjunto', 'Qué prueba', 'Estado', 'Detalle'], R.todo.filas, [1.8, 5, 1.8, 3.4],
  'Fuente: docs/evidencias/H/E-TST-010-ejecucion-2026-11-12 (salida completa de cada conjunto). El FAIL del conjunto linux es «smbd activo»: el contenedor de prueba no tiene systemd y el servicio no puede arrancar; en la VM se verifica con verificar.sh. La prueba de interfaz y las de rendimiento se corren aparte, con la pila levantada.'));
add(P('Además, cada pull request ejecuta en GitHub Actions cuatro trabajos: aplicación (unitarias, PSR-12, base y API contra MySQL 8.0), servicio de análisis, infraestructura (sintaxis de todos los scripts, firewall con tráfico real y lógica de los scripts del DC) y contenedores Ubuntu 24.04 (scripts de srv01, ajustes del laboratorio, respaldos y monitoreo). Un cambio que rompe una prueba no entra a la rama principal (Equipo Error404, 2026b).'));

add(H3('31.4 Métricas de verificación de requisitos y objetivos'));
add(P('La devolución de Gestión pidió métricas que permitan verificar los requisitos y objetivos. Cada métrica de la sección 12 tiene ahora una definición, una meta y una forma de medirla que cualquiera puede repetir. Las que salen de la base las calcula metricas.sh con consultas de solo lectura; el resto, herramientas específicas. La {T:metricas} tiene dos columnas de valores. La de desarrollo sale de datos de demostración sintéticos y muestra que la métrica se calcula y cómo se lee. La del laboratorio sale de la base real de atlas-srv01 después del circuito del 19/11/2026 ({F:metricasLab}): son pocos datos (5 usuarios, 3 intentos y 12 interacciones), así que sirven para comprobar que cada métrica funciona sobre el servidor, no para sacar conclusiones de uso.'));
add(Tabla('metricas', 'Métricas de verificación, meta y valores medidos', ['ID', 'Métrica (objetivo o requisito)', 'Meta', 'Desarrollo', 'Laboratorio (19/11)', 'Cómo se mide'], [
  ['M1', 'Intentos finalizados registrados completos (obj. 3, RF-06 a RF-09)', '100 %', '67 de 67', '3 de 3', 'metricas.sh'],
  ['M2', 'Intentos con más de un resultado (RF-07)', '0', '0', '0', 'metricas.sh'],
  ['M3', 'Resultados distintos del puntaje recalculado (D-4)', '0', '0 de 67', '0 de 3', 'metricas.sh; E-BD-017'],
  ['M4', 'Recomendaciones con regla y versión registradas (obj. 5)', '100 %', '52 de 52', '3 de 3', 'metricas.sh'],
  ['M5', 'Reglas explicables activas (obj. 5)', '≥ 8', '8', '8', 'metricas.sh'],
  ['M6', 'Sugerencias confirmadas por el docente (D-6)', 'Informativa', '1 de 1', '0 de 0', 'metricas.sh'],
  ['M7', 'Preguntas publicadas con habilidad (D-3, RF-21)', '100 %', '13 de 13', '2 de 2', 'metricas.sh'],
  ['M8', 'Accesos denegados registrados (obj. 7, RNF-01)', 'Registrados; revisión semanal', '1 (7 días)', '5 (7 días)', 'metricas.sh'],
  ['M9', 'Cuentas bloqueadas por intentos fallidos (RF-02)', 'Informativa', '0', '0', 'metricas.sh'],
  ['M10', 'Respaldos exitosos en 30 días (RNF-04)', '100 %', 'Sin registros', 'Sin registros (paso 13 sin correr)', 'metricas.sh'],
  ['M11', 'Horas desde el último respaldo (RPO)', '≤ 24 h', 'Sin registros', 'Sin registros (paso 13 sin correr)', 'metricas.sh'],
  ['M12', 'Tiempo de respuesta, percentil 95 (RNF-03)', '≤ 3 s', R.rendimiento.p95max, 'No medido', 'medir.py (E-TST-008); Zabbix'],
  ['M13', 'Disponibilidad (RNF-02)', '≥ 99 %', R.disponibilidad.replace(/ \(.*/, ''), 'SLA de Zabbix desde el 20/11: 89,7 % el primer día, con la caída provocada', 'disponibilidad.sh (E-TST-009); SLA de Zabbix'],
  ['M14', 'Recuperación: tiempo y último intento recuperado (RNF-05)', 'RTO < 4 h; RPO ≤ 24 h', '1 s; último intento recuperado', '1 s (base); último intento recuperado', 'restaurar_intento.sh (E-BD-018, E-BD-020)'],
  ['M15', 'Alertas de infraestructura (RNF-10)', 'Al 80 % de CPU, memoria y disco', 'Alerta de disco disparada al 81,6 %', 'Alerta real: disco de srv01 al 99,1 %', 'Zabbix (E-RED-012; H3-29)'],
  ['M16', 'Eventos de seguridad de red detectados (obj. 10)', 'Todo bloqueo registrado', 'Registro ATLAS-* en el gemelo', 'ATLAS-R12 del 445 desde la VLAN 30, del SSH por la VPN y del 443 desde la WAN', 'journalctl -k en router-lab'],
], [0.8, 3.6, 1.8, 1.9, 2.1, 1.8], 'Fuente: E-TST-007 (M1 a M11 en desarrollo), E-BD-021 (M1 a M11 en el laboratorio), E-TST-008, E-TST-009, E-BD-018, E-BD-020, E-RED-012 y la captura H3-57. M10 y M11 no tienen valor en ningún entorno porque los respaldos automáticos todavía no corren en un servidor; la prueba de respaldos sí verifica que cada copia se anote en registro_respaldos.'));
add(Figura('metricasLab', 'docs/hito-3/capturas/H3-72-srv01-metricas.png', 'metricas.sh sobre la base de atlas-srv01', 'Captura H3-72 (E-BD-021), Shell de Proxmox, 19/11/2026, 23:40. MySQL 8.0.46; base con 5 usuarios, 3 intentos, 3 resultados y 12 interacciones. Resultado: 6 PASS, 0 FAIL y 5 informativas. Debajo, las métricas que se miden con otras herramientas.', { maxAlto: 560 }));
add(P('La precisión de las recomendaciones, que pedía la propuesta, no se puede medir sin docentes reales: se aproxima con M6, el porcentaje de sugerencias que el docente confirma sin cambiar. Esa medición es parte de la prueba piloto de la sección 32.'));

add(H3('31.5 Incidencias corregidas'));
add(Tabla('incidencias', 'Incidencias del laboratorio del Hito 2 y su corrección', ['ID', 'Problema', 'Corrección', 'Estado'], [
  ['INC-01', 'ATLAS no arrancaba sin Internet', 'atlas.service con --no-build --pull never', 'Verificada en desarrollo (E-TST-003)'],
  ['INC-02', 'El administrador inicial no se creaba en una segunda corrida', 'Se crea si su contraseña inicial sigue en atlas.conf', 'Corregida; verificar en R-3'],
  ['INC-03', 'MySQL en bucle por CPU sin x86-64-v2', 'CPU x86-64-v2-AES o host al crear las VM', 'Corregida; resto de VM en R-1'],
  ['INC-04', 'WAN de router-lab sin dirección', 'WAN_IP y WAN_GW en 04-router-lab.sh', 'Verificada'],
  ['INC-05', 'Caída del enlace USB con la MAC de una VM', 'vmbr2 con NAT de Proxmox (WAN_INTERNA=si)', 'Verificada; causa a confirmar con dmesg (R-12)'],
  ['INC-06/07', 'Falsos FAIL del verificador del DC en Windows en español', 'Lectura por posición y redes en dos formatos', 'Verificada (E-WIN-004)'],
  ['INC-08', 'atlas-ctl no instalado', 'Se instala en el paso 7', 'Corregida; verificar en R-3'],
  ['INC-09', 'Publicar devolvía 422 sin explicar', 'Aviso claro y control del grupo antes de enviar', 'Verificada en la prueba de interfaz y en el laboratorio (19/11)'],
], [1.4, 3.6, 4, 3], 'Fuente: informe de Testing del Hito 2 (Equipo Error404, 2026b), sección de incidencias.'));

add(H3('31.6 Lo que dejó la jornada de laboratorio'));
add(P('Las jornadas del 19 y el 20/11/2026 dejaron, además de los resultados, observaciones que no estaban previstas en el plan. Se anotan acá para no perderlas:'));
add(Vineta([
  'La lista de atención prioritaria sigue mostrando al estudiante por R07 y R01 aunque su intento siguiente sacó 100 (sección 26.6). El cálculo es correcto; lo que hay que decidir es si la lista debe descartar una señal que ya se corrigió.',
  'El reloj de cliente-doc marca tres horas menos que la hora de Uruguay. Los datos no se afectan porque los tiempos los pone el servidor; hay que revisar la zona horaria del cliente.',
  'El verificador del DC dio el 19/11 lo mismo que en el Hito 2 (63 PASS y 5 FAIL). El 20/11, con los scripts nuevos copiados, dio 73 PASS y 0 FAIL: era el script viejo (INC-14, cerrada).',
  'La retención del DC falló con la carpeta atlas-backups vacía (INC-18). Ya está corregida y tiene una prueba que reproduce el caso; falta copiar el script corregido al DC.',
  'Zabbix detectó en su primer día que el disco de atlas-srv01 estaba al 99,1 % (INC-19). La causa era que el instalador de Ubuntu había usado 14 de los 28 GB del disco; se amplió el volumen esa noche y quedó al 42 %.',
  'router-lab registra a srv01 intentando sincronizar la hora con servidores de Internet (UDP 123), algo que la política bloquea (INC-20). Se resuelve con el paso 8, que hace que srv01 tome la hora del DC.',
  'En la VM restaurada con la placa desconectada, atlas-web no arranca porque no tiene dónde publicar sus puertos. Para que la prueba de restauración de la VM sea completa, hay que hacerla en una red aislada con la misma dirección, no solo sin placa.',
]));
add(H3('31.7 Trabajo pendiente'));
add(P('Ya se ejecutaron el circuito completo (R-8), las comprobaciones de base de datos (R-9), el respaldo de la VM (R-10), la VPN con las pruebas 14 a 16 (R-7), el monitoreo con los dos agentes (R-6), la Fase 12 del DC y su verificación (R-2, parte de R-5 y R-11). Lo que falta tiene su paso en el Anexo J: comprobar el arranque sin Internet (R-3), unir srv01 al dominio e instalar el certificado de ATLAS-CA (R-4), activar los respaldos con la copia al DC y copiar al DC el script de retención corregido (R-5), y rotar las credenciales que quedaron expuestas en el Hito 2 (R-12). Hasta que se ejecuten, cada una de esas pruebas figura como *No ejecutada*.'));

// 32 ------------------------------------------------------------------------------------------
add(H2('32. Continuidad: plan para los semestres siguientes'));
add(P('La rúbrica pide que el proyecto quede preparado para desarrollarse durante los semestres siguientes, con miras a la entrega final al término de los dos años. Esta sección fija qué se hace, en qué orden y cómo se sabe que se cumplió. Es un plan: nada de lo que sigue está ejecutado.'));
add(H3('32.1 Punto de partida'));
add(P('Cualquier integrante (o un equipo nuevo) puede retomar el proyecto desde el repositorio: el README explica la estructura; ./probar-local.sh levanta ATLAS con datos de demostración en una notebook; ./probar-todo.sh corre todas las pruebas; infra/linux/instalar.sh y los scripts de infra/windows y infra/proxmox reconstruyen el laboratorio; y el Anexo J deja el procedimiento de laboratorio con resultados esperados. Las contraseñas no están en el repositorio: se generan al instalar o se piden sin eco.'));
add(H3('32.2 Plan por semestre'));
add(Tabla('plan', 'Plan de trabajo para los semestres siguientes', ['Período', 'Objetivo', 'Entregables', 'Cómo se verifica'], [
  ['Cierre 2026 (Sprint 5)', 'Terminar en el laboratorio lo implementado en el Hito 3', 'Pasos R-3, R-4, R-5 y R-12 del Anexo J; nueva versión del documento con esos resultados', 'Pruebas 14 a 16 aprobadas; verificar.sh y verificar-dc01 sin FAIL; M10 y M11 con datos'],
  ['Semestre 1 de 2027', 'Prueba piloto controlada en el ITI', 'Protocolo con consentimiento informado (Uruguay, 2008; Unidad Reguladora y de Control de Datos Personales, 2023); relevamiento ampliado a docentes del ITI; dos o tres grupos usando ATLAS durante cuatro semanas', 'Al menos 20 respuestas al relevamiento; SLA ≥ 99 % en el período (Zabbix); tareas principales completadas sin asistencia (RNF-11)'],
  ['Semestre 1 de 2027', 'Usabilidad y accesibilidad', 'Prueba de uso con docentes; revisión con las pautas WCAG 2.2 nivel AA (W3C, 2023)', 'Lista de hallazgos con su corrección; prueba de interfaz ampliada'],
  ['Semestre 2 de 2027', 'Análisis con datos reales', 'Evaluación de las reglas R01 a R08 frente a la decisión docente; evaluación de K-means y regresión logística con datos suficientes', 'M6 (acuerdo docente) y comparación con y sin ML; decisión documentada de mantener o retirar el ML'],
  ['Semestre 2 de 2027', 'Asistente opcional con datos anonimizados', 'Prueba con la API real del modelo de lenguaje, con la clave fuera del repositorio', 'Ninguna consulta con datos personales (revisión de lo enviado); RNF-15 con el servicio apagado'],
  ['Semestre 2 de 2027', 'Operación y seguridad', 'Rotación periódica de credenciales; prueba de restauración mensual con registro; revisión semanal de denegaciones', 'M10, M11 y M14 con datos del servidor; registro de revisiones'],
  ['Fin de 2027', 'Entrega final', 'Documento final, defensa y demostración de punta a punta', 'Todos los criterios de la sección 21 con evidencia de laboratorio o piloto'],
], [2.2, 2.8, 3.8, 3.2]));
add(H3('32.3 Backlog priorizado'));
add(Tabla('backlog', 'Backlog para la siguiente etapa', ['Prioridad', 'Ítem', 'Motivo'], [
  ['Alta', 'Completar el Anexo J (R-3, R-4, R-5 y R-12)', 'Cierra los pendientes de laboratorio que quedaron después del 20/11.'],
  ['Media', 'Lista de atención: descartar señales ya corregidas por un intento posterior', 'Observación de la jornada del 19/11 (sección 31.6).'],
  ['Alta', 'Protocolo de la prueba piloto y consentimiento', 'Condición para usar datos de estudiantes reales.'],
  ['Alta', 'Medición continua de disponibilidad y tiempos en el laboratorio', 'RNF-02 y RNF-03 con datos del entorno real.'],
  ['Media', 'Material de estudio (previsto en la propuesta)', 'Funcionalidad para estudiantes todavía no implementada.'],
  ['Media', 'Exportación de reportes para el docente', 'Pedido frecuente en grupos numerosos (relevamiento).'],
  ['Media', 'Evaluación del ML con datos reales', 'Hoy es experimental (D-7).'],
  ['Baja', 'Asistente con la API real del modelo de lenguaje', 'Opcional (D-5); no es necesario para las consultas guiadas.'],
  ['Baja', 'Uso por más de una institución', 'Fuera del alcance de la tesis (sección 18); el modelo de datos ya lo admite.'],
], [1.6, 5.2, 5.2]));

// 33 ------------------------------------------------------------------------------------------
add(Salto());
add(H1('33. Referencias'));
const refs = [
  ['Canonical. (s. f.). *Ubuntu Server documentation*. ', 'https://ubuntu.com/server/docs/'],
  ['Docker. (s. f.). *Docker documentation*. ', 'https://docs.docker.com/'],
  ['Equipo Error404. (2026a, 22 de octubre). *Hito 2: Qué se hizo y qué cambia en el documento* [Informe técnico interno].'],
  ['Equipo Error404. (2026b, 1 de noviembre). *Hito 2 de Testing: implementación y ejecución de pruebas de ATLAS* [Informe técnico].'],
  ['IEEE. (1998). *IEEE recommended practice for software requirements specifications* (IEEE Std 830-1998). Institute of Electrical and Electronics Engineers.'],
  ['Laravel. (s. f.). *Laravel 12.x documentation*. ', 'https://laravel.com/docs/12.x'],
  ['Microsoft. (s. f.). *Windows Server documentation*. ', 'https://learn.microsoft.com/es-es/windows-server/'],
  ['NGINX. (s. f.). *nginx documentation*. ', 'https://nginx.org/en/docs/'],
  ['Oracle. (s. f.). *MySQL 8.0 reference manual*. ', 'https://dev.mysql.com/doc/refman/8.0/en/'],
  ['PHP Documentation Group. (s. f.). *Manual de PHP*. ', 'https://www.php.net/manual/es/'],
  ['Playwright. (s. f.). *Playwright documentation*. ', 'https://playwright.dev/docs/intro'],
  ['Proxmox Server Solutions. (s. f.). *Proxmox VE administration guide*. ', 'https://pve.proxmox.com/pve-docs/'],
  ['Santiago. (2026, 23 de octubre). *Hito 2 de Redes: implementación del laboratorio ATLAS en Proxmox* [Informe técnico de laboratorio, versión 2].'],
  ['Schwaber, K., y Sutherland, J. (2020). *La Guía Scrum*. ', 'https://scrumguides.org/docs/scrumguide/v2020/2020-Scrum-Guide-Spanish-Latin-South-American.pdf'],
  ['Society for Learning Analytics Research. (2025). *What is learning analytics?* ', 'https://www.solaresearch.org/about/what-is-learning-analytics/'],
  ['Unidad Reguladora y de Control de Datos Personales. (2023). *Guía sobre protección de datos personales en Uruguay*. ', 'https://www.gub.uy/unidad-reguladora-control-datos-personales/comunicacion/noticias/guia-sobre-proteccion-datos-personales-uruguay'],
  ['Uruguay. (2008). *Ley N.º 18.331 de protección de datos personales y acción de habeas data*. ', 'https://www.gub.uy/ministerio-interior/institucional/normativa/ley-n-18331-fecha-18082008-ley-proteccion-datos-personales'],
  ['W3C. (2023). *Web Content Accessibility Guidelines (WCAG) 2.2*. ', 'https://www.w3.org/TR/WCAG22/'],
  ['WireGuard. (s. f.). *Quick start*. ', 'https://www.wireguard.com/quickstart/'],
  ['Zabbix. (s. f.). *Zabbix 7.0 documentation*. ', 'https://www.zabbix.com/documentation/7.0/'],
];
for (const [t, u] of refs) add(Ref(t, u));

// 34 ------------------------------------------------------------------------------------------
add(Salto());
add(H1('34. Anexos'));
add(Tabla('anexos', 'Anexos y estado en esta edición', ['Anexo', 'Contenido', 'Estado'], [
  ['A', 'Formulario y resultados del relevamiento', 'Sin cambios respecto de la V2.4.'],
  ['B', 'Evidencias de programación', 'Actualizado: interfaz nueva (E-APP-015) y capturas del laboratorio (E-APP-014).'],
  ['C', 'Evidencias del servidor Linux', 'Actualizado: pasos 13 y 14, E-LNX-005 y verificación del laboratorio (E-LNX-006).'],
  ['D', 'Evidencias de Windows y dominio', 'Actualizado: Fase 12, E-WIN-004, verificador del laboratorio (63/5 y después 73/0), agente de Zabbix y cliente en la VLAN 30.'],
  ['E', 'Implementación y verificación del laboratorio Proxmox', 'Informe de Redes del Hito 2, incorporado completo al final de este documento.'],
  ['F', 'Decisiones del proyecto', 'D-1 a D-8 y decisiones de infraestructura que se aplicaron en el Hito 3.'],
  ['G', 'Evidencias de base de datos', 'Actualizado: E-BD-016 a E-BD-018 en desarrollo; E-BD-015 y E-BD-019 a 021 en el laboratorio.'],
  ['H', 'Especificación de requisitos de software', 'Versión 1.2: verificación de cada requisito al Hito 3.'],
  ['I', 'Devoluciones de los hitos anteriores y respuesta', 'Nuevo.'],
  ['J', 'Plan de trabajo de Redes en el laboratorio', 'Nuevo.'],
  ['K', 'Índice de evidencias del Hito 3', 'Nuevo; incluye las del laboratorio.'],
], [1.2, 5.2, 5.6], 'Los archivos de evidencia están en docs/evidencias/ del repositorio, en las carpetas B (programación), C (Linux), D (Windows), E (redes), F (decisiones), G (base de datos) y H (pruebas).'));
add(Salto());
