// Parte II: secciones 26 a 30.
const L = require('./lib');
const { add, P, H2, H3, Vineta, Salto, Tabla, Figura, Consola } = L;
const { v24 } = require('./contenido-1');
const R = require('./resultados');
const C = 'docs/evidencias/B/capturas/hito3/';

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
add(P(`La prueba de interfaz recorre los tres roles en cinco anchos de pantalla con Chromium, mediante Playwright (Playwright, s. f.), y dio ${R.interfaz}. Las figuras siguientes son capturas de esa corrida, con datos de demostración sintéticos; el Anexo B agrega el ingreso, el tema oscuro y más pantallas (figuras B1 a B8).`));
add(Figura('fDocente', C + 'docente-donde-intervenir-escritorio-1366.png', 'Inicio del docente: dónde intervenir, en escritorio (1366 píxeles)', 'Captura de la prueba de interfaz (E-APP-015). Datos sintéticos de demostración: no corresponden a estudiantes reales.', { maxAlto: 560 }));
add(Figura('fGrupo', C + 'docente-analisis-grupal-1366.png', 'Análisis del grupo: requieren atención, errores por pregunta y acierto por habilidad', 'Captura de la prueba de interfaz (E-APP-015), con datos sintéticos. La lista «requieren atención» muestra la regla que la origina (R01 a R08).', { maxAlto: 620 }));
add(Figura('fMovil', C + 'estudiante-resolviendo-375.png', 'Resolución de una actividad en un celular (375 píxeles)', 'Captura de la prueba de interfaz (E-APP-015). El estudiante ve una pregunta por vez; el registro de interacciones se envía por lotes.', { maxAlto: 600, maxAncho: 300 }));
add(Figura('fConsultas', C + 'docente-consultas-habilidades-1024.png', 'Consultas guiadas: acierto por habilidad del grupo y del período elegidos', 'Captura de la prueba de interfaz (E-APP-015), con datos sintéticos. Cada consulta explica cómo se obtuvo el resultado (D-5).', { maxAlto: 600 }));
add(H3('26.6 Estado de programación al Hito 3'));
add(Tabla('entregProg', 'Entregables de programación', ['Entregable', 'Estado', 'Evidencia'], [
  ['Stack y estructura del proyecto', 'Listo', 'Sección 26.2'],
  ['Inicio de sesión y paneles por rol', 'Listo en desarrollo', 'E-APP-015'],
  ['Middleware de sesión, permisos, validación y auditoría', 'Listo en desarrollo', 'Sección 26.3; pruebas de API'],
  ['Actividades, habilidades y registro de resolución', 'Listo en desarrollo', 'E-BD-016'],
  ['Consultas guiadas y decisión docente', 'Listo en desarrollo', 'E-APP-015'],
  ['Interfaz rediseñada, responsiva y accesible', 'Listo en desarrollo', 'Sección 26.5; E-APP-015'],
  ['Publicación sin grupo (422 del laboratorio, INC-09)', 'Corregido y verificado en desarrollo', 'Prueba de interfaz «docente sin grupo»'],
  ['Circuito completo en el laboratorio', 'No ejecutada', 'Paso R-8 del Anexo J'],
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
add(P('La devolución de Base de Datos pidió tres comprobaciones. Las tres se automatizaron con herramientas del repositorio y se corrieron en desarrollo; la tercera se repite en el laboratorio después del circuito (paso R-9 del Anexo J).'));
add(P(`Seguimiento de un intento (E-BD-016). Una prueba en el navegador lee las respuestas correctas de una actividad como docente, resuelve como estudiante con un plan fijo (en la pregunta 1 elige primero una opción incorrecta y después la corrige; la pregunta 3 la contesta mal) y calcula el puntaje esperado: 75. Después consulta la base: una respuesta final por pregunta, el evento CAMBIO_OPCION de la pregunta 1 en interacciones y un único resultado con 75,00; por último, el informe del docente muestra el mismo 75. Resultado: ${R.trazado}. En el laboratorio, la parte de la base la muestra seguir_intento.sh.`));
add(Figura('traza', 'docs/evidencias/G/E-BD-016-trazado-intento/1-estudiante-cambia-respuesta.png', 'El estudiante cambia la respuesta de la pregunta 1 durante el seguimiento del intento', 'Captura de E-BD-016 (desarrollo, datos sintéticos). El cambio queda en interacciones como CAMBIO_OPCION y la respuesta final, en respuestas.', { maxAlto: 520 }));
add(P(`Puntaje guardado contra calculado (E-BD-017). Sobre datos representativos de desarrollo se comparó la consulta que lee el puntaje guardado con otra que lo recalcula desde las respuestas: dieron los mismos valores por actividad y por intento. En 20 ejecuciones de cada una, la mediana fue de ${R.comparacion.medianaA} con el puntaje guardado y de ${R.comparacion.medianaB} recalculándolo (percentil 95: ${R.comparacion.p95A} y ${R.comparacion.p95B}). Con atlas_app se intentó modificar el puntaje de un intento cerrado de cinco maneras y las cinco fueron rechazadas con su mensaje: UPDATE y DELETE denegados por privilegios, un segundo resultado rechazado por la restricción UNIQUE, y el cambio de respuesta y la reapertura del intento rechazados por los triggers de integridad.`));
add(P(`Restauración por intento (E-BD-018). restaurar_intento.sh hace un respaldo con atlas_backup, lo restaura en una base aparte y recupera el intento por su número en las dos bases, comparando con huellas sha256 el intento, sus respuestas, sus interacciones y su resultado, además del conteo de cada tabla. En desarrollo dio ${R.restauracion}, con el último intento recuperado igual al último de la base en uso. Ese tiempo es el de la base; volver a operar incluye reiniciar los contenedores y comprobar el acceso, por eso la medición que vale contra el RTO de 4 h es la del laboratorio.`));
add(H3('27.8 Estado de base de datos al Hito 3'));
add(Tabla('entregBD', 'Entregables de base de datos', ['Entregable', 'Estado', 'Evidencia'], [
  ['Modelo, diccionario y scripts 001 a 004', 'Listo', 'docs/fase-05-base-datos/'],
  ['Integridad y cálculos en PHP', 'Verificado en desarrollo', 'E-BD-007; pruebas de base 58 de 58'],
  ['Usuarios y privilegios', 'Verificado', 'E-BD-010; rechazos de atlas_app en E-BD-017'],
  ['Seguimiento de un intento de punta a punta', 'Verificado en desarrollo', 'E-BD-016'],
  ['Puntaje guardado contra calculado, con tiempos', 'Verificado en desarrollo', 'E-BD-017'],
  ['Restauración por intento', 'Verificado en desarrollo; laboratorio pendiente', 'E-BD-018; E-BD-020 (R-9)'],
  ['Respaldos automáticos anotados en registro_respaldos', 'Verificado en desarrollo', 'probar-respaldos.sh, 17 de 17'],
  ['Respaldo de la VM completa', 'No ejecutada', 'E-BD-015 (R-10)'],
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
add(P('La prueba automática del paso 13 corre contra un MySQL 8.0 real con binlog y comprueba diecisiete puntos: volcado completo y verificado, incremental con los datos nuevos, retención de la configuración, anotación con atlas_backup, detección de un archivo alterado y restauración en una base aparte con las 32 tablas y las mismas filas. Resultado: 17 de 17 (E-TST-010). En el laboratorio se ejecuta en el paso R-5 del Anexo J, que incluye comprobar que srv01 no puede borrar en el DC.'));
add(P('Procedimiento de recuperación del servicio completo: verificar la huella de la copia; detener ATLAS (atlas-ctl detener); restaurar la base con el último completo y aplicar los binlog incrementales; restaurar archivos con sus ACL y atributos; iniciar los servicios; comprobar el acceso y anotar la operación. Las metas se mantienen: perder como máximo 24 horas de datos (RPO) y volver a operar en menos de cuatro horas (RTO).'));
add(H3('28.6 Estado del servidor al Hito 3'));
add(Tabla('entregLinux', 'Estado de los entregables del servidor Linux', ['Entregable', 'Repositorio', 'Laboratorio'], [
  ['VM, red definitiva y pila de ATLAS', 'Listo (pasos 1 a 7)', 'Ejecutado en el Hito 2'],
  ['Arranque sin Internet y atlas-ctl (INC-01, INC-08)', 'Corregido y verificado (E-TST-003)', 'No ejecutada (R-3)'],
  ['Hora, dominio, Samba, registros y sudo (pasos 8 a 12)', 'Listo; probado en Ubuntu real (E-LNX-005)', 'No ejecutada (R-4)'],
  ['Respaldos automáticos con copia al DC (paso 13)', 'Listo; 17 de 17', 'No ejecutada (R-5)'],
  ['Monitoreo con Zabbix (paso 14)', 'Listo; 14 de 14 y corrida completa del paso (E-RED-012)', 'No ejecutada (R-6)'],
  ['Certificado firmado por ATLAS-CA', 'Listo (instalar-certificado.sh)', 'No ejecutada (R-4)'],
  ['Verificación completa (verificar.sh)', 'Incluye respaldos y monitoreo', 'No ejecutada (R-11)'],
], [4.6, 4, 3.4]));

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
add(P('La lógica se probó con PowerShell 7 fuera de Windows: retención (siete casos, incluido que el archivo de archivos de un completo no se confunda con el de un incremental), lectura sin errores de los diecinueve scripts y codificación correcta para Windows PowerShell 5.1. Resultado: 52 de 52 (E-WIN-004). La instalación en el DC y el verificador completo (68 controles de la Fase 7 y 5 de la Fase 12) se ejecutan en los pasos R-5, R-6 y R-11.'));
add(H3('29.7 Estado de Windows al Hito 3'));
add(Tabla('entregWin', 'Entregables de Windows y verificación', ['Entregable', 'Estado'], [
  ['Servidor, dominio, OU, grupos, DNS, DHCP, GPO, recursos y CA', 'Instalados y verificados en el laboratorio (Hito 2).'],
  ['Cliente de dominio', 'DOC-PC01 unido; DHCP por relay y GPO_Docentes comprobados.'],
  ['Verificador del DC', '63 PASS y 5 FAIL en el Hito 2; los cinco eran falsos y se corrigieron (INC-06, INC-07); repetir en R-11.'],
  ['Retención de respaldos', 'Implementada y probada fuera de Windows (E-WIN-004); instalación en R-5.'],
  ['Agente de monitoreo', 'Implementado; instalación en R-6.'],
  ['Rotación de svc_atlas_backup', 'Pendiente: quedó expuesta en el Hito 2; se rota en R-5 antes de usarla.'],
], [4.4, 7.6]));

// 30 ------------------------------------------------------------------------------------------
add(H2('30. Redes y seguridad'));
add(P('El laboratorio se implementó en el Hito 2 en Proxmox VE 9.2.2 (Proxmox Server Solutions, s. f.): cuatro máquinas virtuales, cinco VLAN y un firewall obligatorio, con 14 de 17 pruebas ejecutadas con el resultado esperado (Santiago, 2026). Para el Hito 3 se completaron en el repositorio la VPN por perfiles y el monitoreo centralizado, y se preparó el plan para ejecutarlos en el laboratorio (Anexo J).'));
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
  ['Prueba en el laboratorio', 'Pruebas 14, 15 y 16 *No ejecutadas*; paso R-7 del Anexo J (E-RED-008a/b/c y E-RED-014).'],
], [3.2, 8.8]));
add(P('El gemelo de router-lab carga el mismo nftables que genera 04-router-lab.sh en espacios de red de Linux y prueba con conexiones reales: el docente llega a ATLAS por 443 y no al SSH del servidor, ni a Gestión, ni al puerto 445 del DC; el administrador llega a Gestión por SSH y no a ATLAS ni a la red de docentes; el servidor ve la dirección 10.8.0.130 del docente, sin traducir; y desde la WAN no se puede entrar por SSH. El túnel WireGuard real con la PC se prueba en el laboratorio.'));
add(H3('30.5 Monitoreo y verificación'));
add(P('El monitoreo centralizado, que en el Hito 2 era solo diseño, quedó implementado con Zabbix 7.0 LTS (Zabbix, s. f.), según DEC-19. El paso 14 de srv01 genera las contraseñas del monitoreo en un archivo de root fuera del repositorio, levanta los contenedores, abre el 10050 solo para zabbix-server y configura Zabbix por su API: cambia la contraseña inicial de Admin, da de alta atlas-srv01 y atlas-dc01 con las plantillas oficiales y umbrales del 80 %, crea el chequeo de /api/v1/health cada minuto con dos disparadores («ATLAS no responde» y «tarda más de 3 s») y define un SLA del 99 %. La configuración se puede repetir sin duplicar nada. sudo atlas-ctl monitoreo resume el estado en texto.'));
add(Tabla('herrMon', 'Herramientas de monitoreo y verificación', ['Herramienta', 'Uso', 'Estado'], [
  ['nft list ruleset, journalctl -k', 'Configuración aplicada y bloqueos ATLAS-*', 'Laboratorio (Hito 2)'],
  ['Test-NetConnection, /dev/tcp', 'Pruebas TCP desde las VLAN', 'Laboratorio (Hito 2)'],
  ['Zabbix: agentes de srv01 y dc01', 'CPU, memoria y disco con alerta al 80 %', 'Desarrollo; laboratorio en R-6'],
  ['Zabbix: escenario web atlas-salud', 'Disponibilidad y tiempo de respuesta de ATLAS', 'Desarrollo; laboratorio en R-6'],
  ['Zabbix: SLA', 'Disponibilidad diaria frente al 99 %', 'Desarrollo; laboratorio en R-6'],
  ['atlas-ctl monitoreo, verificar.sh', 'Resumen y verificación desde la consola', 'Desarrollo'],
], [3.6, 5, 3.4]));
add(Tabla('metasInfra', 'Metas de infraestructura y medición', ['Indicador', 'Meta', 'Medición disponible al Hito 3'], [
  ['Disponibilidad', 'Al menos 99 %', `Desarrollo: ${R.disponibilidad} (E-TST-009). Laboratorio: SLA de Zabbix desde R-6.`],
  ['Respuesta de la aplicación', 'Hasta 3 s', `Desarrollo: percentil 95 máximo de ${R.rendimiento.p95max} en ${R.rendimiento.consultas} consultas (E-TST-008); el escenario web midió 26 a 29 ms (E-RED-012).`],
  ['Denegaciones', 'Revisión semanal', 'Registro ATLAS-* en router-lab y accesos denegados en auditoría (M8).'],
  ['CPU, RAM y disco', 'Alerta al 80 %', 'Desarrollo: la alerta de disco se disparó con el disco del equipo al 81,6 % (E-RED-012).'],
], [3, 2.2, 6.8]));
add(Figura('zabbix', 'docs/evidencias/E/capturas/zabbix-hosts.png', 'Hosts en Zabbix: el agente de atlas-srv01 responde y el escenario web está activo', 'Captura de E-RED-012 en desarrollo. atlas-dc01 aparece sin respuesta porque en ese equipo no hay un Windows; en el laboratorio se instala el agente en el paso R-6.', { maxAlto: 420 }));
add(P(`La prueba automática del monitoreo levanta Zabbix real con contraseñas descartables y un servicio de salud de prueba, y comprueba el aislamiento (interfaz solo en 127.0.0.1, base en red interna y sin puertos publicados), la configuración repetible, el cambio de la contraseña inicial, los datos del agente, el chequeo web con código 200 en menos de 3 s, el SLA y que, al apagar el servicio, aparezca el problema «ATLAS no responde». Resultado: ${R.monitoreo}.`));
add(H3('30.6 Pruebas de red'));
add(Tabla('pruebasRed', 'Pruebas de red ejecutadas y pendientes', ['N.º', 'Prueba', 'Regla', 'Resultado', 'Estado'], [
  ['1', 'V20 → srv01:443', 'R1', 'True', 'Aprobada'], ['2', 'V20 → srv01:445', 'R3', 'True', 'Aprobada'],
  ['3', 'V20 → srv01:22', 'M2', 'False; ATLAS-M2', 'Aprobada'], ['4', 'V20 → srv01:3306', 'R10', 'False; ATLAS-R10', 'Aprobada'],
  ['5', 'V20 → Internet:443', 'R5 / NAT', 'True', 'Aprobada'], ['6', 'V30 → srv01:443', 'R1', 'True', 'Aprobada'],
  ['7', 'V30 → srv01:445', 'R12', 'False; registro no visible', 'Aprobada; registro en R-8'],
  ['8', 'V30 → srv01:22', 'M2', 'False; ATLAS-M2', 'Aprobada'], ['9', 'V30 → Gestión:22', 'R11', 'False; ATLAS-R11', 'Aprobada'],
  ['10', 'V50 → srv01:22', 'R6', 'Abierto; sesión por clave', 'Aprobada'], ['11', 'V50 → srv01:443', 'R12', 'Cerrado; ATLAS-R12', 'Aprobada'],
  ['12', 'V50 → srv01:3306', 'R10', 'Cerrado; ATLAS-R10', 'Aprobada'], ['13', 'V50 → dc01:3389', 'R6', 'Abierto', 'Aprobada'],
  ['14', 'Exterior → ATLAS sin VPN', '§30.3', 'Sin resultado', 'No ejecutada (R-7)'],
  ['15', 'Exterior → ATLAS con VPN docente', 'R9', 'Sin resultado', 'No ejecutada (R-7)'],
  ['16', 'VPN docente → srv01:22', 'R12', 'Sin resultado', 'No ejecutada (R-7)'],
  ['17', 'V20 → DHCP por relay', 'R4', '172.16.20.100; DNS del DC', 'Aprobada'],
], [0.8, 3.8, 1.4, 3.2, 2.8], 'Se conserva la numeración del informe de Redes del Hito 2 (tabla 8.4 del informe). Las pruebas 14 a 16 tienen su equivalente probado en el gemelo (E-RED-011), que no reemplaza su ejecución en el laboratorio. Las evidencias de las pruebas 1 a 13 y 17 son las figuras E101 a E109 y E56 del Anexo E.'));
add(H3('30.7 Estado de redes y seguridad al Hito 3'));
add(Tabla('entregRedes', 'Entregables de Redes', ['Entregable', 'Repositorio', 'Laboratorio'], [
  ['Laboratorio Proxmox, VLAN y troncal', 'Scripts 01 a 04', 'Implementado (Hito 2)'],
  ['Firewall y NAT', 'Gemelo: 46 de 46 con la VPN', 'Aplicado; 14 de 17 pruebas (Hito 2)'],
  ['VPN por perfiles', '05-vpn.sh; 29 de 29 en las pruebas del script', 'No ejecutada (R-7)'],
  ['Monitoreo centralizado', 'Paso 14 y agente del DC; 14 de 14', 'No ejecutada (R-6)'],
  ['Acceso externo (prueba 14)', 'Procedimiento con ruta temporal por la WAN', 'No ejecutada (R-7)'],
  ['Registro del 445 desde VLAN 30', '—', 'Pendiente (R-8)'],
], [4, 4.4, 3.6]));
add(P('El plan del Anexo J ordena todo lo que falta en el laboratorio, con los comandos exactos, lo que tiene que salir y la evidencia que se guarda en cada paso. No hace falta cablear nada nuevo: lo físico quedó armado en el Hito 2.'));
add(Salto());
