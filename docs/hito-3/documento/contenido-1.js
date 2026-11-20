// Portada, control de versiones, índice y Parte I (secciones 1 a 18).
const L = require('./lib');
const { add, P, PSin, Centro, H1, H2, H3, Vineta, Lista, Salto, Vacio, Tabla, Logo, Consola } = L;
const V24 = require('./fuente-v2.4.json');
const R = require('./resultados');

// Párrafos de la V2.4 tal como están (las viñetas «•» pasan a lista con viñetas).
function v24(clave, { saltear = [] } = {}) {
  const pars = V24[clave].filter((_, i) => !saltear.includes(i));
  let vin = [];
  const volcar = () => { if (vin.length) { add(Vineta(vin)); vin = []; } };
  for (const p of pars) {
    if (p.startsWith('•')) vin.push(p.replace(/^•\s*/, ''));
    else { volcar(); add(P(p)); }
  }
  volcar();
}
module.exports.v24 = v24;

// --- Portada ----------------------------------------------------------------------------------
add(Vacio(), Logo('atlas/public/assets/logotipo.png', 230), Vacio());
add(Centro('**ATLAS**'), Centro('**Plataforma Inteligente de Aprendizaje Adaptativo**'));
add(Centro('Documento integrador - Versión 3.2'), Centro('Hito 3: Proyecto consolidado y documentado'), Vacio());
add(Centro('Grupo Error404'));
for (const n of ['Santiago Emanuel Viñas Rezzano', 'Juan Pablo Beracochea Cabrera', 'Aaron Britos Alonso']) add(Centro(n, { simple: true }));
add(Vacio(), Centro('Instituto Tecnológico de Informática - ITI-CETP/UTU'), Centro('Tecnicatura en Redes y Software - Clase TC4'), Centro('Proyecto Final de Egreso'));
add(Centro('Cuerpo docente: E. Valles, M. Viar'));
add(Centro(`Actualización: ${R.fechaDocumento}`), Centro('Entrega del Hito 3: 20 de noviembre de 2026'));
add(Salto());

// --- Control de versiones -----------------------------------------------------------------------
add(H1('Control de versiones'));
add(Tabla('versiones', 'Control de versiones del documento', ['Versión / fecha', 'Responsable', 'Cambios'], [
  ['V1 · 01/09/2026', 'Equipo Error404', 'Propuesta: problema, objetivos, alcance, límites y requisitos.'],
  ['V2 · 17/09/2026', 'S. Viñas', 'Relevamiento, criterios de verificación, metodología, cronograma, plan por tutoría y avance inicial.'],
  ['V2.1 · 18/09/2026', 'J. P. Beracochea', 'Correcciones de comunicación entre VLAN y firewall; servicios de dominio, Samba, DHCP e Internet. Puertos del switch, VLAN nativa y de gestión, inventario, entorno de implementación, VPN por perfil y plan de pruebas.'],
  ['V2.2 · 18/09/2026', 'J. P. Beracochea y S. Viñas', 'Resultados del relevamiento, formulario en el Anexo A, especificación IEEE 830 en el Anexo H y referencias. Separación entre diseño e implementación.'],
  ['V2.3 · 22/10/2026', 'Equipo Error404', 'Actualización para el Hito 2: Laravel 12, publicación configurable, habilidades, cálculos en PHP, consultas guiadas, decisión docente y tiempo activo.'],
  ['V2.4 · 23/10/2026', 'Equipo Error404', 'Integración del informe de Redes: laboratorio Proxmox, firewall, pruebas, evidencias Windows/Linux, restauración y pendientes.'],
  ['V3.0 · 12/11/2026', 'Equipo Error404', 'Hito 3: respuesta a las devoluciones del Hito 2 (Gestión y Base de Datos); interfaz rediseñada con el logotipo; seguimiento de un intento de punta a punta, comparación de puntajes y restauración por intento; respaldos automáticos con copia al DC y retención; VPN por perfiles; monitoreo con Zabbix; métricas de verificación (sección 31.4); plan de laboratorio (Anexo J); planificación de los semestres siguientes (sección 32); anexo de devoluciones (Anexo I).'],
  ['V3.1 · 20/11/2026', 'Equipo Error404', 'Resultados de la jornada de laboratorio del 19/11/2026: circuito completo docente-estudiante, prueba 7 con su registro, seguimiento del intento, restauración por intento, métricas y respaldo de la VM en el servidor real; verificaciones de srv01, del DC y del firewall. Las capturas de desarrollo se reemplazaron por las del laboratorio donde las había.'],
  [`V3.2 · ${R.fechaCorta}`, 'Equipo Error404', 'Resultados de la segunda jornada de laboratorio (20/11/2026): VPN con un cliente real y pruebas 14, 15 y 16; Zabbix en srv01 con los dos agentes, la alerta probada y el SLA; Fase 12 del DC y su verificador sin FAIL; incidencias INC-18 a INC-20.'],
], [2.2, 2.4, 7.4], 'Las versiones anteriores se conservan en el historial del equipo. Desde la V3.0 cada resultado indica su entorno (desarrollo o laboratorio) y su evidencia; lo que todavía no se ejecutó en el laboratorio figura como *No ejecutada*, con su motivo.'));
add(P('Esta edición consolida el proyecto al cierre del primer año. Reúne la propuesta, el plan de trabajo, el diseño vigente y lo implementado, y deja preparada la continuidad para los semestres siguientes. Mantiene la regla de las versiones anteriores: se separa lo diseñado, lo configurado, lo ejecutado y lo verificado, y no se presenta como aprobado nada que no se haya corrido.'));
add(Salto());

// --- Índice -----------------------------------------------------------------------------------
add(H1('Índice'));
const indice = [
  '**Parte I - Propuesta y precisiones del Hito 3**',
  '1. Problema', '2. Propuesta', '3. Objetivo general', '4. Objetivos específicos', '5. Funcionalidades principales',
  '6. Inteligencia del sistema', '7. Base de datos', '8. Linux / POSIX', '9. Windows / Microsoft', '10. Redes y seguridad',
  '11. Arquitectura', '12. Métricas para demostrar resultados', '13. Impacto', '14. Proyección futura', '15. Metodología',
  '16. Resultado esperado', '17. Alcance del proyecto', '18. Límites del proyecto',
  '**Parte II - Plan de trabajo, implementación y estado**',
  '19. El equipo', '20. Relevamiento', '21. Criterios de verificación de los objetivos', '22. Cómo trabajamos', '23. Cronograma',
  '24. Requisitos del sistema', '25. Arquitectura en detalle', '26. Programación', '27. Base de datos', '28. Linux / POSIX',
  '29. Windows / Microsoft', '30. Redes y seguridad', '31. Estado del proyecto al Hito 3', '32. Continuidad: plan para los semestres siguientes',
  '33. Referencias', '34. Anexos',
  '**Anexos**',
  'A. Formulario y resultados del relevamiento', 'B. Evidencias de programación', 'C. Evidencias del servidor Linux',
  'D. Evidencias de Windows y dominio', 'E. Implementación y verificación del laboratorio Proxmox (informe de Redes del Hito 2)',
  'F. Decisiones del proyecto', 'G. Evidencias de base de datos', 'H. Especificación de requisitos de software (versión 1.2)',
  'I. Devoluciones de los hitos anteriores y respuesta del equipo', 'J. Plan de trabajo de Redes en el laboratorio (Hito 3)',
  'K. Índice de evidencias del Hito 3',
];
for (const l of indice) add(PSin(l));
add(Salto());

// --- Parte I ------------------------------------------------------------------------------------
add(H1('Parte I - Propuesta'));
add(P('Las secciones 1 a 18 provienen de la propuesta entregada el 1 de septiembre de 2026, con las precisiones del Hito 2 sobre las variables registradas, la intervención del docente y la arquitectura (Equipo Error404, 2026a). En esta versión se actualiza el estado de lo implementado en las secciones 8 a 12; el resto mantiene su alcance original.'));

add(H2('1. Problema')); v24('s01');
add(H2('2. Propuesta')); v24('s02');
add(H2('3. Objetivo general')); v24('s03');
add(H2('4. Objetivos específicos'));
add(Lista([
  'Desarrollar una plataforma web con usuarios, roles y autenticación.', 'Crear actividades educativas interactivas.',
  'Registrar las interacciones de los estudiantes.', 'Diseñar una base de datos para almacenar y relacionar los datos obtenidos.',
  'Implementar algoritmos de análisis para detectar patrones de aprendizaje.', 'Generar perfiles y recomendaciones para docentes.',
  'Implementar mecanismos de seguridad y control de acceso.', 'Implementar una infraestructura Linux y Windows para el funcionamiento del sistema.',
  'Diseñar una red segmentada mediante VLAN.', 'Implementar firewall, VPN y mecanismos de monitoreo.',
  'Implementar políticas de respaldo y recuperación.', 'Evaluar el funcionamiento del prototipo mediante métricas objetivas.',
]));
add(H2('5. Funcionalidades principales'));
{
  const ps = V24.s05;
  let vin = [];
  for (const p of ps) {
    if (p.startsWith('•')) vin.push(p.replace(/^•\s*/, ''));
    else { if (vin.length) { add(Vineta(vin)); vin = []; } add(H3(p)); }
  }
  if (vin.length) add(Vineta(vin));
}
add(H2('6. Inteligencia del sistema')); v24('s06');
add(P('El enfoque se inscribe en la analítica del aprendizaje, que mide, recopila y analiza datos sobre los estudiantes y sus contextos para comprender y mejorar el aprendizaje (Society for Learning Analytics Research, 2025).'));

add(H2('7. Base de datos'));
add(P('La base almacena información de estudiantes, docentes, instituciones, actividades, preguntas, habilidades, resultados, intentos, tiempos, eventos, perfiles, recomendaciones, decisiones docentes, usuarios, roles, permisos, auditoría y respaldos. Los privilegios diferenciados limitan el acceso según la función de cada cuenta técnica.'));
add(P('Los cálculos se realizan en PHP; MySQL almacena los resultados y aplica las restricciones de integridad. En el Hito 3 se siguió un intento desde la pantalla del estudiante hasta la base y el informe docente, se comparó el puntaje guardado con el calculado y se restauró un intento por su identificador (sección 27.7). La cuenta de respaldo anota cada copia en registro_respaldos.'));

add(H2('8. Linux / POSIX'));
add(P('El servidor atlas-srv01 ejecuta ATLAS en contenedores sobre Ubuntu Server 24.04.5 (Canonical, s. f.) en el laboratorio Proxmox. En el Hito 2 se ejecutaron los pasos 1 a 7 del instalador y se comprobaron el acceso HTTPS, el aislamiento de MySQL y la administración SSH con clave desde Gestión. Para el Hito 3 el instalador suma dos pasos: respaldos automáticos con copia al controlador de dominio (paso 13) y monitoreo con Zabbix (paso 14). Los dos se probaron en desarrollo. En el laboratorio se corrió el paso 14 el 20/11/2026 y la verificación pasó a 93 PASS y 24 FAIL: la base del servidor y el monitoreo están completos, y los FAIL corresponden a los pasos 8 a 13, que todavía no se corrieron (sección 28.6).'));
add(H2('9. Windows / Microsoft'));
add(P('atlas-dc01 funciona con Windows Server 2022 (Microsoft, s. f.) como controlador de atlas.local con DNS, DHCP, políticas de grupo, recursos compartidos y la CA ATLAS-CA. El cliente DOC-PC01 recibió su configuración por relay DHCP, se unió al dominio y aplicó GPO_Docentes. Para el Hito 3 se agregan la tarea que aplica la retención de las copias de respaldo en \\\\atlas-dc01\\atlas-backups y el agente de monitoreo; las dos se instalaron en el DC el 20/11/2026, y el verificador dio 73 PASS y 0 FAIL (sección 29.6).'));

add(H2('10. Redes y seguridad'));
add(P('El laboratorio integra cuatro máquinas virtuales y cinco VLAN. router-lab concentra el enrutamiento, el filtrado nftables, el relay DHCP y el NAT. La sección 30 documenta la topología, los resultados del Hito 2 y lo que se agrega en el Hito 3.'));
add(Tabla('vlan', 'Distribución de VLAN por área', ['VLAN', 'Área'], [['10', 'Administración'], ['20', 'Docentes'], ['30', 'Estudiantes'], ['40', 'Servidores'], ['50', 'Gestión']], [1, 4]));
add(P(`El laboratorio dispone de segmentación, firewall con estado, NAT de salida y registro de bloqueos; en el Hito 2 se ejecutaron 14 de 17 pruebas de red con los resultados esperados. Para el Hito 3 se implementaron la VPN WireGuard con los dos perfiles de la {T:vpn} y el monitoreo centralizado. Las reglas de la VPN se probaron con tráfico real en un gemelo del router (${R.gemeloVpn}) y el monitoreo con Zabbix real en desarrollo (${R.monitoreo}). En el laboratorio, el 20/11/2026, se probó el túnel del perfil docente desde la PC: con la VPN el docente llega a ATLAS y no al SSH del servidor, y sin la VPN nadie entra desde afuera. Con eso, las 17 pruebas de red del plan del Hito 2 quedan ejecutadas. Zabbix quedó funcionando en srv01 con los agentes de los dos servidores.`));

add(H2('11. Arquitectura'));
add(P('La solución mantiene una arquitectura cliente-servidor. El recorrido de la aplicación es el siguiente:'));
add(Consola([
  'Usuarios: administrador, docente y estudiante',
  '  | HTTPS',
  'Nginx: interfaz web (HTML, CSS y JavaScript) y acceso a la aplicación',
  '  | API REST / JSON',
  'PHP 8.3 + Laravel 12: middleware, controladores, servicios y repositorios',
  '  |',
  'MySQL 8.0                       Servicio adicional: Python / análisis experimental',
  'Despliegue: contenedores Docker en atlas-srv01 (VLAN 40)',
  'Monitoreo: Zabbix 7.0 LTS en contenedores aparte, agentes en srv01 y dc01',
  'Red: VLAN, firewall nftables, NAT de salida y VPN WireGuard por perfil',
]));
add(P('La aplicación se verificó en desarrollo con pruebas unitarias, de API, de base de datos y de interfaz. En el laboratorio, el circuito docente-estudiante quedó incompleto en el Hito 2 por el rechazo de publicación con HTTP 422; la causa se corrigió en la interfaz (INC-09) y el 19/11/2026 el circuito se ejecutó completo en el laboratorio: el docente creó y publicó, el estudiante resolvió desde la VLAN 30, quedó todo registrado y el docente vio los indicadores (sección 26.6).'));

add(H2('12. Métricas para demostrar resultados'));
add(P('El proyecto se evalúa con resultados medibles y no solo por «funcionar». Las métricas previstas en la propuesta son:'));
add(Vineta(['Tiempo de respuesta de la plataforma.', 'Disponibilidad del sistema.', 'Porcentaje de actividades correctamente registradas.', 'Precisión de las recomendaciones.', 'Tiempo de recuperación ante fallos.', 'Porcentaje de respaldos exitosos.', 'Detección de eventos de seguridad.', 'Rendimiento de la infraestructura.']));
add(P('En el Hito 3 cada una tiene una forma concreta de medirse: once métricas salen de la base de datos (metricas.sh) y las demás de herramientas específicas (medición de tiempos, disponibilidad, restauración, Zabbix y registros del firewall). La sección 31.4 presenta la definición, la meta y el valor medido de cada una, en desarrollo y, para las once de la base, también en el servidor del laboratorio.'));

add(H2('13. Impacto')); v24('s13');
add(H2('14. Proyección futura')); v24('s14');
add(P('La sección 32 baja esta proyección a un plan concreto para los semestres siguientes, hasta la entrega final al término de los dos años.'));
add(H2('15. Metodología'));
add(P('El proyecto se desarrolla con Scrum (la elección frente a Kanban se fundamenta en la sección 22.1). El desarrollo se dividió en estas etapas:'));
add(Lista(['Investigación y definición del problema.', 'Diseño de arquitectura y base de datos.', 'Desarrollo del frontend y backend.', 'Desarrollo de actividades educativas.', 'Implementación del análisis de datos.', 'Implementación de Linux, Windows y redes.', 'Seguridad, VPN, firewall y monitoreo.', 'Integración.', 'Pruebas y validación.', 'Documentación y presentación.']));
add(P('La rúbrica exige que la metodología elegida, sus roles, eventos y herramientas queden documentados; eso se desarrolla en la sección 22.'));
add(H2('16. Resultado esperado')); v24('s16');
add(H2('17. Alcance del proyecto')); v24('s17');
add(H2('18. Límites del proyecto (restricciones y exclusiones)')); v24('s18');
add(Salto());
