// Vistas del docente (RF-10..RF-13, RF-16..RF-18, RF-20). La primera pantalla
// responde "¿dónde intervengo hoy?" (§20.4): prioritarios y preguntas con más error.

import { api } from '../api.js';
import { h, montar, mensaje, tabla, etiquetaTipo, etiquetaEstado, fecha, numero, errorEn } from '../ui.js';
import { estado } from '../app.js';

// ---------- Dónde intervenir ----------
export async function inicio() {
  const grupos = await api('GET', '/grupos');
  if (!grupos.length) {
    montar(h('h1', {}, 'Dónde intervenir hoy'), h('p', { clase: 'vacio' }, 'Todavía no tiene grupos asignados.'));
    return;
  }
  const tarjetas = await Promise.all(grupos.map(async (g) => {
    try {
      const a = await api('GET', `/docente/grupos/${g.id}/analisis`);
      return tarjetaGrupo(g, a);
    } catch (e) {
      return h('article', { clase: 'tarjeta' }, h('h2', {}, g.nombre), h('p', { clase: 'aviso' }, e.message));
    }
  }));
  montar(h('h1', {}, 'Dónde intervenir hoy'),
    h('p', { clase: 'suave' }, 'Primero, quienes necesitan atención; después, las preguntas que más cuestan. El detalle está en cada grupo.'),
    h('div', { clase: 'rejilla dos' }, tarjetas));
}

function tarjetaGrupo(g, a) {
  return h('article', { clase: 'tarjeta' },
    h('h2', {}, `Grupo ${g.nombre}`),
    h('p', { clase: 'suave pequeño' }, `${a.estudiantes} estudiantes · promedio ${numero(a.agregados.promedio)} · período ${a.periodo.desde} a ${a.periodo.hasta}`),
    h('h3', {}, `Atención prioritaria (${a.prioritarios.length})`),
    a.prioritarios.length
      ? h('ul', {}, a.prioritarios.slice(0, 5).map((p) => h('li', {},
          h('a', { href: `#/estudiante/${p.estudiante_id}` }, p.nombre), ' — ', h('span', { clase: 'pequeño' }, p.motivo))))
      : h('p', { clase: 'vacio' }, 'Nadie disparó reglas de riesgo en el período.'),
    h('h3', {}, 'Preguntas con más error'),
    a.preguntas_con_mas_error.length
      ? h('ul', {}, a.preguntas_con_mas_error.slice(0, 3).map((q) => h('li', {}, `${Math.round(q.proporcion_error * 100)} % de error — ${q.enunciado}`)))
      : h('p', { clase: 'vacio' }, 'Sin errores registrados.'),
    h('a', { clase: 'boton secundario', href: `#/grupo/${g.id}` }, 'Ver análisis del grupo'));
}

// ---------- Análisis grupal completo (RF-18) ----------
export async function grupo(id) {
  const a = await api('GET', `/docente/grupos/${id}/analisis`);
  const max = Math.max(1, ...a.distribucion.map((d) => Number(d.cantidad)));
  const ml = a.aprendizaje_automatico;
  montar(
    h('h1', {}, `Grupo ${a.grupo.nombre}`),
    h('p', { clase: 'suave' }, `Período ${a.periodo.desde} a ${a.periodo.hasta}`),
    h('div', { clase: 'cifras' },
      cifra(a.agregados.n_estudiantes, 'Estudiantes con datos'), cifra(numero(a.agregados.promedio), 'Promedio'),
      cifra(numero(a.agregados.mediana), 'Mediana'), cifra(numero(a.agregados.minimo), 'Mínimo'), cifra(numero(a.agregados.maximo), 'Máximo')),
    h('div', { clase: 'rejilla tres' },
      h('section', { clase: 'tarjeta' }, h('h2', {}, 'Atención prioritaria'),
        tabla([
          { titulo: 'Estudiante', valor: (p) => h('a', { href: `#/estudiante/${p.estudiante_id}` }, p.nombre) },
          { titulo: 'Motivo (reglas)', valor: (p) => p.motivo },
          { titulo: 'Última señal', valor: (p) => fecha(p.ultima) },
        ], a.prioritarios, 'Nadie disparó reglas de riesgo en el período.')),
      h('section', { clase: 'tarjeta' }, h('h2', {}, 'Distribución de puntajes'),
        h('ul', { clase: 'barras' }, a.distribucion.map((d) => h('li', {},
          h('span', {}, d.rango), barra(Number(d.cantidad) / max),
          h('span', {}, String(d.cantidad))))))),
    h('section', { clase: 'tarjeta' }, h('h2', {}, 'Preguntas con mayor proporción de error'),
      tabla([
        { titulo: 'Pregunta', valor: (q) => q.enunciado },
        { titulo: 'Error', valor: (q) => `${Math.round(q.proporcion_error * 100)} % (${q.errores} de ${q.respuestas})` },
      ], a.preguntas_con_mas_error, 'Sin errores registrados.')),
    seccionHabilidades(a.habilidades, true),
    h('section', { clase: 'tarjeta' }, h('h2', {}, 'Patrones de resolución (aprendizaje automático)'),
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
// texto ("A reforzar"), no solo con color (RNF-12).
function seccionHabilidades(habilidades, grupal) {
  return h('section', { clase: 'tarjeta' }, h('h2', {}, 'Acierto por habilidad'),
    tabla([
      { titulo: 'Habilidad', valor: (x) => x.nombre },
      { titulo: 'Acierto', valor: (x) => `${numero(x.porcentaje)} % (${x.correctas} de ${x.preguntas} preguntas)` },
      grupal ? { titulo: 'Estudiantes por debajo del 50 %', valor: (x) => `${x.estudiantes_bajo_umbral} de ${x.estudiantes}` } : null,
      { titulo: 'Estado', valor: (x) => (x.a_reforzar ? h('strong', {}, 'A reforzar') : 'Adecuado') },
    ].filter(Boolean), habilidades || [], 'Todavía no hay preguntas resueltas vinculadas a habilidades en el período.'),
    h('p', { clase: 'suave pequeño' }, 'Porcentaje de preguntas acertadas en el último intento de cada actividad. Describe aciertos; no mide capacidades.'));
}

// El ancho se fija por CSSOM (no con atributo style) para cumplir la política CSP.
function barra(proporcion) {
  const el = h('span', { clase: 'barra-valor', 'aria-hidden': 'true' });
  el.style.width = `${Math.round(proporcion * 100)}%`;
  return el;
}

function suficiencia(s) {
  if (!s) return 'Todavía no hay agrupamientos para este período.';
  return `Todavía no hay datos suficientes para un análisis confiable: ${s.estudiantes_con_datos ?? 0} de ${s.requeridos ?? 20} estudiantes con la cantidad mínima de intentos. `
    + 'Mostrar agrupamientos con menos datos sería engañoso.';
}

function cifra(valor, texto) {
  return h('div', { clase: 'cifra' }, h('strong', {}, String(valor ?? '—')), texto);
}

// ---------- Perfil individual + "¿por qué?" (RF-10, RF-12) ----------
export async function estudiante(id) {
  const p = await api('GET', `/docente/estudiantes/${id}/perfil`);
  const porActividad = new Map();
  for (const i of p.indicadores) {
    if (!porActividad.has(i.actividad_id)) porActividad.set(i.actividad_id, { actividad: i.actividad, categoria: i.categoria });
    porActividad.get(i.actividad_id)[i.tipo] = i.valor;
  }
  const fundamento = h('div', {});
  montar(
    h('h1', {}, 'Perfil de aprendizaje'),
    h('p', { clase: 'aviso info' }, p.aviso),
    h('section', { clase: 'tarjeta' }, h('h2', {}, `Indicadores (${p.periodo.desde} a ${p.periodo.hasta})`),
      tabla([
        { titulo: 'Actividad', valor: (f) => f.actividad }, { titulo: 'Categoría', valor: (f) => f.categoria },
        { titulo: 'Puntaje', valor: (f) => numero(f.PUNTAJE) }, { titulo: 'Eficiencia', valor: (f) => numero(f.EFICIENCIA, 2) },
        { titulo: 'Mejora', valor: (f) => numero(f.MEJORA) }, { titulo: 'Persistencia', valor: (f) => numero(f.PERSISTENCIA, 0) },
      ], [...porActividad.values()], 'Sin actividades finalizadas en el período.')),
    seccionHabilidades(p.habilidades, false),
    h('section', { clase: 'tarjeta' }, h('h2', {}, 'Recomendaciones'),
      p.recomendaciones.length
        ? h('ul', {}, p.recomendaciones.map((r) => h('li', {},
            h('p', {}, r.reglas.map((x) => etiquetaTipo(x.tipo)), ' ', r.texto),
            h('button', { type: 'button', clase: 'secundario', onclick: () => verFundamento(r.id, fundamento) }, '¿Por qué?'))))
        : h('p', { clase: 'vacio' }, 'Sin recomendaciones en el período.'),
      fundamento),
    h('section', { clase: 'tarjeta' }, h('h2', {}, 'Evolución'),
      tabla([
        { titulo: 'Fecha', valor: (e) => fecha(e.finalizado_en) }, { titulo: 'Actividad', valor: (e) => e.actividad_titulo },
        { titulo: 'Intento', valor: (e) => e.numero_intento }, { titulo: 'Puntaje', valor: (e) => numero(e.puntaje) },
      ], p.evolucion, 'Sin intentos finalizados.')),
  );
}

async function verFundamento(id, destino) {
  const f = await api('GET', `/recomendaciones/${id}/fundamento`);
  destino.replaceChildren(h('div', { clase: 'tarjeta' },
    h('h3', {}, 'Fundamento de la recomendación'),
    h('p', {}, f.texto),
    f.reglas.map((r) => h('div', {},
      h('p', {}, etiquetaTipo(r.tipo), ' ', h('strong', {}, `${r.codigo} — ${r.nombre}`), ` (versión ${r.version_regla})`),
      h('p', { clase: 'suave' }, r.descripcion),
      h('p', {}, 'Datos usados: ', Object.entries(r.valores_entrada.valores || {})
        .filter(([k]) => k !== 'sin_dato').map(([k, v]) => `${k} = ${numero(v, 2)}`).join(' · ')))),
    h('p', { clase: 'suave pequeño' }, 'La regla y sus umbrales están guardados en ATLAS y los puede revisar la coordinación.')));
  destino.scrollIntoView({ behavior: 'smooth' });
}

// ---------- Actividades (RF-16, RF-17) ----------
export async function actividades() {
  const lista = await api('GET', '/actividades');
  montar(
    h('div', { clase: 'fila' }, h('h1', {}, 'Mis actividades'), h('div', {}, h('a', { clase: 'boton', href: '#/actividades/nueva' }, '+ Nueva actividad'))),
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
  const preguntas = h('div', {});
  const form = h('form', { clase: 'tarjeta', novalidate: true },
    h('label', { for: 'titulo' }, 'Título'), h('input', { id: 'titulo', name: 'titulo', value: act?.titulo || '', disabled: !editable }),
    h('label', { for: 'descripcion' }, 'Descripción'), h('textarea', { id: 'descripcion', name: 'descripcion', disabled: !editable }, act?.descripcion || ''),
    h('div', { clase: 'fila' },
      h('div', {}, h('label', { for: 'nivel' }, 'Nivel de dificultad'),
        h('select', { id: 'nivel', name: 'nivel', disabled: !editable }, cat.niveles.map((n) => h('option', { value: n.codigo, selected: act?.nivel === n.codigo }, n.nombre)))),
      h('div', {}, h('label', { for: 'categoria' }, 'Categoría'),
        h('select', { id: 'categoria', name: 'categoria', disabled: !editable }, cat.categorias.map((c) => h('option', { value: c.codigo, selected: act?.categoria === c.codigo }, c.nombre))))),
    h('h2', {}, 'Preguntas'), preguntas,
    editable ? h('button', { type: 'button', clase: 'secundario', onclick: () => agregarPregunta(preguntas, null, true, cat.habilidades) }, '+ Agregar pregunta') : null,
  );
  (act?.preguntas || []).forEach((p) => agregarPregunta(preguntas, p, editable, cat.habilidades));
  if (!act) agregarPregunta(preguntas, null, true, cat.habilidades);

  const acciones = h('div', { clase: 'acciones' });
  if (editable) acciones.append(h('button', { type: 'button', onclick: guardar }, 'Guardar borrador'));
  // D-2: si la institución no exige aprobación, el borrador se publica directo.
  const publicaDirecto = act?.estado === 'BORRADOR' && !act.requiere_aprobacion;
  if (act?.estado === 'BORRADOR' && act.requiere_aprobacion) acciones.append(h('button', { type: 'button', onclick: enviar }, 'Enviar a aprobación'));
  if (act?.estado === 'APROBADA' || publicaDirecto) {
    acciones.append(h('fieldset', {}, h('legend', {}, 'Publicar en:'),
      publicaDirecto ? h('p', { clase: 'suave pequeño' }, 'Su institución no exige aprobación previa: al publicar, queda registrado quién y cuándo.') : null,
      grupos.map((g) => h('label', { clase: 'opcion' }, h('input', { type: 'checkbox', name: 'grupo', value: g.id }), g.nombre)),
      h('button', { type: 'button', onclick: publicar }, 'Publicar')));
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
    try { await api('POST', `/actividades/${act.id}/publicar`, { grupos: ids }); mensaje('Actividad publicada.'); editor(act.id); } catch (e) { errorEn(form, e); }
  }

  montar(
    h('h1', {}, act ? act.titulo : 'Nueva actividad'),
    act ? h('p', {}, etiquetaEstado(act.estado)) : null,
    act?.observaciones_rechazo && act.estado !== 'PUBLICADA' ? h('p', { clase: 'aviso' }, `Observaciones de la coordinación: ${act.observaciones_rechazo}`) : null,
    form, acciones,
    act ? h('section', { clase: 'tarjeta' }, h('h2', {}, 'Historial'),
      tabla([{ titulo: 'Fecha', valor: (t) => fecha(t.creado_en) }, { titulo: 'De', valor: (t) => t.desde || '—' },
        { titulo: 'A', valor: (t) => t.hacia }, { titulo: 'Autor', valor: (t) => t.autor }, { titulo: 'Observaciones', valor: (t) => t.observaciones || '' }], act.transiciones)) : null,
  );
}

function agregarPregunta(contenedor, p, editable, habilidades = []) {
  const opciones = h('div', {});
  // D-3: cada pregunta mide una o más habilidades.
  const marcadas = new Set(p?.habilidades || []);
  const habilidadesPregunta = h('fieldset', { clase: 'habilidades' }, h('legend', {}, 'Habilidades que mide (al menos una)'),
    habilidades.map((x) => h('label', { clase: 'opcion', title: x.descripcion || '' },
      h('input', { type: 'checkbox', value: x.codigo, checked: marcadas.has(x.codigo), disabled: !editable }), x.nombre)));
  const bloque = h('div', { clase: 'tarjeta pregunta' },
    h('label', {}, 'Enunciado'), h('textarea', { clase: 'enunciado', disabled: !editable }, p?.enunciado || ''),
    habilidadesPregunta,
    h('p', { clase: 'suave pequeño' }, 'Marque la única opción correcta.'), opciones,
    editable ? h('div', { clase: 'acciones' },
      h('button', { type: 'button', clase: 'secundario', onclick: () => agregarOpcion(opciones, null, editable) }, '+ Opción'),
      h('button', { type: 'button', clase: 'peligro', onclick: () => bloque.remove() }, 'Quitar pregunta')) : null);
  (p?.opciones || [null, null]).forEach((o) => agregarOpcion(opciones, o, editable));
  contenedor.append(bloque);
}

let contadorRadio = 0;
function agregarOpcion(contenedor, o, editable) {
  const nombre = contenedor.dataset.radio || (contenedor.dataset.radio = `correcta-${++contadorRadio}`);
  contenedor.append(h('div', { clase: 'fila' },
    h('input', { clase: 'texto-opcion', value: o?.texto || '', placeholder: 'Texto de la opción', disabled: !editable, 'aria-label': 'Texto de la opción' }),
    h('label', { clase: 'opcion' }, h('input', { type: 'radio', name: nombre, checked: !!o?.correcta, disabled: !editable }), 'Correcta')));
}

function leerPreguntas(contenedor) {
  return [...contenedor.querySelectorAll('.pregunta')].map((b) => ({
    enunciado: b.querySelector('.enunciado').value,
    opciones: [...b.querySelectorAll('.fila')].map((f) => ({ texto: f.querySelector('.texto-opcion').value, correcta: f.querySelector('input[type=radio]').checked }))
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
    h('div', {}, h('button', { type: 'submit' }, 'Consultar')));
  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    try {
      const r = await api('GET', '/reportes', null, { grupo: form.grupo.value, desde: form.desde.value, hasta: form.hasta.value });
      resultado.replaceChildren(
        h('section', { clase: 'tarjeta' }, h('h2', {}, 'Resumen por actividad'),
          tabla([{ titulo: 'Actividad', valor: (x) => x.actividad_titulo }, { titulo: 'Nivel', valor: (x) => x.nivel }, { titulo: 'Categoría', valor: (x) => x.categoria },
            { titulo: 'Estudiantes', valor: (x) => x.estudiantes }, { titulo: 'Intentos', valor: (x) => x.intentos }, { titulo: 'Promedio', valor: (x) => numero(x.promedio) },
            { titulo: 'Tiempo medio', valor: (x) => `${x.duracion_media_seg} s` }], r.resumen)),
        h('section', { clase: 'tarjeta' }, h('h2', {}, `Intentos finalizados (${r.filas.length})`),
          tabla([{ titulo: 'Fecha', valor: (x) => fecha(x.finalizado_en) }, { titulo: 'Estudiante', valor: (x) => `${x.estudiante_nombre} ${x.estudiante_apellido}` },
            { titulo: 'Actividad', valor: (x) => x.actividad_titulo }, { titulo: 'Puntaje', valor: (x) => numero(x.puntaje) }], r.filas.slice(0, 200))));
    } catch (e) { errorEn(form, e); }
  });
  montar(h('h1', {}, 'Estadísticas y reportes'), form, resultado);
  form.requestSubmit();
}

// ---------- Asistente (RF-20) ----------
export async function asistente() {
  const dialogo = h('div', { clase: 'dialogo' });
  const historial = await api('GET', '/asistente/consultas');
  historial.reverse().forEach((c) => pintarIntercambio(dialogo, c.pregunta, c));
  const form = h('form', { clase: 'tarjeta' },
    h('label', { for: 'pregunta' }, 'Pregunta'),
    h('textarea', { id: 'pregunta', name: 'pregunta', placeholder: '¿Cómo viene el grupo 3A en resolución de problemas?' }),
    h('div', { clase: 'acciones' }, h('button', { type: 'submit' }, 'Preguntar')));
  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const pregunta = form.pregunta.value.trim();
    if (!pregunta) return;
    const boton = form.querySelector('button');
    boton.disabled = true;
    boton.textContent = 'Redactando…';
    try {
      const r = await api('POST', '/asistente/consultas', { pregunta });
      pintarIntercambio(dialogo, pregunta, r);
      form.pregunta.value = '';
    } catch (e) { errorEn(form, e); } finally { boton.disabled = false; boton.textContent = 'Preguntar'; }
  });
  montar(h('h1', {}, 'Asistente'),
    h('p', { clase: 'aviso info' }, 'El asistente solo redacta sobre datos ya calculados por ATLAS. Al modelo externo no se envían nombres ni datos identificables: podés ver exactamente qué se envió en cada respuesta.'),
    dialogo, form);
  void estado;
}

function pintarIntercambio(dialogo, pregunta, r) {
  dialogo.append(
    h('div', { clase: 'burbuja docente' }, pregunta),
    h('div', { clase: 'burbuja atlas' }, h('p', {}, r.respuesta || ''),
      r.estado === 'LLM_NO_DISPONIBLE' ? h('p', { clase: 'aviso' }, 'Redacción no disponible: se muestran los datos verificados.') : null,
      r.contexto_enviado ? h('details', {}, h('summary', {}, 'Qué se envió al modelo'), h('pre', {}, JSON.stringify(r.contexto_enviado, null, 2))) : null));
}
