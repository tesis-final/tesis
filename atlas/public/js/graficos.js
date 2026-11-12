// ATLAS — gráficos en SVG hechos con el DOM, sin librerías (la CSP no permite CDN y el
// laboratorio puede no tener Internet). Cada gráfico lleva role="img" y un aria-label
// con los datos en texto, y los valores también se escriben al lado: nada se entiende
// solo por el color o por la forma (RNF-12).

import { h, numero } from './ui.js';

const NS = 'http://www.w3.org/2000/svg';

function s(etiqueta, atributos = {}, ...hijos) {
  const el = document.createElementNS(NS, etiqueta);
  for (const [k, v] of Object.entries(atributos)) if (v !== null && v !== undefined) el.setAttribute(k, String(v));
  for (const hijo of hijos.flat()) if (hijo !== null && hijo !== undefined) el.append(hijo instanceof Node ? hijo : document.createTextNode(String(hijo)));
  return el;
}

/** Nivel para colorear sin depender del color: siempre va acompañado del número. */
export function nivel(porcentaje) {
  if (porcentaje === null || porcentaje === undefined || Number.isNaN(Number(porcentaje))) return '';
  const p = Number(porcentaje);
  return p < 50 ? 'bajo' : p < 70 ? 'medio' : 'alto';
}

/** Anillo de progreso con el valor en el centro. */
export function anillo(porcentaje, { tamano = 96, grosor = 9, texto = null, subtitulo = '', etiqueta = '' } = {}) {
  const valor = porcentaje === null || porcentaje === undefined ? null : Math.max(0, Math.min(100, Number(porcentaje)));
  const r = (tamano - grosor) / 2;
  const largo = 2 * Math.PI * r;
  const progreso = s('circle', { class: 'progreso-anillo', cx: tamano / 2, cy: tamano / 2, r, fill: 'none', 'stroke-width': grosor, 'stroke-dasharray': largo, 'stroke-dashoffset': largo });
  const svg = s('svg', { width: tamano, height: tamano, viewBox: `0 0 ${tamano} ${tamano}`, 'aria-hidden': 'true' },
    s('circle', { class: 'pista', cx: tamano / 2, cy: tamano / 2, r, fill: 'none', 'stroke-width': grosor }), progreso);
  // La animación arranca en el cuadro siguiente para que se vea el recorrido.
  requestAnimationFrame(() => requestAnimationFrame(() => progreso.setAttribute('stroke-dashoffset', String(largo * (1 - (valor ?? 0) / 100)))));
  const contenedor = h('div', { clase: `anillo ${nivel(valor)}`, role: 'img', 'aria-label': etiqueta || `${valor === null ? 'sin dato' : `${numero(valor)} de 100`}${subtitulo ? `, ${subtitulo}` : ''}` },
    svg, h('div', { clase: 'anillo-texto', 'aria-hidden': 'true' }, h('div', {}, h('strong', {}, texto ?? (valor === null ? '—' : numero(valor, 0))), subtitulo ? h('small', {}, subtitulo) : null)));
  contenedor.style.width = `${tamano}px`;
  contenedor.style.height = `${tamano}px`;
  contenedor.style.fontSize = `${Math.round(tamano / 3.2)}px`;
  return contenedor;
}

/** Medidor horizontal 0–100 con el texto del valor y, opcionalmente, una marca de umbral. */
export function medidor(porcentaje, { umbral = null, texto = null, tono = null } = {}) {
  const valor = porcentaje === null || porcentaje === undefined ? null : Math.max(0, Math.min(100, Number(porcentaje)));
  const barra = h('span', { clase: 'medidor-valor' });
  requestAnimationFrame(() => { barra.style.width = `${valor ?? 0}%`; });
  const pista = h('span', { clase: 'medidor-pista', 'aria-hidden': 'true' }, barra);
  if (umbral !== null) {
    const marca = h('span', { clase: 'medidor-umbral', title: `Umbral ${umbral} %` });
    marca.style.left = `${umbral}%`;
    pista.append(marca);
  }
  // tono fija el color cuando lo alto es malo (por ejemplo, la proporción de error).
  return h('span', { clase: `medidor ${tono || nivel(valor)}` }, pista, h('span', { clase: 'medidor-texto' }, texto ?? (valor === null ? '—' : `${numero(valor)} %`)));
}

/** Columnas para la distribución de puntajes (rango → cantidad). */
export function columnas(datos, { alto = 190, ancho = 320, titulo = 'Distribución' } = {}) {
  const margen = { arriba: 22, abajo: 26, izq: 8, der: 8 };
  const max = Math.max(1, ...datos.map((d) => Number(d.cantidad)));
  const paso = (ancho - margen.izq - margen.der) / Math.max(1, datos.length);
  const util = alto - margen.arriba - margen.abajo;
  const resumen = datos.map((d) => `${d.rango}: ${d.cantidad}`).join('; ');
  const svg = s('svg', { class: 'grafico', viewBox: `0 0 ${ancho} ${alto}`, role: 'img', 'aria-label': `${titulo}. ${resumen}` },
    s('line', { class: 'eje', x1: margen.izq, x2: ancho - margen.der, y1: alto - margen.abajo, y2: alto - margen.abajo }),
    datos.map((d, i) => {
      const valor = Number(d.cantidad);
      const altura = valor === 0 ? 3 : Math.max(4, (valor / max) * util);
      const x = margen.izq + i * paso + paso * 0.16;
      const w = paso * 0.68;
      const y = alto - margen.abajo - altura;
      return s('g', {},
        s('rect', { class: `columna${valor === 0 ? ' vacia' : ''}`, x, y, width: w, height: altura, rx: 6 }),
        s('text', { class: 'valor', x: x + w / 2, y: y - 6, 'text-anchor': 'middle' }, String(valor)),
        s('text', { x: x + w / 2, y: alto - 8, 'text-anchor': 'middle' }, d.rango));
    }));
  return svg;
}

/** Línea de evolución de puntajes (0–100) en el tiempo. */
export function linea(puntos, { alto = 200, titulo = 'Evolución' } = {}) {
  const ancho = 640;
  const m = { arriba: 16, abajo: 28, izq: 34, der: 14 };
  const n = puntos.length;
  const x = (i) => m.izq + (n <= 1 ? (ancho - m.izq - m.der) / 2 : (i * (ancho - m.izq - m.der)) / (n - 1));
  const y = (v) => m.arriba + (1 - Number(v) / 100) * (alto - m.arriba - m.abajo);
  const guias = [0, 50, 100].map((v) => s('g', {},
    s('line', { class: v === 0 ? 'eje' : 'guia', x1: m.izq, x2: ancho - m.der, y1: y(v), y2: y(v) }),
    s('text', { x: m.izq - 8, y: y(v) + 4, 'text-anchor': 'end' }, String(v))));
  const trazo = puntos.map((p, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)},${y(p.valor).toFixed(1)}`).join(' ');
  const area = n ? `${trazo} L${x(n - 1).toFixed(1)},${y(0)} L${x(0).toFixed(1)},${y(0)} Z` : '';
  const resumen = puntos.map((p) => `${p.etiqueta}: ${numero(p.valor)}`).join('; ');
  const cada = Math.max(1, Math.ceil(n / 6));
  return s('svg', { class: 'grafico', viewBox: `0 0 ${ancho} ${alto}`, role: 'img', 'aria-label': `${titulo}. ${resumen}` },
    guias,
    n ? s('path', { class: 'area', d: area }) : null,
    n ? s('path', { class: 'serie', d: trazo }) : null,
    puntos.map((p, i) => s('g', {},
      s('circle', { class: 'punto', cx: x(i), cy: y(p.valor), r: 4.5 }, s('title', {}, `${p.etiqueta}: ${numero(p.valor)}`)),
      i % cada === 0 || i === n - 1 ? s('text', { x: x(i), y: alto - 8, 'text-anchor': 'middle' }, p.corta || p.etiqueta) : null)));
}
