// ATLAS — utilidades de interfaz. Todo el contenido se inserta como texto
// (nunca innerHTML con datos), para evitar inyección de código.

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
  app.replaceChildren(...nodos.flat(Infinity).filter((n) => n !== null && n !== undefined && n !== false));
  document.getElementById('principal').focus({ preventScroll: true });
}

export function mensaje(texto, tipo = 'info') {
  const zona = document.getElementById('mensajes');
  const m = h('div', { clase: `mensaje ${tipo}` }, texto);
  zona.append(m);
  setTimeout(() => m.remove(), 6000);
}

export function errorEn(formulario, error) {
  formulario.querySelectorAll('.campo-error').forEach((e) => e.remove());
  for (const [campo, texto] of Object.entries(error.errores || {})) {
    const entrada = formulario.querySelector(`[name="${CSS.escape(campo)}"]`);
    if (entrada) entrada.after(h('div', { clase: 'campo-error', role: 'alert' }, texto));
  }
  mensaje(error.message, 'error');
}

/** Tabla que en celular se ve como tarjetas (RNF-12): cada celda lleva su etiqueta. */
export function tabla(columnas, filas, vacio = 'Sin datos.') {
  if (!filas.length) return h('p', { clase: 'vacio' }, vacio);
  return h('table', { clase: 'tabla' },
    h('thead', {}, h('tr', {}, columnas.map((c) => h('th', { scope: 'col' }, c.titulo)))),
    h('tbody', {}, filas.map((f) => h('tr', {}, columnas.map((c) => {
      const valor = c.valor(f);
      return h('td', { 'data-etiqueta': c.titulo }, valor instanceof Node ? valor : (valor ?? '—'));
    })))));
}

export function etiquetaTipo(tipo) {
  const nombres = { RIESGO: 'Riesgo', AVANCE: 'Avance', REFUERZO: 'Refuerzo', RECONOCIMIENTO: 'Reconocimiento' };
  return h('span', { clase: `etiqueta ${tipo}` }, nombres[tipo] || tipo);
}

export function etiquetaEstado(estado) {
  const nombres = { BORRADOR: 'Borrador', PENDIENTE: 'Pendiente de aprobación', APROBADA: 'Aprobada', RECHAZADA: 'Rechazada', PUBLICADA: 'Publicada' };
  return h('span', { clase: 'etiqueta estado' }, nombres[estado] || estado);
}

export function fecha(valor) {
  if (!valor) return '—';
  const d = new Date(`${String(valor).replace(' ', 'T')}Z`);
  return Number.isNaN(d.getTime()) ? valor : d.toLocaleString('es-UY', { dateStyle: 'short', timeStyle: 'short' });
}

export function numero(v, decimales = 1) {
  return v === null || v === undefined ? '—' : Number(v).toLocaleString('es-UY', { maximumFractionDigits: decimales });
}

export function formularioDatos(form) {
  return Object.fromEntries(new FormData(form).entries());
}
