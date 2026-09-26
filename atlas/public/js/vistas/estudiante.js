// Vistas del estudiante (RF-04, RF-06..RF-09). Ve solo sus actividades y su
// resultado; no accede a indicadores ni recomendaciones (H4, DEC-00b).

import { api } from '../api.js';
import { h, montar, mensaje, numero } from '../ui.js';
import { Registro } from '../registro.js';

export async function inicio() {
  const actividades = await api('GET', '/estudiante/actividades');
  montar(
    h('h1', {}, 'Mis actividades'),
    actividades.length
      ? h('div', { clase: 'rejilla dos' }, actividades.map((a) => h('article', { clase: 'tarjeta' },
          h('h2', {}, a.titulo),
          h('p', { clase: 'suave' }, `${a.categoria_nombre} · Nivel ${a.nivel_nombre} · ${a.total_preguntas} preguntas`),
          a.descripcion ? h('p', {}, a.descripcion) : null,
          a.ultimo_puntaje !== null ? h('p', {}, `Último resultado: ${numero(a.ultimo_puntaje)} / 100`) : null,
          h('a', { clase: 'boton', href: `#/resolver/${a.id}` }, Number(a.intentos) > 0 ? 'Intentar de nuevo' : 'Comenzar'))))
      : h('p', { clase: 'vacio' }, 'Todavía no hay actividades publicadas para tus grupos.'),
  );
}

export async function resolver(actividadId) {
  const datos = await api('POST', '/intentos', { actividad_id: Number(actividadId) });
  const { intento, actividad } = datos;
  const registro = new Registro(intento);
  const preguntas = actividad.preguntas;
  const elegidas = new Map();
  const inicioPregunta = new Map();
  let actual = 0;

  const contenedor = h('div', {});
  const progreso = h('p', { clase: 'progreso', 'aria-live': 'polite' });

  function mostrar(indice, origen) {
    if (origen !== undefined && origen !== indice) {
      registro.evento('NAVEGACION', { pregunta_id: preguntas[indice].id });
    }
    actual = indice;
    const p = preguntas[indice];
    inicioPregunta.set(p.id, inicioPregunta.get(p.id) ?? Date.now());
    registro.evento('VER_PREGUNTA', { pregunta_id: p.id });
    progreso.textContent = `Pregunta ${indice + 1} de ${preguntas.length}`;
    const nombre = `p${p.id}`;
    const opciones = p.opciones.map((o) => h('label', { clase: 'opcion' },
      h('input', { type: 'radio', name: nombre, value: o.id, checked: elegidas.get(p.id) === o.id,
        onchange: () => elegir(p, o.id) }),
      h('span', {}, o.texto)));
    contenedor.replaceChildren(h('section', { clase: 'tarjeta pregunta' },
      h('fieldset', {}, h('legend', {}, `${indice + 1}. ${p.enunciado}`), opciones),
      h('div', { clase: 'acciones' },
        h('button', { type: 'button', clase: 'secundario', disabled: indice === 0, onclick: () => mostrar(indice - 1, indice) }, '← Anterior'),
        indice < preguntas.length - 1
          ? h('button', { type: 'button', onclick: () => mostrar(indice + 1, indice) }, 'Siguiente →')
          : h('button', { type: 'button', onclick: finalizar }, 'Finalizar'),
      )));
  }

  async function elegir(p, opcionId) {
    const anterior = elegidas.get(p.id);
    elegidas.set(p.id, opcionId);
    registro.evento(anterior === undefined ? 'SELECCION' : 'CAMBIO_OPCION', { pregunta_id: p.id, opcion_id: opcionId });
    const segundos = Math.round((Date.now() - inicioPregunta.get(p.id)) / 1000);
    try {
      await api('PUT', `/intentos/${intento.id}/respuestas/${p.id}`, { opcion_id: opcionId, tiempo_seg: segundos });
    } catch (e) {
      mensaje(`No se pudo guardar la respuesta: ${e.message}`, 'error');
    }
  }

  async function finalizar() {
    const faltan = preguntas.length - elegidas.size;
    if (faltan > 0 && !confirm(`Te faltan ${faltan} pregunta(s). ¿Querés finalizar igual?`)) return;
    await registro.cerrar();
    const r = await api('POST', `/intentos/${intento.id}/finalizar`);
    location.hash = `#/resultado/${r.intento.id}`;
  }

  async function salir() {
    await registro.cerrar();
    await api('POST', `/intentos/${intento.id}/abandonar`);
    location.hash = '#/';
  }

  montar(
    h('h1', {}, actividad.titulo),
    h('p', { clase: 'suave' }, `${actividad.categoria} · Nivel ${actividad.nivel}${datos.reanudado ? ' · Intento retomado' : ''}`),
    progreso,
    contenedor,
    h('button', { type: 'button', clase: 'secundario', onclick: salir }, 'Salir sin finalizar'),
  );
  mostrar(0);
}

export async function resultado(intentoId) {
  const r = await api('GET', `/intentos/${intentoId}/resultado`);
  montar(
    h('h1', {}, 'Resultado'),
    h('div', { clase: 'cifras' },
      h('div', { clase: 'cifra' }, h('strong', {}, `${numero(r.puntaje)} / 100`), 'Puntaje'),
      h('div', { clase: 'cifra' }, h('strong', {}, `${r.correctas} de ${r.total_preguntas}`), 'Respuestas correctas'),
      h('div', { clase: 'cifra' }, h('strong', {}, `${r.intento.duracion_seg} s`), 'Tiempo'),
    ),
    h('section', { clase: 'tarjeta' }, h('h2', {}, 'Detalle'),
      h('ol', {}, r.detalle.map((d) => h('li', { clase: d.acerto ? 'acierto' : 'error' },
        `${d.enunciado} — ${d.acerto ? 'correcta' : (d.opcion_elegida_id ? 'incorrecta' : 'sin responder')}`)))),
    h('a', { clase: 'boton', href: '#/' }, 'Volver a mis actividades'),
  );
}
