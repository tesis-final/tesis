// Vistas del docente (RF-10..RF-13, RF-16..RF-18, RF-20). La primera pantalla
// responde "¿dónde intervengo hoy?" (§20.4): prioritarios y preguntas con más error.

import { api } from '../api.js';
import {
  h, montar, mensaje, tabla, etiquetaTipo, etiquetaEstado, fecha, fechaCorta, dia, numero, errorEn,
  encabezado, seccion, vacio, cifra, avatar, chipsReglas, icono, textoCodigo, enCurso,
} from '../ui.js';
import { anillo, medidor, columnas, linea } from '../graficos.js';
import { estado } from '../app.js';

// Nombres ya vistos en esta sesión (para titular el perfil sin otra consulta).
const nombres = new Map();
function recordar(id, nombre) { if (id && nombre) nombres.set(Number(id), nombre); }

function saludo() {
  const hora = new Date().getHours();
  const parte = hora < 12 ? 'Buenos días' : hora < 20 ? 'Buenas tardes' : 'Buenas noches';
  return estado.usuario ? `${parte}, ${estado.usuario.nombre}` : parte;
}

function periodoTexto(p) {
  return `${dia(p.desde)} – ${dia(p.hasta)}`;
}

function enlacePersona(id, nombre) {
  recordar(id, nombre);
  return h('span', { clase: 'celda-persona' }, avatar(nombre), h('a', { href: `#/estudiante/${id}` }, nombre));
}

// ---------- Dónde intervenir ----------
export async function inicio() {
  const grupos = await api('GET', '/grupos');
  if (!grupos.length) {
    montar(encabezado('Dónde intervenir hoy', { antetitulo: saludo() }), vacio('Todavía no tiene grupos asignados.'));
    return;
  }
  const analisis = await Promise.all(grupos.map(async (g) => {
    try { return { g, a: await api('GET', `/docente/grupos/${g.id}/analisis`) }; } catch (e) { return { g, error: e }; }
  }));
  const validos = analisis.filter((x) => x.a);
  const totalEstudiantes = validos.reduce((t, x) => t + Number(x.a.estudiantes || 0), 0);
  const totalPrioritarios = validos.reduce((t, x) => t + x.a.prioritarios.length, 0);
  const resumen = h('div', { clase: 'cifras' },
    cifra(grupos.length, grupos.length === 1 ? 'Grupo a cargo' : 'Grupos a cargo', { icono: 'grupos' }),
    cifra(totalEstudiantes, 'Estudiantes', { icono: 'usuarios' }),
    cifra(totalPrioritarios, 'Requieren atención', { icono: 'alerta', detalle: 'según las reglas R01–R08' }));
  resumen.style.setProperty('--columnas', '3');
  montar(
    encabezado('Dónde intervenir hoy', {
      antetitulo: saludo(),
      bajada: 'Primero, quienes necesitan atención; después, las preguntas que más cuestan. El detalle está en cada grupo.',
      acciones: [h('a', { clase: 'boton secundario', href: '#/consultas' }, icono('consultas'), 'Consultas guiadas'),
        h('a', { clase: 'boton', href: '#/actividades/nueva' }, icono('mas'), 'Nueva actividad')],
    }),
    resumen,
    h('div', { clase: 'pila' }, analisis.map(({ g, a, error }) => (a ? tarjetaGrupo(g, a)
      : h('article', { clase: 'tarjeta' }, h('h2', {}, g.nombre), h('p', { clase: 'aviso' }, error.message))))),
  );
}

function tarjetaGrupo(g, a) {
  const prioritarios = a.prioritarios.slice(0, 5);
  return h('article', { clase: 'tarjeta' },
    h('div', { clase: 'tarjeta-cabeza' },
      h('div', {}, h('h2', {}, icono('grupos'), `Grupo ${g.nombre}`),
        h('p', { clase: 'suave pequeño' }, `${a.estudiantes} estudiantes · promedio ${numero(a.agregados.promedio)} · período ${a.periodo.desde} a ${a.periodo.hasta}`)),
      anillo(a.agregados.promedio, { tamano: 76, grosor: 8, subtitulo: 'promedio', etiqueta: `Promedio del grupo: ${numero(a.agregados.promedio)} de 100` })),
    h('div', { clase: 'rejilla dos' },
      h('div', {},
        h('h3', {}, `Atención prioritaria (${a.prioritarios.length})`),
        prioritarios.length
          ? h('ul', { clase: 'lista-personas' }, prioritarios.map((p) => {
            recordar(p.estudiante_id, p.nombre);
            return h('li', {}, avatar(p.nombre), h('div', {}, h('a', { href: `#/estudiante/${p.estudiante_id}` }, p.nombre), chipsReglas(p.motivo)));
          }))
          : vacio('Nadie disparó reglas de riesgo en el período.')),
      h('div', {},
        h('h3', {}, 'Preguntas con más error'),
        a.preguntas_con_mas_error.length
          ? h('ul', { clase: 'lista-error' }, a.preguntas_con_mas_error.slice(0, 3).map((q) => h('li', {},
            h('span', {}, q.enunciado), medidor(q.proporcion_error * 100, { tono: 'riesgo', texto: `${Math.round(q.proporcion_error * 100)} % de error` }))))
          : vacio('Sin errores registrados.'))),
    h('div', { clase: 'acciones' }, h('a', { clase: 'boton secundario', href: `#/grupo/${g.id}` }, 'Ver análisis del grupo', icono('derecha'))));
}

// ---------- Análisis grupal completo (RF-18) ----------
export async function grupo(id) {
  const a = await api('GET', `/docente/grupos/${id}/analisis`);
  const ml = a.aprendizaje_automatico;
  montar(
    encabezado(`Grupo ${a.grupo.nombre}`, {
      antetitulo: 'Análisis del grupo',
      bajada: `Período ${a.periodo.desde} a ${a.periodo.hasta}`,
      acciones: [h('a', { clase: 'boton secundario', href: '#/consultas' }, icono('consultas'), 'Consultas guiadas'),
        h('button', { type: 'button', clase: 'secundario', onclick: () => window.print() }, icono('libro'), 'Imprimir')],
    }),
    h('div', { clase: 'cifras' },
      cifra(a.agregados.n_estudiantes, 'Estudiantes con datos', { icono: 'usuarios' }), cifra(numero(a.agregados.promedio), 'Promedio', { icono: 'grafico' }),
      cifra(numero(a.agregados.mediana), 'Mediana', { icono: 'reportes' }), cifra(numero(a.agregados.minimo), 'Mínimo', { icono: 'alerta' }),
      cifra(numero(a.agregados.maximo), 'Máximo', { icono: 'estrella' })),
    h('div', { clase: 'rejilla tres' },
      seccion('Atención prioritaria', { icono: 'alerta' },
        tabla([
          { titulo: 'Estudiante', valor: (p) => enlacePersona(p.estudiante_id, p.nombre) },
          { titulo: 'Motivo (reglas)', valor: (p) => chipsReglas(p.motivo) },
          { titulo: 'Última señal', valor: (p) => fecha(p.ultima) },
        ], a.prioritarios, 'Nadie disparó reglas de riesgo en el período.')),
      seccion('Distribución de puntajes', { icono: 'reportes' },
        a.distribucion.length ? columnas(a.distribucion, { titulo: 'Distribución de puntajes del grupo' }) : vacio('Sin intentos finalizados.'),
        h('p', { clase: 'suave pequeño' }, 'Cantidad de intentos finalizados en cada rango de puntaje.'))),
    seccion('Preguntas con mayor proporción de error', { icono: 'consultas' },
      tabla([
        { titulo: 'Pregunta', valor: (q) => q.enunciado },
        { titulo: 'Error', valor: (q) => medidor(q.proporcion_error * 100, { tono: 'riesgo', texto: `${Math.round(q.proporcion_error * 100)} % (${q.errores} de ${q.respuestas})` }) },
      ], a.preguntas_con_mas_error, 'Sin errores registrados.')),
    seccionHabilidades(a.habilidades, true),
    seccion('Patrones de resolución (aprendizaje automático)', { icono: 'asistente' },
      !ml.servicio_disponible
        ? h('p', { clase: 'aviso' }, 'El servicio de análisis no está disponible. El resto del panel funciona normalmente.')
        : ml.agrupamiento
          ? h('div', {}, h('p', {}, `${ml.agrupamiento.k} agrupamientos (silueta ${numero(ml.agrupamiento.silueta, 2)}) sobre ${ml.agrupamiento.n_muestras} estudiantes.`),
            tabla([{ titulo: 'Estudiante', valor: (m) => m.nombre }, { titulo: 'Agrupamiento', valor: (m) => `Grupo ${Number(m.cluster) + 1}` }], ml.agrupamiento.miembros))
          : h('p', { clase: 'aviso info' }, suficiencia(ml.suficiencia)),
      h('p', { clase: 'suave pequeño' }, ml.aviso)),
  );
}

// D-3: acierto por habilidad, de la más débil a la más fuerte. El estado se dice con
// texto ("A reforzar"), no solo con color (RNF-12). La marca vertical es el umbral del 50 %.
function seccionHabilidades(habilidades, grupal) {
  return seccion('Acierto por habilidad', { icono: 'objetivo' },
    tabla([
      { titulo: 'Habilidad', valor: (x) => h('strong', {}, x.nombre) },
      { titulo: 'Acierto', valor: (x) => medidor(x.porcentaje, { umbral: 50, texto: `${numero(x.porcentaje)} %` }) },
      { titulo: 'Preguntas', valor: (x) => `${x.correctas} de ${x.preguntas}` },
      grupal ? { titulo: 'Estudiantes por debajo del 50 %', valor: (x) => `${x.estudiantes_bajo_umbral} de ${x.estudiantes}` } : null,
      { titulo: 'Estado', valor: (x) => (x.a_reforzar ? h('span', { clase: 'etiqueta REFUERZO' }, 'A reforzar') : h('span', { clase: 'etiqueta ok' }, 'Adecuado')) },
    ].filter(Boolean), habilidades || [], 'Todavía no hay preguntas resueltas vinculadas a habilidades en el período.'),
    h('p', { clase: 'suave pequeño' }, 'Porcentaje de preguntas acertadas en el último intento de cada actividad. Describe aciertos; no mide capacidades. La marca indica el 50 %.'));
}

function suficiencia(s) {
  if (!s) return 'Todavía no hay agrupamientos para este período.';
  return `Todavía no hay datos suficientes para un análisis confiable: ${s.estudiantes_con_datos ?? 0} de ${s.requeridos ?? 20} estudiantes con la cantidad mínima de intentos. `
    + 'Mostrar agrupamientos con menos datos sería engañoso.';
}

// D-8: un tiempo que no se registró (intentos anteriores a la medición) se muestra como "—".
function segundos(valor) {
  if (valor === null || valor === undefined) return '—';
  const s = Number(valor);
  return s >= 60 ? `${Math.floor(s / 60)} min ${s % 60} s` : `${s} s`;
}

// ---------- Perfil individual + "¿por qué?" (RF-10, RF-12) ----------
async function nombreEstudiante(id) {
  if (nombres.has(Number(id))) return nombres.get(Number(id));
  try {
    for (const g of await api('GET', '/grupos')) {
      for (const m of await api('GET', `/grupos/${g.id}/miembros`)) recordar(m.id, `${m.nombre} ${m.apellido || ''}`.trim());
      if (nombres.has(Number(id))) break;
    }
  } catch { /* sin nombre: se titula de forma genérica */ }
  return nombres.get(Number(id)) || null;
}

export async function estudiante(id) {
  const [p, misActividades, nombre] = await Promise.all([api('GET', `/docente/estudiantes/${id}/perfil`), api('GET', '/actividades'), nombreEstudiante(id)]);
  const publicadas = misActividades.filter((a) => a.estado === 'PUBLICADA');
  const porActividad = new Map();
  for (const i of p.indicadores) {
    if (!porActividad.has(i.actividad_id)) porActividad.set(i.actividad_id, { actividad: i.actividad, categoria: i.categoria });
    porActividad.get(i.actividad_id)[i.tipo] = i.valor;
  }
  const filas = [...porActividad.values()];
  const puntajes = filas.map((f) => Number(f.PUNTAJE)).filter((x) => !Number.isNaN(x));
  const promedio = puntajes.length ? puntajes.reduce((a, b) => a + b, 0) / puntajes.length : null;
  const ultimo = p.evolucion.length ? Number(p.evolucion[p.evolucion.length - 1].puntaje) : null;
  const fundamento = h('div', { 'aria-live': 'polite' });
  montar(
    h('header', { clase: 'encabezado' },
      h('div', { clase: 'encabezado-texto fila encoger' }, avatar(nombre || 'Estudiante', 'grande'),
        h('div', {}, h('div', { clase: 'antetitulo' }, 'Perfil de aprendizaje'), h('h1', {}, nombre || 'Perfil de aprendizaje'),
          h('p', { clase: 'bajada' }, `Período ${p.periodo.desde} a ${p.periodo.hasta}`)))),
    h('p', { clase: 'aviso info' }, p.aviso),
    h('div', { clase: 'cifras' },
      cifra(filas.length, 'Actividades con datos', { icono: 'actividades' }),
      cifra(numero(promedio), 'Puntaje promedio', { icono: 'grafico' }),
      cifra(numero(ultimo), 'Último puntaje', { icono: 'reloj' }),
      cifra(p.recomendaciones.length, 'Recomendaciones', { icono: 'bandera' })),
    h('div', { clase: 'rejilla lateral-der' },
      seccion('Evolución', { icono: 'grafico' },
        p.evolucion.length
          ? linea(p.evolucion.map((e) => ({ valor: e.puntaje, etiqueta: `${e.actividad_titulo} (${fecha(e.finalizado_en)})`, corta: fechaCorta(e.finalizado_en) })), { titulo: 'Puntaje de cada intento finalizado' })
          : vacio('Sin intentos finalizados.'),
        p.evolucion.length ? h('details', {}, h('summary', {}, 'Ver los intentos en una tabla'),
          tabla([
            { titulo: 'Fecha', valor: (e) => fecha(e.finalizado_en) }, { titulo: 'Actividad', valor: (e) => e.actividad_titulo },
            { titulo: 'Intento', valor: (e) => e.numero_intento }, { titulo: 'Puntaje', valor: (e) => numero(e.puntaje) },
          ], p.evolucion)) : null),
      seccionHabilidades(p.habilidades, false)),
    seccion(`Indicadores (${p.periodo.desde} a ${p.periodo.hasta})`, { icono: 'reportes' },
      tabla([
        { titulo: 'Actividad', valor: (f) => h('strong', {}, f.actividad) }, { titulo: 'Categoría', valor: (f) => f.categoria },
        { titulo: 'Puntaje', valor: (f) => medidor(f.PUNTAJE, { texto: numero(f.PUNTAJE) }) }, { titulo: 'Eficiencia', valor: (f) => numero(f.EFICIENCIA, 2) },
        { titulo: 'Mejora', valor: (f) => numero(f.MEJORA) }, { titulo: 'Persistencia', valor: (f) => numero(f.PERSISTENCIA, 0) },
      ], filas, 'Sin actividades finalizadas en el período.')),
    seccion('Recomendaciones', { icono: 'bandera' },
      p.recomendaciones.length
        ? h('div', { clase: 'pila' }, p.recomendaciones.map((r) => h('article', { clase: 'tarjeta recomendacion' },
          h('div', { clase: 'chips' }, r.reglas.map((x) => etiquetaTipo(x.tipo))),
          h('p', {}, r.texto),
          decisionDocente(r, publicadas, () => estudiante(id)),
          h('div', { clase: 'acciones' }, h('button', { type: 'button', clase: 'secundario chico', onclick: () => verFundamento(r.id, fundamento) }, icono('info'), '¿Por qué?')))))
        : vacio('Sin recomendaciones en el período.'),
      fundamento),
  );
}

// D-6: el sistema recomienda y el docente decide (confirma la sugerencia o la cambia).
function decisionDocente(r, publicadas, recargar) {
  if (r.decision) {
    return h('p', { clase: 'aviso info' }, h('span', {}, h('strong', {}, r.decision === 'CONFIRMADA' ? 'Confirmada por usted: ' : 'Cambiada por usted a: '),
      `«${r.actividad_asignada}» (el estudiante la ve como recomendada).`));
  }
  const otras = publicadas.filter((a) => Number(a.id) !== Number(r.actividad_sugerida_id));
  const selector = h('select', { 'aria-label': 'Otra actividad para asignar' },
    h('option', { value: '' }, 'Elegir otra actividad…'), otras.map((a) => h('option', { value: a.id }, a.titulo)));
  async function decidir(actividad) {
    try {
      await api('POST', `/recomendaciones/${r.id}/decision`, actividad ? { actividad_id: Number(actividad) } : {});
      mensaje('Decisión guardada: el estudiante verá la actividad como recomendada.');
      recargar();
    } catch (e) { mensaje(e, 'error'); }
  }
  return h('div', { clase: 'fila' },
    r.actividad_sugerida_id ? h('div', { clase: 'encoger' }, h('button', { type: 'button', onclick: () => decidir(null) }, icono('check'), `Confirmar «${r.actividad_sugerida}»`)) : null,
    otras.length ? h('div', { clase: 'fila' }, selector,
      h('div', { clase: 'encoger' }, h('button', { type: 'button', clase: 'secundario', onclick: () => { if (selector.value) decidir(selector.value); else mensaje('Elija una actividad.', 'error'); } }, 'Asignar esta'))) : null);
}

async function verFundamento(id, destino) {
  const f = await api('GET', `/recomendaciones/${id}/fundamento`);
  destino.replaceChildren(h('div', { clase: 'tarjeta destacada' },
    h('div', { clase: 'tarjeta-cabeza' }, h('h3', {}, 'Fundamento de la recomendación'),
      h('button', { type: 'button', clase: 'fantasma chico', onclick: () => destino.replaceChildren() }, icono('cerrar'), 'Cerrar')),
    h('p', {}, f.texto),
    f.reglas.map((r) => h('div', { clase: 'pila' },
      h('p', {}, etiquetaTipo(r.tipo), ' ', h('strong', {}, `${r.codigo} — ${r.nombre}`), h('span', { clase: 'suave' }, ` (versión ${r.version_regla})`)),
      h('p', { clase: 'suave' }, r.descripcion),
      h('p', { clase: 'num pequeño' }, 'Datos usados: ', Object.entries(r.valores_entrada.valores || {})
        .filter(([k]) => k !== 'sin_dato').map(([k, v]) => `${k} = ${numero(v, 2)}`).join(' · ')))),
    h('p', { clase: 'suave pequeño' }, 'La regla y sus umbrales están guardados en ATLAS y los puede revisar la coordinación.')));
  destino.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

// ---------- Consultas guiadas (acta D-5): grupo + período + qué ver ----------
// Es la forma principal de consultar: elige entre preguntas fijas, responde con datos
// ya calculados por ATLAS y explica cómo se obtuvo cada número. El asistente con
// lenguaje natural queda como opción.
const QUE_VER = [
  ['atencion', '¿Quiénes requieren atención?', 'alerta'],
  ['preguntas', '¿Qué preguntas costaron más?', 'consultas'],
  ['habilidades', '¿Cómo va el grupo en cada habilidad?', 'objetivo'],
  ['actividades', '¿Cómo les fue en cada actividad y cuánto tardaron?', 'reloj'],
];

function iso(d) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function rangoDe(periodo, desde, hasta) {
  const hoy = new Date();
  if (periodo === 'semana') return [iso(new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate() - 6)), iso(hoy)];
  if (periodo === 'mes') return [iso(new Date(hoy.getFullYear(), hoy.getMonth(), 1)), iso(new Date(hoy.getFullYear(), hoy.getMonth() + 1, 0))];
  if (periodo === 'anterior') return [iso(new Date(hoy.getFullYear(), hoy.getMonth() - 1, 1)), iso(new Date(hoy.getFullYear(), hoy.getMonth(), 0))];
  return [desde, hasta];
}

export async function consultas() {
  const grupos = await api('GET', '/grupos');
  if (!grupos.length) {
    montar(encabezado('Consultas'), vacio('Todavía no tiene grupos asignados.'));
    return;
  }
  const resultado = h('div', { 'aria-live': 'polite' });
  const personalizado = h('div', { clase: 'fila', hidden: true },
    h('div', {}, h('label', { for: 'c-desde' }, 'Desde'), h('input', { id: 'c-desde', name: 'desde', type: 'date' })),
    h('div', {}, h('label', { for: 'c-hasta' }, 'Hasta'), h('input', { id: 'c-hasta', name: 'hasta', type: 'date' })));
  const form = h('form', { clase: 'tarjeta', novalidate: true },
    h('div', { clase: 'fila' },
      h('div', {}, h('label', { for: 'c-grupo' }, '1. Grupo'),
        h('select', { id: 'c-grupo', name: 'grupo' }, grupos.map((g) => h('option', { value: g.id }, g.nombre)))),
      h('div', {}, h('label', { for: 'c-periodo' }, '2. Período'),
        h('select', { id: 'c-periodo', name: 'periodo', onchange: (ev) => { personalizado.hidden = ev.target.value !== 'otro'; } },
          h('option', { value: 'semana' }, 'Últimos 7 días'), h('option', { value: 'mes', selected: true }, 'Este mes'),
          h('option', { value: 'anterior' }, 'Mes anterior'), h('option', { value: 'otro' }, 'Otro rango…')))),
    personalizado,
    h('fieldset', {}, h('legend', {}, '3. ¿Qué quiere ver?'),
      h('div', { clase: 'rejilla dos' }, QUE_VER.map(([valor, texto, nombreIcono], i) => h('label', { clase: 'opcion' },
        h('input', { type: 'radio', name: 'que', value: valor, checked: i === 0 }), icono(nombreIcono), texto)))),
    h('div', { clase: 'acciones' }, h('button', { type: 'submit' }, icono('buscar'), 'Consultar')));

  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const que = form.querySelector('input[name=que]:checked').value;
    const [desde, hasta] = rangoDe(form.periodo.value, form.desde.value, form.hasta.value);
    if (!desde || !hasta) { mensaje('Indique las dos fechas del rango.', 'error'); return; }
    const grupoNombre = form.grupo.selectedOptions[0].textContent;
    try {
      resultado.replaceChildren(await respuestaGuiada(que, form.grupo.value, grupoNombre, desde, hasta));
    } catch (e) { errorEn(form, e); }
  });

  montar(encabezado('Consultas', {
    antetitulo: 'Consultas guiadas',
    bajada: 'Elija el grupo, el período y qué quiere saber. Las respuestas salen de los datos registrados y dicen cómo se calcularon.',
  }), form, resultado);
  form.requestSubmit();
}

async function respuestaGuiada(que, grupo, grupoNombre, desde, hasta) {
  const titulo = `${QUE_VER.find(([v]) => v === que)[1]} — Grupo ${grupoNombre}, ${desde} a ${hasta}`;
  if (que === 'actividades') {
    const r = await api('GET', '/reportes', null, { grupo, desde, hasta });
    return seccion(titulo, { icono: 'reloj' },
      tabla([{ titulo: 'Actividad', valor: (x) => h('strong', {}, x.actividad_titulo) }, { titulo: 'Estudiantes', valor: (x) => x.estudiantes },
        { titulo: 'Intentos', valor: (x) => x.intentos }, { titulo: 'Puntaje promedio', valor: (x) => medidor(x.promedio, { texto: numero(x.promedio) }) },
        { titulo: 'Tiempo medio (total)', valor: (x) => segundos(x.duracion_media_seg) },
        { titulo: 'Tiempo medio activo', valor: (x) => segundos(x.duracion_activa_media_seg) }],
      r.resumen, 'No hay intentos finalizados en el período.'),
      h('p', { clase: 'suave pequeño' }, 'Promedio de todos los intentos finalizados. Tiempo activo = total menos pausas de más de 60 s sin actividad.'));
  }
  const a = await api('GET', `/docente/grupos/${grupo}/analisis`, null, { desde, hasta });
  if (que === 'atencion') {
    return seccion(titulo, { icono: 'alerta' },
      tabla([
        { titulo: 'Estudiante', valor: (p) => enlacePersona(p.estudiante_id, p.nombre) },
        { titulo: 'Motivo (reglas)', valor: (p) => chipsReglas(p.motivo) },
        { titulo: 'Última señal', valor: (p) => fecha(p.ultima) },
      ], a.prioritarios, 'Nadie disparó reglas de riesgo en el período.'),
      h('p', { clase: 'suave pequeño' }, 'Aparece quien disparó al menos una regla de riesgo (por ejemplo, R01: puntaje menor a 50). En el perfil, el botón "¿Por qué?" muestra la regla y los datos exactos.'));
  }
  if (que === 'preguntas') {
    return seccion(titulo, { icono: 'consultas' },
      tabla([
        { titulo: 'Pregunta', valor: (q) => q.enunciado },
        { titulo: 'Error', valor: (q) => medidor(q.proporcion_error * 100, { tono: 'riesgo', texto: `${Math.round(q.proporcion_error * 100)} % (${q.errores} de ${q.respuestas} respuestas)` }) },
      ], a.preguntas_con_mas_error, 'Sin errores registrados en el período.'),
      h('p', { clase: 'suave pequeño' }, 'Proporción de respuestas incorrectas en los intentos finalizados del período.'));
  }
  return seccionHabilidades(a.habilidades, true);
}

// ---------- Actividades (RF-16, RF-17) ----------
export async function actividades() {
  const lista = await api('GET', '/actividades');
  const cuenta = (e) => lista.filter((a) => a.estado === e).length;
  montar(
    encabezado('Mis actividades', {
      antetitulo: 'Contenido',
      bajada: 'Cada pregunta mide una o más habilidades. Si su institución no exige aprobación, publica directo en sus grupos.',
      acciones: h('a', { clase: 'boton', href: '#/actividades/nueva' }, icono('mas'), 'Nueva actividad'),
    }),
    h('div', { clase: 'cifras' },
      cifra(lista.length, 'Actividades', { icono: 'actividades' }), cifra(cuenta('PUBLICADA'), 'Publicadas', { icono: 'check' }),
      cifra(cuenta('BORRADOR'), 'En borrador', { icono: 'libro' })),
    tabla([
      { titulo: 'Título', valor: (a) => h('a', { href: `#/actividades/${a.id}` }, a.titulo) },
      { titulo: 'Estado', valor: (a) => etiquetaEstado(a.estado) },
      { titulo: 'Nivel', valor: (a) => a.nivel_nombre }, { titulo: 'Categoría', valor: (a) => a.categoria_nombre },
      { titulo: 'Preguntas', valor: (a) => a.total_preguntas }, { titulo: 'Actualizada', valor: (a) => fecha(a.actualizado_en) },
    ], lista, 'Todavía no creó actividades.'),
  );
}

export async function editor(id) {
  const [cat, act, grupos] = await Promise.all([
    api('GET', '/catalogos'),
    id ? api('GET', `/actividades/${id}`) : Promise.resolve(null),
    api('GET', '/grupos'),
  ]);
  const editable = !act || ['BORRADOR', 'RECHAZADA'].includes(act.estado);
  const preguntas = h('div', { clase: 'pila' });
  const form = h('form', { clase: 'tarjeta', novalidate: true },
    h('div', { clase: 'tarjeta-cabeza' }, h('h2', {}, icono('libro'), 'Datos de la actividad')),
    h('label', { for: 'titulo' }, 'Título'), h('input', { id: 'titulo', name: 'titulo', value: act?.titulo || '', disabled: !editable, placeholder: 'Por ejemplo: Problemas con fracciones' }),
    h('label', { for: 'descripcion' }, 'Descripción'), h('textarea', { id: 'descripcion', name: 'descripcion', disabled: !editable, placeholder: 'Qué se trabaja y para quién (opcional)' }, act?.descripcion || ''),
    h('div', { clase: 'fila' },
      h('div', {}, h('label', { for: 'nivel' }, 'Nivel de dificultad'),
        h('select', { id: 'nivel', name: 'nivel', disabled: !editable }, cat.niveles.map((n) => h('option', { value: n.codigo, selected: act?.nivel === n.codigo }, n.nombre)))),
      h('div', {}, h('label', { for: 'categoria' }, 'Categoría'),
        h('select', { id: 'categoria', name: 'categoria', disabled: !editable }, cat.categorias.map((c) => h('option', { value: c.codigo, selected: act?.categoria === c.codigo }, c.nombre))))),
    h('div', { clase: 'tarjeta-cabeza' }, h('h2', {}, icono('consultas'), 'Preguntas')),
    preguntas,
    editable ? h('div', { clase: 'acciones' }, h('button', { type: 'button', clase: 'secundario', onclick: () => agregarPregunta(preguntas, null, true, cat.habilidades) }, icono('mas'), 'Agregar pregunta')) : null,
  );
  (act?.preguntas || []).forEach((p) => agregarPregunta(preguntas, p, editable, cat.habilidades));
  if (!act) agregarPregunta(preguntas, null, true, cat.habilidades);

  const acciones = h('div', { clase: 'acciones' });
  if (editable) acciones.append(h('button', { type: 'button', onclick: (ev) => enCurso(ev.currentTarget, guardar) }, icono('check'), 'Guardar borrador'));
  // D-2: si la institución no exige aprobación, el borrador se publica directo.
  const publicaDirecto = act?.estado === 'BORRADOR' && !act.requiere_aprobacion;
  if (act?.estado === 'BORRADOR' && act.requiere_aprobacion) acciones.append(h('button', { type: 'button', onclick: (ev) => enCurso(ev.currentTarget, enviar) }, icono('enviar'), 'Enviar a aprobación'));
  if (act?.estado === 'APROBADA' || publicaDirecto) {
    acciones.append(h('fieldset', { clase: 'publicar-en' }, h('legend', {}, 'Publicar en:'),
      publicaDirecto ? h('p', { clase: 'suave pequeño' }, 'Su institución no exige aprobación previa: al publicar, queda registrado quién y cuándo.') : null,
      // Sin grupos, la API responde 422 "grupos: Es obligatorio" y la pantalla solo
      // decía "Los datos enviados no son válidos" (Hito 2 de Redes, sección 9.11).
      grupos.length
        ? grupos.map((g) => h('label', { clase: 'opcion' }, h('input', { type: 'checkbox', name: 'grupo', value: g.id }), g.nombre))
        : h('p', { clase: 'aviso', role: 'alert' }, 'Todavía no está en ningún grupo, así que no tiene a quién publicarle. Pídale a la coordinación que le asigne un grupo como docente (Grupos → Miembros).'),
      h('div', { clase: 'acciones' }, h('button', { type: 'button', onclick: (ev) => enCurso(ev.currentTarget, publicar), disabled: !grupos.length }, icono('enviar'), 'Publicar'))));
  }

  async function guardar() {
    try {
      const datos = { titulo: form.titulo.value, descripcion: form.descripcion.value || null, nivel: form.nivel.value, categoria: form.categoria.value, preguntas: leerPreguntas(preguntas) };
      const r = act ? await api('PATCH', `/actividades/${act.id}`, datos) : await api('POST', '/actividades', datos);
      mensaje('Borrador guardado.');
      location.hash = `#/actividades/${r.id}`;
      if (act) editor(r.id);
    } catch (e) { errorEn(form, e); }
  }
  async function enviar() {
    try { await api('POST', `/actividades/${act.id}/enviar`); mensaje('Enviada a aprobación.'); editor(act.id); } catch (e) { errorEn(form, e); }
  }
  async function publicar() {
    const ids = [...acciones.querySelectorAll('input[name=grupo]:checked')].map((i) => Number(i.value));
    if (!ids.length) { mensaje('Elija al menos un grupo para publicar.', 'error'); return; }
    try { await api('POST', `/actividades/${act.id}/publicar`, { grupos: ids }); mensaje('Actividad publicada.'); editor(act.id); } catch (e) { errorEn(form, e); }
  }

  montar(
    encabezado(act ? act.titulo : 'Nueva actividad', {
      antetitulo: 'Editor de actividades',
      bajada: act ? null : 'Escriba el enunciado, las opciones y marque la correcta. Cada pregunta mide al menos una habilidad.',
      acciones: act ? etiquetaEstado(act.estado) : null,
    }),
    act?.observaciones_rechazo && act.estado !== 'PUBLICADA' ? h('p', { clase: 'aviso' }, `Observaciones de la coordinación: ${act.observaciones_rechazo}`) : null,
    form, acciones,
    act ? seccion('Historial', { icono: 'reloj' },
      act.transiciones.length
        ? h('ol', { clase: 'linea-tiempo' }, act.transiciones.map((t) => h('li', {},
          h('time', {}, fecha(t.creado_en)), h('div', {}, h('strong', {}, `${t.desde || 'Creación'} → ${t.hacia}`), ` · ${t.autor}`),
          t.observaciones ? h('div', { clase: 'suave' }, t.observaciones) : null)))
        : vacio('Sin cambios de estado todavía.')) : null,
  );
}

function agregarPregunta(contenedor, p, editable, habilidades = []) {
  const opciones = h('div', { clase: 'opciones-editor' });
  // D-3: cada pregunta mide una o más habilidades.
  const marcadas = new Set(p?.habilidades || []);
  const habilidadesPregunta = h('fieldset', { clase: 'habilidades' }, h('legend', {}, 'Habilidades que mide (al menos una)'),
    habilidades.map((x) => h('label', { clase: 'opcion', title: x.descripcion || '' },
      h('input', { type: 'checkbox', value: x.codigo, checked: marcadas.has(x.codigo), disabled: !editable }), x.nombre)));
  const numeroPregunta = h('span', { clase: 'pregunta-numero' });
  const bloque = h('div', { clase: 'tarjeta pregunta' },
    h('div', { clase: 'pregunta-cabeza' }, numeroPregunta,
      editable ? h('button', { type: 'button', clase: 'peligro chico', onclick: () => { bloque.remove(); renumerar(contenedor); } }, icono('papelera'), 'Quitar pregunta') : null),
    h('label', {}, 'Enunciado'), h('textarea', { clase: 'enunciado', disabled: !editable, placeholder: 'Escriba la pregunta' }, p?.enunciado || ''),
    habilidadesPregunta,
    h('p', { clase: 'suave pequeño' }, 'Marque la única opción correcta.'), opciones,
    editable ? h('div', { clase: 'acciones' },
      h('button', { type: 'button', clase: 'secundario chico', onclick: () => { agregarOpcion(opciones, null, editable); renumerar(contenedor); } }, icono('mas'), 'Opción')) : null);
  (p?.opciones || [null, null]).forEach((o) => agregarOpcion(opciones, o, editable));
  contenedor.append(bloque);
  renumerar(contenedor);
}

function renumerar(contenedor) {
  contenedor.querySelectorAll('.pregunta').forEach((b, i) => {
    b.querySelector('.pregunta-numero').textContent = `Pregunta ${i + 1}`;
    b.querySelectorAll('.opciones-editor .letra').forEach((l, j) => { l.textContent = String.fromCharCode(65 + j); });
  });
}

let contadorRadio = 0;
function agregarOpcion(contenedor, o, editable) {
  const nombre = contenedor.dataset.radio || (contenedor.dataset.radio = `correcta-${++contadorRadio}`);
  contenedor.append(h('div', { clase: 'fila' },
    h('span', { clase: 'letra', 'aria-hidden': 'true' }),
    h('input', { clase: 'texto-opcion', value: o?.texto || '', placeholder: 'Texto de la opción', disabled: !editable, 'aria-label': 'Texto de la opción' }),
    h('label', { clase: 'opcion' }, h('input', { type: 'radio', name: nombre, checked: !!o?.correcta, disabled: !editable }), 'Correcta')));
}

function leerPreguntas(contenedor) {
  return [...contenedor.querySelectorAll('.pregunta')].map((b) => ({
    enunciado: b.querySelector('.enunciado').value,
    opciones: [...b.querySelectorAll('.opciones-editor .fila')].map((f) => ({ texto: f.querySelector('.texto-opcion').value, correcta: f.querySelector('input[type=radio]').checked }))
      .filter((o) => o.texto.trim() !== ''),
    habilidades: [...b.querySelectorAll('.habilidades input:checked')].map((i) => i.value),
  }));
}

// ---------- Reportes (RF-13) ----------
export async function reportes() {
  const grupos = await api('GET', '/grupos');
  const resultado = h('div', {});
  const form = h('form', { clase: 'tarjeta fila' },
    h('div', {}, h('label', { for: 'grupo' }, 'Grupo'), h('select', { id: 'grupo', name: 'grupo' }, h('option', { value: '' }, 'Todos'), grupos.map((g) => h('option', { value: g.id }, g.nombre)))),
    h('div', {}, h('label', { for: 'desde' }, 'Desde'), h('input', { id: 'desde', name: 'desde', type: 'date' })),
    h('div', {}, h('label', { for: 'hasta' }, 'Hasta'), h('input', { id: 'hasta', name: 'hasta', type: 'date' })),
    h('div', { clase: 'encoger' }, h('button', { type: 'submit' }, icono('buscar'), 'Consultar')));
  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    try {
      const r = await api('GET', '/reportes', null, { grupo: form.grupo.value, desde: form.desde.value, hasta: form.hasta.value });
      const puntajes = r.filas.map((x) => Number(x.puntaje)).filter((x) => !Number.isNaN(x));
      const activos = r.filas.map((x) => x.duracion_activa_seg).filter((x) => x !== null && x !== undefined).map(Number);
      const media = (v) => (v.length ? v.reduce((a, b) => a + b, 0) / v.length : null);
      resultado.replaceChildren(
        h('div', { clase: 'cifras' },
          cifra(r.filas.length, 'Intentos finalizados', { icono: 'check' }),
          cifra(numero(media(puntajes)), 'Puntaje promedio', { icono: 'grafico' }),
          cifra(segundos(activos.length ? Math.round(media(activos)) : null), 'Tiempo activo medio', { icono: 'reloj' })),
        seccion('Resumen por actividad', { icono: 'actividades' },
          tabla([{ titulo: 'Actividad', valor: (x) => h('strong', {}, x.actividad_titulo) }, { titulo: 'Nivel', valor: (x) => textoCodigo(x.nivel) }, { titulo: 'Categoría', valor: (x) => textoCodigo(x.categoria) },
            { titulo: 'Estudiantes', valor: (x) => x.estudiantes }, { titulo: 'Intentos', valor: (x) => x.intentos }, { titulo: 'Promedio', valor: (x) => medidor(x.promedio, { texto: numero(x.promedio) }) },
            { titulo: 'Tiempo medio (total)', valor: (x) => segundos(x.duracion_media_seg) },
            { titulo: 'Tiempo medio activo', valor: (x) => segundos(x.duracion_activa_media_seg) }], r.resumen),
          h('p', { clase: 'suave pequeño' }, 'Tiempo activo = total menos las pausas de más de 60 s sin actividad.')),
        seccion(`Intentos finalizados (${r.filas.length})`, { icono: 'reloj' },
          tabla([{ titulo: 'Fecha', valor: (x) => fecha(x.finalizado_en) }, { titulo: 'Estudiante', valor: (x) => `${x.estudiante_nombre} ${x.estudiante_apellido}` },
            { titulo: 'Actividad', valor: (x) => x.actividad_titulo }, { titulo: 'Puntaje', valor: (x) => numero(x.puntaje) },
            { titulo: 'Tiempo total', valor: (x) => segundos(x.duracion_seg) }, { titulo: 'Tiempo activo', valor: (x) => segundos(x.duracion_activa_seg) }],
          r.filas.slice(0, 200))));
    } catch (e) { errorEn(form, e); }
  });
  montar(encabezado('Estadísticas y reportes', {
    antetitulo: 'Reportes',
    bajada: 'Filtre por grupo y período. El tiempo activo descuenta las pausas; los dos tiempos se muestran por separado (D-8).',
    acciones: h('button', { type: 'button', clase: 'secundario', onclick: () => window.print() }, icono('libro'), 'Imprimir'),
  }), form, resultado);
  form.requestSubmit();
}

// ---------- Asistente (RF-20) ----------
const SUGERENCIAS = ['¿Cómo viene el grupo 3A en resolución de problemas?', '¿Qué preguntas costaron más este mes?', '¿Quiénes requieren atención en el grupo?'];

export async function asistente() {
  const dialogo = h('div', { clase: 'dialogo', 'aria-live': 'polite' });
  const historial = await api('GET', '/asistente/consultas');
  historial.reverse().forEach((c) => pintarIntercambio(dialogo, c.pregunta, c));
  const area = h('textarea', { id: 'pregunta', name: 'pregunta', placeholder: '¿Cómo viene el grupo 3A en resolución de problemas?' });
  const form = h('form', { clase: 'tarjeta' },
    h('label', { for: 'pregunta' }, 'Pregunta'), area,
    h('div', { clase: 'sugerencias', 'aria-label': 'Preguntas de ejemplo' },
      SUGERENCIAS.map((t) => h('button', { type: 'button', onclick: () => { area.value = t; area.focus(); } }, t))),
    h('div', { clase: 'acciones' }, h('button', { type: 'submit' }, icono('enviar'), 'Preguntar')));
  area.addEventListener('keydown', (ev) => { if (ev.key === 'Enter' && (ev.ctrlKey || ev.metaKey)) form.requestSubmit(); });
  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const pregunta = form.pregunta.value.trim();
    if (!pregunta) return;
    const boton = form.querySelector('button[type=submit]');
    boton.disabled = true;
    boton.replaceChildren('Redactando…');
    try {
      const r = await api('POST', '/asistente/consultas', { pregunta });
      pintarIntercambio(dialogo, pregunta, r);
      form.pregunta.value = '';
    } catch (e) { errorEn(form, e); } finally { boton.disabled = false; boton.replaceChildren(icono('enviar'), 'Preguntar'); }
  });
  montar(encabezado('Asistente', {
    antetitulo: 'Opcional',
    bajada: 'Las consultas guiadas son la forma principal de consultar. El asistente redacta sobre datos ya calculados por ATLAS.',
  }),
  h('p', { clase: 'aviso info' }, 'El asistente solo redacta sobre datos ya calculados por ATLAS. Al modelo externo no se envían nombres ni datos identificables: podés ver exactamente qué se envió en cada respuesta.'),
  dialogo, form);
}

function pintarIntercambio(dialogo, pregunta, r) {
  dialogo.append(
    h('div', { clase: 'burbuja docente' }, pregunta),
    h('div', { clase: 'burbuja atlas' },
      h('div', { clase: 'burbuja-autor' }, h('img', { src: '/assets/isotipo.png', alt: '', width: 18, height: 18 }), 'ATLAS'),
      h('p', {}, r.respuesta || ''),
      r.estado === 'LLM_NO_DISPONIBLE' ? h('p', { clase: 'aviso' }, 'Redacción no disponible: se muestran los datos verificados.') : null,
      r.contexto_enviado ? h('details', {}, h('summary', {}, 'Qué se envió al modelo'), h('pre', {}, JSON.stringify(r.contexto_enviado, null, 2))) : null));
}
