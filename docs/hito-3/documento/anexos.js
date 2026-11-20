// Anexos A a K.
const L = require('./lib');
const { add, P, PSin, H1, H2, H3, Vineta, Salto, Tabla, Figura, Consola } = L;
const V24 = require('./fuente-v2.4.json');
const R = require('./resultados');
const C = 'docs/evidencias/B/capturas/hito3/';
const LAB = 'docs/hito-3/capturas/';

// A -------------------------------------------------------------------------------------------
add(H1('Anexo A'));
add(PSin('**Formulario y resultados del relevamiento**'));
add(P('El relevamiento se administró mediante Google Forms entre el 9 y el 18 de septiembre de 2026 a docentes de primaria, educación especial, secundaria, UTU y terciario, y obtuvo cuatro respuestas. Las preguntas se agrupan según los objetivos de la {T:relev}; el análisis está en la sección 20.4. El formulario y los gráficos de resultados de cada pregunta (figuras 2 a 5 de la versión 2.4) se conservan sin cambios en esta edición.'));
add(Salto());

// B -------------------------------------------------------------------------------------------
add(H1('Anexo B'));
add(PSin('**Evidencias de programación**'));
add(Tabla(null, 'Resultados de las pruebas de programación', ['Código', 'Prueba', 'Resultado', 'Archivo'], [
  ['E-APP-007', 'Unitarias PHP, incluidas rutas Laravel (Hito 2)', '37/37', 'B/E-APP-007-tests-unitarios-hito2.txt'],
  ['E-APP-008', 'API a través de Laravel y MySQL real (Hito 2)', '71/71', 'B/E-APP-008-tests-api-hito2.txt'],
  ['E-APP-009', 'Interfaz en Chromium, cinco anchos (Hito 2)', '27/27', 'B/E-APP-009-interfaz-hito2.txt'],
  ['E-APP-010', 'Convención PSR-12 (Hito 2)', '0 errores', 'B/E-APP-010-psr12-hito2.txt'],
  ['E-APP-011', 'Cierre de sesión con concurrencia', '5/16 sin bloqueo; 0/16 con bloqueo', 'B/E-APP-011-sesion-concurrente-logout.txt'],
  ['E-APP-012', 'Servicio Python (Hito 2)', '23/23', 'B/E-APP-012-tests-analisis-hito2.txt'],
  ['E-APP-015', 'Interfaz nueva del Hito 3: tres roles, cinco anchos, CSP y errores de JavaScript', '29/29', 'B/E-APP-015-interfaz-hito3.txt y B/capturas/hito3/'],
  ['E-TST-010', 'Corrida completa de probar-todo.sh (Hito 3)', 'Sección 31.3', 'H/E-TST-010-ejecucion-2026-11-12/'],
], [1.6, 4.8, 2.4, 3.2], 'Rutas relativas a docs/evidencias/. Los resultados corresponden al entorno de desarrollo.', 'Tabla B1'));
add(Tabla(null, 'Aplicación en atlas-srv01 (laboratorio)', ['Código', 'Resultado y alcance'], [
  ['E-APP-013', 'Hito 2: estado documentado con docker ps y systemctl, porque atlas-ctl no estaba instalado (INC-08, corregido). En el Hito 3 se repite con atlas-ctl estado y salud (R-3).'],
  ['E-APP-014', 'Hito 2: incompleta (acceso, usuarios, grupo y borrador; publicación rechazada con 422). Hito 3, 19/11/2026: circuito completo ejecutado. El docente creó y publicó, el estudiante resolvió desde la VLAN 30, el docente vio los indicadores y la auditoría registró todo (sección 26.6; capturas H3-49 a H3-69, salvo la 59 y la 60, que no se tomaron).'],
], [2, 10], 'El resultado de desarrollo no reemplaza la prueba del mismo circuito en el laboratorio. Las capturas del laboratorio están en docs/hito-3/capturas/.', 'Tabla B2'));
add(Figura(null, C + 'docente-sin-grupo-1024.png', 'Aviso al docente sin grupo asignado: la causa del 422 del laboratorio', 'Captura de E-APP-015. El botón de publicar queda deshabilitado y el aviso explica qué falta (INC-09).', { etiqueta: 'Figura B1', maxAlto: 480 }));
add(Figura(null, LAB + 'H3-52-app-editor.png', 'Editor de actividades en el laboratorio, con la habilidad de la pregunta y la opción correcta', 'Captura H3-52, cliente-doc, 19/11/2026, 20:07. «Actividad de prueba 2»: nivel Básico, categoría Atención, una pregunta que mide Cálculo y la opción B marcada como correcta (D-3, RF-21). La actividad empieza con una sola pregunta; las demás se agregan con «Agregar pregunta».', { etiqueta: 'Figura B2', maxAlto: 560 }));
add(Figura(null, LAB + 'H3-63-app-docente-estudiante.png', 'Perfil de Matias Perez visto por el docente', 'Captura H3-63, 19/11/2026, 20:33. Dos actividades con datos, puntaje promedio y último puntaje de 100 y tres recomendaciones; la evolución baja a 0 y vuelve a 100; el acierto en Cálculo es del 100 % (2 de 2). Arriba, el aviso de que los indicadores describen el proceso y no diagnostican ni etiquetan (D-6, D-8).', { etiqueta: 'Figura B3', maxAlto: 560 }));
add(Figura(null, LAB + 'H3-61-app-estudiante-resultado.png', 'Resultado que ve el estudiante al terminar, con tiempo total y tiempo activo', 'Captura H3-61, cliente-doc en la VLAN 30, 19/11/2026, 20:27. 100 de 100, 1 de 1 respuestas correctas, tiempo total de 3 s y tiempo activo de 3 s (D-8, RF-09).', { etiqueta: 'Figura B4', maxAlto: 520 }));
add(Figura(null, C + 'admin-reglas-768.png', 'Coordinación: reglas de análisis con sus parámetros', 'Captura de E-APP-015 en una tableta (768 píxeles).', { etiqueta: 'Figura B5', maxAlto: 560 }));
add(Figura(null, LAB + 'H3-49-app-ingreso.png', 'Pantalla de ingreso de ATLAS en el laboratorio', 'Captura H3-49, cliente-doc, 19/11/2026, 19:57. Logotipo, presentación del sistema y aviso de que tres intentos fallidos bloquean el acceso por unos minutos. El aviso «No seguro» del navegador se debe a que el certificado firmado por ATLAS-CA todavía no se instaló (paso R-4).', { etiqueta: 'Figura B6', maxAlto: 460 }));
add(Figura(null, LAB + 'H3-68-app-tema-oscuro.png', 'Inicio del docente en tema oscuro', 'Captura H3-68, 19/11/2026, 20:00. Es la misma pantalla de la {F:fDocente} después de tocar el botón del tema.', { etiqueta: 'Figura B7', maxAlto: 460 }));
add(Figura(null, LAB + 'H3-58-app-estudiante-inicio.png', 'Inicio del estudiante con la próxima actividad destacada', 'Captura H3-58, cliente-doc en la VLAN 30, 19/11/2026, 20:26. Matias Perez ve «Actividad de prueba 3» como próxima actividad y, debajo, la que ya resolvió el 12/11, con su último resultado (100/100) y la opción de intentar de nuevo.', { etiqueta: 'Figura B8', maxAlto: 460 }));
add(Figura(null, LAB + 'H3-50-app-coordinacion-grupos.png', 'Coordinación: grupos del año y sus integrantes', 'Captura H3-50, 19/11/2026, 19:59. Grupos «Docentes» y «Grupo 1» de 2026 en el Instituto Tecnológico de Informática. En los miembros de Grupo 1 aparecen Juan Fernandez (docente) y Matias Perez (estudiante); la pantalla recuerda que un docente solo puede publicar en los grupos de los que es miembro, la regla que explica el 422 del Hito 2.', { etiqueta: 'Figura B9', maxAlto: 460 }));
add(Salto());

// C -------------------------------------------------------------------------------------------
add(H1('Anexo C'));
add(PSin('**Evidencias del servidor Linux**'));
add(Tabla(null, 'Evidencias del servidor Linux', ['Código', 'Contenido', 'Entorno y resultado'], [
  ['E-LNX-001', 'Scripts de srv01 en Ubuntu 24.04 real (Hito 1)', 'Contenedor privilegiado'],
  ['E-LNX-003 / 004', 'Configuración y despliegue con Laravel', 'Linux de prueba'],
  ['E-LNX-005', 'Scripts de srv01 en Ubuntu 24.04 real, Hito 3, con la regla 10050 del agente', 'Contenedor privilegiado; único FAIL esperado (smbd sin systemd)'],
  ['probar-respaldos.sh', 'Respaldo completo, incremental, configuración, anotación, verificación y restauración', 'MySQL 8.0 real; 17 de 17 (E-TST-010)'],
  ['E-RED-012', 'Paso 14 corrido de punta a punta, con el chequeo de ATLAS por la IP del servidor', 'Desarrollo; solo falla atlas-dc01 (sin Windows)'],
  ['E-LNX-006', 'verificar.sh completo en srv01, 20/11/2026', 'Laboratorio: 86 PASS y 31 FAIL el 19/11; después del paso 14, 93 PASS y 24 FAIL, y monitoreo y firewall 23 de 23 (sección 28.6)'],
  ['E-LNX-007', 'Respaldos con copia al DC en srv01', 'Laboratorio: *No ejecutada* (R-5)'],
], [2.4, 5.8, 3.8], 'Archivos en docs/evidencias/C/ y E/. Las figuras E61 a E86 del Anexo E documentan la instalación de srv01 en el Hito 2.', 'Tabla C1'));
add(Salto());

// D -------------------------------------------------------------------------------------------
add(H1('Anexo D'));
add(PSin('**Evidencias de Windows y dominio**'));
add(Tabla(null, 'Evidencias del cliente y del controlador', ['Código / captura', 'Contenido', 'Alcance'], [
  ['E-WIN-003a / E56', 'ipconfig /all del cliente', 'Dirección y opciones del DHCP del DC por relay.'],
  ['E-WIN-003b / E60', 'gpresult /r', 'DOC-PC01 en el dominio, GPO_Docentes y GG_Docentes.'],
  ['E49 a E51', 'Verificador y revisión manual del DC', '63 PASS y 5 FAIL falsos (INC-06, INC-07).'],
  ['E-WIN-004', 'Módulo y scripts del DC con PowerShell 7, Hito 3', '52 de 52: retención, sintaxis de los 19 scripts y codificación.'],
  ['E-WIN-005', 'Verificador del DC, 20/11/2026', '19/11: 63 PASS y 5 FAIL, con el script viejo. 20/11, con los scripts nuevos: 73 PASS y 0 FAIL (sección 29.6).'],
  ['E-WIN-006', 'Retención y agente de Zabbix instalados en el DC, 20/11/2026', 'Tarea programada lista; la simulación falló con la carpeta vacía (INC-18, corregida). Agente con firma válida, respondiendo a Zabbix.'],
  ['H3-55', 'ipconfig de cliente-doc en la VLAN 30', '172.16.30.100/24, puerta 172.16.30.1 y sufijo atlas.local, entregados por el DHCP del DC a través del relay.'],
], [2.6, 4, 5.4], null, 'Tabla D1'));
add(Figura(null, LAB + 'H3-55-cliente-vlan30.png', 'cliente-doc en la VLAN 30 después de renovar la dirección', 'Captura H3-55, sesión de prueba.docente, 19/11/2026, 20:15. Después de ipconfig /release y /renew, el equipo recibe 172.16.30.100 con máscara 255.255.255.0, puerta de enlace 172.16.30.1 y sufijo atlas.local: el ámbito de la VLAN 30 del DHCP del DC, por el relay de router-lab.', { etiqueta: 'Figura D1', maxAlto: 480 }));
add(Salto());

// E -------------------------------------------------------------------------------------------
add(H1('Anexo E'));
add(PSin('**Implementación y verificación del laboratorio Proxmox**'));
add(P('Este anexo es el informe de Redes del Hito 2 (Santiago, 2026), con sus 109 figuras (E1 a E109), el detalle de las dos jornadas de laboratorio, las incidencias y las pruebas. Se incorpora completo y sin cambios a continuación de los anexos de este documento, con su propia portada y numeración de páginas. Las referencias del cuerpo del documento a figuras «E» corresponden a ese informe. Las evidencias de redes del Hito 3 (gemelo con VPN y monitoreo) están en el Anexo K.'));
add(Salto());

// F -------------------------------------------------------------------------------------------
add(H1('Anexo F'));
add(PSin('**Decisiones del proyecto**'));
add(P('Las decisiones D-1 a D-8 constan en el acta docs/evidencias/F/acta_tesis y responden a la devolución de Programación del Hito 1. Las decisiones de infraestructura (DEC y CT) están en docs/fase-02-arquitectura/01-registro-decisiones.md; se listan las que se aplicaron en el Hito 3.'));
add(Tabla(null, 'Decisiones vigentes', ['ID', 'Decisión', 'Aplicación'], [
  ['D-1', 'Laravel 12 para HTTP; lógica de negocio propia reutilizada', 'Migración del Hito 2; interfaz nueva del Hito 3 sin cambiar la API.'],
  ['D-2', 'Aprobación configurable por institución, desactivada por defecto', 'Publicación directa con la transición registrada.'],
  ['D-3', 'Habilidades vinculadas a preguntas', 'Acierto por habilidad por estudiante y grupo; M7.'],
  ['D-4', 'Cálculos en PHP; la base guarda y protege', 'Migración 004; comparación de puntajes (E-BD-017).'],
  ['D-5', 'Consultas guiadas como vía principal', 'Pantalla Consultas; asistente opcional.'],
  ['D-6', 'El sistema sugiere y el docente decide', 'Decisión registrada; M6.'],
  ['D-7', 'Reglas explicables; ML experimental', 'R01 a R08; ML con «datos insuficientes».'],
  ['D-8', 'Tiempo activo aparte del total; nada sobre memoria o atención', 'Pausas de más de 60 s; resultado con los dos tiempos.'],
  ['DEC-09', 'El incremental también se copia a Windows; la cuenta crea pero no borra (CT-05); retención en el DC', 'Pasos 13 de srv01 y 13 del DC.'],
  ['DEC-19', 'Monitoreo con Zabbix en contenedores de srv01; interfaz solo por túnel SSH desde Gestión', 'Paso 14 y agente del DC.'],
  ['DEC-20', 'Certificado de ATLAS firmado por ATLAS-CA con la IP en el SAN (para la VPN)', 'Paso R-4.'],
], [1.4, 5.6, 5], null, 'Tabla F1'));
add(Salto());

// G -------------------------------------------------------------------------------------------
add(H1('Anexo G'));
add(PSin('**Evidencias de base de datos**'));
add(Tabla(null, 'Verificaciones de base de datos en desarrollo (Hito 2)', ['Código', 'Verificación', 'Resultado'], [
  ['E-BD-007', 'Base de datos con migración 004', '58/58 pruebas'],
  ['E-BD-008', 'Datos representativos, consultas y 3FN', '0 inconsistencias sobre 8.749 resultados'],
  ['E-BD-009', 'Restauración en desarrollo', 'RPO 0, sin diferencias ni huérfanos'],
  ['E-BD-010', 'Privilegios con migración 004', 'Según la tabla de privilegios'],
], [2, 5.4, 4.6], null, 'Tabla G1'));
add(Tabla(null, 'Verificaciones en el laboratorio', ['Código', 'Resultado', 'Estado'], [
  ['E-BD-013', 'Conteos de tablas antes del circuito (intentos en 0, Hito 2); después del circuito, en E-BD-020: 5 usuarios, 3 intentos, 3 resultados, 12 interacciones y 78 registros de auditoría', 'Ejecutada (19/11)'],
  ['E-BD-014', 'Volcado de 78 KB y restauración en base aparte; usuarios 3/3 (Hito 2)', 'Acotada; la reemplaza E-BD-020'],
  ['E-BD-015', `Respaldo de la VM 130 con vzdump (${R.lab.vzdump}) y restauración como VM 930 en ${R.lab.qmrestore}; en la copia sin red, atlas-web se reinicia`, 'Ejecutada (19/11); ver figuras G3 y G4'],
  ['E-BD-019', `Seguimiento del intento en srv01: ${R.lab.seguir}`, 'Aprobada, sin cambio de respuesta en el intento'],
  ['E-BD-020', `Restauración por intento en srv01: ${R.lab.restauracion}`, 'Aprobada'],
  ['E-BD-021', `Métricas M1 a M11 en srv01: ${R.lab.metricas}`, 'Ejecutada'],
], [2.2, 6, 3.8], 'Capturas H3-70 a H3-73 en docs/hito-3/capturas/. Los scripts se lanzaron desde la Shell de Proxmox con el atajo vm.', 'Tabla G2'));
add(Tabla(null, 'Comprobaciones del Hito 3 en desarrollo', ['Código', 'Comprobación', 'Resultado', 'Archivo'], [
  ['E-BD-016', 'Seguimiento de un intento de la pantalla a la base y al informe', R.trazado.replace(/ \(.*\)/, ''), 'G/E-BD-016-trazado-intento/'],
  ['E-BD-017', 'Puntaje guardado contra calculado; tiempos; rechazos de atlas_app', `Mismos valores; medianas ${R.comparacion.medianaA} y ${R.comparacion.medianaB}; 5 rechazos`, 'G/E-BD-017-puntaje-guardado-vs-calculado.txt'],
  ['E-BD-018', 'Restauración por intento con huellas sha256', R.restauracion.replace(/ \(.*\)/, ''), 'G/E-BD-018-restauracion-intento-desarrollo.txt'],
], [1.6, 4, 3.4, 3], null, 'Tabla G3'));
add(Figura(null, 'docs/evidencias/G/E-BD-016-trazado-intento/2-estudiante-resultado.png', 'Resultado que ve el estudiante al terminar el intento seguido (75)', 'Captura de E-BD-016, con datos sintéticos.', { etiqueta: 'Figura G1', maxAlto: 520 }));
add(Figura(null, 'docs/evidencias/G/E-BD-016-trazado-intento/3-docente-informe.png', 'El mismo intento en el informe del docente', 'Captura de E-BD-016, con datos sintéticos. El puntaje coincide con el de la pantalla y con el guardado en resultados.', { etiqueta: 'Figura G2', maxAlto: 520 }));
add(Figura(null, LAB + 'H3-73b-proxmox-restauracion.png', 'Restauración de la copia de la VM 130 como VM 930', 'Captura H3-73b (E-BD-015), historial de tareas de Proxmox, 19/11/2026. «VM 930 - Restore» de 23:46:48 a 23:48:09, con 32 GB leídos en 79 s y «TASK OK»; la VM 930 se arrancó a las 23:49:16.', { etiqueta: 'Figura G3', maxAlto: 560 }));
add(Figura(null, LAB + 'H3-73c-vm930-docker-ps.png', 'Contenedores en la VM 930 restaurada, arrancada con la placa desconectada', 'Captura H3-73c (E-BD-015), consola de la VM 930. atlas-db y atlas-analysis sanos, atlas-php en marcha y atlas-web en «Restarting». Con la placa desconectada no queda configurada la dirección 172.16.40.10, donde Nginx publica sus puertos; es la explicación más probable, no comprobada (sección 27.7).', { etiqueta: 'Figura G4', maxAlto: 420 }));
add(Salto());

// H -------------------------------------------------------------------------------------------
add(H1('Anexo H'));
add(PSin('**Especificación de requisitos de software (versión 1.2)**'));
add(Tabla(null, 'Datos generales de la especificación', ['Campo', 'Valor'], [
  ['Proyecto', 'ATLAS - Plataforma de análisis del proceso de aprendizaje.'], ['Equipo', 'Error404 - Tecnicatura en Redes y Software, ITI CETP-UTU.'],
  ['Versión', '1.2 - Verificación al Hito 3 (la 1.1 incorporó RF-21 y RF-22 en el Hito 2).'], ['Fecha', R.fechaDocumento + '.'],
  ['Estándar de referencia', 'IEEE 830-1998 (IEEE, 1998).'],
], [3, 9], null, 'Tabla H1'));
add(H2('H.1 Introducción'));
V24.h1.forEach((p) => {
  const m = p.match(/^(H\.1\.\d) (Propósito|Alcance) (.*)$/);
  if (m) { add(H3(`${m[1]} ${m[2]}`)); add(P(m[3])); } else add(P(p.replace('La validación de laboratorio es parcial: la red y los servicios tienen evidencias, mientras el circuito funcional completo y la integración de Linux permanecen pendientes.', 'Al Hito 3, cada requisito tiene su verificación en desarrollo. En el laboratorio ya se ejecutaron el circuito completo, la VPN y el monitoreo; lo que falta está en el plan del Anexo J.')));
});
add(H3('H.1.3 Definiciones, acrónimos y abreviaturas'));
add(Tabla(null, 'Definiciones y acrónimos utilizados en la especificación', ['Término', 'Definición'], [
  ['ACL', 'Lista de control de acceso: permisos para usuarios o grupos específicos más allá de dueño, grupo y otros.'],
  ['Actividad', 'Conjunto de preguntas con sus opciones, creado por un docente y resuelto por estudiantes.'],
  ['AD', 'Active Directory, servicio de directorio de Microsoft para la gestión centralizada de usuarios y equipos.'],
  ['Indicador', 'Valor calculado a partir de los datos registrados que describe un aspecto del proceso de aprendizaje.'],
  ['Intento', 'Cada ocasión en que un estudiante inicia la resolución de una actividad, esté o no finalizada.'],
  ['Interacción', 'Evento registrado durante la resolución que describe cómo el estudiante llegó a su respuesta.'],
  ['LLM', 'Modelo de lenguaje de gran escala; en ATLAS solo redacta respuestas sobre datos ya procesados.'],
  ['Perfil de aprendizaje', 'Conjunto de indicadores asociados a un estudiante que describen su forma de resolver.'],
  ['RF / RNF', 'Requisito funcional / requisito no funcional.'],
  ['VLAN', 'Red de área local virtual: segmento lógico independiente del cableado físico.'],
  ['VPN', 'Red privada virtual; en ATLAS, WireGuard con un perfil para administración y otro para docentes.'],
], [3, 9], null, 'Tabla H2'));
add(H2('H.2 Descripción general'));
add(H3('H.2.1 Perspectiva del producto'));
V24.h2_1.forEach((p) => add(P(p)));
add(H3('H.2.2 Funciones del producto'));
add(Tabla(null, 'Funciones principales del sistema agrupadas por bloque', ['Bloque', 'Funciones'], [
  ['Gestión de acceso', 'Registro de usuarios, autenticación, diferenciación de roles y gestión de usuarios, instituciones y permisos.'],
  ['Gestión de contenidos', 'Actividades con preguntas, opciones y habilidades; niveles de dificultad; ciclo de aprobación y publicación.'],
  ['Registro del proceso', 'Interacciones, intentos, tiempos (total y activo) y resultados durante la resolución.'],
  ['Análisis', 'Perfiles, análisis grupal, acierto por habilidad, agrupamientos experimentales y recomendaciones con fundamento.'],
  ['Consulta y control', 'Panel docente, consultas guiadas, reportes, decisión docente, consulta conversacional opcional y auditoría.'],
], [3, 9], null, 'Tabla H3'));
add(H3('H.2.3 Características de los usuarios'));
add(Tabla(null, 'Perfiles de usuario del sistema', ['Usuario', 'Formación técnica', 'Uso previsto'], [
  ['Estudiante', 'No se asume ninguna', 'Resuelve las actividades publicadas en sus grupos; no accede a análisis ni a datos de otros estudiantes.'],
  ['Docente', 'No se asume ninguna', 'Crea actividades, consulta la evolución individual y grupal y decide sobre las recomendaciones. Es el usuario principal.'],
  ['Administrador', 'Conocimientos informáticos generales', 'Gestiona usuarios, instituciones, permisos y reglas, y consulta la auditoría.'],
], [2.4, 3, 6.6], 'La mitad de los docentes consultados trabaja con grupos de más de 35 estudiantes; por eso se priorizan la vista grupal y las consultas guiadas.', 'Tabla H4'));
add(H3('H.2.4 Restricciones'));
add(Tabla(null, 'Restricciones del sistema', ['Tipo', 'Restricción'], [
  ['Institucional', 'La implementación y las pruebas se limitan al ITI de UTU; la validación distingue desarrollo de laboratorio.'],
  ['Tecnológica', 'PHP con Laravel 12 para la capa HTTP y lógica en clases propias; interfaz en HTML, CSS y JavaScript sin framework; análisis en Python; MySQL y contenedores.'],
  ['De red', 'Comunicación entre segmentos restringida por la sección 30; el motor de base de datos no es accesible desde la red.'],
  ['Legal', 'Tratamiento de datos conforme a la Ley N.º 18.331 (Uruguay, 2008); ninguna consulta externa incluye datos identificables.'],
  ['De alcance de la IA', 'Modelos clásicos entrenados con datos de la plataforma; no se desarrollan modelos de lenguaje propios.'],
  ['Temporal', 'Cinco Sprints en el primer año (sección 23) y continuidad según la sección 32.'],
], [3, 9], null, 'Tabla H5'));
add(H3('H.2.5 Suposiciones y dependencias'));
add(Tabla(null, 'Suposiciones y requisitos afectados', ['Suposición', 'Requisitos afectados'], [
  ['Se dispone de la infraestructura de virtualización para los servidores Linux y Windows.', 'RNF-07, RNF-08, RNF-09'],
  ['Hay al menos un cliente Windows unido al dominio para las pruebas de integración.', 'RNF-01, RNF-07'],
  ['Los docentes participantes disponen de tiempo para las pruebas del prototipo.', 'RNF-11, RNF-12'],
  ['Se genera un volumen de datos suficiente para entrenar los modelos de agrupamiento.', 'RF-19'],
  ['El servicio externo de modelo de lenguaje está disponible por su API (con clave fuera del repositorio).', 'RF-20'],
  ['Las estimaciones de equipos por área se confirman con un relevamiento de infraestructura.', 'RNF-08'],
], [8, 4], 'Requisitos futuros, fuera de esta versión: integración con sistemas de gestión educativa externos, uso por instituciones distintas del ITI y versión comercial.', 'Tabla H6'));
add(H2('H.3 Requisitos específicos'));
add(H3('H.3.1 Interfaces externas'));
add(Tabla(null, 'Interfaces externas del sistema', ['Interfaz', 'Descripción'], [
  ['De usuario', 'Web responsiva con puntos de corte en 480, 768, 1024 y 1280 píxeles; tema claro y oscuro; la información nunca depende solo del color.'],
  ['De software', 'Servicio de análisis en Python por una API interna; servicio externo de modelo de lenguaje, opcional, limitado a redactar.'],
  ['De comunicaciones', 'HTTPS para los usuarios; VPN WireGuard para administradores y docentes remotos; directorio y nombres provistos por el servidor Windows.'],
  ['De hardware', 'Solo un navegador web actualizado del lado del cliente.'],
], [3, 9], null, 'Tabla H7'));
add(H3('H.3.2 Requisitos funcionales'));
const prio = { 'RF-05': 'Media', 'RF-10': 'Media', 'RF-12': 'Media', 'RF-13': 'Media', 'RF-15': 'Media', 'RF-17': 'Media', 'RF-19': 'Baja', 'RF-20': 'Baja', 'RF-21': 'Por confirmar', 'RF-22': 'Por confirmar' };
const objetivo = { 'RF-01': '1', 'RF-02': '1', 'RF-03': '1', 'RF-04': '2', 'RF-05': '2', 'RF-06': '3', 'RF-07': '3', 'RF-08': '3', 'RF-09': '3', 'RF-10': '5', 'RF-11': '6', 'RF-12': '6', 'RF-13': '6', 'RF-14': '1', 'RF-15': '7', 'RF-16': '2', 'RF-17': '2', 'RF-18': '5', 'RF-19': '5', 'RF-20': '6', 'RF-21': '2, 5 y 6', 'RF-22': '6' };
// Especificación detallada: se toma de la V2.4 (Tablas H9 a H30) separando cada campo.
const ETQ = ['Identificador', 'Nombre', 'Descripción', 'Prioridad', 'Precondición', 'Postcondición', 'Criterios de aceptación'];
const NOMBRES = Object.fromEntries(require('./fuente-v2.4.json')._reqs.map((r) => [r.id, null]));
const RFN = { 'RF-01': 'Registro de usuarios', 'RF-02': 'Autenticación', 'RF-03': 'Gestión de roles', 'RF-04': 'Acceso a actividades educativas', 'RF-05': 'Niveles de dificultad', 'RF-06': 'Registro de interacciones', 'RF-07': 'Registro de resultados', 'RF-08': 'Registro de intentos', 'RF-09': 'Registro de tiempo', 'RF-10': 'Perfil de aprendizaje', 'RF-11': 'Panel docente', 'RF-12': 'Recomendaciones', 'RF-13': 'Estadísticas y reportes', 'RF-14': 'Gestión administrativa', 'RF-15': 'Auditoría', 'RF-16': 'Creación de actividades', 'RF-17': 'Ciclo de aprobación', 'RF-18': 'Análisis grupal', 'RF-19': 'Análisis de patrones', 'RF-20': 'Consulta conversacional', 'RF-21': 'Habilidades', 'RF-22': 'Decisión del docente' };
const cortarCriterios = (c) => c.replace(/^[.\s]+/, '').split(/\s(?:Origen\.|H\.3\.2\.1|Verificación informada)/)[0].trim().replace(/\s•\s/g, '\n• ').replace(/^•\s/, '• ');
function campos(txt, id) {
  let t = txt.replace(/Campo Contenido/g, ' ').replace(new RegExp(`${id} \\(continuación\\)`, 'g'), ' ').replace(/\s+/g, ' ').trim();
  if (/Identificador\s+R/.test(t)) {               // formato «campo valor» en la misma línea
    const out = {};
    const pos = ETQ.map((e) => ({ e, i: t.indexOf(e) })).filter((x) => x.i >= 0).sort((a, b) => a.i - b.i);
    pos.forEach((x, k) => { out[x.e] = t.slice(x.i + x.e.length, k + 1 < pos.length ? pos[k + 1].i : undefined).trim(); });
    out['Criterios de aceptación'] = cortarCriterios(out['Criterios de aceptación'] || '');
    return out;
  }
  // formato aplanado: primero las etiquetas y después los valores en orden
  t = t.replace(/\b(Identificador|Nombre|Descripción|Prioridad|Precondición|Postcondición)\b/g, ' ').replace(/\s+/g, ' ').trim();
  const [antes, crit = ''] = t.split(/Criterios de aceptación/);
  let resto = antes.replace(id, '').trim();
  const nom = RFN[id];
  if (resto.startsWith(nom)) resto = resto.slice(nom.length).trim();
  const m = resto.match(/^(.*?)\s(Alta|Media|Baja|Por confirmar en el backlog\.)\s(.*)$/);
  if (!m) throw new Error(`No pude separar los campos de ${id}`);
  const k = m[3].indexOf('. ');
  return { Nombre: nom, 'Descripción': m[1], Prioridad: m[2].replace(' en el backlog.', ''), 'Precondición': m[3].slice(0, k + 1), 'Postcondición': m[3].slice(k + 2).trim(), 'Criterios de aceptación': cortarCriterios(crit) };
}
const reqs = V24._reqs.map((r) => ({ id: r.id, ...campos(r.texto, r.id) }));
add(Tabla(null, 'Resumen de los requisitos funcionales', ['ID', 'Requisito', 'Prioridad', 'Objetivo específico'],
  reqs.map((r) => [r.id, RFN[r.id], r.Prioridad && r.Prioridad.length < 20 ? r.Prioridad : (prio[r.id] || 'Alta'), `N.º ${objetivo[r.id]}`]), [1.6, 5.4, 2, 3],
  'RF-21 y RF-22 formalizan lo incorporado en D-3 y D-6; su prioridad queda por confirmar en el backlog.', 'Tabla H8'));
let nH = 9;
for (const r of reqs) {
  const filas = [['Identificador', r.id], ['Nombre', r.Nombre], ['Descripción', r['Descripción']], ['Prioridad', (r.Prioridad && r.Prioridad.length < 20 ? r.Prioridad : prio[r.id] || 'Alta')],
    ['Precondición', r['Precondición']], ['Postcondición', r['Postcondición']], ['Criterios de aceptación', r['Criterios de aceptación']]];
  for (const f of filas) if (!f[1]) throw new Error(`Falta ${f[0]} en ${r.id}`);
  add(Tabla(null, `Especificación del requisito ${r.id}`, ['Campo', 'Contenido'], filas, [3, 9], null, `Tabla H${nH++}`));
}
add(H3('H.3.3 Requisitos no funcionales'));
add(Tabla(null, 'Requisitos no funcionales y criterio de verificación', ['ID', 'Requisito', 'Criterio de verificación'], [
  ['RNF-01', 'Seguridad', 'Pruebas de acceso cruzado entre roles: todo intento no autorizado devuelve error y queda registrado.'],
  ['RNF-02', 'Disponibilidad', 'Disponibilidad igual o superior al 99 % durante las ventanas de prueba, medida con la herramienta de monitoreo.'],
  ['RNF-03', 'Rendimiento', 'Tiempo de respuesta igual o menor a 3 segundos en las consultas más frecuentes.'],
  ['RNF-04', 'Respaldo', 'Respaldos según la frecuencia definida, verificables en el destino de almacenamiento.'],
  ['RNF-05', 'Recuperación', 'Restauración a partir de un respaldo, con verificación de integridad.'],
  ['RNF-06', 'Escalabilidad', 'Incorporación de un módulo sin modificar las capas existentes.'],
  ['RNF-07', 'Infraestructura', 'Despliegue funcional sobre los servidores de las secciones 28 y 29.'],
  ['RNF-08', 'Segmentación de red', 'Cada segmento obtiene direccionamiento de su propia VLAN.'],
  ['RNF-09', 'Control de acceso de red', 'Plan de pruebas de la sección 30.6 con resultados coincidentes con la matriz de comunicación.'],
  ['RNF-10', 'Monitoreo', 'Alertas ante los umbrales definidos y registros consultables.'],
  ['RNF-11', 'Usabilidad', 'Prueba de uso con docentes: las tareas principales se completan sin asistencia.'],
  ['RNF-12', 'Diseño responsivo', 'Verificación en los puntos de corte, sin desplazamiento horizontal ni pérdida de contenido.'],
  ['RNF-13', 'Mantenibilidad', 'Estructura por capas y criterios de desarrollo de la sección 26.4.'],
  ['RNF-14', 'Privacidad', 'Revisión de los datos almacenados frente a la finalidad declarada, conforme a la Ley N.º 18.331.'],
  ['RNF-15', 'Independencia de servicios externos', 'Con el servicio externo deshabilitado, el registro y la consulta siguen operativos.'],
], [1.6, 3, 7.4], null, `Tabla H${nH++}`));
add(H2('H.4 Matriz de trazabilidad y verificación al Hito 3'));
add(P('La matriz vincula cada requisito con su objetivo, la sección donde se diseña y la evidencia que lo verifica al Hito 3. Las pruebas citadas por nombre están en atlas/tests/ y corren en cada pull request; los códigos E-… son archivos de docs/evidencias/.'));
const verif = {
  'RF-01': ['26.3', 'GestionAdministrativaTest (API)'], 'RF-02': ['26.3', 'AutenticacionTest; bloqueo por intentos (M9)'],
  'RF-03': ['26.3', 'ControlAccesoTest: 403 registrado'], 'RF-04': ['26.5', 'ResolucionTest; E-APP-015'],
  'RF-05': ['27.2', 'Catálogo niveles_dificultad; editor (E-APP-015)'], 'RF-06': ['27.3', 'E-BD-016 (CAMBIO_OPCION); M1'],
  'RF-07': ['27.3', 'ResultadosTest; E-BD-016 y E-BD-017; M2 y M3'], 'RF-08': ['27.3', 'ResolucionTest; M1'],
  'RF-09': ['25.4', 'TiempoActivoTest; E-BD-016'], 'RF-10': ['25.4', 'IndicadoresTest; MotorAnalisisApiTest'],
  'RF-11': ['26.5', 'PanelGrupalTest; E-APP-015'], 'RF-12': ['25.4', 'MotorReglasTest; M4 y M5'],
  'RF-13': ['26.5', 'Reportes en E-APP-015; informe en E-BD-016'], 'RF-14': ['26.3', 'GestionAdministrativaTest'],
  'RF-15': ['26.3', 'AuditoriaTest (auditoría inmutable); M8'], 'RF-16': ['25.3', 'CicloAprobacionApiTest; editor (E-APP-015)'],
  'RF-17': ['25.3', 'CicloAprobacionApiTest; CicloActividadTest; HabilidadesAprobacionTest'], 'RF-18': ['25.4', 'AnalisisGrupalTest; ResumenGrupalTest; PanelGrupalTest'],
  'RF-19': ['25.4', 'test_modelos.py (pytest); experimental'], 'RF-20': ['25.4', 'AsistenteApiTest; AsistenteTest (anonimización); API real pendiente'],
  'RF-21': ['25.4', 'IndicadoresHabilidadTest; M7'], 'RF-22': ['25.4', 'MotorAnalisisApiTest; M6'],
};
add(Tabla(null, 'Trazabilidad y verificación de los requisitos funcionales', ['RF', 'Objetivo', 'Diseño', 'Verificación al Hito 3 (desarrollo)'],
  reqs.map((r) => [r.id, `N.º ${objetivo[r.id]}`, verif[r.id][0], verif[r.id][1]]), [1.4, 1.8, 1.4, 7.4],
  'El circuito completo (RF-04 a RF-13, RF-16, RF-17, RF-21 y RF-22) se ejecutó también en el laboratorio el 19/11/2026 (sección 26.6). RF-02 (bloqueo) y RF-20 (asistente con la API real) no se probaron en el laboratorio.', `Tabla H${nH++}`));
add(Tabla(null, 'Trazabilidad y verificación de los requisitos no funcionales', ['RNF', 'Evidencia al Hito 3', 'Alcance'], [
  ['RNF-01 / 09', 'ControlAccesoTest; firewall del laboratorio (E-RED-009/010); gemelo con VPN (E-RED-011)', 'Laboratorio para la red (17 de 17 pruebas, VPN incluida); desarrollo para la aplicación'],
  ['RNF-02', `Disponibilidad ${R.disponibilidad} (E-TST-009); SLA de Zabbix (E-RED-013)`, 'Desarrollo; en el laboratorio, SLA de Zabbix desde el 20/11'],
  ['RNF-03', `Percentil 95 máximo ${R.rendimiento.p95max} (E-TST-008)`, 'Desarrollo; laboratorio con Zabbix'],
  ['RNF-04 / 05', `probar-respaldos.sh 17 de 17; ${R.restauracion}. Laboratorio: restauración por intento 13 de 13 y respaldo de la VM (E-BD-020, E-BD-015)`, 'Recuperación verificada en el laboratorio; respaldos automáticos solo en desarrollo (R-5 no ejecutado)'],
  ['RNF-06 / 13', 'Interfaz reemplazada completa sin tocar la API; PSR-12 sin errores', 'Repositorio'],
  ['RNF-07', 'Pila en srv01 y dominio en dc01 (Hito 2)', 'Laboratorio parcial: unión de srv01 en R-4'],
  ['RNF-08', 'DHCP por VLAN desde el cliente (E56, E106-E107)', 'Laboratorio'],
  ['RNF-10', `Zabbix con alertas y SLA (${R.monitoreo}); registro ATLAS-*`, 'Desarrollo y laboratorio: alerta probada al apagar ATLAS y alerta real de disco en srv01'],
  ['RNF-11 / 12', `Prueba de interfaz en cinco anchos (${R.interfaz})`, 'Desarrollo; prueba con docentes en la sección 32'],
  ['RNF-14', 'Anonimizador (AsistenteTest); datos de demostración sintéticos', 'Desarrollo'],
  ['RNF-15', 'Registro y consulta con el análisis caído (pruebas de API con cliente falso); arranque sin Internet (E-TST-003)', 'Desarrollo; laboratorio en R-3'],
], [2, 6.4, 3.6], null, `Tabla H${nH++}`));
add(Salto());

// I -------------------------------------------------------------------------------------------
add(H1('Anexo I'));
add(PSin('**Devoluciones de los hitos anteriores y respuesta del equipo**'));
add(P('El cuerpo docente pidió entregar las devoluciones de los hitos anteriores junto con la entrega final. Se transcribe lo esencial de cada una y qué hizo el equipo, con la evidencia correspondiente.'));
add(H2('I.1 Hito 1: devolución de Programación'));
add(Tabla(null, 'Puntos de la devolución de Programación del Hito 1 y decisiones tomadas', ['Punto', 'Observación', 'Respuesta del equipo'], [
  ['4.a', 'Precisar qué capacidades mide cada actividad', 'D-3: habilidades por pregunta e indicadores por habilidad.'],
  ['4.b', 'No concluir sobre memoria o atención a partir de los tiempos', 'D-8: se concluye acierto, tiempo, cambios e intentos; tiempo activo aparte.'],
  ['4.c', 'Revisar el circuito de aprobación de actividades', 'D-2: aprobación configurable, desactivada por defecto.'],
  ['4.d', 'Usar un framework para la capa HTTP', 'D-1: Laravel 12; lógica propia reutilizada.'],
  ['4.e', 'Definir dónde se calcula cada cosa', 'D-4: PHP calcula; MySQL guarda y protege; Python solo análisis adicional.'],
  ['4.f', 'Justificar el machine learning', 'D-7: reglas explicables; ML experimental con datos y variable a predecir declarados.'],
  ['4.g', 'Forma de consulta del docente', 'D-5: consultas guiadas como vía principal; LLM opcional.'],
  ['4.h', 'Qué significa «adaptativo»', 'D-6: el sistema sugiere y el docente decide.'],
], [1.2, 4.6, 6.2], 'Fuente: acta de decisiones (docs/evidencias/F/acta_tesis). La redacción de la columna «Observación» resume el punto al que responde cada decisión.', 'Tabla I1'));
add(H2('I.2 Hito 2: devolución de Gestión de Proyectos'));
add(Tabla(null, 'Devolución de Gestión del Hito 2 y respuesta', ['Observación', 'Respuesta', 'Evidencia'], [
  ['Resolver el 422 y completar el circuito docente-estudiante en el laboratorio', 'Causa corregida (INC-09); circuito completo ejecutado el 19/11/2026', 'Sección 26.6; E-APP-014'],
  ['Completar VPN, monitoreo centralizado y configuraciones pendientes del servidor Linux', 'En el laboratorio desde el 20/11: VPN del docente probada (pruebas 14 a 16) y Zabbix con agentes en srv01 y el DC. Del servidor Linux quedan sin ejecutar los pasos 8 a 13 (dominio, Samba y respaldos)', 'E-RED-008a/b/c, 011 a 015 y 017; E-LNX-005 y 006'],
  ['Verificar respaldos completos, recuperación y controles de acceso', 'Respaldos automáticos con copia al DC; restauración por intento; rechazos', 'probar-respaldos; E-BD-017 y 018'],
  ['Fortalecer actas, seguimiento de tareas y evidencias Scrum', 'Registro por pull request y formato de acta', 'Sección 22.9; Tabla I4'],
  ['Entregar las devoluciones de los hitos anteriores', 'Este anexo', '—'],
  ['Hito 3: integración, corrección de incidencias y demostración de extremo a extremo', 'Incidencias corregidas; demostración completa en el laboratorio el 19/11/2026', 'Secciones 26.6 y 31.5; E-APP-014'],
  ['Incorporar métricas que permitan verificar requisitos y objetivos', 'M1 a M16 con meta y medición', 'Sección 31.4'],
], [4.4, 4.4, 3.2], null, 'Tabla I2'));
add(H2('I.3 Hito 2: devolución de Base de Datos'));
add(Tabla(null, 'Devolución de Base de Datos del Hito 2 y respuesta', ['Pedido', 'Respuesta', 'Evidencia'], [
  ['Seguir un intento desde la pantalla del estudiante (cambiar una respuesta, puntaje esperado) hasta la base (respuesta final, cambio en interacciones, único puntaje) y el informe del docente', 'Prueba automática de punta a punta; versión para srv01', 'E-BD-016; E-BD-019 (laboratorio, sin cambio de respuesta)'],
  ['Comparar la consulta con puntaje guardado contra la calculada, con tiempos en varias ejecuciones; intentar modificar con atlas_app el puntaje de un intento cerrado y conservar el rechazo', 'Mismos valores; 20 ejecuciones de cada una; cinco intentos rechazados', 'E-BD-017'],
  ['Repetir la restauración en el laboratorio después del circuito, recuperar el intento por su identificador comparando respuestas, interacciones y puntaje, registrar el tiempo y el último intento recuperado frente a RPO/RTO; respaldo de la VM', 'Ejecutado en el laboratorio después del circuito: intento 3 recuperado igual, 13 de 13, respaldo y restauración en 1 s; además, vzdump de la VM', 'E-BD-018; E-BD-020; E-BD-015'],
], [5, 4, 3], null, 'Tabla I3'));
add(H2('I.4 Formato de acta adoptado'));
add(Tabla(null, 'Contenido mínimo de cada acta de Scrum', ['Campo', 'Qué se registra'], [
  ['Encabezado', 'Sprint, tipo de reunión (planificación, revisión o retrospectiva), fecha, duración y asistentes.'],
  ['Objetivo', 'Objetivo del Sprint o de la reunión, en una frase verificable.'],
  ['Tareas', 'Cada tarea con responsable, fecha y tarjeta del tablero.'],
  ['Alcanzado', 'Qué se terminó, con su evidencia (pull request, archivo de docs/evidencias/ o captura).'],
  ['No alcanzado', 'Qué quedó pendiente y por qué; a qué Sprint pasa.'],
  ['Mejoras', 'Qué cambiamos para el siguiente Sprint (solo en la retrospectiva).'],
  ['Decisiones', 'Decisiones tomadas, con su código si modifican el diseño (D-x o DEC-x).'],
], [3, 9], 'Las actas se guardan en docs/evidencias/F/ con el nombre acta-sprint-N-tipo.', 'Tabla I4'));
add(Salto());

// J -------------------------------------------------------------------------------------------
add(H1('Anexo J'));
add(PSin('**Plan de trabajo de Redes en el laboratorio (Hito 3)**'));
add(P('El plan completo, con todos los comandos, está en docs/hito-3/plan-redes-laboratorio.md. Arranca donde terminó el laboratorio del Hito 2. No requiere cambios físicos: la PC, el Proxmox con el adaptador USB y el iPhone quedaron armados; hace falta Internet en la primera parte para descargar actualizaciones e imágenes (unos 300 a 400 MB) y subir la memoria de srv01 a 4 GB. Duración estimada: entre 6 y 8 horas, en dos jornadas.'));
add(Tabla(null, 'Pasos del plan de laboratorio', ['Paso', 'Dónde', 'Qué se hace', 'Qué tiene que salir', 'Evidencia', 'Estado'], [
  ['R-0', 'Proxmox', 'Revisar ICS; snapshot hito3_inicio de las cuatro VM', 'Snapshots creados', '—', 'Sin evidencia'],
  ['R-1', 'Proxmox', 'CPU host en 110/120/140; srv01 a 4 GB; quitar ISO; frase de paso a atlas_admin', 'qm config con los cambios', '—', 'Sin evidencia'],
  ['R-2', 'Proxmox y DC', 'Actualizar repositorio y CD (con el MSI del agente); copiar scripts al DC', 'Scripts 13 y 14 en C:\\ATLAS', '—', 'Ejecutado 20/11'],
  ['R-3', 'srv01', 'git pull; pasos 5 a 7; arranque sin Internet', 'atlas-ctl salud ok sin Internet', 'E-APP-013, E-TST-006', 'No ejecutado'],
  ['R-4', 'srv01 y DC', 'Pasos 8 a 12; certificado firmado por ATLAS-CA', 'verificar.sh sin FAIL en esas secciones', 'E-LNX-006', 'No ejecutado'],
  ['R-5', 'DC y srv01', 'Rotar svc_atlas_backup; paso 13; probar borrado; retención en el DC', 'Copia en el DC; borrado denegado; tarea lista', 'E-LNX-007, E-WIN-006', 'Retención en el DC instalada (INC-18); paso 13 y rotación sin ejecutar'],
  ['R-6', 'srv01 y DC', 'Paso 14; agente del DC; túnel a la interfaz; alerta real', 'Todo en PASS; alerta al detener ATLAS', 'E-RED-015', 'Ejecutado 20/11'],
  ['R-7', 'router, PC y Proxmox', 'VPN docente (y admin); pruebas 14, 15 y 16; VPN-09', '15 pasa; 14 y 16 bloqueadas con registro', 'E-RED-008a/b/c, E-RED-014', 'Ejecutado 20/11 (perfil docente)'],
  ['R-8', 'Cliente y navegador', 'Asignar grupo, publicar, resolver desde VLAN 30, ver indicadores; 445 desde VLAN 30', 'Circuito completo; 445 bloqueado con registro', 'E-APP-014, E-RED-016', 'Ejecutado 19/11'],
  ['R-9', 'srv01', 'seguir_intento, restaurar_intento y metricas', 'Un resultado; huellas iguales; tiempos', 'E-BD-019 a 021, E-BD-013', 'Ejecutado 19/11'],
  ['R-10', 'Proxmox', 'vzdump de la VM 130 y restauración con la placa desconectada', 'Tiempos frente al RTO', 'E-BD-015', 'Ejecutado 19/11'],
  ['R-11', 'Las tres máquinas', 'verificar.sh, verificar-dc01 y nft list ruleset', 'Sin FAIL', 'E-LNX-006, E-WIN-005, E-RED-017', 'Ejecutado 20/11: DC sin FAIL; srv01 con los FAIL de los pasos 8 a 13'],
  ['R-12', 'Todas', 'Rotar credenciales; limpiar historiales; revisar dmesg; snapshots finales', 'Sin credenciales expuestas', '—', 'Sin evidencia'],
], [0.9, 1.6, 3.6, 2.6, 1.7, 1.6], 'El estado es el de la jornada del 19 y 20/11/2026. «Sin evidencia» quiere decir que el paso puede haberse hecho, pero no hay captura ni archivo que lo muestre.', 'Tabla J1'));
add(Salto());

// K -------------------------------------------------------------------------------------------
add(H1('Anexo K'));
add(PSin('**Índice de evidencias del Hito 3**'));
add(Tabla(null, 'Evidencias generadas en el Hito 3', ['Código', 'Qué muestra', 'Resultado', 'Archivo (docs/evidencias/)'], [
  ['E-APP-015', 'Interfaz nueva en el navegador', '29/29', 'B/E-APP-015-interfaz-hito3.txt'],
  ['E-LNX-005', 'Scripts de srv01 en Ubuntu real con la regla 10050', 'Sin FAIL salvo smbd', 'C/E-LNX-005-prueba-scripts-ubuntu-hito3.txt'],
  ['E-WIN-004', 'Módulo y scripts del DC', '52/52', 'D/E-WIN-004-modulo-y-scripts-hito3.txt'],
  ['E-RED-011', 'Firewall de router-lab con la VPN (gemelo)', '46/46', 'E/E-RED-011-firewall-vpn-gemelo.txt'],
  ['E-RED-012', 'Paso 14 de punta a punta y capturas de Zabbix', 'Solo falla dc01 (sin Windows)', 'E/E-RED-012-monitoreo-zabbix-desarrollo.txt; E/capturas/'],
  ['E-RED-013', 'Prueba automática del monitoreo', '14/14', 'E/E-RED-013-prueba-monitoreo.txt'],
  ['E-BD-016', 'Seguimiento de un intento', '6/6', 'G/E-BD-016-trazado-intento/'],
  ['E-BD-017', 'Puntaje guardado contra calculado y rechazos', 'Aprobada', 'G/E-BD-017-puntaje-guardado-vs-calculado.txt'],
  ['E-BD-018', 'Restauración por intento', '13/13', 'G/E-BD-018-restauracion-intento-desarrollo.txt'],
  ['E-TST-007', 'Métricas M1 a M11', '6 PASS y 5 informativas', 'H/E-TST-007-metricas-desarrollo.txt'],
  ['E-TST-008', 'Tiempos de respuesta', '7/7', 'H/E-TST-008-rendimiento-hito3.txt'],
  ['E-TST-009', 'Disponibilidad durante 10 minutos', R.disponibilidad.replace(/ \(.*/, ''), 'H/E-TST-009-disponibilidad-hito3.txt'],
  ['E-TST-010', 'Corrida completa de probar-todo.sh', 'Sección 31.3', 'H/E-TST-010-ejecucion-2026-11-12/'],
], [1.6, 4, 2.6, 3.8], 'Todas corresponden al entorno de desarrollo.', 'Tabla K1'));
add(Tabla(null, 'Evidencias del laboratorio Proxmox (19 y 20/11/2026)', ['Código', 'Qué muestra', 'Resultado', 'Capturas (docs/hito-3/capturas/)'], [
  ['E-APP-014', 'Circuito completo docente-estudiante', 'Ejecutado y verificado', 'H3-49 a H3-58, H3-61 a H3-69'],
  ['E-RED-016', 'Prueba 7 repetida: 445 desde la VLAN 30 con registro', 'False; ATLAS-R12 registrado', 'H3-55, H3-56 y H3-57'],
  ['E-BD-019', 'Seguimiento del intento 3', 'RESULTADO: OK', 'H3-70'],
  ['E-BD-020', 'Restauración por intento', '13 de 13', 'H3-71'],
  ['E-BD-021', 'Métricas M1 a M11', '6 PASS, 0 FAIL, 5 informativas', 'H3-72'],
  ['E-BD-015', 'Respaldo y restauración de la VM 130', 'Ejecutado; atlas-web sin red en la copia', 'H3-73a, H3-73b y H3-73c'],
  ['E-LNX-006', 'verificar.sh en srv01', '86 PASS y 31 FAIL; después del paso 14, 93 y 24; monitoreo y firewall 23 de 23', 'H3-74a, H3-26 y H3-74e'],
  ['E-WIN-005', 'Verificador del DC', '63/5 con el script viejo; 73 PASS y 0 FAIL con los nuevos', 'H3-74b y H3-74d'],
  ['E-WIN-006', 'CD nuevo, scripts copiados, retención y agente de Zabbix en el DC', 'Instalados; retención con INC-18', 'H3-03, H3-05, H3-23, H3-24 y H3-28'],
  ['E-RED-008a/b/c', 'Pruebas 15 y 16 por la VPN y VPN-09 sin NAT', 'Aprobadas', 'H3-36 a H3-44 y H3-47'],
  ['E-RED-014', 'Prueba 14: sin VPN no se entra desde la WAN', 'Aprobada', 'H3-45 y H3-46'],
  ['E-RED-015', 'Zabbix en el laboratorio: agentes, web, alerta y SLA', 'Funcionando; alerta probada; SLA 89,7 % el primer día; alerta real de disco resuelta (INC-19)', 'H3-26 a H3-35, H3-75, H3-74f y H3-74g'],
  ['E-RED-017', 'Ruleset de router-lab', 'Reglas de la VPN cargadas', 'H3-74c'],
], [1.6, 4, 3, 3.4], 'Siguen como *No ejecutada*, con el paso del Anexo J que las cubre: E-APP-013 y E-TST-006 (R-3) y E-LNX-007 (R-5). No se tomaron las capturas H3-01, H3-02, H3-04, H3-06 a H3-22, H3-25, H3-48, H3-59 y H3-60.', 'Tabla K2'));
