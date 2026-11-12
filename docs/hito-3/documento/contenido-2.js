// Parte II: secciones 19 a 25.
const L = require('./lib');
const { add, P, PSin, H1, H2, H3, Vineta, Lista, Salto, Tabla, Figura, Consola } = L;
const { v24 } = require('./contenido-1');
const R = require('./resultados');

add(H1('Parte II - Plan de trabajo, implementación y estado'));

// 19 ------------------------------------------------------------------------------------------
add(H2('19. El equipo'));
add(Tabla('equipo', 'Roles, integrantes y tutorías asignadas', ['Rol de coordinación', 'Rol Scrum', 'Integrante', 'Tutoría a cargo'], [
  ['Coordinador', 'Product Owner', 'Santiago Emanuel Viñas Rezzano', 'Gestión y documentación'],
  ['Subcoordinador', 'Scrum Master', 'Juan Pablo Beracochea Cabrera', 'Redes MS y Conectividad'],
  ['Integrante 1', 'Developer', 'Aaron Britos Alonso', 'Programación'],
  ['Integrante 2', 'Developer', 'Brian Daniel Reyes Ortiz', 'Base de datos'],
  ['Integrante 3', 'Developer', 'Sergio Enrique Rodríguez Oquel', 'POSIX / Linux'],
], [2.2, 2, 3.4, 3]));
v24('s19nota');

// 20 ------------------------------------------------------------------------------------------
add(H2('20. Relevamiento'));
add(H3('20.1 Por qué lo hicimos')); v24('s20_1');
add(H3('20.2 Cómo lo armamos')); v24('s20_2');
add(Tabla('relev', 'Objetivos y preguntas del relevamiento docente', ['Qué queríamos saber', 'Preguntas'], [
  ['Quién responde y en qué contexto trabaja', '1, 2, 3'], ['Qué usa hoy para evaluar', '4'], ['Si percibe la limitación que planteamos', '5'],
  ['Qué le falta y no tiene', '6, 11'], ['Si ya usa alguna herramienta digital', '7'], ['Cuán útil le parecería ATLAS', '8'],
  ['Qué reparos le genera', '9'], ['Si probaría el sistema', '10'],
], [6, 2]));
v24('s20_2b');
add(H3('20.3 A quiénes consultamos')); v24('s20_3');
add(H3('20.4 Conclusiones y resultados')); v24('s20_4', { saltear: [14] });
add(P('Al cierre de esta versión el relevamiento sigue con las cuatro respuestas informadas. Su ampliación, con docentes del ITI y con consentimiento informado, forma parte del plan de la sección 32. La orientación de diseño que dejó (priorizar la vista grupal y la lista de quienes requieren atención) se mantuvo en el Hito 3: la pantalla de inicio del docente arranca por el grupo y la lista ordenada por prioridad (sección 26.5).'));

// 21 ------------------------------------------------------------------------------------------
add(H2('21. Criterios de verificación de los objetivos'));
v24('s21');
add(P('En el Hito 3 se agrega a la tabla el estado de cada criterio y la evidencia que lo respalda. «Desarrollo» indica la pila local con datos de prueba; «laboratorio», el entorno Proxmox. Un criterio que solo se comprobó en desarrollo no se da por cumplido en el laboratorio.'));
add(Tabla('criterios', 'Criterios de verificación de los objetivos específicos y estado al Hito 3', ['Objetivo (sección 4)', 'Cómo lo verificamos', 'Estado al Hito 3 y evidencia'], [
  ['1. Plataforma web con usuarios, roles y autenticación', 'Los tres roles acceden solo a lo que les corresponde, comprobado con diez casos de prueba documentados.', `Cumplido en desarrollo: las pruebas de API comprueban 401 sin sesión, 403 en el acceso cruzado entre roles (y que queda registrado), el rechazo sin token CSRF y 422 con detalle por campo (ControlAccesoTest, E-TST-010); interfaz ${R.interfaz}. Laboratorio: ingreso por rol comprobado en el Hito 2.`],
  ['2. Crear actividades educativas interactivas', 'Una actividad recorre sus estados y queda registro de cada cambio.', 'Cumplido en desarrollo: ciclo validado en la aplicación y en la base (transiciones_actividad); publicación directa por defecto (D-2). Laboratorio: publicación pendiente del paso R-8.'],
  ['3. Registrar las interacciones', 'Sobre 50 resoluciones de prueba, el 100 % queda con respuestas, tiempo e intentos registrados.', 'Cumplido en desarrollo: M1 = 67 de 67 intentos finalizados completos (E-TST-007); seguimiento de un intento de punta a punta (E-BD-016).'],
  ['4. Diseñar la base de datos', 'Modelo en 3FN, mínimo 15 tablas, integridad referencial y privilegios distintos por rol.', 'Cumplido: 32 tablas, claves foráneas y CHECK; cinco cuentas con privilegios distintos (E-BD-010); atlas_app no puede alterar un resultado (E-BD-017).'],
  ['5. Algoritmos de análisis', 'Al menos ocho reglas documentadas y trazabilidad de cada recomendación.', 'Cumplido en desarrollo: M5 = 8 reglas activas; M4 = 52 de 52 recomendaciones con regla y versión registradas (E-TST-007).'],
  ['6. Perfiles y recomendaciones', 'Se genera perfil individual y grupal a partir de los datos registrados.', 'Cumplido en desarrollo: perfil del estudiante, análisis del grupo y acierto por habilidad (E-APP-015, capturas del Anexo B).'],
  ['7. Seguridad y control de acceso', 'Cinco intentos de acceso no autorizado rechazados y registrados.', 'Cumplido en desarrollo: accesos sin permiso rechazados con 403 y registrados en auditoría (M8); bloqueo por intentos fallidos (RF-02). Laboratorio: firewall con registro de bloqueos (Hito 2).'],
  ['8. Infraestructura Linux y Windows', 'Autenticación centralizada funcionando y recursos compartidos accesibles entre ambos.', 'Parcial: dominio y recursos del DC funcionando; unión de srv01 con SSSD y Samba en el laboratorio pendientes (paso R-4). Copia de respaldos de Linux a Windows implementada y probada en desarrollo.'],
  ['9. Red segmentada mediante VLAN', 'Las cinco VLAN operativas, con pruebas de qué se permite y qué se bloquea.', 'Cumplido en el laboratorio para las VLAN con equipos: 14 de 17 pruebas con resultado esperado (Hito 2).'],
  ['10. Firewall, VPN y monitoreo', 'Los tres funcionando, con registro de eventos.', `Firewall cumplido en el laboratorio. VPN y monitoreo implementados y probados en desarrollo (${R.gemeloVpn}; ${R.monitoreo}); en el laboratorio, *No ejecutada* hasta los pasos R-6 y R-7.`],
  ['11. Respaldo y recuperación', 'Respaldo automatizado con verificación y al menos una restauración documentada; perder como máximo 24 h y restablecer en menos de 4 h.', `Cumplido en desarrollo: respaldos automáticos con verificación (17 de 17, E-TST-010) y restauración de un intento con ${R.restauracion}. En el laboratorio, pasos R-5, R-9 y R-10.`],
  ['12. Evaluar mediante métricas objetivas', 'Informe con disponibilidad, tiempo de respuesta y porcentaje de registros correctos.', `Cumplido en desarrollo: sección 31.4 (M1 a M11, tiempos con percentil 95 máximo de ${R.rendimiento.p95max}, disponibilidad ${R.disponibilidad}). En el laboratorio la medición continua la hace Zabbix.`],
], [2.6, 3.4, 6]));

// 22 ------------------------------------------------------------------------------------------
add(H2('22. Cómo trabajamos'));
add(H3('22.1 Por qué Scrum y no Kanban')); v24('s22_1');
add(H3('22.2 Roles'));
add(P('Los roles, eventos y artefactos siguen la Guía Scrum (Schwaber y Sutherland, 2020), con las adaptaciones que se explican en cada caso.'));
add(Tabla('rolesScrum', 'Roles y responsabilidades del equipo Scrum', ['Rol', 'Quién', 'Qué hace'], [
  ['Product Owner', 'Santiago Viñas', 'Define y prioriza el Product Backlog; consolida la documentación.'],
  ['Scrum Master', 'Juan Pablo Beracochea', 'Coordina los eventos, hace el seguimiento y destraba lo que se frena.'],
  ['Developers', 'Aaron Britos, Brian Reyes, Sergio Rodríguez', 'Diseñan, desarrollan e implementan los componentes.'],
], [2.2, 3.4, 6.4], 'Todos colaboramos entre áreas cuando hace falta, según lo que necesite cada Sprint.'));
add(H3('22.3 Eventos'));
add(Tabla('eventos', 'Organización de los eventos de Scrum', ['Evento', 'Cuándo', 'Duración', 'Qué queda registrado'], [
  ['Sprint Planning', 'Al empezar el Sprint', '60 min', 'Acta con el objetivo y las tareas'],
  ['Daily', 'Según disponibilidad', '15 min', 'Actualización del tablero'],
  ['Sprint Review', 'Al cerrar el Sprint', '45 min', 'Acta con lo alcanzado'],
  ['Retrospective', 'Después de la Review', '30 min', 'Acta con mejoras para el siguiente'],
], [2.4, 2.6, 1.6, 4]));
add(P('Una aclaración sobre el Daily: como ninguno del equipo tiene dedicación completa al proyecto, no llegamos a hacer una reunión todos los días. Lo resolvemos actualizando el tablero cada uno por su cuenta y con reuniones breves cuando hace falta. Lo dejamos escrito tal cual es, porque poner que hacemos reuniones diarias cuando no las hacemos le quitaría valor a toda la documentación.'));
add(P('Durante el Sprint 1 la coordinación fue asincrónica, sin registro formal de los eventos. Desde el Sprint 2 las decisiones se registran en el acta de decisiones (Anexo F). La devolución de Gestión del Hito 2 pidió fortalecer las actas, el seguimiento de tareas y las evidencias de Scrum; la respuesta está en la sección 22.9 y en el Anexo I.'));
add(H3('22.4 Puesta en común')); v24('s22_4');
add(H3('22.5 Artefactos'));
add(Vineta(['Product Backlog: todas las tareas del proyecto, ordenadas por prioridad. Lo maneja el Product Owner en Trello.', 'Sprint Backlog: las tareas del Sprint en curso, cada una con responsable y fecha.', 'Incremento: lo que queda funcionando al cerrar cada Sprint. Desde el Hito 2, cada incremento entra a la rama principal por pull request, con las pruebas automáticas en verde.']));
add(H3('22.6 Cuándo damos una tarea por terminada'));
add(P('Acordamos que una tarea está terminada cuando cumple estas cinco condiciones:'));
add(Lista(['Funciona como se esperaba.', 'Está documentada.', 'Tiene evidencia: captura, registro de prueba o código.', 'Otro integrante la revisó.', 'Está actualizada en el tablero.']));
add(H3('22.7 Herramientas'));
add(Tabla('herramientas', 'Herramientas utilizadas para la gestión del proyecto', ['Herramienta', 'Para qué'], [
  ['Trello', 'Product Backlog, Sprints y seguimiento de tareas'], ['Miro', 'Diagramas y esquemas del proyecto'],
  ['Google Drive', 'Documentación compartida'], ['Git / GitHub', 'Control de versiones; ramas por funcionalidad y pull requests'],
  ['GitHub Actions', 'Pruebas automáticas en cada pull request (aplicación, análisis, infraestructura y contenedores)'],
  ['Google Forms', 'Formulario de relevamiento'],
], [2.4, 7.6]));
add(H3('22.8 Cómo está organizado el tablero')); v24('s22_8');
add(H3('22.9 Seguimiento y evidencias del trabajo'));
add(P('La devolución de Gestión del Hito 2 observó que las actas y el seguimiento de tareas eran débiles como evidencia. Para que el avance se pueda comprobar sin depender de lo que digamos, cada incremento queda registrado en el repositorio: una rama, un pull request con su descripción, las pruebas automáticas que corrieron y la fecha en que se integró. La {T:prs} resume ese registro, tomado del historial de Git.'));
add(Tabla('prs', 'Incrementos integrados a la rama principal por pull request', ['PR', 'Integrado', 'Contenido'], [
  ['#1 y #2', '29/09/2026', 'Repositorio base: aplicación, scripts SQL, servicio de análisis y documentación de las fases 1 a 8.'],
  ['#3 a #6', '20/10/2026', 'Preparación del Hito 2: habilidades, aprobación configurable, consultas guiadas, decisión docente y pruebas.'],
  ['#7', '22/10/2026', 'Migración de la aplicación a Laravel 12 con el mismo contrato de API (D-1).'],
  ['#8', '22/10/2026', 'Migración 004: cálculos y análisis grupal en PHP; se retiran el trigger y el procedimiento (D-4).'],
  ['#9', '22/10/2026', 'Cierre de documentación y evidencias del Hito 2.'],
  ['#10', '30/10/2026', 'Informe de Testing del Hito 2, corrección de incidencias del laboratorio y script único de pruebas.'],
  ['#11', '01/11/2026', 'Informe de Testing en Word con normas APA.'],
  ['Rama del Hito 3', '12/11/2026', 'Interfaz rediseñada, comprobaciones de la devolución de Base de Datos, métricas, respaldos automáticos, VPN, monitoreo, scripts del DC y este documento (pull request de cierre del Hito 3).'],
], [1.6, 1.8, 8.6], 'Fuente: historial de Git del repositorio del proyecto. Cada pull request ejecuta los cuatro trabajos de GitHub Actions descritos en la sección 31.3.'));
add(P('Las actas de planificación, revisión y retrospectiva siguen el formato del Anexo I, que fija qué se registra en cada reunión: asistentes, objetivo, tareas con responsable y fecha, lo alcanzado con su evidencia y las mejoras acordadas. Ese mismo anexo reúne las devoluciones recibidas en los Hitos 1 y 2 y qué hicimos con cada una, como pidió el cuerpo docente para la entrega final.'));

// 23 ------------------------------------------------------------------------------------------
add(H2('23. Cronograma'));
add(H3('23.1 Hitos'));
add(Tabla('hitos', 'Hitos del proyecto y fechas de entrega', ['Hito', 'Semana', 'Qué se entrega', 'Fecha', 'Estado'], [
  ['1', '7', 'Plan de trabajo consolidado', '18/09/2026', 'Entregado'],
  ['2', '12', 'Prototipo o avance funcional validado', '23/10/2026', 'Entregado (V2.4)'],
  ['3', '16', 'Proyecto consolidado y documentado', '20/11/2026', 'Esta versión'],
], [1, 1.2, 4.6, 1.8, 2.2]));
add(H3('23.2 Sprints'));
add(Tabla('sprints', 'Planificación y resultado de los Sprints', ['Sprint', 'Período', 'Objetivo', 'Resultado'], [
  ['1', '07/09 – 18/09', 'Cerrar el diseño funcional', 'Cumplido: Hito 1.'],
  ['2', '22/09 – 09/10', 'Gestión de actividades y aprobación; base de datos; Linux y Windows integrados', 'Cumplido en desarrollo (PR #1 a #6); integración Linux y Windows en el laboratorio parcial.'],
  ['3', '13/10 – 23/10', 'El estudiante resuelve y queda registro; red segmentada operativa', 'Cumplido: Laravel, migración 004, laboratorio con 14 de 17 pruebas de red (Hito 2).'],
  ['4', '27/10 – 13/11', 'Motor de reglas y panel docente; análisis Python; seguridad perimetral y VPN', 'Cumplido en el repositorio: interfaz nueva, VPN, monitoreo, respaldos automáticos, comprobaciones de BD y métricas.'],
  ['5', '17/11 – 20/11', 'Integración, pruebas y cierre de documentación', 'En curso: ejecución del plan de laboratorio (Anexo J) y entrega del Hito 3.'],
], [1, 2, 4.4, 4.6], 'El asistente conversacional quedó como complemento opcional (D-5); la prueba con la API real de Groq se traslada a la siguiente etapa (sección 32).'));
add(H3('23.3 Riesgos que identificamos'));
add(Tabla('riesgos', 'Riesgos identificados y medidas de mitigación', ['Riesgo', 'Impacto', 'Qué hacemos'], [
  ['Disponibilidad horaria dispar entre nosotros', 'Alto', 'Cada uno tiene su tarea asignada y su fecha, con margen antes de la entrega real.'],
  ['Dependencias entre tutorías (direccionamiento IP, modelo de datos)', 'Medio', 'Definimos esos puntos una sola vez y temprano; quedan en este documento.'],
  ['Llegar a tiempo alternando estudio, trabajo y clases', 'Medio', 'Organización por Sprint y tareas chicas que se cierran por pull request.'],
  ['Pocas respuestas en el relevamiento', 'Medio', 'Ampliarlo en la prueba piloto de la sección 32.'],
  ['Perder trabajo del proyecto', 'Alto', 'Documentación en Drive con historial; código y evidencias en Git; respaldos automáticos del servidor.'],
  ['Laboratorio dependiente de la conexión del iPhone (ICS)', 'Medio', 'Descargas antes de la jornada; ATLAS arranca sin Internet (INC-01); snapshots antes de cada cambio.'],
  ['Poco tiempo para ejecutar en el laboratorio lo implementado en el Hito 3', 'Alto', 'Plan paso a paso con comandos y resultados esperados (Anexo J), repartido entre los cinco integrantes.'],
], [4.2, 1.2, 6.6]));

// 24 ------------------------------------------------------------------------------------------
add(H2('24. Requisitos del sistema'));
add(H3('24.1 Requisitos funcionales'));
add(P('Se conserva la identificación de los requisitos RF-01 a RF-20 y los RF-21 y RF-22 incorporados en el Hito 2 para las habilidades y la decisión del docente. Los criterios de aceptación y la verificación de cada uno al Hito 3 están en el Anexo H.'));
const rf = [
  ['RF-01', 'Registro de usuarios', 'Registrar usuarios con los datos necesarios para su identificación.'],
  ['RF-02', 'Autenticación', 'Iniciar sesión mediante credenciales válidas.'],
  ['RF-03', 'Gestión de roles', 'Diferenciar estudiante, docente y administrador.'],
  ['RF-04', 'Actividades educativas', 'Permitir el acceso de los estudiantes a actividades educativas.'],
  ['RF-05', 'Niveles de dificultad', 'Establecer diferentes niveles de dificultad.'],
  ['RF-06', 'Registro de interacciones', 'Registrar los eventos durante la resolución de actividades.'],
  ['RF-07', 'Registro de resultados', 'Almacenar los resultados de los estudiantes.'],
  ['RF-08', 'Registro de intentos', 'Registrar los intentos de resolución de una actividad.'],
  ['RF-09', 'Registro de tiempo', 'Registrar por separado el tiempo total y el tiempo activo, descontando las pausas.'],
  ['RF-10', 'Perfil de aprendizaje', 'Procesar los datos registrados para describir el desempeño del estudiante.'],
  ['RF-11', 'Panel docente', 'Consultar la evolución y las consultas guiadas por grupo y período.'],
  ['RF-12', 'Recomendaciones', 'Sugerir actividades con reglas y fundamentos consultables.'],
  ['RF-13', 'Estadísticas', 'Consultar estadísticas y reportes.'],
  ['RF-14', 'Gestión administrativa', 'Gestionar usuarios, instituciones y permisos.'],
  ['RF-15', 'Auditoría', 'Registrar accesos y acciones relevantes.'],
  ['RF-16', 'Creación de actividades', 'Crear actividades, preguntas y opciones de respuesta.'],
  ['RF-17', 'Ciclo de aprobación', 'Gestionar estados; permitir publicación directa si la institución no exige aprobación.'],
  ['RF-18', 'Análisis grupal', 'Consultar resultados agregados, dificultades y acierto por habilidad.'],
  ['RF-19', 'Análisis de patrones', 'Agrupamiento experimental mediante ML, condicionado a datos suficientes.'],
  ['RF-20', 'Consulta conversacional', 'Consulta opcional en lenguaje natural sobre datos procesados.'],
  ['RF-21', 'Habilidades', 'Asociar cada pregunta con una o más habilidades e informar aciertos por estudiante y grupo.'],
  ['RF-22', 'Decisión del docente', 'Confirmar o cambiar la siguiente actividad sugerida y registrar la decisión.'],
];
add(Tabla('rf', 'Requisitos funcionales del sistema', ['ID', 'Requisito', 'Descripción'], rf, [1.4, 3, 7.6], 'RF-19 conserva su carácter experimental y RF-20 no es necesario para utilizar las consultas guiadas.'));
add(H3('24.2 Requisitos no funcionales'));
add(P('Los requisitos RNF-01 a RNF-10 son los de la propuesta; RNF-11 a RNF-15 se agregaron porque la rúbrica evalúa aspectos (diseño responsivo, modularidad, independencia de servicios externos) que no tenían un requisito que los respaldara.'));
add(Tabla('rnf', 'Requisitos no funcionales del sistema', ['ID', 'Requisito', 'Descripción'], [
  ['RNF-01', 'Seguridad', 'Autenticación y control de acceso que impidan acceder a información que no corresponde.'],
  ['RNF-02', 'Disponibilidad', 'Plataforma disponible durante los períodos definidos para las pruebas.'],
  ['RNF-03', 'Rendimiento', 'Respuesta dentro de un tiempo aceptable durante las pruebas.'],
  ['RNF-04', 'Respaldo', 'Mecanismos de respaldo y recuperación de información.'],
  ['RNF-05', 'Recuperación', 'Posibilidad de recuperar la información respaldada ante una falla.'],
  ['RNF-06', 'Escalabilidad', 'Incorporar usuarios, actividades y funcionalidades sin rediseñar el sistema.'],
  ['RNF-07', 'Infraestructura', 'Ejecución sobre la infraestructura Linux y Windows definida.'],
  ['RNF-08', 'Segmentación', 'VLAN para separar los tipos de usuarios y los servidores.'],
  ['RNF-09', 'Control de acceso de red', 'Comunicación entre VLAN controlada mediante reglas de seguridad.'],
  ['RNF-10', 'Monitoreo', 'Registrar y monitorear eventos relevantes del sistema y de seguridad.'],
  ['RNF-11', 'Usabilidad', 'Uso por personas sin formación técnica.'],
  ['RNF-12', 'Diseño responsivo', 'Adaptación a escritorio, tableta y celular.'],
  ['RNF-13', 'Mantenibilidad', 'Código modular que otra persona pueda mantener.'],
  ['RNF-14', 'Privacidad', 'Registrar únicamente los datos necesarios para la finalidad.'],
  ['RNF-15', 'Independencia de servicios externos', 'Si el análisis o el modelo de lenguaje no están disponibles, el registro y la consulta siguen funcionando.'],
], [1.4, 3, 7.6]));
add(H3('24.3 De requisito a tarea'));
add(P('Para llevar los requisitos al trabajo concreto usamos este recorrido: requisito → historia de usuario → Product Backlog → Sprint Backlog → tareas → incremento. Un ejemplo con RF-02:'));
add(Tabla('rf02', 'Descomposición del requisito RF-02 en historia de usuario, criterios de aceptación y tareas', ['Elemento', 'Contenido'], [
  ['Requisito', 'RF-02 — Autenticación'],
  ['Historia de usuario', 'Como usuario del sistema quiero iniciar sesión con mis credenciales para acceder a lo que corresponde a mi rol.'],
  ['Criterios de aceptación', 'Con credenciales válidas entra al panel de su rol; con credenciales inválidas ve un error que no revela cuál dato está mal; tras varios intentos fallidos la cuenta se bloquea por un rato.'],
  ['Tareas', 'Diseñar el formulario, implementar la validación, guardar contraseñas con hash Argon2id, redirigir según el rol, registrar el acceso en auditoría.'],
  ['Sprint e incremento', 'Sprint 1; módulo de ingreso funcionando. En el Hito 3 se rediseñó la pantalla sin cambiar el contrato de la API.'],
], [3, 9]));

// 25 ------------------------------------------------------------------------------------------
add(H2('25. Arquitectura en detalle'));
add(P('La sección 11 plantea la arquitectura general. Acá se desarrolla con el detalle necesario para construir, desplegar y mantener el sistema.'));
add(H3('25.1 Las capas'));
add(Figura('arq', 'docs/hito-3/documento/img/arquitectura.png', 'Capas, contenedores y servicios de ATLAS al Hito 3', 'Elaboración propia a partir de atlas/docker-compose.yml, infra/monitoring/docker-compose.yml y los scripts de infra/. Las redes 192.168.250.x/28 son internas de Docker en atlas-srv01; la única dirección publicada hacia las VLAN es 172.16.40.10 (80 y 443).', { maxAlto: 620 }));
add(H3('25.2 Por qué así'));
{
  const pars = require('./fuente-v2.4.json').s25_2;
  pars.slice(0, 6).forEach((p) => add(P(p)));
  add(P(pars[6] + ' ' + pars[7]));
}
add(P('Monitoreo separado. Zabbix corre en un proyecto de contenedores aparte, con su propia base en una red interna. Si el monitoreo se detiene o se actualiza, ATLAS no se entera; y si ATLAS se cae, el monitoreo lo registra. La interfaz de Zabbix no se publica en ninguna VLAN: se entra con un túnel SSH desde Gestión, como el resto de la administración (DEC-19).'));
add(H3('25.3 El flujo, paso a paso'));
add(Consola([
  'DOCENTE: crea actividad, preguntas, opciones y habilidades → BORRADOR',
  '   ¿La institución exige aprobación?',
  '     No → publicación directa en sus grupos      Sí → PENDIENTE → APROBADA / RECHAZADA',
  '   → PUBLICADA',
  'ESTUDIANTE: resuelve una pregunta por vez (teclas 1 a 9, avance y retroceso)',
  '   → registro por lotes de respuestas, eventos, pausas, tiempos e intentos',
  '   → el servidor pone inicio y fin, calcula el puntaje una sola vez y guarda el resultado',
  'PHP: indicadores y reglas explicables (R01 a R08)',
  'DOCENTE: ve el grupo, quién requiere atención y por qué; confirma o cambia la actividad sugerida',
  'ESTUDIANTE: ve la actividad «Recomendada por tu docente»',
]));
v24('s25_3b');
add(H3('25.4 El motor de análisis'));
{
  const pars = require('./fuente-v2.4.json').s25_4;
  pars.forEach((p, i) => {
    if (p.startsWith('Estado del Hito 2.')) {
      add(P('Estado al Hito 3. El servicio Python tiene sus pruebas automáticas (sección 31.3) y la anonimización está implementada. La conexión con la API real de Groq sigue sin probarse porque requiere una clave, que no se guarda en el repositorio; no se presenta esa integración como validada y pasa a la siguiente etapa (sección 32).'));
    } else add(P(p.replace('Para el Hito 2 se incorpora', 'Desde el Hito 2 se incluye').replace('En el Hito 2 se consideran experimentales.', 'Se mantienen como experimentales.').replace('En el Hito 2, la', 'La')));
  });
}
add(H3('25.5 Contenedores y despliegue'));
v24('s25_5');
add(Tabla('contenedores', 'Contenedores de ATLAS y del monitoreo en atlas-srv01', ['Contenedor', 'Imagen base', 'Función', 'Red y puertos'], [
  ['atlas-web', 'nginx:alpine', 'Servidor web: interfaz y proxy hacia la aplicación', 'atlas_front; publica 80 y 443 en 172.16.40.10'],
  ['atlas-php', 'php:8.3-fpm', 'Aplicación PHP con Laravel 12', 'atlas_front y atlas_back; interno'],
  ['atlas-db', 'mysql:8.0', 'Base de datos (binlog para el incremental)', 'atlas_back, interna; 3306 sin publicar'],
  ['atlas-analysis', 'python:3.11-slim', 'Análisis adicional y ML experimental', 'atlas_back y atlas_egress; interno'],
  ['zabbix-db', 'mysql:8.0', 'Base del monitoreo', 'zbx_back, interna'],
  ['zabbix-server', 'zabbix-server-mysql 7.0 LTS', 'Consulta agentes y prueba la salud de ATLAS', 'zbx_back y zbx_front; interno'],
  ['zabbix-web', 'zabbix-web-nginx-mysql 7.0 LTS', 'Interfaz del monitoreo', 'solo 127.0.0.1:8080 (túnel SSH)'],
  ['zabbix-agent', 'zabbix-agent2 7.0 LTS', 'Agente de srv01 (CPU, memoria, disco)', 'red del host; 10050 solo desde 192.168.250.64/28'],
], [2.2, 3, 3.8, 3]));
add(P('Los contenedores se definen con Docker Compose (Docker, s. f.). ATLAS arranca con atlas.service sin construir imágenes ni consultar Docker Hub (INC-01, E-TST-003): después de un corte de luz, el servidor vuelve a funcionar aunque no haya Internet. Las imágenes se reconstruyen solo a pedido, con sudo atlas-ctl reconstruir.'));
add(Salto());
