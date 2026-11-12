// ATLAS — utilidades de interfaz. Todo el contenido se inserta como texto
// (nunca innerHTML con datos), para evitar inyección de código.

import { icono } from './iconos.js';

export function h(etiqueta, atributos = {}, ...hijos) {
  const el = document.createElement(etiqueta);
  for (const [clave, valor] of Object.entries(atributos || {})) {
    if (valor === null || valor === undefined || valor === false) continue;
    if (clave.startsWith('on') && typeof valor === 'function') el.addEventListener(clave.slice(2), valor);
    else if (clave === 'clase') el.className = valor;
    else if (valor === true) el.setAttribute(clave, '');
    else el.setAttribute(clave, valor);
  }
  for (const hijo of hijos.flat()) {
    if (hijo === null || hijo === undefined || hijo === false) continue;
    el.append(hijo instanceof Node ? hijo : document.createTextNode(String(hijo)));
  }
  return el;
}

export function montar(...nodos) {
  const app = document.getElementById('app');
  const lista = nodos.flat(Infinity).filter((n) => n !== null && n !== undefined && n !== false);
  app.replaceChildren(...lista);
  app.removeAttribute('aria-busy');
  document.getElementById('principal').focus({ preventScroll: true });
  // El título de la pestaña acompaña a la pantalla (lectores de pantalla e historial).
  const titulo = app.querySelector('h1');
  document.title = titulo ? `${titulo.textContent} · ATLAS` : 'ATLAS — Plataforma de aprendizaje';
}

/** Esqueleto que se ve mientras llega la respuesta de la API. */
export function esqueleto() {
  const app = document.getElementById('app');
  app.setAttribute('aria-busy', 'true');
  app.replaceChildren(h('div', { clase: 'esqueleto', 'aria-hidden': 'true' },
    h('i', { clase: 'h' }), h('i', {}),
    h('div', { clase: 'cifras' }, h('i', { clase: 'k' }), h('i', { clase: 'k' }), h('i', { clase: 'k' })),
    h('i', { clase: 'b' }), h('i', { clase: 'b' })));
}

export function mensaje(texto, tipo = 'info') {
  const zona = document.getElementById('mensajes');
  const m = h('div', { clase: `mensaje ${tipo}` }, h('span', {}, texto));
  const cerrar = h('button', { type: 'button', 'aria-label': 'Cerrar aviso', onclick: () => m.remove() }, '×');
  m.append(cerrar);
  zona.append(m);
  setTimeout(() => m.remove(), tipo === 'error' ? 8000 : 5000);
}

export function errorEn(formulario, error) {
  formulario.querySelectorAll('.campo-error').forEach((e) => e.remove());
  for (const [campo, texto] of Object.entries(error.errores || {})) {
    const entrada = formulario.querySelector(`[name="${CSS.escape(campo)}"]`);
    if (entrada) {
      entrada.setAttribute('aria-invalid', 'true');
      entrada.after(h('div', { clase: 'campo-error', role: 'alert' }, texto));
    }
  }
  mensaje(error.message, 'error');
}

/** Encabezado de página: antetítulo, título, bajada y acciones. */
export function encabezado(titulo, { antetitulo = null, bajada = null, acciones = null } = {}) {
  return h('header', { clase: 'encabezado' },
    h('div', { clase: 'encabezado-texto' },
      antetitulo ? h('div', { clase: 'antetitulo' }, antetitulo) : null,
      h('h1', {}, titulo),
      bajada ? h('p', { clase: 'bajada' }, bajada) : null),
    acciones ? h('div', { clase: 'encabezado-acciones' }, acciones) : null);
}

/** Tarjeta de sección con título e ícono. */
export function seccion(titulo, { icono: nombre = null, extra = null, clase = '' } = {}, ...contenido) {
  return h('section', { clase: `tarjeta ${clase}`.trim() },
    h('div', { clase: 'tarjeta-cabeza' }, h('h2', {}, nombre ? icono(nombre) : null, titulo), extra),
    contenido);
}

export function vacio(texto) {
  return h('p', { clase: 'vacio' }, texto);
}

/** Tabla que en celular se ve como tarjetas (RNF-12): cada celda lleva su etiqueta. */
export function tabla(columnas, filas, textoVacio = 'Sin datos.') {
  if (!filas.length) return vacio(textoVacio);
  return h('div', { clase: 'tabla-marco' }, h('table', { clase: 'tabla' },
    h('thead', {}, h('tr', {}, columnas.map((c) => h('th', { scope: 'col' }, c.titulo)))),
    h('tbody', {}, filas.map((f) => h('tr', {}, columnas.map((c) => {
      const valor = c.valor(f);
      return h('td', { 'data-etiqueta': c.titulo }, valor instanceof Node ? valor : (valor ?? '—'));
    }))))));
}

export function etiquetaTipo(tipo) {
  const nombres = { RIESGO: 'Riesgo', AVANCE: 'Avance', REFUERZO: 'Refuerzo', RECONOCIMIENTO: 'Reconocimiento' };
  return h('span', { clase: `etiqueta ${tipo}` }, nombres[tipo] || tipo);
}

export function etiquetaEstado(estado) {
  const nombres = { BORRADOR: 'Borrador', PENDIENTE: 'Pendiente de aprobación', APROBADA: 'Aprobada', RECHAZADA: 'Rechazada', PUBLICADA: 'Publicada' };
  return h('span', { clase: `etiqueta estado ${estado}` }, nombres[estado] || estado);
}

/** Resultado de auditoría con símbolo y texto. */
export function etiquetaResultado(resultado) {
  const clase = { OK: 'ok', DENEGADO: 'denegado', ERROR: 'fallo' }[resultado] || '';
  return h('span', { clase: `etiqueta ${clase}` }, resultado);
}

/** "R01 Puntaje bajo · R08 Dificultad…" → chips con el código de cada regla. */
export function chipsReglas(motivo) {
  const partes = String(motivo || '').split('·').map((x) => x.trim()).filter(Boolean);
  return h('span', { clase: 'chips' }, partes.map((p) => {
    const m = p.match(/^(R\d{2})\s+(.*)$/);
    return h('span', { clase: 'chip-regla' }, m ? [h('b', {}, m[1]), ` ${m[2]}`] : p);
  }));
}

export function iniciales(nombre) {
  return String(nombre || '?').trim().split(/\s+/).slice(0, 2).map((x) => x[0]?.toUpperCase() || '').join('') || '?';
}

/** Avatar con iniciales; el tono sale del nombre, así cada persona conserva el suyo. */
export function avatar(nombre, clase = '') {
  let hash = 0;
  for (const c of String(nombre || '')) hash = (hash * 31 + c.charCodeAt(0)) % 360;
  const el = h('span', { clase: `avatar ${clase}`.trim(), 'aria-hidden': 'true' }, iniciales(nombre));
  el.style.setProperty('--tono', String(hash));
  return el;
}

/** Cifra destacada (KPI) con ícono opcional. */
export function cifra(valor, texto, { icono: nombre = null, detalle = null } = {}) {
  return h('div', { clase: 'cifra' },
    nombre ? h('span', { clase: 'cifra-icono' }, icono(nombre)) : null,
    h('strong', {}, String(valor ?? '—')), h('span', {}, texto), detalle ? h('small', {}, detalle) : null);
}

export function fecha(valor) {
  if (!valor) return '—';
  const d = new Date(`${String(valor).replace(' ', 'T')}Z`);
  return Number.isNaN(d.getTime()) ? valor : d.toLocaleString('es-UY', { dateStyle: 'short', timeStyle: 'short' });
}

/** Fecha corta para ejes de gráficos ("30/10"). */
export function fechaCorta(valor) {
  if (!valor) return '';
  const d = new Date(`${String(valor).replace(' ', 'T')}Z`);
  return Number.isNaN(d.getTime()) ? String(valor) : d.toLocaleDateString('es-UY', { day: '2-digit', month: '2-digit' });
}

/** "2026-10-01" → "1 oct." para mostrar períodos. */
export function dia(valor) {
  if (!valor) return '—';
  const d = new Date(`${valor}T12:00:00`);
  return Number.isNaN(d.getTime()) ? valor : d.toLocaleDateString('es-UY', { day: 'numeric', month: 'short' });
}

/** "RESOLUCION_PROBLEMAS" → "Resolución problemas" para mostrar códigos de catálogo. */
export function textoCodigo(codigo) {
  if (!codigo) return '—';
  const t = String(codigo).replaceAll('_', ' ').toLowerCase().replace('resolucion', 'resolución').replace('basico', 'básico');
  return t.charAt(0).toUpperCase() + t.slice(1);
}

export function numero(v, decimales = 1) {
  return v === null || v === undefined ? '—' : Number(v).toLocaleString('es-UY', { maximumFractionDigits: decimales });
}

export function formularioDatos(form) {
  return Object.fromEntries(new FormData(form).entries());
}

export { icono };
