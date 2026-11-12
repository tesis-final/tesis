// Vistas del estudiante (RF-04, RF-06..RF-09). Ve solo sus actividades y su
// resultado; no accede a indicadores ni recomendaciones (H4, DEC-00b).

import { api } from '../api.js';
import { h, montar, mensaje, numero, encabezado, vacio, cifra, icono, confirmar, textoError } from '../ui.js';
import { anillo } from '../graficos.js';
import { Registro } from '../registro.js';
import { estado } from '../app.js';

function tarjetaActividad(a) {
  const hecho = a.ultimo_puntaje !== null;
  return h('article', { clase: 'tarjeta interactiva' },
    h('div', { clase: 'tarjeta-cabeza' },
      h('div', {},
        // D-6: la siguiente actividad la sugiere el sistema y la decide el docente.
        a.recomendada ? h('p', { clase: 'etiqueta recomendada' }, 'Recomendada por tu docente') : null,
        h('h2', {}, a.titulo),
        h('p', { clase: 'suave pequeño' }, `${a.categoria_nombre} · Nivel ${a.nivel_nombre} · ${a.total_preguntas} preguntas`)),
      hecho ? anillo(a.ultimo_puntaje, { tamano: 64, grosor: 7, subtitulo: 'último', etiqueta: `Último resultado: ${numero(a.ultimo_puntaje)} de 100` }) : null),
    a.descripcion ? h('p', {}, a.descripcion) : null,
    hecho ? h('p', { clase: 'suave pequeño' }, `Último resultado: ${numero(a.ultimo_puntaje)} / 100`) : null,
    h('div', { clase: 'acciones' }, h('a', { clase: 'boton', href: `#/resolver/${a.id}` }, Number(a.intentos) > 0 ? 'Intentar de nuevo' : 'Comenzar', icono('derecha'))));
}

export async function inicio() {
  const actividades = await api('GET', '/estudiante/actividades');
  // La recomendada por el docente va primero; si no hay, la primera sin hacer y, si ya
  // hizo todas, la de puntaje más bajo para seguir practicando.
  const practicar = [...actividades].filter((a) => a.ultimo_puntaje !== null).sort((x, y) => Number(x.ultimo_puntaje) - Number(y.ultimo_puntaje))[0];
  const proxima = actividades.find((a) => a.recomendada) || actividades.find((a) => Number(a.intentos) === 0) || practicar || null;
  const resto = actividades.filter((a) => a !== proxima);
  montar(
    encabezado('Mis actividades', {
      antetitulo: estado.usuario ? `Hola, ${estado.usuario.nombre}` : null,
      bajada: 'Resolvé una pregunta por vez. Podés pausar: el tiempo activo no cuenta las pausas.',
    }),
    proxima ? h('section', { clase: 'heroe', 'aria-labelledby': 'proxima-titulo' },
      h('div', { clase: 'heroe-cuerpo' },
        h('div', {},
          h('div', { clase: 'antetitulo' }, proxima.recomendada ? 'Recomendada por tu docente' : Number(proxima.intentos) === 0 ? 'Tu próxima actividad' : 'Para seguir practicando'),
          h('h2', { id: 'proxima-titulo', clase: 'acceso-titulo' }, proxima.titulo),
          h('p', {}, `${proxima.categoria_nombre} · Nivel ${proxima.nivel_nombre} · ${proxima.total_preguntas} preguntas`),
          proxima.descripcion ? h('p', {}, proxima.descripcion) : null,
          h('div', { clase: 'acciones' }, h('a', { clase: 'boton', href: `#/resolver/${proxima.id}` }, Number(proxima.intentos) > 0 ? 'Intentar de nuevo' : 'Comenzar ahora', icono('derecha')))),
        proxima.ultimo_puntaje !== null ? anillo(proxima.ultimo_puntaje, { tamano: 120, grosor: 10, subtitulo: 'último' }) : null)) : null,
    actividades.length
      ? h('div', { clase: 'rejilla dos' }, resto.map(tarjetaActividad))
      : vacio('Todavía no hay actividades publicadas para tus grupos.'),
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
  const pasos = h('div', { clase: 'pasos', 'aria-hidden': 'true' }, preguntas.map(() => h('span')));

  function pintarPasos() {
    [...pasos.children].forEach((s, i) => {
      s.className = i === actual ? 'actual' : elegidas.has(preguntas[i].id) ? 'hecho' : '';
    });
  }

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
    const opciones = p.opciones.map((o, j) => h('label', { clase: 'opcion' },
      h('input', { type: 'radio', name: nombre, value: o.id, checked: elegidas.get(p.id) === o.id,
        onchange: () => elegir(p, o.id) }),
      h('span', { clase: 'letra', 'aria-hidden': 'true' }, String.fromCharCode(65 + j)),
      h('span', {}, o.texto)));
    contenedor.replaceChildren(h('section', { clase: 'tarjeta pregunta' },
      h('fieldset', {}, h('legend', {}, `${indice + 1}. ${p.enunciado}`), opciones),
      h('div', { clase: 'acciones' },
        h('button', { type: 'button', clase: 'secundario', disabled: indice === 0, onclick: () => mostrar(indice - 1, indice) }, icono('izquierda'), 'Anterior'),
        indice < preguntas.length - 1
          ? h('button', { type: 'button', onclick: () => mostrar(indice + 1, indice) }, 'Siguiente', icono('derecha'))
          : h('button', { type: 'button', onclick: finalizar }, icono('check'), 'Finalizar'),
      ),
      h('p', { clase: 'atajos' }, 'Atajo: teclas ', h('kbd', {}, '1'), '–', h('kbd', {}, String(Math.min(9, p.opciones.length))), ' para elegir una opción.')));
    pintarPasos();
  }

  async function elegir(p, opcionId) {
    const anterior = elegidas.get(p.id);
    if (anterior === opcionId) return;
    elegidas.set(p.id, opcionId);
    pintarPasos();
    registro.evento(anterior === undefined ? 'SELECCION' : 'CAMBIO_OPCION', { pregunta_id: p.id, opcion_id: opcionId });
    const segundos = Math.round((Date.now() - inicioPregunta.get(p.id)) / 1000);
    try {
      await api('PUT', `/intentos/${intento.id}/respuestas/${p.id}`, { opcion_id: opcionId, tiempo_seg: segundos });
    } catch (e) {
      mensaje(`No se pudo guardar la respuesta: ${textoError(e)}`, 'error');
    }
  }

  // Teclas 1–9: eligen la opción como si se hiciera clic (mismo registro de eventos).
  function alTeclear(ev) {
    if (!document.body.contains(contenedor)) { document.removeEventListener('keydown', alTeclear); return; }
    if (ev.ctrlKey || ev.metaKey || ev.altKey || /^(TEXTAREA|SELECT)$/.test(ev.target.tagName) || (ev.target.tagName === 'INPUT' && ev.target.type !== 'radio')) return;
    const n = Number(ev.key);
    const p = preguntas[actual];
    if (Number.isInteger(n) && n >= 1 && n <= Math.min(9, p.opciones.length)) {
      const entrada = contenedor.querySelectorAll('.opcion input')[n - 1];
      entrada.checked = true;
      entrada.focus();
      elegir(p, p.opciones[n - 1].id);
      ev.preventDefault();
    }
  }
  document.addEventListener('keydown', alTeclear);

  async function finalizar() {
    const faltan = preguntas.length - elegidas.size;
    if (faltan > 0 && !(await confirmar(`Te ${faltan === 1 ? 'falta 1 pregunta' : `faltan ${faltan} preguntas`} por responder. Las que no respondas cuentan como incorrectas.`, { titulo: '¿Finalizar igual?', aceptar: 'Finalizar', cancelar: 'Seguir respondiendo' }))) return;
    document.removeEventListener('keydown', alTeclear);
    await registro.cerrar();
    const r = await api('POST', `/intentos/${intento.id}/finalizar`);
    location.hash = `#/resultado/${r.intento.id}`;
  }

  async function salir() {
    document.removeEventListener('keydown', alTeclear);
    await registro.cerrar();
    await api('POST', `/intentos/${intento.id}/abandonar`);
    location.hash = '#/';
  }

  // "Salir sin finalizar" va al final, lejos del título: así no se toca sin querer.
  montar(h('div', { clase: 'foco' },
    encabezado(actividad.titulo, {
      antetitulo: `${actividad.categoria} · Nivel ${actividad.nivel}${datos.reanudado ? ' · Intento retomado' : ''}`,
    }),
    progreso, pasos, contenedor,
    h('div', { clase: 'acciones' }, h('button', { type: 'button', clase: 'fantasma', onclick: salir }, icono('salir'), 'Salir sin finalizar'))));
  mostrar(0);
}

function duracion(segundos) {
  if (segundos === null || segundos === undefined) return '—';
  const s = Number(segundos);
  return s >= 60 ? `${Math.floor(s / 60)} min ${s % 60} s` : `${s} s`;
}

export async function resultado(intentoId) {
  const r = await api('GET', `/intentos/${intentoId}/resultado`);
  const puntaje = Number(r.puntaje);
  const frase = puntaje >= 90 ? '¡Excelente trabajo!' : puntaje >= 70 ? 'Muy bien, vas por buen camino.' : puntaje >= 50 ? 'Bien. Revisá las que fallaste y volvé a intentar.' : 'Seguí practicando: cada intento cuenta.';
  montar(h('div', { clase: 'foco' },
    h('section', { clase: 'heroe', 'aria-labelledby': 'resultado-titulo' },
      h('div', { clase: 'heroe-cuerpo' },
        h('div', {}, h('div', { clase: 'antetitulo' }, 'Actividad finalizada'), h('h1', { id: 'resultado-titulo' }, 'Resultado'), h('p', {}, frase)),
        anillo(puntaje, { tamano: 132, grosor: 11, subtitulo: 'de 100', etiqueta: `Puntaje: ${numero(puntaje)} de 100` }))),
    h('div', { clase: 'cifras' },
      cifra(`${numero(r.puntaje)} / 100`, 'Puntaje', { icono: 'estrella' }),
      cifra(`${r.correctas} de ${r.total_preguntas}`, 'Respuestas correctas', { icono: 'check' }),
      cifra(duracion(r.intento.duracion_seg), 'Tiempo total', { icono: 'reloj' }),
      // D-8: el tiempo activo descuenta las pausas (más de 60 s sin actividad o pestaña oculta).
      r.intento.duracion_activa_seg !== null ? cifra(duracion(r.intento.duracion_activa_seg), 'Tiempo activo', { icono: 'rayo', detalle: 'sin contar las pausas' }) : null),
    h('section', { clase: 'tarjeta' }, h('div', { clase: 'tarjeta-cabeza' }, h('h2', {}, icono('consultas'), 'Detalle')),
      h('ol', { clase: 'detalle-lista' }, r.detalle.map((d) => h('li', { clase: d.acerto ? 'acierto' : 'error' },
        h('div', {}, h('span', { clase: 'estado-respuesta' }, d.acerto ? 'Correcta' : (d.opcion_elegida_id ? 'Incorrecta' : 'Sin responder')), d.enunciado))))),
    h('div', { clase: 'acciones' }, h('a', { clase: 'boton', href: '#/' }, icono('izquierda'), 'Volver a mis actividades'))));
}
