// Parte II: secciones 26 a 30.
const L = require('./lib');
const { add, P, H2, H3, Vineta, Lista, Salto, Tabla, Figura, Consola } = L;
const { v24 } = require('./contenido-1');
const R = require('./resultados');
const C = 'docs/evidencias/B/capturas/hito3/';
const LAB = 'docs/hito-3/capturas/';

// 26 ------------------------------------------------------------------------------------------
add(H2('26. Programación'));
add(H3('26.1 Con qué lo hacemos'));
add(Tabla('tecno', 'Tecnologías y responsabilidades', ['Capa', 'Tecnología', 'Uso'], [
  ['Frontend', 'HTML5, CSS3 y JavaScript (módulos ES, sin framework)', 'Aplicación de una sola página: vistas por rol, componentes propios, gráficos e íconos en SVG.'],
  ['Backend', 'PHP 8.3 + Laravel 12', 'Rutas, sesión, validación y errores; la lógica propia vive en servicios y repositorios (PHP Documentation Group, s. f.).'],
  ['Comunicación', 'API REST / JSON (/api/v1, 43 rutas)', 'Contrato compartido entre interfaz y servidor; no cambió al rediseñar la interfaz.'],
  ['Servidor web', 'Nginx', 'Sirve solo public/ y deriva las solicitudes de la aplicación.'],
  ['Base de datos', 'MySQL 8.0', 'Guarda y protege la integridad; los scripts SQL son la fuente de verdad del esquema.'],
  ['Análisis adicional', 'Python 3.11 + FastAPI; pandas, scikit-learn y NumPy', 'Servicio separado para análisis experimental.'],
  ['Modelo de lenguaje', 'API de un LLM, opcional', 'Redacción sobre datos ya procesados y anonimizados; integración real pendiente.'],
  ['Calidad', 'PHPUnit, PSR-12, pytest, Playwright, GitHub Actions', 'Pruebas unitarias, de API, de base, de interfaz y de infraestructura en cada pull request.'],
  ['Contenedores y versiones', 'Docker + Docker Compose; Git / GitHub', 'Entorno reproducible y trazabilidad del desarrollo.'],
], [2.2, 4, 5.8]));
add(H3('26.2 Cómo se organiza el código'));
add(P('Laravel resuelve la capa HTTP; los servicios, los repositorios y el motor de análisis son clases propias que se reutilizaron al migrar (D-1). La estructura principal es la siguiente:'));
add(Consola([
  'atlas/',
  '  public/            index.php · app.html · css/ · js/ (app, api, ui, gráficos, íconos, registro)',
  '                     js/vistas/ (login, docente, estudiante, admin) · assets/ · fonts/',
  '  app/Http/          Controllers/ (Auth, Actividad, Docente, Estudiante, Admin, Salud)',
  '                     Middleware/ (Autenticacion, Permiso, Auditoria) · Requests/',
  '  app/Services/      ActividadService · IntentoService · PanelDocenteService · UsuarioService',
  '                     Analysis/ (Indicadores, IndicadoresHabilidad, MotorReglas, TiempoActivo)',
  '                     Asistente/ (Anonimizador, IntentParser, AsistenteService)',
  '  app/Repositories/  Actividad · Intento · Usuario · Organizacion · Reporte · Analisis · Auditoria',
  '  config/rutas.php   las 43 rutas con su permiso y sus reglas de validación',
  '  database/          migrations/*.sql (001 a 004) · seeds/ · tools/ (pruebas y comprobaciones)',
  '  tests/             Unit · Api · Database · e2e (Playwright) · rendimiento',
  'atlas-analysis/      app/main.py · models/ · features.py · llm/ · tests/',
]));
add(P('Nginx expone únicamente public/. Las configuraciones y las contraseñas se leen de variables de entorno (atlas.conf en el servidor), fuera del repositorio y fuera de esa carpeta.'));
add(H3('26.3 Middleware'));
add(P('Cada ruta de /api/v1 declara en config/rutas.php el permiso que exige y las reglas de validación de sus datos. Laravel arma con eso una cadena de controles que se aplica siempre en el mismo orden; si un control falla, la solicitud no llega al controlador.'));
add(Tabla('middleware', 'Cadena de controles aplicada a las solicitudes protegidas', ['Orden', 'Componente', 'Responsabilidad', 'Si falla'], [
  ['1', 'atlas.sesion (Autenticacion)', 'Comprueba la sesión del servidor y, en las operaciones que modifican datos, el token CSRF (cabecera X-CSRF-Token).', '401 sin sesión; 403 sin token CSRF.'],
  ['2', 'atlas.permiso (Permiso)', 'Comprueba en rol_permiso que el rol tenga el permiso que pide la ruta.', '403, y el intento queda en auditoría.'],
  ['3', 'Form Request', 'Valida los datos de entrada con las reglas de la ruta.', '422 con el detalle por campo.'],
  ['4', 'atlas.auditoria (Auditoria)', 'Registra la operación con su autor y los datos relevantes.', 'No corresponde: solo registra.'],
], [1, 3, 5.4, 2.6], 'Fuente: atlas/bootstrap/app.php y app/Http/Middleware/. La sesión se bloquea por petición para que una solicitud concurrente no vuelva a guardar una sesión después del cierre (E-APP-011).'));
add(P('La auditoría no guarda cada evento del navegador: las respuestas e interacciones van a sus propias tablas y se auditan las acciones relevantes (ingresos, cambios de estado, decisiones, accesos denegados). La métrica M8 de la sección 31.4 cuenta los accesos denegados registrados.'));
add(H3('26.4 Cómo escribimos el código'));
add(Tabla('criteriosDev', 'Criterios de desarrollo y cómo se comprueban', ['Criterio', 'Aplicación', 'Cómo se comprueba'], [
  ['DRY', 'Servicios reutilizables; consultas concentradas en repositorios; en la interfaz, componentes comunes (ui.js, graficos.js, iconos.js).', 'Revisión en cada pull request.'],
  ['Una responsabilidad por clase', 'Controladores coordinan; servicios resuelven la lógica; repositorios acceden a datos.', 'Estructura de app/ y pruebas unitarias por servicio.'],
  ['Modularidad', 'Separación por capas; vistas de la interfaz en módulos ES independientes.', 'Se cambió toda la interfaz sin tocar la API.'],
  ['Nombres y estilo', 'Nombres descriptivos en español; convención PSR-12.', 'phpcs: sin errores ni advertencias (E-TST-010).'],
  ['Independencia de un único framework', 'Lógica de negocio en clases PHP propias; análisis en Python; interfaz sin framework.', 'El motor y los indicadores se reutilizaron al migrar a Laravel.'],
  ['Versiones', 'Ramas por funcionalidad y pull requests con pruebas automáticas.', 'Historial de Git (sección 22.9).'],
], [2.6, 5.4, 4]));
add(H3('26.5 La interfaz'));
add(P('En el Hito 3 se rediseñó la interfaz completa sobre la misma arquitectura: sigue siendo una aplicación de una sola página en HTML, CSS y JavaScript, servida por Nginx y conectada a la misma API. No se agregó ningún framework ni dependencia externa. El objetivo fue que el docente encuentre en segundos dónde intervenir y que el estudiante resuelva sin distracciones, en cualquier pantalla.'));
add(Vineta([
  'Identidad: la paleta sale del logotipo de ATLAS (azules del 50 al 900) con un acento ámbar para el foco del teclado. El logotipo aparece en el ingreso, en el menú y en el favicon.',
  'Tema claro y oscuro: respeta la preferencia del sistema y se puede cambiar con un botón; la elección se recuerda en el navegador.',
  'Responsivo: puntos de corte en 480, 768, 1024 y 1280 píxeles; en el celular el menú pasa a un panel lateral y las tablas se desplazan dentro de su marco, sin desplazamiento horizontal de la página.',
  'Docente: inicio con el estado de cada grupo (anillo de acierto, lista de quienes requieren atención y medidor de error), análisis del grupo con gráfico de columnas, perfil del estudiante con su evolución y el «¿Por qué?» de cada recomendación, consultas guiadas en tarjetas y editor con las preguntas numeradas y sus habilidades.',
  'Estudiante: una pregunta por vez en modo de foco, con indicador de pasos, opciones con letra y atajos de teclado (1 a 9); al terminar, el resultado con su puntaje, tiempo total y tiempo activo.',
  'Accesibilidad, siguiendo las pautas WCAG 2.2 (W3C, 2023): los estados se comunican con texto e ícono además del color; foco visible; textos alternativos en gráficos; movimiento reducido y alto contraste del sistema respetados; estilos de impresión.',
  'Seguridad: política de seguridad de contenido estricta (sin scripts ni estilos en línea) y fuentes alojadas en el propio servidor; la prueba de interfaz verifica que no haya violaciones de esa política ni errores de JavaScript.',
]));
add(P(`La prueba de interfaz recorre los tres roles en cinco anchos de pantalla con Chromium, mediante Playwright (Playwright, s. f.), y dio ${R.interfaz}. Las figuras de esta sección y de la siguiente ya no son de esa corrida: se tomaron en el laboratorio el ${R.fechaLab}, en cliente-doc (Windows 10 con Microsoft Edge) contra https://172.16.40.10. Las cuentas son de prueba, creadas por el equipo para la jornada: Coordinación ITI, el docente Juan Fernandez y el estudiante Matias Perez; no corresponden a personas reales. El Anexo B agrega el ingreso, el tema oscuro, la gestión de grupos y otras pantallas.`));
add(Figura('fDocente', LAB + 'H3-51-app-docente-inicio.png', 'Inicio del docente en el laboratorio: dónde intervenir hoy', 'Captura H3-51, cliente-doc en la VLAN 20, 19/11/2026, 20:00. Antes del circuito: un grupo a cargo («Docentes»), un estudiante y nadie que requiera atención. El promedio de 100 corresponde al intento del 12/11.', { maxAlto: 520 }));
add(Figura('fGrupo', LAB + 'H3-62-app-docente-grupo.png', 'Análisis del grupo después del circuito: atención prioritaria, errores por pregunta y acierto por habilidad', 'Captura H3-62, 19/11/2026, 20:32. Matias Perez figura con R07 (no reintento) y R01 (puntaje bajo); la pregunta «¿Cuál es el resultado de dividir 100 entre 0?» tiene 50 % de error (1 de 2 respuestas). El agrupamiento automático no se calcula: hay 1 estudiante con datos y hacen falta 20.', { maxAlto: 600 }));
add(Figura('fMovil', LAB + 'H3-67-app-celular.png', 'Pantalla de ingreso emulada en un celular (iPhone SE, 375 × 667 píxeles)', 'Captura H3-67, cliente-doc con las herramientas de desarrollo de Edge, 19/11/2026. El texto de presentación pasa arriba, el formulario queda debajo y no hay desplazamiento horizontal.', { maxAlto: 560, maxAncho: 420 }));
add(Figura('fConsultas', LAB + 'H3-65-app-docente-consultas.png', 'Consulta guiada en el laboratorio: cómo va el grupo en cada habilidad', 'Captura H3-65, 19/11/2026, 20:36. Grupo «Docentes», período «Este mes»: Cálculo con 100 % de acierto (2 de 2 preguntas) y ningún estudiante por debajo del 50 %. La consulta aclara que describe aciertos y no mide capacidades (D-5, D-8).', { maxAlto: 560 }));
add(H3('26.6 El circuito completo en el laboratorio'));
add(P('En el Hito 2 el circuito se cortó al publicar: el servidor devolvía HTTP 422 y la pantalla no decía por qué (INC-09). El 19/11/2026 se repitió entero en el laboratorio, con ATLAS en atlas-srv01 y el navegador en cliente-doc. Para que el estudiante entrara desde su propia red, el cliente se pasó de la VLAN 20 a la 30 a mitad de la jornada y después se devolvió a la 20. La {T:circuito} resume lo que pasó en cada paso y dónde está su captura.'));
add(Tabla('circuito', 'Circuito docente-estudiante ejecutado en el laboratorio el 19/11/2026', ['Paso', 'Quién y desde dónde', 'Qué pasó', 'Captura'], [
  ['1', 'Coordinación ITI, VLAN 20', 'Grupos «Docentes» y «Grupo 1» del año 2026, con el docente y el estudiante cargados como integrantes.', 'Figura B9 (H3-50)'],
  ['2', 'Juan Fernandez (docente), VLAN 20', 'Crea «Actividad de prueba 2» y «Actividad de prueba 3», cada una con una pregunta de opción múltiple que mide Cálculo.', 'Figura B2 (H3-52)'],
  ['3', 'Docente', 'Intenta publicar la actividad 3 sin marcar la opción correcta. ATLAS no publica y explica el motivo en su propio aviso, con la pregunta marcada.', '{F:aviso} (H3-53)'],
  ['4', 'Docente', 'Marca la opción C y publica. El historial muestra BORRADOR → PUBLICADA, sin pasar por aprobación (D-2).', '{F:publicada} (H3-54)'],
  ['5', 'cliente-doc pasa a la VLAN 30', 'Recibe 172.16.30.100 del DHCP del DC. El puerto 445 de srv01 queda cerrado y router-lab registra cada intento con ATLAS-R12.', 'Figura D1 (H3-55); {F:test445} y {F:r12}'],
  ['6', 'Matias Perez (estudiante), VLAN 30', 'Ve la actividad publicada y la resuelve dos veces: primero saca 0 y después 100, con 3 s de tiempo total y 3 s de tiempo activo en el segundo intento.', 'Figuras B8 y B4 (H3-58, H3-61)'],
  ['7', 'Docente, de nuevo en la VLAN 20', 'Ve el análisis del grupo, el perfil del estudiante, el fundamento de cada recomendación, la consulta guiada y el reporte de intentos.', '{F:fGrupo}, Figura B3, {F:porque}, {F:fConsultas} y {F:reportes}'],
  ['8', 'Coordinación ITI', 'La auditoría muestra 78 registros: ingresos, cierres de sesión, los intentos del estudiante desde 172.16.30.100 y la publicación desde 172.16.20.100.', '{F:auditoria} (H3-69)'],
], [0.8, 2.8, 6, 2.4], 'Las horas de las capturas de cliente-doc van tres horas atrás de la hora de Uruguay; se explica más abajo. Las capturas H3-59 (cambio de respuesta) y H3-60 (confirmación al finalizar) no se tomaron.'));
add(Figura('aviso', LAB + 'H3-53-app-aviso-motivo.png', 'ATLAS no publica una actividad sin opción correcta y dice por qué', 'Captura H3-53, 19/11/2026. El aviso es de ATLAS, no del navegador: «La actividad no cumple las condiciones para publicarse · Pregunta 1: Cada pregunta necesita exactamente 1 opción correcta». La misma pregunta queda con el borde rojo y el mensaje arriba del enunciado.', { maxAlto: 520 }));
add(Figura('publicada', LAB + 'H3-54-app-publicada.png', 'Actividad publicada, con su historial de estados', 'Captura H3-54, 19/11/2026. Historial: 20:10 «Creación → BORRADOR» y 20:12 «BORRADOR → PUBLICADA», los dos por Juan Fernandez. La institución no exige aprobación (D-2), así que la actividad pasa directo a publicada.', { maxAlto: 520 }));
add(P('Con el estudiante ya resuelto, el docente vio los resultados desde su red. En el perfil de Matias Perez la evolución pasa de 100 (12/11) a 0 y vuelve a 100 (19/11); el acierto en Cálculo es del 100 % porque se cuenta el último intento de cada actividad. Las recomendaciones se muestran con un botón «¿Por qué?» que abre la regla que las generó, su versión y el dato que la disparó ({F:porque}). El reporte de intentos ({F:reportes}) muestra los tres intentos finalizados con su puntaje, el tiempo total y el tiempo activo por separado (D-8).'));
add(Figura('porque', LAB + 'H3-64-app-docente-por-que.png', 'Fundamento de una recomendación: regla, versión y datos usados', 'Captura H3-64, 19/11/2026, 20:34. La recomendación sale de R01 «Puntaje bajo» (versión 1), con el dato puntaje = 0. ATLAS avisa además que no hay otra actividad publicada de la misma categoría y nivel para sugerir, y deja al docente confirmar la sugerida o elegir otra (D-6).', { maxAlto: 560 }));
add(Figura('reportes', LAB + 'H3-66-app-docente-reportes.png', 'Reporte del docente: intentos finalizados con tiempo total y tiempo activo', 'Captura H3-66, 19/11/2026, 20:37. Tres intentos finalizados, puntaje promedio 66,7 y tiempo activo medio de 5 s. «Actividad de prueba 3» tiene dos intentos de Matias Perez (0 en 7 s y 100 en 3 s); «Actividad de prueba», uno del 12/11 (100 en 6 s).', { maxAlto: 560 }));
add(Figura('auditoria', LAB + 'H3-69-app-auditoria.png', 'Auditoría vista por la coordinación después del circuito', 'Captura H3-69, 19/11/2026, 20:38. 78 registros, 5 accesos denegados y 4 usuarios distintos. Cada fila tiene la acción, el recurso, el resultado y la dirección de origen: los intentos de matiasperez1@atlas.local salen de 172.16.30.100 (VLAN 30) y la publicación de juanfernandez1@atlas.local, de 172.16.20.100 (VLAN 20). Las direcciones de correo son de las cuentas de prueba.', { maxAlto: 560 }));
add(P('Quedaron anotadas dos cosas de la jornada. La primera: aunque el segundo intento de Matias Perez sacó 100, el análisis del grupo lo sigue mostrando en «atención prioritaria» por R07 y R01. Las reglas se evaluaron al cerrar el intento con 0 (así lo dice el fundamento de la recomendación) y la lista muestra las señales del período, no solo la del último intento. No es un error de cálculo, pero puede confundir; el docente lo resuelve mirando el perfil, y queda en el backlog revisar si la lista debe descartar una señal que el intento siguiente ya corrigió. La segunda: el reloj de cliente-doc marca tres horas menos que la hora de Uruguay. El resultado del intento 3 aparece a las 20:27 en su pantalla, mientras la base lo guardó a las 02:27 UTC del 20/11, que en Uruguay son las 23:27. Los datos no cambian, porque inicio y fin del intento los pone el servidor; lo que queda corrido es la hora que muestra el navegador de ese equipo. Lo más probable es que la zona horaria del cliente esté mal configurada; se revisa en la próxima jornada.'));
add(H3('26.7 Estado de programación al Hito 3'));
add(Tabla('entregProg', 'Entregables de programación', ['Entregable', 'Estado', 'Evidencia'], [
  ['Stack y estructura del proyecto', 'Listo', 'Sección 26.2'],
  ['Inicio de sesión y paneles por rol', 'Listo; usado en el laboratorio con los tres roles', 'E-APP-015; figuras B6, B9 y {F:fDocente}'],
  ['Middleware de sesión, permisos, validación y auditoría', 'Listo; auditoría comprobada en el laboratorio', 'Sección 26.3; pruebas de API; {F:auditoria}'],
  ['Actividades, habilidades y registro de resolución', 'Listo; comprobado en el laboratorio', 'E-BD-016; sección 27.7'],
  ['Consultas guiadas y decisión docente', 'Listo; comprobado en el laboratorio', '{F:fConsultas} y {F:porque}'],
  ['Interfaz rediseñada, responsiva y accesible', 'Listo; tema claro, oscuro y celular vistos en el laboratorio', 'Sección 26.5; E-APP-015; figuras B6 y B7'],
  ['Motivo visible cuando no se puede publicar (INC-09)', 'Verificado en desarrollo y en el laboratorio', '{F:aviso}'],
  ['Circuito completo en el laboratorio', 'Ejecutado y verificado el 19/11/2026', 'Sección 26.6; E-APP-014'],
  ['Integración real con la API de Groq', 'No ejecutada', 'Requiere clave; sección 32'],
], [5, 3.2, 3.8]));

// 27 ------------------------------------------------------------------------------------------
add(H2('27. Base de datos'));
add(H3('27.1 Cómo se organiza'));
add(P('La base corre en MySQL 8.0 (Oracle, s. f.). El esquema reúne 32 tablas en cinco grupos: identidad, contenido, interacción, análisis y control. Los scripts SQL de atlas/database/migrations (001 a 004) son la fuente de verdad: la aplicación no crea ni modifica tablas, porque su cuenta (atlas_app) no tiene permisos de definición. El diccionario de datos y el diagrama entidad-relación están en docs/fase-05-base-datos/.'));
add(Figura('der', 'docs/fase-05-base-datos/img/der-interaccion.png', 'Diagrama entidad-relación del grupo de interacción (intentos, respuestas, interacciones y resultados)', 'Fuente: docs/fase-05-base-datos/img/. Es el grupo que siguen las comprobaciones de la sección 27.7; los diagramas de los otros cuatro grupos y el general de 32 tablas están en la misma carpeta, junto con el diccionario de datos.', { maxAlto: 560 }));
add(H3('27.2 Las tablas'));
add(Tabla('tablas', 'Estructura de tablas por grupo', ['Grupo', 'Tablas', 'Qué guarda'], [
  ['Identidad', 'instituciones, roles, permisos, rol_permiso, usuarios, grupos_clase, usuario_grupo', 'Cuentas, roles con sus permisos, instituciones (con requiere_aprobacion) y grupos.'],
  ['Contenido', 'niveles_dificultad, categorias, estados_actividad, actividades, preguntas, opciones, transiciones_actividad, actividad_grupo, habilidades, pregunta_habilidad', 'Actividades con su ciclo de estados y su historial, preguntas, opciones y habilidades (N:M).'],
  ['Interacción', 'intentos, respuestas, interacciones, resultados', 'Cada resolución: respuesta final por pregunta, eventos del proceso y un único resultado por intento.'],
  ['Análisis', 'perfiles_aprendizaje, indicadores, reglas_analisis, recomendaciones, recomendacion_regla, decisiones_recomendacion, analisis_grupal, agrupamientos', 'Indicadores, reglas con versión, sugerencias con su fundamento y la decisión del docente.'],
  ['Control', 'auditoria, conversaciones, registro_respaldos', 'Auditoría inmutable, consultas al asistente y el registro de cada respaldo.'],
], [1.8, 5.4, 4.8], 'La relación de cada tabla con las demás (1:N, N:M y 1:0..1) se conserva sin cambios respecto de la V2.4 y está en el diccionario de datos.'));
add(H3('27.3 Decisiones de diseño'));
v24('s27_3');
add(H3('27.4 Integridad y rendimiento'));
add(Tabla('integridad', 'Mecanismos de integridad y rendimiento', ['Mecanismo', 'Uso'], [
  ['Claves foráneas', 'Integridad referencial entre las tablas.'],
  ['Restricciones CHECK', 'Rangos y valores admitidos.'],
  ['Índices simples y compuestos', 'Claves y columnas de filtrado frecuente.'],
  ['Vistas', 'Consultas de lectura para reportes (cinco vistas).'],
  ['Triggers', 'Solo controles de integridad: estados válidos, intento cerrado inmutable, respuestas válidas, auditoría inmutable y contenido editable solo en borrador. No calculan: los cálculos están en PHP (D-4).'],
  ['Restricción UNIQUE', 'Un único resultado por intento (uq_resultados_intento).'],
  ['Transacciones', 'Cierre del intento y guardado del resultado en una sola operación.'],
], [3, 9]));
add(P('Para consultas de un grupo se evita la vista v_preguntas_error, que se materializa entera (cerca de 490 ms con muchos datos): la aplicación usa una consulta que arranca por el grupo (cerca de 41 ms, E-BD-006).'));
add(H3('27.5 Privilegios'));
add(Tabla('privilegios', 'Usuarios de la base de datos', ['Usuario MySQL', 'Privilegios y propósito'], [
  ['atlas_app', 'Lectura y escritura en tablas operativas; en auditoria, transiciones_actividad, resultados, analisis_grupal y decisiones_recomendacion solo SELECT e INSERT. Sin DDL. Lo usa la aplicación.'],
  ['atlas_read', 'SELECT sobre vistas de reporte.'],
  ['atlas_analysis', 'SELECT en datos de interacción e INSERT en análisis. Lo usa el servicio Python.'],
  ['atlas_backup', 'SELECT, LOCK TABLES, SHOW VIEW, TRIGGER y SHOW_ROUTINE para el volcado (DEC-10); INSERT en registro_respaldos para anotar cada copia (CT-06).'],
  ['atlas_admin', 'Administración de atlas_db, solo desde localhost; la aplicación nunca usa esta cuenta.'],
], [2.4, 9.6], 'Fuente: atlas/docker/mysql/02-usuarios.sh; verificado con SHOW GRANTS en E-BD-010. Las cuentas de aplicación y análisis se restringen a la red interna 192.168.250.16/28.'));
add(H3('27.6 Integración con el sistema operativo'));
add(Tabla('bdso', 'La base de datos en el sistema operativo', ['Aspecto', 'Diseño e implementación'], [
  ['Servicio', 'Contenedor atlas-db, con el usuario del sistema atlasdb (5003) dueño de los datos; sin acceso interactivo.'],
  ['Datos', '/srv/atlas/datos/, grupo atlas-db, modo 770; ACL de lectura para la cuenta de respaldo sin incorporarla al grupo.'],
  ['Respaldo', 'atlas-respaldo (paso 13) con temporizadores de systemd; los archivos quedan en /srv/atlas/backups (atlasbkp:atlas-backup 700) y se copian al DC.'],
  ['Registros', '/srv/atlas/logs/ y el diario del sistema (journald) para los contenedores.'],
  ['Operación', 'atlas.service en systemd; atlas-ctl para operar con sudo acotado, sin pertenecer al grupo docker.'],
], [2.4, 9.6]));
add(H3('27.7 Comprobaciones pedidas en la devolución del Hito 2'));
add(P('La devolución de Base de Datos pidió tres comprobaciones. Las tres se automatizaron con herramientas del repositorio y se corrieron primero en desarrollo. El 19/11/2026, después del circuito de la sección 26.6, se corrieron en el laboratorio el seguimiento del intento, la restauración por intento y las métricas, sobre la base real de atlas-srv01 (paso R-9 del Anexo J). En el laboratorio se lanzaron desde la Shell de Proxmox con el atajo vm, que ejecuta el comando dentro de srv01 por el agente de QEMU.'));
add(P(`Seguimiento de un intento (E-BD-016). Una prueba en el navegador lee las respuestas correctas de una actividad como docente, resuelve como estudiante con un plan fijo (en la pregunta 1 elige primero una opción incorrecta y después la corrige; la pregunta 3 la contesta mal) y calcula el puntaje esperado: 75. Después consulta la base: una respuesta final por pregunta, el evento CAMBIO_OPCION de la pregunta 1 en interacciones y un único resultado con 75,00; por último, el informe del docente muestra el mismo 75. Resultado: ${R.trazado}. `));
add(P(`En el laboratorio, seguir_intento.sh tomó el último intento de la base: el intento 3, que es el segundo de Matias Perez en «Actividad de prueba 3». El inicio y el fin los puso el servidor (02:27:20 y 02:27:23 UTC, 3 s); hay una sola respuesta final, la opción correcta, contestada en 2 s; las interacciones son cuatro y están en orden (INICIO, VER_PREGUNTA, SELECCION y FIN); y hay un único resultado de 100,00, igual al que se recalcula desde las respuestas ({F:seguir}). En ese intento el estudiante eligió directamente la opción correcta, así que no hubo CAMBIO_OPCION: el registro del cambio de respuesta queda comprobado en desarrollo y no en el laboratorio.`));
add(Figura('seguir', LAB + 'H3-70-srv01-seguir-intento.png', 'Seguimiento del intento 3 en la base de atlas-srv01', 'Captura H3-70 (E-BD-019), Shell de Proxmox, 19/11/2026, 23:39. Intento, respuesta final, interacciones en orden y un único resultado; al final, «RESULTADO: OK · un único resultado y el puntaje guardado coincide con el recalculado». Algunas tildes se ven mal por la codificación de la consola; el contenido no cambia.', { maxAlto: 600 }));
add(P(`Puntaje guardado contra calculado (E-BD-017). Sobre datos representativos de desarrollo se comparó la consulta que lee el puntaje guardado con otra que lo recalcula desde las respuestas: dieron los mismos valores por actividad y por intento. En 20 ejecuciones de cada una, la mediana fue de ${R.comparacion.medianaA} con el puntaje guardado y de ${R.comparacion.medianaB} recalculándolo (percentil 95: ${R.comparacion.p95A} y ${R.comparacion.p95B}). Con atlas_app se intentó modificar el puntaje de un intento cerrado de cinco maneras y las cinco fueron rechazadas con su mensaje: UPDATE y DELETE denegados por privilegios, un segundo resultado rechazado por la restricción UNIQUE, y el cambio de respuesta y la reapertura del intento rechazados por los triggers de integridad.`));
add(P(`Restauración por intento (E-BD-018). restaurar_intento.sh hace un respaldo con atlas_backup, lo restaura en una base aparte y recupera el intento por su número en las dos bases, comparando con huellas sha256 el intento, sus respuestas, sus interacciones y su resultado, además del conteo de cada tabla. En desarrollo dio ${R.restauracion}, con el último intento recuperado igual al último de la base en uso. Ese tiempo es el de la base; volver a operar incluye reiniciar los contenedores y comprobar el acceso, por eso la medición que vale contra el RTO de 4 h es la del laboratorio.`));
add(P(`En el laboratorio, restaurar_intento.sh dio ${R.lab.restauracion} ({F:restaurar}). El respaldo, de 94 KB, se tomó con atlas_backup y --single-transaction, sin frenar la aplicación; el intento 3 tiene las mismas huellas en la base en uso y en la restaurada, y las nueve tablas comparadas tienen la misma cantidad de filas (por ejemplo, 12 interacciones y 78 registros de auditoría en las dos). Frente a las metas, el tiempo de la base es de alrededor de 1 s contra un RTO de 4 h, y con el respaldo diario se perdería como máximo lo posterior a la última copia, dentro del RPO de 24 h. Falta sumar el reinicio de los contenedores y la comprobación del acceso, que en esta jornada no se cronometraron.`));
add(Figura('restaurar', LAB + 'H3-71-srv01-restaurar-intento.png', 'Restauración por intento en el laboratorio, con huellas y conteo de filas', 'Captura H3-71 (E-BD-020), 19/11/2026, 23:39. Las cuatro partes del intento 3 dan PASS con la misma huella sha256 en las dos bases; abajo, el conteo de filas por tabla y los tiempos frente al RTO y al RPO. La base de prueba y el archivo de respaldo se borran al terminar, porque tienen datos de personas.', { maxAlto: 600 }));
add(P(`Además del respaldo de la base, se respaldó la máquina virtual completa (E-BD-015). vzdump copió la VM 130 en caliente, en modo snapshot y con compresión zstd: ${R.lab.vzdump}, en 2 min 6 s de reloj ({F:vzdump}). La copia se restauró como VM 930 en ${R.lab.qmrestore} y arrancó con la placa de red desconectada, para que no chocara con la 130 original (Figura G3). En su consola, atlas-db y atlas-analysis estaban sanos y atlas-php en marcha, pero atlas-web se reiniciaba una y otra vez (Figura G4). La explicación más probable es la propia prueba: Nginx publica sus puertos en 172.16.40.10 y, con la placa desconectada, esa dirección no queda configurada, así que Docker no puede abrir el puerto. No se comprobó conectando la placa, porque la copia tiene la misma dirección que el servidor en uso. Aun así, respaldo y restauración de la VM suman menos de cuatro minutos frente a un RTO de 4 h.`));
add(Figura('vzdump', LAB + 'H3-73a-proxmox-vzdump.png', 'Respaldo de la VM 130 con vzdump', 'Captura H3-73a (E-BD-015), Shell de Proxmox, 19/11/2026, 23:45. «Finished Backup of VM 130 (00:02:05)» y «Backup job finished successfully»; el archivo vzdump-qemu-130-2026_11_19-23_42_45.vma.zst ocupa 5,2 GB porque el 64 % del disco son bloques vacíos.', { maxAlto: 600 }));
add(H3('27.8 Estado de base de datos al Hito 3'));
add(Tabla('entregBD', 'Entregables de base de datos', ['Entregable', 'Estado', 'Evidencia'], [
  ['Modelo, diccionario y scripts 001 a 004', 'Listo', 'docs/fase-05-base-datos/'],
  ['Integridad y cálculos en PHP', 'Verificado en desarrollo', 'E-BD-007; pruebas de base 58 de 58'],
  ['Usuarios y privilegios', 'Verificado', 'E-BD-010; rechazos de atlas_app en E-BD-017'],
  ['Seguimiento de un intento de punta a punta', 'Verificado en desarrollo y en el laboratorio (en el laboratorio, sin cambio de respuesta)', 'E-BD-016; E-BD-019, {F:seguir}'],
  ['Puntaje guardado contra calculado, con tiempos', 'Verificado en desarrollo', 'E-BD-017'],
  ['Restauración por intento', 'Verificado en desarrollo y en el laboratorio (13 de 13)', 'E-BD-018; E-BD-020, {F:restaurar}'],
  ['Métricas M1 a M11 sobre la base del laboratorio', 'Ejecutado: 6 PASS, 0 FAIL y 5 informativas', 'E-BD-021; sección 31.4'],
  ['Respaldos automáticos anotados en registro_respaldos', 'Verificado en desarrollo; en el laboratorio, No ejecutada (paso 13 sin correr)', 'probar-respaldos.sh, 17 de 17; M10 y M11 sin registros'],
  ['Respaldo de la VM completa', 'Ejecutado: respaldo y restauración; en la copia sin red, atlas-web no arranca', 'E-BD-015, {F:vzdump}, figuras G3 y G4'],
], [5, 3.6, 3.4]));

// 28 ------------------------------------------------------------------------------------------
add(H2('28. Linux / POSIX'));
add(H3('28.1 El servidor'));
add(Tabla('srv', 'Características del servidor Linux', ['Característica', 'Valor'], [
  ['Sistema operativo', 'Ubuntu Server 24.04.5, en la VM 130 de Proxmox.'],
  ['Nombre y dirección', 'atlas-srv01 · 172.16.40.10/24 · gateway 172.16.40.1 · DNS 172.16.40.20.'],
  ['Recursos', '2 núcleos (CPU host) y disco de 30 GB; la memoria pasa de 3 a 4 GB para alojar el monitoreo (paso R-1).'],
  ['Servicios', 'ATLAS en Docker (Nginx, PHP/Laravel, MySQL, Python); Zabbix en un proyecto aparte; Samba para docentes.'],
  ['Instalador', 'infra/linux/instalar.sh, 14 pasos idempotentes, y verificar.sh con PASS/FAIL por requisito.'],
], [3, 9]));
add(H3('28.2 Quién accede a qué'));
add(P('Las cuentas técnicas de Linux y las de usuarios de ATLAS están separadas: entrar por el navegador no da ningún permiso sobre el sistema operativo.'));
add(Tabla('gruposPosix', 'Grupos POSIX y sus funciones en el servidor', ['Grupo', 'GID', 'Para qué'], [
  ['atlas-admin', '5001', 'Administrar el servidor'], ['atlas-web', '5002', 'El servicio web'], ['atlas-db', '5003', 'La base de datos'],
  ['atlas-backup', '5004', 'Los respaldos'], ['atlas-audit', '5005', 'Leer los registros de auditoría'],
], [3, 1.6, 7.4]));
add(Tabla('usuariosPosix', 'Usuarios del sistema Linux y grupos asignados', ['Usuario', 'UID', 'Grupo', 'Shell'], [
  ['atlasadmin', '5001', 'atlas-admin', '/bin/bash'], ['atlasweb', '5002', 'atlas-web', '/usr/sbin/nologin'],
  ['atlasdb', '5003', 'atlas-db', '/usr/sbin/nologin'], ['atlasbkp', '5004', 'atlas-backup', '/usr/sbin/nologin'],
], [3, 1.6, 3, 4.4], 'El nologin de las cuentas de servicio impide usarlas para entrar al sistema aunque alguien consiguiera la contraseña.'));
add(Tabla('permisosPosix', 'Permisos de acceso a los recursos del servidor', ['Recurso', 'admin', 'web', 'db', 'backup', 'audit'], [
  ['/srv/atlas/web/', 'rwx', 'r-x', '—', 'r--', '—'], ['/srv/atlas/datos/', 'rwx', '—', 'rwx', 'r--', '—'],
  ['/srv/atlas/logs/', 'rwx', '-wx', '-wx', 'r--', 'r--'], ['/srv/atlas/scripts/', 'rwx', '—', '—', 'r-x', '—'],
  ['/srv/atlas/backups/', 'r-x', '—', '—', 'rwx', '—'], ['/srv/atlas/config/', 'rwx', 'r--', 'r--', 'r--', '—'],
], [3.4, 1.7, 1.7, 1.7, 1.7, 1.8], 'El usuario de respaldo lee todo pero solo escribe en backups/; el administrador no puede escribir en backups/: si se compromete la cuenta administrativa, no puede borrar los respaldos.'));
add(H3('28.3 Permisos, ACL y atributos'));
add(P('El paso 3 del instalador crea la estructura con sus dueños y modos y aplica las ACL que la tabla de permisos necesita: la cuenta de respaldo lee los datos sin estar en atlas-db, el servicio web escribe registros (y lo hereda lo que se cree después) y el grupo de auditoría lee sin modificar (RF-15). La configuración queda inmutable (chattr +i) y el registro de auditoría solo admite agregar (chattr +a). El verificador comprueba cada celda de la tabla con permisos efectivos.'));
add(Consola([
  '/srv/atlas/            atlasadmin:atlas-admin   750',
  '├── web/               atlasweb:atlas-web       750   (public/ 755)',
  '├── datos/             atlasdb:atlas-db         770   ACL u:atlasbkp:r-x',
  '├── logs/              atlasadmin:atlas-admin   770   ACL atlasweb rwx · atlas-audit r-x',
  '├── config/            atlasadmin:atlas-admin   750   atlas.conf con +i · monitoreo.conf root 600',
  '├── backups/           atlasbkp:atlas-backup    700   completo/ incremental/ config/',
  '└── monitoreo/         root:root                750   compose y scripts de Zabbix',
]));
add(H3('28.4 Quién puede conectarse y controles del host'));
add(P('El control entre VLAN lo hace router-lab. En el servidor hay una segunda barrera: SSH solo con clave, solo para atlasadmin y el grupo de soporte del dominio, y solo desde la VLAN 50; TCP Wrappers corta antes de autenticar cualquier otro origen. UFW niega lo entrante por defecto y la cadena DOCKER-USER repite la Tabla 44 para los puertos que publica Docker, que de otra forma no pasarían por UFW.'));
add(Tabla('ufw', 'Reglas del firewall del servidor (UFW y DOCKER-USER)', ['Puerto', 'Origen', 'Motivo'], [
  ['22/tcp', 'VLAN 50 (Gestión)', 'Administración (regla 6)'],
  ['443/tcp', 'VLAN 10, 20 y 30; VPN docentes 10.8.0.128/25', 'Acceso a ATLAS (reglas 1 y 9); también en DOCKER-USER'],
  ['445/tcp', 'VLAN 10 y 20; atlas-dc01', 'Samba y servicios de dominio (regla 3)'],
  ['10050/tcp', '192.168.250.64/28 (zabbix-server)', 'Agente de monitoreo (DEC-19, nuevo en el Hito 3)'],
  ['3306', 'Ninguno', 'MySQL no se publica (DEC-02)'],
], [1.8, 4.6, 5.6], 'Fuente: infra/linux/05-firewall.sh y archivos/ufw-docker-user.rules.tpl. La regla del 10050 se probó con conexiones reales en un Ubuntu 24.04 (E-LNX-005): llega desde la red de zabbix-server y no desde las VLAN 30 ni 50.'));
add(H3('28.5 Respaldo y recuperación'));
add(P('En el Hito 2 solo se había probado un volcado y una restauración a mano. Para el Hito 3 se implementó la política completa de la sección 28.5 con atlas-respaldo, un programa de root instalado por el paso 13, y temporizadores de systemd.'));
add(Tabla('respaldoDatos', 'Datos a respaldar y criticidad', ['Recurso', 'Criticidad', 'Justificación'], [
  ['Base de datos', 'Alta', 'Conserva usuarios, contenido y resultados.'], ['Configuraciones', 'Alta', 'Permiten reconstruir los servicios.'],
  ['Usuarios, grupos y ACL', 'Alta', 'Definen la estructura de acceso.'], ['Código', 'Media', 'Se conserva también en Git.'],
  ['Registros', 'Media', 'Sostienen la auditoría y el diagnóstico.'],
], [3.4, 1.8, 6.8]));
add(Tabla('respaldoPlan', 'Frecuencia, retención y destino de los respaldos (implementado)', ['Tipo', 'Cuándo', 'Qué incluye', 'Retención', 'Destino'], [
  ['Completo', 'Domingos 02:00', 'mysqldump --single-transaction con atlas_backup; archivos con ACL y atributos; listado de permisos', '4 semanas', 'Local y Windows'],
  ['Incremental', 'Lunes a sábado 02:00', 'binlog nuevos de MySQL; archivos cambiados (tar --listed-incremental)', '7 días', 'Local y Windows (DEC-09)'],
  ['Configuración', 'Cada vez que cambia /srv/atlas/config', 'Copia de la carpeta de configuración', '10 versiones', 'Local y Windows'],
  ['Verificación', 'Todos los días 03:30', 'Huella sha256 de cada archivo y antigüedad del último respaldo', '—', '—'],
  ['Prueba de restauración', 'Día 1 de cada mes 04:00', 'Restaura el último completo en una base aparte y compara filas', '—', '—'],
], [1.9, 2.2, 4.2, 1.6, 2.1], 'Fuente: infra/linux/13-respaldos.sh y archivos/atlas-respaldo. La copia a Windows va por SMB3 cifrado a \\\\atlas-dc01\\atlas-backups con svc_atlas_backup, que puede crear archivos pero no borrarlos (CT-05); la retención en el DC la aplica una tarea programada (sección 29.6). Cada copia queda anotada en registro_respaldos.'));
add(P('El criterio 3-2-1 queda cubierto así: la base en uso, la copia local en /srv/atlas/backups y la copia externa en el DC, en otro equipo y otro sistema. Si alguien compromete el servidor Linux, no puede borrar las copias del DC; y si se compromete el DC, las copias locales siguen en srv01.'));
add(P('La prueba automática del paso 13 corre contra un MySQL 8.0 real con binlog y comprueba diecisiete puntos: volcado completo y verificado, incremental con los datos nuevos, retención de la configuración, anotación con atlas_backup, detección de un archivo alterado y restauración en una base aparte con las 32 tablas y las mismas filas. Resultado: 17 de 17 (E-TST-010). En el laboratorio corresponde al paso R-5 del Anexo J, que incluye comprobar que srv01 no puede borrar en el DC; al 19/11/2026 ese paso no se había corrido (sección 28.6).'));
add(P('Procedimiento de recuperación del servicio completo: verificar la huella de la copia; detener ATLAS (atlas-ctl detener); restaurar la base con el último completo y aplicar los binlog incrementales; restaurar archivos con sus ACL y atributos; iniciar los servicios; comprobar el acceso y anotar la operación. Las metas se mantienen: perder como máximo 24 horas de datos (RPO) y volver a operar en menos de cuatro horas (RTO).'));
add(H3('28.6 Estado del servidor al Hito 3'));
add(Tabla('entregLinux', 'Estado de los entregables del servidor Linux', ['Entregable', 'Repositorio', 'Laboratorio'], [
  ['VM, red definitiva y pila de ATLAS', 'Listo (pasos 1 a 7)', 'Ejecutado en el Hito 2; la pila atendió el circuito del 19/11'],
  ['Arranque sin Internet y atlas-ctl (INC-01, INC-08)', 'Corregido y verificado (E-TST-003)', 'No ejecutada: no hay evidencia de R-3'],
  ['Hora, dominio, Samba, registros y sudo (pasos 8 a 12)', 'Listo; probado en Ubuntu real (E-LNX-005)', 'No ejecutados: FAIL en esas cinco secciones'],
  ['Respaldos automáticos con copia al DC (paso 13)', 'Listo; 17 de 17', 'No ejecutado: FAIL en respaldos'],
  ['Monitoreo con Zabbix (paso 14)', 'Listo; 14 de 14 y corrida completa del paso (E-RED-012)', 'Ejecutado el 20/11: monitoreo y firewall 23 de 23 (E-RED-015)'],
  ['Certificado firmado por ATLAS-CA', 'Listo (instalar-certificado.sh)', 'No ejecutado: el navegador de cliente-doc marca «No seguro»'],
  ['Verificación completa (verificar.sh)', 'Incluye respaldos y monitoreo', '19/11: 86 PASS y 31 FAIL; 20/11, después del paso 14: 93 PASS y 24 FAIL'],
], [4.6, 4, 3.4]));
add(P(`La verificación completa del 19/11/2026 (E-LNX-006) muestra con claridad hasta dónde llegó srv01 en el laboratorio: ${R.lab.verificarSrv} ({F:verifSrv}). Las secciones de la base del servidor, que vienen del Hito 2 (usuarios y grupos, dueños y permisos, atributos, SSH, UFW con DOCKER-USER, Docker y la pila de ATLAS), no muestran ningún FAIL. Todos los FAIL caen en las secciones de los pasos 8 a 14: hora desde el DC, unión al dominio con SSSD, Samba, registros persistentes, sudo acotado, respaldos y monitoreo. No son errores de configuración, sino pasos que todavía no se corrieron en esa máquina; los scripts están probados (E-LNX-005, probar-respaldos y E-RED-012) y su ejecución queda como primera tarea pendiente (sección 31.7).`));
add(P('El 20/11/2026 se corrió el paso 14 en srv01, y el instalador repitió la verificación al terminar: 93 PASS y 24 FAIL. Los siete PASS nuevos son de la sección de monitoreo; el único FAIL que quedaba en ella era el agente de atlas-dc01, que todavía no estaba instalado. Una vez instalado (sección 29.6), verificar.sh monitoreo firewall dio 23 de 23 ({F:verifMon}). Los 24 FAIL restantes son de los pasos 8 a 13, que siguen sin correr.'));
add(Figura('verifMon', LAB + 'H3-74e-srv01-verificar-monitoreo.png', 'Verificación del monitoreo y del firewall de atlas-srv01 después del paso 14', 'Captura H3-74e, Shell de Proxmox, 20/11/2026, 19:14. Las nueve comprobaciones del monitoreo (contenedores, interfaz solo en 127.0.0.1, base en red interna, monitoreo.conf de root, UFW del 10050 y agentes con SLA) y las catorce del firewall: 23 PASS y 0 FAIL.', { maxAlto: 600 }));
add(Figura('verifSrv', LAB + 'H3-74a-srv01-verificar.png', 'Final de verificar.sh en atlas-srv01', 'Captura H3-74a (E-LNX-006), 20/11/2026, 00:16. Se ven las secciones con FAIL (hora, dominio, samba, registros, sudo, respaldos y monitoreo) y el resultado: 86 PASS y 31 FAIL. Varios FAIL de respaldos y monitoreo indican el paso que los resuelve (13-respaldos.sh y 14-monitoreo.sh).', { maxAlto: 620 }));

// 29 ------------------------------------------------------------------------------------------
add(H2('29. Windows / Microsoft'));
add(H3('29.1 El servidor'));
add(Tabla('dc', 'Servidor Windows implementado', ['Parámetro', 'Valor'], [
  ['Sistema', 'Windows Server 2022 Standard Evaluation, con escritorio.'], ['Equipo', 'atlas-dc01, VM 120, 3 GB de RAM y disco de 50 GB.'],
  ['Red', '172.16.40.20/24, gateway 172.16.40.1, VLAN 40.'], ['Dominio', 'atlas.local.'],
  ['Servicios', 'AD DS, DNS, DHCP, GPO, recursos compartidos, CA ATLAS-CA; en el Hito 3, retención de respaldos y agente de Zabbix.'],
], [3, 9]));
add(H3('29.2 Active Directory')); v24('s29_2');
add(H3('29.3 Seguridad'));
add(Tabla('segWin', 'Medidas documentadas en Windows Server', ['Medida', 'Configuración'], [
  ['Contraseñas', 'Mínimo 10 caracteres, complejidad, historial de 5 y vencimiento a 90 días.'], ['Bloqueo', '15 minutos tras cinco intentos fallidos.'],
  ['Cuentas', 'Administrator renombrada a atlas.emergencia; Guest deshabilitada.'], ['Delegación', 'GG_SoporteTI con alcance acotado sobre OU=ATLAS.'],
  ['Auditoría', 'Inicio de sesión, cambios del directorio, recursos y administración de cuentas.'], ['RDP y WinRM', 'Solo desde 172.16.50.0/24.'],
  ['Agente de monitoreo', 'TCP 10050 solo desde 172.16.40.10; sin comandos remotos (Hito 3).'],
], [3, 9]));
add(Tabla('gpo', 'Políticas de grupo y ámbito', ['Política', 'Ámbito'], [
  ['GPO_Seguridad_Base', 'Dominio.'], ['GPO_Auditoria', 'Dominio.'], ['GPO_Estudiantes', 'OU Estudiantes (unidad S:).'],
  ['GPO_Docentes', 'OU Docentes; aplicación comprobada en DOC-PC01 (unidad T:).'], ['GPO_Servidores', 'OU Servidores y Domain Controllers.'],
], [4, 8]));
add(H3('29.4 DNS y DHCP')); v24('s29_4');
add(Tabla('dhcp', 'Ámbitos DHCP configurados', ['VLAN', 'Rango', 'Opciones'], [
  ['10', '172.16.10.100 a .200', 'Gateway 172.16.10.1'], ['20', '172.16.20.100 a .200', 'Gateway 172.16.20.1'],
  ['30', '172.16.30.100 a .250', 'Gateway 172.16.30.1'], ['40 y 50', 'Sin ámbito', 'Direcciones fijas'],
], [2, 4, 6], 'Los tres ámbitos entregan DNS 172.16.40.20 y sufijo atlas.local; el relay de router-lab reenvía las solicitudes al DC.'));
add(H3('29.5 Integración con Linux'));
add(Tabla('integracion', 'Integración entre Windows y Linux', ['Componente', 'Estado'], [
  ['DNS de servidores', 'Registros A/PTR documentados.'],
  ['Hora desde el DC', 'DC configurado como fuente; srv01 se ajusta en el paso 8 (R-4).'],
  ['SSSD / Kerberos en Linux', 'Paso 9 listo en el repositorio; unión de srv01 en R-4.'],
  ['Recursos compartidos', 'estudiantes y atlas-backups en el DC; docentes en srv01 (Samba, paso 10).'],
  ['Copia de respaldos', 'srv01 sube a atlas-backups con svc_atlas_backup (crear sí, borrar no); el DC aplica la retención.'],
  ['Correspondencia de identidades', 'GG_SoporteTI → atlas-admin (administración del servidor); docentes y estudiantes, solo acceso web.'],
  ['Certificado de la aplicación', 'CA ATLAS-CA creada; firma del certificado de srv01 en R-4.'],
], [3.4, 8.6]));
add(H3('29.6 Retención de respaldos y agente de monitoreo (Fase 12)'));
add(P('13-retencion-respaldos.ps1 instala una tarea programada que corre todos los días a las 05:00 como SYSTEM y borra lo vencido en atlas-backups: completos de más de 28 días, incrementales de más de 7 y configuraciones más allá de las últimas 10. La decisión de qué está vencido la toma una función del módulo común a partir de la fecha que va en el nombre del archivo (no de la fecha de modificación, que cambia al copiar), y nunca toca archivos que no tengan el formato de atlas-srv01. Cada borrado queda en un registro de texto y en el visor de eventos.'));
add(P('14-agente-zabbix.ps1 instala el agente 2 de Zabbix desde su instalador oficial firmado (comprueba la firma antes de instalar), lo configura para responder solo a 172.16.40.10, sin chequeos activos ni comandos remotos, y abre el 10050 en el firewall de Windows solo para esa dirección. Como el DC no tiene Internet, el instalador viaja en el CD del laboratorio (02-iso-repo.sh lo descarga en Proxmox).'));
add(P('La lógica se probó con PowerShell 7 fuera de Windows: retención (siete casos, incluido que el archivo de archivos de un completo no se confunda con el de un incremental), lectura sin errores de los diecinueve scripts y codificación correcta para Windows PowerShell 5.1. Resultado: 52 de 52 (E-WIN-004). La instalación en el DC se hizo el 20/11/2026 y se cuenta a continuación.'));
add(P(`Ese día sí se corrió el verificador del DC desde Proxmox, con la salida guardada en C:\\ATLAS\\E-WIN-005-verificacion-hito3.txt: dio ${R.lab.verificarDc} ({F:verifDc}). El número llama la atención, porque es exactamente el del Hito 2. La versión del repositorio tiene 73 controles (68 de la Fase 7 y 5 de la Fase 12) y ya no tiene los cinco FAIL falsos de INC-06 e INC-07; un total de 68 con 5 FAIL coincide con el script viejo. Lo más probable es que en C:\\ATLAS siga la versión del Hito 2, porque el paso R-2 (copiar los scripts nuevos desde el CD del laboratorio) no tiene evidencia. La captura muestra solo el total, así que había que confirmarlo.`));
add(P('Se confirmó el 20/11/2026. Primero se regeneró el CD del laboratorio con el instalador del agente de Zabbix (descargado y con la firma comprobada) y se copiaron los scripts nuevos al DC; la lista ya incluye 13-retencion-respaldos.ps1 y 14-agente-zabbix.ps1. Con eso, el verificador dio 73 PASS y 0 FAIL ({F:verifDc2}): los 68 controles de la Fase 7 y los 5 de la Fase 12. Los cinco FAIL del 19/11 eran, entonces, los falsos de INC-06 e INC-07 del script viejo, y la corrección de esas dos incidencias queda verificada en el DC (INC-14, cerrada).'));
add(Figura('verifDc2', LAB + 'H3-74d-dc-verificar-nuevo.png', 'Verificador de atlas-dc01 con los scripts nuevos', 'Captura H3-74d, Shell de Proxmox, 20/11/2026, 19:13. Las últimas secciones: recursos compartidos, hora, RPC, firewall y CA, y la Fase 12 (tarea de retención, permisos de C:\\ATLAS\\scripts, servicio, configuración y regla del agente). Resultado: 73 PASS y 0 FAIL.', { maxAlto: 560 }));
add(P('La instalación de la retención mostró una falla nueva (INC-18). El script registró la tarea programada, pero al simular qué se borraría hoy terminó con «No se puede enlazar el argumento con el parámetro Nombres porque es una cadena vacía». La carpeta atlas-backups estaba vacía, porque srv01 todavía no le copió ningún respaldo, y en Windows PowerShell 5.1 @($archivos.Name) de una lista vacía no da una lista vacía sino una con un elemento nulo. La prueba del módulo pasaba una lista vacía directamente y por eso no lo veía. Se agregó una prueba que arma la lista igual que el script, falló como en el laboratorio, y después de corregir el script (la lista se arma archivo por archivo) y la función (ignora nombres vacíos) pasó: 54 de 54. La tarea quedó instalada igual, diaria a las 05:00 como SYSTEM ({F:tareaRet}); hay que volver a copiar el script corregido al DC.'));
add(Figura('tareaRet', LAB + 'H3-24-dc-tarea-programada.png', 'Tarea programada de retención en atlas-dc01', 'Captura H3-24, consola del DC, 20/11/2026. Programador de tareas → carpeta ATLAS: «ATLAS - Retencion de respaldos», lista, todos los días a las 05:00, con la descripción de la política (28 días, 7 días y 10 versiones).', { maxAlto: 460 }));
add(P('El agente de Zabbix se instaló desde el CD: el script comprobó la firma del instalador (válida, de Zabbix SIA), lo instaló sin chequeos activos ni comandos remotos (DenyKey=system.run[*]), con Server=172.16.40.10, y abrió el 10050 solo para esa dirección ({F:agenteDc}). Tres minutos después, Zabbix ya recibía la CPU, la memoria y el disco del DC (sección 30.5).'));
add(Figura('agenteDc', LAB + 'H3-28-dc-agente-zabbix.png', 'Instalación del agente de Zabbix en atlas-dc01', 'Captura H3-28, Shell de Proxmox, 20/11/2026, 18:43. Firma válida, servicio «Zabbix Agent 2» en marcha y automático, el 10050 escuchando y la regla del firewall solo desde 172.16.40.10.', { maxAlto: 560 }));
add(Figura('verifDc', LAB + 'H3-74b-dc-verificar.png', 'Verificador de atlas-dc01 lanzado desde la Shell de Proxmox', 'Captura H3-74b (E-WIN-005), 20/11/2026, 00:06. El comando guarda la salida completa en C:\\ATLAS y muestra la última línea: «Resultado: 63 PASS · 5 FAIL» (el punto medio sale como «ú» por la codificación de la consola).', { maxAlto: 360 }));
add(H3('29.7 Estado de Windows al Hito 3'));
add(Tabla('entregWin', 'Entregables de Windows y verificación', ['Entregable', 'Estado'], [
  ['Servidor, dominio, OU, grupos, DNS, DHCP, GPO, recursos y CA', 'Instalados y verificados en el laboratorio (Hito 2).'],
  ['Cliente de dominio', 'DOC-PC01 unido; DHCP por relay y GPO_Docentes comprobados.'],
  ['Verificador del DC', '20/11/2026, con los scripts nuevos: 73 PASS y 0 FAIL (el 63/5 del 19/11 era el script viejo).'],
  ['Retención de respaldos', 'Tarea instalada el 20/11; la simulación falló con la carpeta vacía (INC-18), ya corregida y probada; falta copiar el script corregido.'],
  ['Agente de monitoreo', 'Instalado el 20/11 y respondiendo a Zabbix.'],
  ['Rotación de svc_atlas_backup', 'Pendiente: quedó expuesta en el Hito 2 y no hay evidencia de la rotación; se hace en R-5, antes de usarla.'],
], [4.4, 7.6]));

// 30 ------------------------------------------------------------------------------------------
add(H2('30. Redes y seguridad'));
add(P('El laboratorio se implementó en el Hito 2 en Proxmox VE 9.2.2 (Proxmox Server Solutions, s. f.): cuatro máquinas virtuales, cinco VLAN y un firewall obligatorio, con 14 de 17 pruebas ejecutadas con el resultado esperado (Santiago, 2026). Para el Hito 3 se completaron en el repositorio la VPN por perfiles y el monitoreo centralizado, y se preparó el plan para ejecutarlos en el laboratorio (Anexo J). El 19/11/2026 se ejecutó una parte de ese plan: el circuito completo con el registro del 445 desde la VLAN 30, las comprobaciones de base de datos, el respaldo de la VM y las verificaciones finales, incluido el volcado del firewall con las reglas de la VPN. El 20/11 se completó lo que faltaba de la VPN y del monitoreo: el túnel desde la PC con las pruebas 14, 15 y 16, Zabbix en srv01 con el agente del DC y la alerta real al apagar ATLAS.'));
add(H3('30.1 Topología y direccionamiento'));
add(Figura('topo', 'docs/hito-3/documento/img/topologia.png', 'Topología del laboratorio ATLAS con VPN y monitoreo', 'Elaboración propia a partir del informe de Redes del Hito 2 (Santiago, 2026) y de los scripts infra/proxmox/04-router-lab.sh y 05-vpn.sh. El tráfico entre VLAN atraviesa router-lab; el que queda dentro de una VLAN permanece en vmbr1.', { maxAlto: 620 }));
add(Tabla('direcc', 'Direccionamiento implementado', ['VLAN / red', 'Función', 'Gateway', 'Equipos'], [
  ['10 / 172.16.10.0/24', 'Administración', '172.16.10.1', 'Sin estación de prueba'],
  ['20 / 172.16.20.0/24', 'Docentes', '172.16.20.1', 'DOC-PC01: .100'],
  ['30 / 172.16.30.0/24', 'Estudiantes', '172.16.30.1', 'El mismo cliente, al pasarlo a VLAN 30'],
  ['40 / 172.16.40.0/24', 'Servidores', '172.16.40.1', 'srv01 .10; dc01 .20'],
  ['50 / 172.16.50.0/24', 'Gestión', '172.16.50.1', 'Proxmox .10'],
  ['10.8.0.0/24', 'VPN WireGuard', '10.8.0.1 (router-lab)', 'Admin .2 a .126; docentes .129 a .254'],
  ['10.99.0.0/24', 'WAN virtual (vmbr2)', '10.99.0.1 (Proxmox)', 'router-lab .2'],
], [3.2, 2.4, 2.8, 3.6]));
add(Tabla('vms', 'Máquinas virtuales del laboratorio', ['VM / ID', 'Sistema', 'RAM / disco', 'Función'], [
  ['router-lab / 110', 'Ubuntu Server 24.04.5', '1 GB / 10 GB', 'Router, nftables, NAT, relay DHCP y VPN'],
  ['atlas-dc01 / 120', 'Windows Server 2022', '3 GB / 50 GB', 'AD, DNS, DHCP, GPO, CA, copias externas'],
  ['atlas-srv01 / 130', 'Ubuntu Server 24.04.5', '3 GB → 4 GB / 30 GB', 'ATLAS, monitoreo y respaldos'],
  ['cliente-doc / 140', 'Windows 10 Pro', '2 GB / 40 GB', 'DOC-PC01 y pruebas de usuario'],
], [3, 3, 2.6, 3.4], 'Las cuatro VM suman 10 GB con el aumento de srv01, en un nodo con 15 GiB. Los snapshots son puntos de vuelta del laboratorio; no reemplazan el respaldo independiente de la VM (E-BD-015).'));
add(H3('30.2 Matriz de comunicación'));
add(Tabla('matriz', 'Comunicación autorizada entre segmentos', ['Origen', 'Destino permitido', 'Alcance'], [
  ['VLAN 10 y 20', 'srv01; dc01; Internet', 'HTTPS y SMB a srv01; dominio al DC; web externa.'],
  ['VLAN 30', 'srv01; dc01; Internet', 'HTTPS a srv01; dominio al DC; sin SMB a srv01.'],
  ['VLAN 40', 'Internet', 'HTTP/HTTPS; DNS externo solo desde el DC.'],
  ['VLAN 50', 'VLAN 10, 20, 30, 40; Internet', 'SSH/RDP para gestión y web externa.'],
  ['VPN administración', 'VLAN 50', 'Perfil 10.8.0.0/25: llega a Gestión y desde ahí administra.'],
  ['VPN docente', 'srv01', 'Perfil 10.8.0.128/25: solo HTTPS a 172.16.40.10.'],
  ['Internet', '—', 'Sin NAT de entrada: no se publica ningún servicio.'],
], [2.6, 3.4, 6], 'Todo tráfico no autorizado se deniega y se registra.'));
add(H3('30.3 Firewall y NAT'));
add(P('router-lab concentra el enrutamiento y el firewall nftables, con política de descarte en input y forward. Las negaciones específicas preceden a los permisos y las respuestas se admiten por estado.'));
add(Tabla('reglas', 'Política aplicada en forward, en orden de evaluación', ['Regla', 'Origen', 'Destino y servicio', 'Acción'], [
  ['Estado', 'Cualquiera', 'Sesiones establecidas o relacionadas', 'Aceptar; descartar inválido'],
  ['R10', 'Cualquiera', 'srv01 TCP 3306', 'Negar y registrar ATLAS-R10'],
  ['M2', 'VLAN 10, 20, 30', 'srv01 TCP 22', 'Negar y registrar ATLAS-M2'],
  ['R11', 'VLAN 30', 'VLAN 10, 20, 50', 'Negar y registrar ATLAS-R11'],
  ['R1', 'VLAN 10, 20, 30', 'srv01 TCP 443', 'Permitir'],
  ['R2', 'VLAN 10, 20, 30', 'dc01, puertos de dominio', 'Permitir'],
  ['R3', 'VLAN 10, 20', 'srv01 TCP 445', 'Permitir'],
  ['R5', 'VLAN 10, 20, 30, 50', 'Internet TCP 80/443', 'Permitir'],
  ['R6', 'VLAN 50', 'VLAN 10, 20, 30, 40 TCP 22/3389', 'Permitir'],
  ['R7', 'VLAN 40', 'Internet TCP 80/443; DNS del DC', 'Permitir'],
  ['R8', 'VPN 10.8.0.0/25', 'VLAN 50', 'Permitir'],
  ['R9', 'VPN 10.8.0.128/25', 'srv01 TCP 443', 'Permitir'],
  ['R12', 'Cualquier otro', 'Cualquier otro', 'Negar y registrar ATLAS-R12'],
], [1.4, 2.8, 4.2, 3.6], 'Fuente: infra/proxmox/04-router-lab.sh. Los puertos del dominio hacia 172.16.40.20 son TCP 53, 88, 135, 389, 445, 464, 636, 3268-3269 y 49152-65535, y UDP 53, 88, 123, 389 y 464. En input se aceptan el relay DHCP, SSH e ICMP desde la VLAN 50 y UDP 51820 por la WAN; el resto se descarta con ATLAS-IN-DROP.'));
add(P('El NAT se limita a la salida de 172.16.0.0/16 por la WAN; la VPN no se traduce, para que el servidor vea la dirección del perfil (VPN-09). No hay DNAT hacia ningún servidor.'));
add(H3('30.4 VPN'));
add(P('La VPN termina en router-lab con WireGuard (WireGuard, s. f.). 05-vpn.sh da de alta o de baja cada dispositivo con su clave pública y le asigna una dirección fija dentro del segmento de su perfil; el firewall distingue el perfil por esa dirección. La clave privada se genera en el propio dispositivo y nunca pasa por el servidor. El script regenera la configuración desde la lista de pares (agregar o quitar no deja restos), aplica los cambios sin cortar los túneles abiertos y muestra el túnel que hay que cargar en el cliente.'));
add(Tabla('vpn', 'VPN WireGuard por perfil', ['Parámetro', 'Valor y estado'], [
  ['Red y puerto', '10.8.0.0/24 · UDP 51820 por la WAN de router-lab.'],
  ['Perfil administración', '10.8.0.0/25 (direcciones .2 a .126) → solo la VLAN 50 (R8).'],
  ['Perfil docente', '10.8.0.128/25 (direcciones .129 a .254) → solo HTTPS a 172.16.40.10 (R9).'],
  ['Autenticación', 'Una clave pública por dispositivo; alta y baja con 05-vpn.sh.'],
  ['Prueba en el gemelo', `Tráfico real con un cliente de cada perfil: ${R.gemeloVpn}.`],
  ['Prueba en el laboratorio', 'Túnel atlas-docente desde la PC, 20/11/2026: prueba 15 aprobada (ATLAS por 443), prueba 16 aprobada (SSH bloqueado y registrado) y prueba 14 aprobada (sin VPN no se entra); el servidor ve 10.8.0.130 (VPN-09).'],
], [3.2, 8.8]));
add(P('El gemelo de router-lab carga el mismo nftables que genera 04-router-lab.sh en espacios de red de Linux y prueba con conexiones reales: el docente llega a ATLAS por 443 y no al SSH del servidor, ni a Gestión, ni al puerto 445 del DC; el administrador llega a Gestión por SSH y no a ATLAS ni a la red de docentes; el servidor ve la dirección 10.8.0.130 del docente, sin traducir; y desde la WAN no se puede entrar por SSH. El túnel WireGuard real con la PC se probó en el laboratorio el 20/11/2026.'));
add(P('Se hizo con el perfil docente. En la PC se creó el túnel atlas-docente en la aplicación de WireGuard, que generó la clave privada sin sacarla del equipo, y en router-lab se dio de alta su clave pública con 05-vpn.sh, con la dirección 10.8.0.130 ({F:vpnAlta}). Como la WAN de router-lab (10.99.0.0/24) está detrás de Proxmox, la PC necesitó una ruta hacia esa red por 192.168.2.2. Con el túnel activo ({F:vpnTunel}) se corrieron las tres pruebas que quedaban del Hito 2:'));
add(Lista([
  'Prueba 15, el docente llega a ATLAS por la VPN: Test-NetConnection 172.16.40.10 -Port 443 dio TcpTestSucceeded True, con origen 10.8.0.130 y por la interfaz atlas-docente, y el navegador de la PC abrió la pantalla de ingreso de ATLAS. En router-lab, wg show mostró el par con su último saludo de hace 9 segundos y tráfico en los dos sentidos.',
  'Prueba 16, el docente no llega al SSH del servidor: el mismo comando al puerto 22 dio False, y router-lab registró cinco intentos con ATLAS-R12, entrando por wg0 desde 10.8.0.130 hacia 172.16.40.10, puerto 22 ({F:vpn16}). También se descartó un ping desde el túnel.',
  'Prueba 14, desde afuera y sin VPN no se entra: con el túnel apagado, desde la Shell de Proxmox (que está del lado de la WAN) se pidió /api/v1/health por router-lab. curl terminó con el código 28, tiempo agotado, y router-lab registró los intentos con ATLAS-R12 entrando por ens19 desde 10.99.0.1 hacia 172.16.40.10, puerto 443 ({F:vpn14}). La ruta temporal se borró enseguida.',
]));
add(P('Además se comprobó que la VPN no traduce direcciones (VPN-09): en el registro de Nginx de srv01, los pedidos de la prueba 15 aparecen con el origen 10.8.0.130, la dirección del perfil, y no con la de router-lab. Eso permite que el servidor y la auditoría sepan desde qué perfil llegó cada pedido.'));
add(Figura('vpnAlta', LAB + 'H3-36-router-vpn-alta.png', 'Alta del dispositivo del docente en la VPN', 'Captura H3-36, router-lab, 20/11/2026, 20:43 (hora UTC). 05-vpn.sh agrega el par con su clave pública y la dirección 10.8.0.130 y muestra cómo queda el túnel en el cliente. La clave privada del router figura como «(hidden)» y la del cliente la pone la aplicación: no aparece en ningún lado.', { maxAlto: 600 }));
add(Figura('vpnTunel', LAB + 'H3-37-pc-wireguard-activo.png', 'Túnel atlas-docente activo en la PC', 'Captura H3-37, aplicación WireGuard en la PC, 20/11/2026. Estado activo, dirección 10.8.0.130/32, punto final 10.99.0.2:51820, solo 172.16.40.10/32 por el túnel y último saludo hace 24 segundos. Es la pantalla principal, no la de edición, para que no se vea la clave privada.', { maxAlto: 460 }));
add(Figura('vpn16', LAB + 'H3-43-router-registro-prueba16.png', 'Prueba 16: el SSH del servidor desde la VPN queda bloqueado y registrado', 'Captura H3-43, router-lab, 20/11/2026 (hora UTC). A las 21:17 aparecen las líneas ATLAS-R12 con IN=wg0, SRC=10.8.0.130 y DPT=22. Las demás líneas son de srv01 intentando sincronizar la hora con servidores de Internet (UDP 123), algo que la política no permite (INC-20).', { maxAlto: 600 }));
add(Figura('vpn14', LAB + 'H3-45-proxmox-prueba14.png', 'Prueba 14: desde la WAN y sin VPN, ATLAS no responde', 'Captura H3-45, Shell de Proxmox, 20/11/2026, 18:26. Ruta temporal por router-lab, pedido con curl que termina con rc=28 (tiempo agotado) y ruta borrada. El registro de router-lab con ATLAS-R12, IN=ens19, SRC=10.99.0.1 y DPT=443 está en la captura H3-46.', { maxAlto: 420 }));
add(Figura('nft', LAB + 'H3-74c-router-nft.png', 'Firewall de router-lab el 20/11/2026, con las reglas de la VPN', 'Captura H3-74c (E-RED-017), 20/11/2026, 00:07. En input se acepta UDP 51820 por ens19; en forward, al final, 10.8.0.0/25 hacia la VLAN 50 (R8) y 10.8.0.128/25 solo hacia 172.16.40.10:443 (R9), antes del descarte con ATLAS-R12. La salida completa quedó en E-RED-017-ruleset-hito3.txt.', { maxAlto: 620 }));
add(H3('30.5 Monitoreo y verificación'));
add(P('El monitoreo centralizado, que en el Hito 2 era solo diseño, quedó implementado con Zabbix 7.0 LTS (Zabbix, s. f.), según DEC-19. El paso 14 de srv01 genera las contraseñas del monitoreo en un archivo de root fuera del repositorio, levanta los contenedores, abre el 10050 solo para zabbix-server y configura Zabbix por su API: cambia la contraseña inicial de Admin, da de alta atlas-srv01 y atlas-dc01 con las plantillas oficiales y umbrales del 80 %, crea el chequeo de /api/v1/health cada minuto con dos disparadores («ATLAS no responde» y «tarda más de 3 s») y define un SLA del 99 %. La configuración se puede repetir sin duplicar nada. sudo atlas-ctl monitoreo resume el estado en texto.'));
add(Tabla('herrMon', 'Herramientas de monitoreo y verificación', ['Herramienta', 'Uso', 'Estado'], [
  ['nft list ruleset, journalctl -k', 'Configuración aplicada y bloqueos ATLAS-*', 'Laboratorio (Hito 2)'],
  ['Test-NetConnection, /dev/tcp', 'Pruebas TCP desde las VLAN', 'Laboratorio (Hito 2)'],
  ['Zabbix: agentes de srv01 y dc01', 'CPU, memoria y disco con alerta al 80 %', 'Laboratorio desde el 20/11'],
  ['Zabbix: escenario web atlas-salud', 'Disponibilidad y tiempo de respuesta de ATLAS', 'Laboratorio desde el 20/11'],
  ['Zabbix: SLA', 'Disponibilidad diaria frente al 99 %', 'Laboratorio desde el 20/11'],
  ['atlas-ctl monitoreo, verificar.sh', 'Resumen y verificación desde la consola', 'Laboratorio desde el 20/11'],
], [3.6, 5, 3.4]));
add(Tabla('metasInfra', 'Metas de infraestructura y medición', ['Indicador', 'Meta', 'Medición disponible al Hito 3'], [
  ['Disponibilidad', 'Al menos 99 %', `Desarrollo: ${R.disponibilidad} (E-TST-009). Laboratorio: el SLA de Zabbix mide desde el 20/11; el primer día dio 89,7 % por la caída provocada para probar la alerta.`],
  ['Respuesta de la aplicación', 'Hasta 3 s', `Desarrollo: percentil 95 máximo de ${R.rendimiento.p95max} en ${R.rendimiento.consultas} consultas (E-TST-008); el escenario web de Zabbix midió 29 ms en desarrollo (E-RED-012) y 11 ms en el laboratorio.`],
  ['Denegaciones', 'Revisión semanal', 'Registro ATLAS-* en router-lab y accesos denegados en auditoría (M8).'],
  ['CPU, RAM y disco', 'Alerta al 80 %', 'Desarrollo: alerta de disco al 81,6 % (E-RED-012). Laboratorio: alerta real, el disco de srv01 al 99,1 % (INC-19).'],
], [3, 2.2, 6.8]));
add(Figura('zabbix', LAB + 'H3-30-zabbix-hosts.png', 'Hosts en Zabbix en el laboratorio: los agentes de atlas-srv01 y atlas-dc01 responden', 'Captura H3-30, interfaz de Zabbix por túnel SSH desde la PC, 20/11/2026, 18:52. atlas-dc01 y atlas-srv01 con el ícono ZBX en verde y el escenario web en srv01. «Zabbix server» es el host que la imagen oficial crea sola, con el agente en 127.0.0.1 del contenedor; aparece en rojo porque ATLAS no lo usa (se monitorea srv01 con su propio agente).', { maxAlto: 460 }));
add(P(`La prueba automática del monitoreo levanta Zabbix real con contraseñas descartables y un servicio de salud de prueba, y comprueba el aislamiento (interfaz solo en 127.0.0.1, base en red interna y sin puertos publicados), la configuración repetible, el cambio de la contraseña inicial, los datos del agente, el chequeo web con código 200 en menos de 3 s, el SLA y que, al apagar el servicio, aparezca el problema «ATLAS no responde». Resultado: ${R.monitoreo}.`));
add(P('En el laboratorio se corrió el paso 14 el 20/11/2026. Levantó los cuatro contenedores de Zabbix (la interfaz solo en 127.0.0.1:8080 de srv01 y el agente en el 10050) junto a los de ATLAS, que seguían arriba, y configuró Zabbix por su API. Con el agente del DC instalado, atlas-ctl monitoreo dio «Resultado: OK»: la contraseña inicial de Admin ya no entra, los dos agentes responden, el chequeo de /api/v1/health devuelve 200 en 11 ms y el SLA está definido ({F:monLab}). A la interfaz se entró desde la PC con dos túneles SSH, sin abrir ningún puerto nuevo; ahí se vieron los hosts, los últimos datos de los dos equipos y el escenario web en estado OK.'));
add(Figura('monLab', LAB + 'H3-29-srv01-atlas-ctl-monitoreo.png', 'Estado del monitoreo en el laboratorio', 'Captura H3-29, Shell de Proxmox, 20/11/2026, 18:46. Agentes de atlas-dc01 (CPU 4,5 %, memoria 57,9 %, disco C: 25,9 %) y atlas-srv01 (CPU 2,7 %, memoria 52,9 %, disco 99,1 %), chequeo web en 11 ms, problemas abiertos y SLA. Resultado: OK.', { maxAlto: 600 }));
add(P('La alerta se probó apagando ATLAS a propósito. A las 19:01 se detuvo con atlas-ctl detener; a las 19:02 Zabbix abrió el problema «ATLAS no responde (salud de la plataforma)» con severidad alta ({F:alerta}). A las 19:05 se volvió a iniciar y a las 19:06 el problema pasó a resuelto, con una duración de 3 minutos y 40 segundos. El informe del SLA de ese día dio 89,7 %, por debajo de la meta del 99 %: el SLA empezó a medir cuando se configuró, una media hora antes, y la caída provocada ocupa una parte grande de ese rato. No dice nada del servicio en el tiempo; para eso hay que dejarlo medir varios días.'));
add(Figura('alerta', LAB + 'H3-34-zabbix-alerta-resuelta.png', 'La alerta «ATLAS no responde», abierta al apagar ATLAS y resuelta al encenderlo', 'Captura H3-34, Zabbix → Problems con el historial, 20/11/2026, 19:08. Arriba, el problema de ATLAS: 19:02:21, severidad alta, resuelto a las 19:06:01, 3 min 40 s. Abajo siguen abiertos el disco de srv01 por encima del 90 %, el servicio spice-agent del DC y el host «Zabbix server».', { maxAlto: 520 }));
add(P('Zabbix encontró además un problema real en su primer día: el disco de atlas-srv01 estaba al 99,1 % y disparó «Space is critically low (used > 90 %, total 13.7 GB)» (INC-19). Es exactamente para lo que se instaló el monitoreo, y hay que resolverlo antes de que ATLAS o MySQL se queden sin espacio. Los otros dos avisos no son del servicio: el agente de SPICE no está en uso en el DC y el host «Zabbix server» es el que trae la imagen por defecto.'));
add(H3('30.6 Pruebas de red'));
add(Tabla('pruebasRed', 'Pruebas de red del plan del Hito 2 y su resultado', ['N.º', 'Prueba', 'Regla', 'Resultado', 'Estado'], [
  ['1', 'V20 → srv01:443', 'R1', 'True', 'Aprobada'], ['2', 'V20 → srv01:445', 'R3', 'True', 'Aprobada'],
  ['3', 'V20 → srv01:22', 'M2', 'False; ATLAS-M2', 'Aprobada'], ['4', 'V20 → srv01:3306', 'R10', 'False; ATLAS-R10', 'Aprobada'],
  ['5', 'V20 → Internet:443', 'R5 / NAT', 'True', 'Aprobada'], ['6', 'V30 → srv01:443', 'R1', 'True', 'Aprobada'],
  ['7', 'V30 → srv01:445', 'R12', 'False; ATLAS-R12 registrado', 'Aprobada; registro verificado el 19/11'],
  ['8', 'V30 → srv01:22', 'M2', 'False; ATLAS-M2', 'Aprobada'], ['9', 'V30 → Gestión:22', 'R11', 'False; ATLAS-R11', 'Aprobada'],
  ['10', 'V50 → srv01:22', 'R6', 'Abierto; sesión por clave', 'Aprobada'], ['11', 'V50 → srv01:443', 'R12', 'Cerrado; ATLAS-R12', 'Aprobada'],
  ['12', 'V50 → srv01:3306', 'R10', 'Cerrado; ATLAS-R10', 'Aprobada'], ['13', 'V50 → dc01:3389', 'R6', 'Abierto', 'Aprobada'],
  ['14', 'Exterior → ATLAS sin VPN', '§30.3', 'rc=28; ATLAS-R12 desde ens19', 'Aprobada (20/11)'],
  ['15', 'Exterior → ATLAS con VPN docente', 'R9', 'True; ingreso de ATLAS en el navegador', 'Aprobada (20/11)'],
  ['16', 'VPN docente → srv01:22', 'R12', 'False; ATLAS-R12 desde wg0', 'Aprobada (20/11)'],
  ['17', 'V20 → DHCP por relay', 'R4', '172.16.20.100; DNS del DC', 'Aprobada'],
], [0.8, 3.8, 1.4, 3.2, 2.8], 'Se conserva la numeración del informe de Redes del Hito 2 (tabla 8.4 del informe). Las pruebas 14 a 16 se ejecutaron en el laboratorio el 20/11/2026 (sección 30.4). Las evidencias de las pruebas 1 a 13 y 17 son las figuras E101 a E109 y E56 del Anexo E. En el Hito 2 la prueba 7 dio el resultado esperado, pero el registro no se llegó a ver; se repitió el 19/11/2026 ({F:test445} y {F:r12}).'));
add(P('La repetición de la prueba 7 se hizo con cliente-doc en la VLAN 30 (172.16.30.100) y el registro del núcleo abierto en router-lab. Test-NetConnection al puerto 445 de srv01 dio TcpTestSucceeded False y, al mismo tiempo, router-lab anotó cinco intentos con el prefijo ATLAS-R12, entrando por ens18.30 y saliendo hacia ens18.40, desde 172.16.30.100 hacia 172.16.40.10, puerto 445. Es lo que pide la matriz: los estudiantes no llegan a los recursos compartidos del servidor y el bloqueo queda registrado. El ping también falla, porque la política no permite ICMP desde la VLAN 30 hacia los servidores.'));
add(Figura('test445', LAB + 'H3-56-cliente-445-vlan30.png', 'Prueba 7 repetida: el puerto 445 de srv01 desde la VLAN 30', 'Captura H3-56, cliente-doc, 19/11/2026. Origen 172.16.30.100, destino 172.16.40.10:445: «TCP connect … failed» y TcpTestSucceeded False.', { maxAlto: 480 }));
add(Figura('r12', LAB + 'H3-57-router-registro-445.png', 'Registro del bloqueo en router-lab con el prefijo ATLAS-R12', 'Captura H3-57, sesión SSH a router-lab desde la Shell de Proxmox, 20/11/2026 (hora UTC del router: 02:22 y 02:23). Cada línea es un intento de conexión (SYN) desde 172.16.30.100 al puerto 445 de 172.16.40.10, descartado por R12.', { maxAlto: 620 }));
add(H3('30.7 Estado de redes y seguridad al Hito 3'));
add(Tabla('entregRedes', 'Entregables de Redes', ['Entregable', 'Repositorio', 'Laboratorio'], [
  ['Laboratorio Proxmox, VLAN y troncal', 'Scripts 01 a 04', 'Implementado (Hito 2)'],
  ['Firewall y NAT', 'Gemelo: 46 de 46 con la VPN', 'Aplicado; 14 de 17 pruebas (Hito 2) y volcado del 20/11 con las reglas de la VPN'],
  ['VPN por perfiles', '05-vpn.sh; 29 de 29 en las pruebas del script', 'Perfil docente probado el 20/11: pruebas 15 y 16 aprobadas y sin NAT (VPN-09); el perfil de administración no se probó'],
  ['Monitoreo centralizado', 'Paso 14 y agente del DC; 14 de 14', 'Funcionando desde el 20/11: dos agentes, chequeo web, SLA y alerta probada'],
  ['Acceso externo (prueba 14)', 'Procedimiento con ruta temporal por la WAN', 'Aprobada el 20/11'],
  ['Registro del 445 desde VLAN 30', '—', 'Verificado el 19/11/2026'],
], [4, 4.4, 3.6]));
add(P('Lo que quedó sin ejecutar sigue en el plan del Anexo J, con los comandos exactos, lo que tiene que salir y la evidencia que se guarda en cada paso. No hace falta cablear nada nuevo: lo físico quedó armado en el Hito 2.'));
add(Salto());
