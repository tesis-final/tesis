// Genera el informe del Hito 3 de Testing en Word, con el mismo formato APA 7 del Hito 2.
// Uso: NODE_PATH=$(npm root -g) node docs/hito-3/testing/generar.js [salida.docx]
// Los números salen de resultados.json, y cada uno apunta a un archivo de docs/evidencias/H/.
const B = require('./base');
const { fs, path, Packer, Paragraph, TextRun, SANGRIA, DOBLE, P, PSin, Centro, Vacio, Salto, H1, H2, H3,
  Numerada, Tabla, Fig, Consola, Ref, documento } = B;
const R = JSON.parse(fs.readFileSync(path.join(__dirname, 'resultados.json'), 'utf8'));
const LAB = 'docs/hito-3/capturas/';
const CAP = 'docs/evidencias/H/E-TST-014-interfaz/';
const TITULO = 'Hito 3 de Testing: análisis de cobertura, calidad del software y conclusiones de las pruebas de ATLAS';

const c = [];

// Portada --------------------------------------------------------------------------------------
for (let i = 0; i < 3; i++) c.push(Vacio());
c.push(Centro(`**${TITULO}**`));
c.push(Vacio());
c.push(Centro('Santiago Emanuel Viñas Rezzano, Juan Pablo Beracochea Cabrera, Aaron Britos Alonso, Brian Daniel Reyes Ortiz y Sergio Enrique Rodríguez Oquel'));
c.push(Centro('Grupo Error404'));
c.push(Centro('Tecnicatura en Redes y Software, Instituto Tecnológico de Informática, ITI-CETP/UTU'));
c.push(Centro('Testing, Clase TC4, Proyecto Final de Egreso'));
c.push(Centro('Prof. Carina Sindoni'));
c.push(Centro('20 de noviembre de 2026'));
c.push(Salto());

// Resumen --------------------------------------------------------------------------------------
c.push(H1('Resumen'));
c.push(PSin(R.resumen));
c.push(new Paragraph({ spacing: DOBLE, indent: { firstLine: SANGRIA }, children: [
  new TextRun({ text: 'Palabras clave:', italics: true }),
  new TextRun(' cobertura de pruebas, calidad del software, análisis estático, integración continua, evidencias de prueba'),
] }));
c.push(Salto());

// Introducción ---------------------------------------------------------------------------------
c.push(Centro(`**${TITULO}**`, { keepNext: true }));
c.push(P('ATLAS es la plataforma web del grupo Error404 en la que los estudiantes resuelven actividades de múltiple opción y el sistema registra el proceso: tiempos, intentos, cambios de respuesta y abandonos. Con esos datos el docente ve indicadores por estudiante, por habilidad y por grupo, y una lista de quiénes requieren atención (Error404, 2026a). La aplicación está hecha en Laravel 12 sobre MySQL 8.0, con un servicio de análisis en Python, y corre en un laboratorio Proxmox con cuatro máquinas virtuales: router-lab, atlas-dc01, atlas-srv01 y cliente-doc.'));
c.push(P('En el Hito 2 de Testing se escribieron las pruebas, se automatizaron y se ejecutaron por primera vez completas (Error404, 2026b). El Hito 3 pide cerrar el proceso con tres entregables: un análisis de cobertura y de calidad del software basado en resultados, la documentación de las evidencias con sus conclusiones, y la presentación final con la defensa del proceso de testing. La Tabla 1 muestra dónde se responde cada pedido.'));
c.push(...Tabla('Pedidos del hito y dónde se resuelven', ['Pedido', 'Cómo se resolvió', 'Apartado'], [
  ['Análisis de cobertura basado en resultados', 'Cobertura de código medida en PHP, Python y JavaScript; cobertura de las rutas de la API, de los requisitos y de la infraestructura', 'Análisis de cobertura'],
  ['Análisis de calidad del software basado en resultados', 'Defectos encontrados y corregidos, análisis estático de todo el código, estabilidad de las pruebas en GitHub y comparación con el Hito 2', 'Calidad del software'],
  ['Documentación de evidencias', 'Corrida completa del 20 de noviembre, pruebas en el laboratorio del 19 y 20 de noviembre e índice de evidencias', 'Resultados y Apéndice A'],
  ['Conclusiones', 'Qué quedó probado, qué no y qué significa para el proyecto', 'Conclusiones'],
  ['Presentación final y defensa del proceso', 'Guion de la presentación, demostración y preguntas previstas con sus respuestas', 'Presentación y defensa'],
], [3.4, 6, 2.4]));
c.push(P(`El informe sigue el mismo criterio del Hito 2: una prueba solo se da por aprobada si se ejecutó y dio lo esperado, y lo que no se pudo correr figura como no ejecutado, con su motivo. Las cifras salen de las salidas de las pruebas, que están en el repositorio del proyecto (Error404, 2026c), y no de estimaciones.`));

// Método ---------------------------------------------------------------------------------------
c.push(H1('Método'));
c.push(H2('Entornos de ejecución'));
c.push(P('Las pruebas de este hito se ejecutaron en tres lugares y cada resultado indica en cuál. Lo que pasó en el entorno de pruebas no se presenta como si hubiera pasado en el laboratorio. La Tabla 2 resume los tres entornos.'));
c.push(...Tabla('Entornos en los que se ejecutaron las pruebas', ['Entorno', 'Qué se ejecutó', 'Características'], [
  ['Entorno de pruebas', `La corrida completa de los once conjuntos, la cobertura, el análisis estático, la prueba de interfaz, los tiempos de respuesta y las comprobaciones de base de datos, el ${R.fecha}`, R.entorno],
  ['GitHub Actions', 'Las pruebas automáticas en cada pull request, desde el Hito 2', 'Máquinas ubuntu-24.04 de GitHub, cuatro trabajos en paralelo'],
  ['Laboratorio Proxmox', 'El circuito completo de ATLAS, la prueba 7 de la red, las comprobaciones de base de datos, el respaldo de la máquina virtual y los verificadores, el 19 y el 20 de noviembre', 'Proxmox VE 9.2.2 con router-lab, atlas-dc01, atlas-srv01 y cliente-doc'],
], [2.5, 5, 4.5]));

c.push(H2('Qué se midió y cómo'));
c.push(P('La cobertura dice qué parte del sistema ejecutaron las pruebas; no dice si lo que se ejecutó está bien. Por eso se midió de varias formas y se acompañó con medidas de calidad que no dependen de la cobertura (Myers et al., 2011). Las características de calidad que se usan para ordenar el análisis son las del modelo ISO/IEC 25010 (International Organization for Standardization [ISO], 2011): adecuación funcional, eficiencia de desempeño, fiabilidad, seguridad, mantenibilidad y portabilidad. La Tabla 3 detalla cada medida.'));
c.push(...Tabla('Medidas de cobertura y de calidad usadas en el hito', ['Medida', 'Qué indica', 'Herramienta'], [
  ['Cobertura de código PHP', 'Líneas, métodos y clases de atlas/app/ que ejecutan juntas las pruebas unitarias, de API y de base de datos', 'PHPUnit con pcov (Bergmann, 2026; Krakjoe, 2024)'],
  ['Cobertura de código Python', 'Sentencias y ramas del servicio de análisis que ejecutan sus pruebas', 'pytest (pytest-dev, 2024) con pytest-cov sobre coverage.py (Batchelder, 2024)'],
  ['Cobertura de JavaScript', 'Caracteres del código del navegador que se ejecutaron durante la prueba de interfaz', 'Perfilador de Chromium durante la prueba de Playwright (Microsoft, 2024), el mismo dato del panel Coverage de DevTools (Google, s. f.)'],
  ['Cobertura de rutas de la API', 'Cuántas de las rutas de /api/v1 alcanzan las pruebas y con qué códigos de respuesta', 'Registro agregado al cliente de las pruebas de API'],
  ['Cobertura de requisitos', 'Qué requisitos y criterios del documento de ATLAS tienen una prueba ejecutada', 'Trazabilidad del Anexo H del documento integrador'],
  ['Análisis estático', 'Errores y malas prácticas que se detectan sin ejecutar el código', 'PHP_CodeSniffer (PHPCSStandards, 2026), php -l, node --check, ShellCheck (Holzer, 2024) y Ruff (Astral, 2024)'],
  ['Defectos', 'Fallas encontradas, su causa y si quedaron corregidas y verificadas', 'Registro de incidencias'],
  ['Estabilidad de las pruebas', 'Cuántas corridas de GitHub fallaron sin que el producto tuviera un error', 'Historial de GitHub Actions'],
  ['Desempeño y disponibilidad', 'Tiempo de respuesta frente a los 3 segundos de RNF-03 y respuestas correctas durante diez minutos', 'medir.py y disponibilidad.sh'],
], [3, 5.4, 3.6]));
c.push(P('El documento de ATLAS no fija un porcentaje mínimo de cobertura, así que no se inventó uno. El equipo usó una referencia propia para leer los resultados: la lógica que decide qué ve el docente (servicios, indicadores y reglas) debería estar cubierta en su mayoría, y lo que quede afuera tiene que tener un motivo. Esa referencia es del equipo y no un requisito del proyecto.'));

c.push(H2('Criterio para informar los resultados'));
c.push(P('Se mantienen los tres estados del Hito 2. *Aprobada* significa que la prueba se ejecutó y dio lo esperado. *Fallada* significa que se ejecutó y dio otra cosa; en ese caso se anota qué dio y se abre una incidencia. *No ejecutada* significa que no se pudo correr, y se anota el motivo. Una corrección se considera verificada solo si hay una prueba que primero reproduce la falla y después pasa.'));

c.push(H2('Herramientas agregadas en este hito'));
c.push(P('Para medir la cobertura sin cambiar la forma de correr las pruebas de todos los días, se agregaron cuatro piezas que solo se activan cuando se pide la medición. La Tabla 4 las describe.'));
c.push(...Tabla('Herramientas de medición agregadas en el Hito 3', ['Herramienta', 'Ubicación', 'Qué hace'], [
  ['Script de cobertura', 'atlas/tests/cobertura.sh', 'Levanta un MySQL 8.0 descartable, corre juntas las pruebas unitarias, de API y de base de datos con pcov, y arma el resumen de rutas'],
  ['Configuración de cobertura', 'atlas/phpunit-cobertura.xml', 'La misma configuración de PHPUnit, más el código que se mide (atlas/app/)'],
  ['Registro de rutas', 'atlas/tests/Api/Cliente.php', 'Con ATLAS_RUTAS_CUBIERTAS, anota cada ruta que alcanza una prueba y el código que recibió'],
  ['Cobertura del navegador', 'atlas/tests/e2e/interfaz.py', 'Con ATLAS_COBERTURA_JS, pide a Chromium qué partes del JavaScript se ejecutaron durante el recorrido'],
], [3, 3.6, 5.4]));

// Resultados -----------------------------------------------------------------------------------
c.push(H1('Resultados'));
c.push(H2(`Corrida completa del ${R.fecha}`));
c.push(P(R.corrida.texto));
c.push(...Tabla(`Resultados de la corrida completa del ${R.fecha} de 2026`, ['Conjunto', 'Pruebas', 'Resultado', 'Estado'], R.corrida.filas, [4.6, 2, 3.8, 1.6], R.corrida.nota));
c.push(P(R.corrida.comparacion));

c.push(H2('Prueba de interfaz'));
c.push(P(R.interfaz.texto));
R.interfaz.figuras.forEach((f) => c.push(...Fig(CAP + f[0], f[1], f[2], f[3] || 520, f[4] || 560)));

c.push(H2('Tiempo de respuesta y disponibilidad'));
c.push(P(R.rendimiento.texto));
c.push(...Tabla('Tiempo de respuesta de las consultas más frecuentes, en milisegundos', ['Rol', 'Consulta', 'Mín.', 'Mediana', 'P95', 'Máx.', 'Resultado'], R.rendimiento.filas, [1.8, 4.2, 1, 1.4, 1, 1, 1.7], R.rendimiento.nota));
c.push(P(R.disponibilidad));

c.push(H2('Comprobaciones de la base de datos'));
c.push(P(R.bd.texto));
c.push(...Tabla('Comprobaciones de la base de datos pedidas en la devolución del Hito 2', ['Comprobación', 'Entorno de pruebas', 'Laboratorio', 'Estado'], R.bd.filas, [3.4, 3.6, 3.4, 1.6]));

c.push(H2('Pruebas en el laboratorio Proxmox'));
c.push(P('El 19 y el 20 de noviembre se ejecutó en el laboratorio casi todo el plan del Hito 3, en dos jornadas. Es la primera vez que el circuito completo de ATLAS corrió sobre las máquinas virtuales (en el Hito 2 se había cortado al publicar), y la primera vez que se probaron la VPN con un cliente real y el monitoreo. La Tabla 8 resume lo ejecutado y las figuras 5 a 10 muestran las evidencias principales; el resto de las capturas está en el documento integrador y en el repositorio.'));
c.push(...Tabla('Pruebas ejecutadas en el laboratorio Proxmox el 19 y el 20 de noviembre de 2026', ['Prueba', 'Resultado', 'Estado'], [
  ['Circuito completo: el docente crea y publica, el estudiante resuelve desde la VLAN 30 y el docente ve los indicadores', 'Se completó. La publicación sin opción correcta se rechazó con el motivo y, ya corregida, pasó a publicada sin aprobación (D-2). Matias Perez resolvió dos veces (0 y 100) y el docente vio el grupo, el perfil, la consulta y el reporte', 'Aprobada'],
  ['Prueba 7 de la red: el puerto 445 de atlas-srv01 desde la VLAN 30', 'TcpTestSucceeded False desde 172.16.30.100 y cinco líneas ATLAS-R12 en router-lab', 'Aprobada'],
  ['Seguimiento del intento en la base de atlas-srv01', 'Un único resultado de 100,00, igual al recalculado, y las cuatro interacciones en orden. En ese intento no hubo cambio de respuesta', 'Aprobada'],
  ['Restauración por intento', '13 de 13 comparaciones iguales; respaldo en 165 ms y restauración en 1004 ms', 'Aprobada'],
  ['Métricas M1 a M11 sobre la base real', '6 PASS, 0 FAIL y 5 informativas', 'Aprobada'],
  ['Respaldo de la máquina virtual 130 y restauración como 930', 'vzdump en 124 s y restauración en 81 s; en la copia sin placa de red, el contenedor web no arranca', 'Aprobada, con observación'],
  ['Prueba 15: con la VPN, el docente llega a ATLAS', 'Test-NetConnection al 443 True desde 10.8.0.130 y la pantalla de ingreso en el navegador de la PC; el servidor registra el origen 10.8.0.130 (sin NAT)', 'Aprobada'],
  ['Prueba 16: con la VPN, el docente no llega al SSH', 'TcpTestSucceeded False y cinco líneas ATLAS-R12 desde wg0 en router-lab', 'Aprobada'],
  ['Prueba 14: sin VPN, desde la WAN no se entra', 'curl terminó con rc=28 y router-lab registró ATLAS-R12 desde ens19 hacia el 443', 'Aprobada'],
  ['Monitoreo con Zabbix en atlas-srv01', 'Dos agentes respondiendo, chequeo web en 11 ms, SLA definido; al apagar ATLAS se abrió «ATLAS no responde» y se resolvió al encenderlo (3 min 40 s). Detectó el disco de srv01 al 99,1 %, que se amplió esa noche a 28 GB (42 % de uso)', 'Aprobada'],
  ['Retención de respaldos en atlas-dc01', 'La tarea quedó instalada, pero la simulación falló con la carpeta vacía (INC-18); corregida y verificada fuera de Windows', 'Fallada, corregida'],
  ['verificar.sh en atlas-srv01', '86 PASS y 31 FAIL el 19/11; después del paso 14, 93 PASS y 24 FAIL, y monitoreo y firewall 23 de 23. Los FAIL que quedan son de los pasos 8 a 13, que no se corrieron', 'Fallada (pasos sin ejecutar)'],
  ['verificar-dc01.ps1 en atlas-dc01', '63 PASS y 5 FAIL con el script viejo el 19/11; 73 PASS y 0 FAIL con los scripts nuevos el 20/11', 'Aprobada'],
  ['Firewall de router-lab', 'El volcado de nftables muestra cargadas las reglas de la VPN (R8 y R9) y la entrada UDP 51820', 'Aprobada'],
], [4.2, 6, 1.8], 'Detalle y capturas en el documento integrador V3.1, sección 26.6 y Anexo K (Error404, 2026a), y en docs/hito-3/capturas/ del repositorio.'));
c.push(...Fig(LAB + 'H3-53-app-aviso-motivo.png', 'ATLAS no publica una actividad sin opción correcta y explica el motivo',
  'Captura del laboratorio, cliente-doc, 19 de noviembre de 2026. El aviso es de ATLAS y nombra la pregunta que falla; la pregunta queda marcada en rojo. Es la corrección de la incidencia INC-09 del Hito 2 vista en el entorno real.', 520, 520));
c.push(...Fig(LAB + 'H3-57-router-registro-445.png', 'Registro del bloqueo del puerto 445 en router-lab',
  'Captura del laboratorio, 20 de noviembre de 2026 (hora UTC del router). Cada línea es un intento desde 172.16.30.100 hacia 172.16.40.10:445 descartado por la regla R12. En el Hito 2 la prueba había dado el resultado esperado, pero el registro no se había podido ver.', 560, 560));
c.push(...Fig(LAB + 'H3-71-srv01-restaurar-intento.png', 'Restauración por intento sobre la base de atlas-srv01',
  'Captura del laboratorio, 19 de noviembre de 2026. Las cuatro partes del intento tienen la misma huella sha256 en la base en uso y en la restaurada, y las nueve tablas tienen la misma cantidad de filas.', 560, 600));
c.push(...Fig(LAB + 'H3-74a-srv01-verificar.png', 'Final de verificar.sh en atlas-srv01',
  'Captura del laboratorio, 20 de noviembre de 2026. Las secciones con FAIL son las de los pasos 8 a 14 del instalador (hora, dominio, Samba, registros, sudo, respaldos y monitoreo). Las secciones de la base del servidor no tienen fallas.', 560, 600));
c.push(...Fig(LAB + 'H3-43-router-registro-prueba16.png', 'Prueba 16: el SSH del servidor desde la VPN queda bloqueado y registrado',
  'Captura del laboratorio, router-lab, 20 de noviembre de 2026 (hora UTC). A las 21:17 aparecen los intentos desde 10.8.0.130, entrando por wg0, hacia 172.16.40.10:22, descartados por R12. Las otras líneas son de atlas-srv01 intentando sincronizar la hora con Internet (INC-20).', 560, 600));
c.push(...Fig(LAB + 'H3-34-zabbix-alerta-resuelta.png', 'Zabbix avisa que ATLAS no responde y registra cuando vuelve',
  'Captura del laboratorio, Zabbix, 20 de noviembre de 2026. Con ATLAS apagado a propósito, el problema «ATLAS no responde» se abrió a las 19:02 y se resolvió a las 19:06, al volver a encenderlo. En ese momento seguía abierto el aviso del disco de atlas-srv01 por encima del 90 %, que se resolvió esa noche ampliando el volumen (INC-19); los otros dos avisos no son del servicio.', 560, 520));

c.push(H2('Ejecución en GitHub Actions'));
c.push(P(R.ci.texto));
c.push(...Tabla('Corridas de GitHub Actions desde que existe el workflow', ['Período', 'Corridas', 'Aprobadas', 'Falladas', 'Causa de las fallas'], R.ci.filas, [2.8, 1.4, 1.6, 1.4, 4.8], R.ci.nota));

// Análisis de cobertura ------------------------------------------------------------------------
c.push(H1('Análisis de cobertura'));
c.push(P(R.cobertura.intro));
c.push(H2('Cobertura del código PHP'));
c.push(P(R.cobertura.php.texto));
c.push(...Tabla('Cobertura del código PHP de atlas/app/ por capa', ['Capa', 'Clases', 'Líneas cubiertas', 'Cobertura de líneas', 'Métodos cubiertos'], R.cobertura.php.filas, [3.6, 1.2, 2.6, 2.2, 2.4], R.cobertura.php.nota));
c.push(P(R.cobertura.php.lectura));
c.push(H2('Cobertura del servicio de análisis en Python'));
c.push(P(R.cobertura.python.texto));
c.push(...Tabla('Cobertura del servicio de análisis por módulo', ['Módulo', 'Sentencias', 'Sin ejecutar', 'Ramas', 'Cobertura'], R.cobertura.python.filas, [4, 1.8, 2, 1.6, 1.8], R.cobertura.python.nota));
c.push(H2('Cobertura del JavaScript de la interfaz'));
c.push(P(R.cobertura.js.texto));
c.push(...Tabla('Cobertura del JavaScript durante la prueba de interfaz', ['Archivo', 'Qué contiene', 'Caracteres ejecutados', 'Cobertura'], R.cobertura.js.filas, [2.8, 4.4, 2.8, 1.6], R.cobertura.js.nota));
c.push(H2('Cobertura de las rutas de la API'));
c.push(P(R.cobertura.rutas.texto));
c.push(...Tabla('Rutas que no tenían una prueba completa y pruebas agregadas', ['Ruta', 'Para qué sirve', 'Cómo se prueba hoy'], R.cobertura.rutas.filas, [4, 4, 4], R.cobertura.rutas.nota));
c.push(H2('Cobertura de requisitos e infraestructura'));
c.push(P(R.cobertura.requisitos.texto));
c.push(...Tabla('Cobertura de requisitos y de la infraestructura por pruebas ejecutadas', ['Elemento', 'Total', 'Con prueba automática', 'Ejecutado también en el laboratorio'], R.cobertura.requisitos.filas, [4.4, 1.4, 3, 3.2], R.cobertura.requisitos.nota));
c.push(H2('Lo que la cobertura no dice'));
c.push(P(R.cobertura.limites));

// Calidad --------------------------------------------------------------------------------------
c.push(H1('Calidad del software'));
c.push(H2('Defectos encontrados en el hito'));
c.push(P(R.calidad.defectos.texto));
c.push(...Tabla('Incidencias del Hito 3', ['ID', 'Origen', 'Síntoma', 'Causa', 'Solución y estado'], R.calidad.defectos.filas, [1.2, 1.8, 3, 3, 3], R.calidad.defectos.nota));
c.push(H2('Estado de las incidencias del Hito 2'));
c.push(P(R.calidad.hito2.texto));
c.push(...Tabla('Seguimiento de las incidencias abiertas o sin verificar al cierre del Hito 2', ['ID', 'Estado en el Hito 2', 'Estado en el Hito 3'], R.calidad.hito2.filas, [1.6, 4.4, 6]));
c.push(H2('Análisis estático del código'));
c.push(P(R.calidad.estatico.texto));
c.push(...Tabla('Resultados del análisis estático', ['Código', 'Herramienta', 'Alcance', 'Resultado'], R.calidad.estatico.filas, [2, 2.6, 3, 4.4], R.calidad.estatico.nota));
c.push(H2('Evolución respecto del Hito 2'));
c.push(P(R.calidad.evolucion.texto));
c.push(...Tabla('Cantidad de comprobaciones por conjunto en el Hito 2 y en el Hito 3', ['Conjunto', 'Hito 2 (30/10)', 'Hito 3 (20/11)', 'Qué se agregó'], R.calidad.evolucion.filas, [3.4, 2, 2, 4.6]));
c.push(H2('Calidad por característica'));
c.push(P('La Tabla 19 junta los resultados según las características de ISO/IEC 25010 (ISO, 2011). Sirve para ver de un vistazo dónde hay evidencia fuerte y dónde todavía no.'));
c.push(...Tabla('Evaluación de la calidad de ATLAS por característica de ISO/IEC 25010', ['Característica', 'Evidencia', 'Evaluación'], R.calidad.iso, [2.8, 6.4, 2.8]));

// Ajustes --------------------------------------------------------------------------------------
c.push(H1('Ajustes y mejoras'));
c.push(P('Cada falla encontrada en el hito terminó en un cambio y, cuando se pudo, en una prueba que la reproduce. Ningún cambio modifica la forma de las respuestas de la API, el esquema de la base de datos ni las reglas del firewall.'));
c.push(...Tabla('Cambios hechos en el Hito 3 y su verificación', ['Cambio', 'Archivos', 'Verificación'], R.ajustes, [4.4, 3.6, 4]));
c.push(H2('Mejoras propuestas que no se hicieron'));
c.push(...Tabla('Mejoras propuestas y no realizadas en este hito', ['Propuesta', 'Motivo', 'Cuándo'], R.noHechas, [4.6, 4, 3.4]));

// Cumplimiento ---------------------------------------------------------------------------------
c.push(H1('Cumplimiento de los criterios del documento de ATLAS'));
c.push(P(R.criterios.texto));
c.push(...Tabla('Estado de cada criterio de verificación al cierre del Hito 3', ['Criterio', 'Cómo se comprueba', 'Hito 2', 'Hito 3'], R.criterios.filas, [4.4, 4, 1.6, 2], 'Los criterios provienen de la Tabla 5 y de la Tabla H29 del documento de ATLAS (Error404, 2026a).'));

// Pendientes -----------------------------------------------------------------------------------
c.push(H1('Pendientes y pruebas no ejecutadas'));
c.push(P('Nada de la Tabla 23 se presenta como aprobado. Casi todo depende de una jornada más en el laboratorio, con los pasos que ya están escritos en el plan de cierre del laboratorio (docs/hito-3/plan-cierre-laboratorio.md).'));
c.push(...Tabla('Pruebas pendientes y no ejecutadas al cierre del Hito 3', ['Pendiente', 'Estado y motivo', 'Qué falta hacer'], R.pendientes, [3.8, 4, 4.2]));

// Presentación y defensa -----------------------------------------------------------------------
c.push(H1('Presentación final y defensa del proceso de testing'));
c.push(P('La presentación cuenta el proceso de punta a punta en unos quince minutos y muestra las pruebas funcionando, no solo sus resultados. Está pensada para que cada integrante defienda la parte en la que trabajó, siguiendo los roles del equipo.'));
c.push(H2('Guion de la presentación'));
c.push(...Tabla('Guion de la presentación final', ['Momento', 'Quién', 'Qué se muestra', 'Tiempo'], R.defensa.guion, [2.6, 2.4, 5.6, 1.4]));
c.push(H2('Demostración en vivo'));
c.push(P('La demostración se hace con el repositorio y con ATLAS levantado en una notebook, sin depender del laboratorio. Si el laboratorio está encendido, se agrega el circuito desde cliente-doc. El orden es este:'));
c.push(...Numerada(R.defensa.demo));
c.push(H2('Preguntas previstas y respuestas'));
c.push(P('Estas son las preguntas que es razonable esperar del tribunal, con la respuesta que da el equipo y la evidencia que la respalda.'));
c.push(...Tabla('Preguntas previstas en la defensa', ['Pregunta', 'Respuesta del equipo', 'Evidencia'], R.defensa.preguntas, [3.4, 6, 2.6]));

// Seguridad de la evidencia --------------------------------------------------------------------
c.push(H1('Seguridad de la evidencia'));
c.push(P('Ninguna evidencia de este hito muestra una contraseña real. Las salidas de las pruebas y las capturas se revisaron antes de subirlas al repositorio. La Tabla 26 explica cómo se manejó cada dato sensible.'));
c.push(...Tabla('Manejo de los datos sensibles en la evidencia', ['Dato', 'Cómo se manejó'], [
  ['Contraseñas de la base de pruebas y de Zabbix de prueba', 'Son descartables: existen mientras dura cada corrida, porque los contenedores se crean y se borran. Nunca se usan en atlas-srv01'],
  ['Clave de las cuentas de demostración', 'Se genera al azar con probar-local.sh, queda en atlas/local/atlas.conf, que no está en Git, y se pasa a las pruebas por una variable. No aparece en ninguna salida'],
  ['Capturas del laboratorio', 'Cuentas de prueba creadas para la jornada (Juan Fernandez, Matias Perez y Coordinación ITI), sin datos de personas reales. Ninguna muestra contraseñas, la clave privada de WireGuard ni los archivos de configuración con secretos'],
  ['Respaldo de la base en la restauración por intento', 'La base de prueba y el archivo del respaldo se borran al terminar, porque contienen datos de usuarios'],
  ['Certificado del proxy del entorno de pruebas', 'Se pasó a los contenedores para instalar paquetes y no se guardó en el repositorio'],
], [3.6, 8.4]));

// Conclusiones ---------------------------------------------------------------------------------
c.push(H1('Conclusiones'));
R.conclusiones.forEach((t) => c.push(P(t)));

// Referencias ----------------------------------------------------------------------------------
c.push(Salto());
c.push(H1('Referencias'));
[
  'Batchelder, N. (2024). *Coverage.py* (Versión 7.6) [Software]. https://coverage.readthedocs.io',
  'Bergmann, S. (2026). *PHPUnit* (Versión 11.5.56) [Software]. https://phpunit.de',
  'Error404. (2026a). *ATLAS: Plataforma inteligente de aprendizaje adaptativo. Documento integrador* (Versión 3.1) [Documento inédito]. Instituto Tecnológico de Informática, ITI-CETP/UTU.',
  'Error404. (2026b). *Hito 2 de Testing: Implementación y ejecución de pruebas de ATLAS* [Informe inédito]. Instituto Tecnológico de Informática, ITI-CETP/UTU.',
  'Error404. (2026c). *tesis* [Repositorio de código fuente]. GitHub. https://github.com/tesis-final/tesis',
  'Google. (s. f.). *Coverage: Find unused JavaScript and CSS*. Chrome for Developers. https://developer.chrome.com/docs/devtools/coverage',
  'Holzer, V. (2024). *ShellCheck* (Versión 0.9.0) [Software]. https://www.shellcheck.net',
  'International Organization for Standardization. (2011). *Systems and software engineering: Systems and software Quality Requirements and Evaluation (SQuaRE). System and software quality models* (ISO/IEC 25010:2011). https://www.iso.org/standard/35733.html',
  'Krakjoe. (2024). *pcov: CodeCoverage compatible driver for PHP* (Versión 1.0) [Software]. https://github.com/krakjoe/pcov',
  'Microsoft. (2024). *Playwright* (Versión 1.48) [Software]. https://playwright.dev',
  'Myers, G. J., Sandler, C. y Badgett, T. (2011). *The art of software testing* (3.ª ed.). Wiley.',
  'PHPCSStandards. (2026). *PHP_CodeSniffer* (Versión 3.13.6) [Software]. https://github.com/PHPCSStandards/PHP_CodeSniffer',
  'pytest-dev. (2024). *pytest* (Versión 8.3.4) [Software]. https://pytest.org',
  'Astral. (2024). *Ruff* (Versión 0.8.4) [Software]. https://docs.astral.sh/ruff',
].sort((a, b) => a.localeCompare(b, 'es')).forEach((r) => c.push(Ref(r)));

// Apéndices ------------------------------------------------------------------------------------
Tabla.base = B.nTabla;
c.push(Salto());
c.push(H1('Apéndice A'));
c.push(Centro('**Índice de evidencias**', { keepNext: true }));
c.push(P('Las evidencias de este hito están en el repositorio, en docs/evidencias/H/ y en docs/hito-3/capturas/ (Error404, 2026c), y el resumen para el repositorio está en docs/hito-3/testing/README.md. La Tabla A1 las enumera.'));
c.push(...Tabla('Evidencias del Hito 3 de Testing', ['Evidencia', 'Qué muestra', 'Archivo', 'Estado'], R.evidencias, [1.8, 4.4, 3.8, 2], null, 'A'));
c.push(Salto());
c.push(H1('Apéndice B'));
c.push(Centro('**Comandos para repetir las pruebas y las mediciones**', { keepNext: true }));
c.push(P('Desde la raíz del repositorio, en una PC con Linux, Docker, PHP 8.3 y Composer:'));
c.push(...Consola([
  'sudo ./probar-todo.sh                          # los once conjuntos',
  'CA_EXTRA=/ruta/ca.crt sudo -E ./probar-todo.sh # si la red sale por un proxy con certificado propio',
  'cd atlas && tests/cobertura.sh /tmp/cobertura  # cobertura de PHP y de rutas (necesita pcov)',
]));
c.push(Vacio());
c.push(P('Cobertura del servicio de análisis, en un contenedor de Python 3.11:'));
c.push(...Consola([
  'cd atlas-analysis && pip install -r requirements-dev.txt pytest-cov',
  'python -m pytest --cov=app --cov-branch --cov-report=term-missing',
]));
c.push(Vacio());
c.push(P('Con ATLAS levantado con datos de demostración recién cargados (./probar-local.sh):'));
c.push(...Consola([
  'ATLAS_COBERTURA_JS=/tmp/js.txt python3 atlas/tests/e2e/interfaz.py https://localhost <carpeta> <clave>',
  'python3 atlas/tests/e2e/trazar_intento.py https://localhost <carpeta> <clave>',
  'python3 atlas/tests/rendimiento/medir.py https://localhost <clave> 30',
  'atlas/tests/rendimiento/disponibilidad.sh https://localhost 10',
  'sudo atlas/database/tools/comparar_puntaje.sh',
  'sudo atlas/database/tools/restaurar_intento.sh',
  'sudo atlas/database/tools/metricas.sh',
]));
c.push(Vacio());
c.push(P('Análisis estático:'));
c.push(...Consola([
  'shellcheck -S warning $(git ls-files "*.sh")',
  'ruff check --select E,F,W,B --line-length 130 $(git ls-files "*.py")',
]));
c.push(Salto());
c.push(H1('Apéndice C'));
c.push(Centro(`**Salida final de probar-todo.sh del ${R.fecha} de 2026**`, { keepNext: true }));
c.push(P(R.apendiceC.texto));
c.push(...Consola(R.apendiceC.lineas));
c.push(Salto());
c.push(H1('Apéndice D'));
c.push(Centro('**Cobertura de las clases PHP con menos del 70 % de líneas**', { keepNext: true }));
c.push(P(R.apendiceD.texto));
Tabla.base = B.nTabla;
c.push(...Tabla('Clases PHP por debajo de la referencia del equipo', ['Clase', 'Líneas', 'Cobertura', 'Por qué'], R.apendiceD.filas, [4.2, 1.6, 1.6, 4.6], null, 'D'));

const salida = process.argv[2] || path.join(__dirname, '..', 'Hito3_Testing_ATLAS.docx');
Packer.toBuffer(documento(TITULO, c)).then((b) => { fs.writeFileSync(salida, b); console.log('ok', salida); });
