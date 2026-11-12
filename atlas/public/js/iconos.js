// ATLAS — íconos de trazo (24 × 24), dibujados para el proyecto. Se arman con el DOM
// (createElementNS), nunca con innerHTML, y llevan aria-hidden: el texto de al lado es
// el que dice qué significan (RNF-12: nada depende solo de un dibujo o de un color).

const NS = 'http://www.w3.org/2000/svg';

// Cada ícono es una lista de [elemento, atributos].
const TRAZOS = {
  inicio: [['circle', { cx: 12, cy: 12, r: 9 }], ['circle', { cx: 12, cy: 12, r: 5 }], ['circle', { cx: 12, cy: 12, r: 1.2, fill: 'currentColor' }]],
  consultas: [['path', { d: 'M4 6h16M7 12h10M10 18h4' }]],
  actividades: [['path', { d: 'M12 3 3 8l9 5 9-5-9-5Z' }], ['path', { d: 'm3 13 9 5 9-5' }]],
  reportes: [['path', { d: 'M4 20V10M10 20V4M16 20v-7M22 20H2' }]],
  asistente: [['path', { d: 'M12 3l1.8 4.6L18.5 9l-4.7 1.4L12 15l-1.8-4.6L5.5 9l4.7-1.4L12 3Z' }], ['path', { d: 'M19 15l.9 2.1L22 18l-2.1.9L19 21l-.9-2.1L16 18l2.1-.9L19 15Z' }]],
  usuarios: [['circle', { cx: 9, cy: 8, r: 3.5 }], ['path', { d: 'M2.5 20c.8-3.5 3.4-5.5 6.5-5.5s5.7 2 6.5 5.5' }], ['path', { d: 'M16 4.6a3.5 3.5 0 0 1 0 6.8M18.5 14.8c1.6.8 2.7 2.6 3 5.2' }]],
  grupos: [['rect', { x: 3, y: 4, width: 18, height: 16, rx: 3 }], ['path', { d: 'M3 9h18M8 4v16' }]],
  instituciones: [['path', { d: 'M3 21h18M5 21V9l7-5 7 5v12' }], ['path', { d: 'M9 21v-6h6v6M9 11h.01M15 11h.01' }]],
  reglas: [['path', { d: 'M4 7h10M18 7h2M4 17h4M12 17h8' }], ['circle', { cx: 16, cy: 7, r: 2 }], ['circle', { cx: 10, cy: 17, r: 2 }]],
  auditoria: [['path', { d: 'M12 3 4 6v6c0 4.5 3.4 8 8 9 4.6-1 8-4.5 8-9V6l-8-3Z' }], ['path', { d: 'm8.5 12 2.5 2.5 4.5-5' }]],
  revisar: [['path', { d: 'M4 13h4l2 3h4l2-3h4' }], ['path', { d: 'M5.5 5h13L20 13v6H4v-6l1.5-8Z' }]],
  buscar: [['circle', { cx: 11, cy: 11, r: 7 }], ['path', { d: 'm20 20-3.5-3.5' }]],
  sol: [['circle', { cx: 12, cy: 12, r: 4 }], ['path', { d: 'M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4' }]],
  luna: [['path', { d: 'M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5Z' }]],
  menu: [['path', { d: 'M4 6h16M4 12h16M4 18h16' }]],
  cerrar: [['path', { d: 'M6 6l12 12M18 6 6 18' }]],
  salir: [['path', { d: 'M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3' }], ['path', { d: 'M10 8l-4 4 4 4M6 12h10' }]],
  alerta: [['path', { d: 'M12 4 2.5 20h19L12 4Z' }], ['path', { d: 'M12 10v4M12 17h.01' }]],
  derecha: [['path', { d: 'M5 12h14M13 6l6 6-6 6' }]],
  izquierda: [['path', { d: 'M19 12H5M11 6l-6 6 6 6' }]],
  check: [['path', { d: 'm5 12 4.5 4.5L19 7' }]],
  reloj: [['circle', { cx: 12, cy: 12, r: 9 }], ['path', { d: 'M12 7v5l3 2' }]],
  persona: [['circle', { cx: 12, cy: 8, r: 4 }], ['path', { d: 'M4 21c1-4 4-6 8-6s7 2 8 6' }]],
  libro: [['path', { d: 'M4 5a2 2 0 0 1 2-2h13v16H6a2 2 0 0 0-2 2V5Z' }], ['path', { d: 'M4 19a2 2 0 0 1 2-2h13' }]],
  rayo: [['path', { d: 'M13 2 4 14h7l-1 8 9-12h-7l1-8Z' }]],
  ojo: [['path', { d: 'M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12Z' }], ['circle', { cx: 12, cy: 12, r: 3 }]],
  ojoTachado: [['path', { d: 'M3 3l18 18M10.6 5.1A10 10 0 0 1 12 5c6.5 0 10 7 10 7a17 17 0 0 1-3.2 4M6.6 6.6A17 17 0 0 0 2 12s3.5 7 10 7a9.7 9.7 0 0 0 5.4-1.6' }], ['path', { d: 'M9.9 9.9a3 3 0 0 0 4.2 4.2' }]],
  info: [['circle', { cx: 12, cy: 12, r: 9 }], ['path', { d: 'M12 11v6M12 7.5h.01' }]],
  mas: [['path', { d: 'M12 5v14M5 12h14' }]],
  papelera: [['path', { d: 'M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3' }]],
  estrella: [['path', { d: 'm12 3 2.7 5.6 6.2.9-4.5 4.4 1.1 6.1L12 17l-5.5 3 1.1-6.1L3.1 9.5l6.2-.9L12 3Z' }]],
  grafico: [['path', { d: 'M3 17l5-5 4 4 8-8' }], ['path', { d: 'M15 8h5v5' }]],
  escudo: [['path', { d: 'M12 3 4 6v6c0 4.5 3.4 8 8 9 4.6-1 8-4.5 8-9V6l-8-3Z' }]],
  enviar: [['path', { d: 'M4 12 20 4l-6 16-2.5-6.5L4 12Z' }]],
  manos: [['path', { d: 'M12 21s-7-4.4-9-9a5 5 0 0 1 9-3 5 5 0 0 1 9 3c-2 4.6-9 9-9 9Z' }]],
  teclado: [['rect', { x: 2, y: 6, width: 20, height: 12, rx: 2 }], ['path', { d: 'M6 10h.01M10 10h.01M14 10h.01M18 10h.01M7 14h10' }]],
  bandera: [['path', { d: 'M5 21V4M5 4h11l-2 4 2 4H5' }]],
  objetivo: [['circle', { cx: 12, cy: 12, r: 9 }], ['path', { d: 'M12 3v4M12 17v4M3 12h4M17 12h4' }], ['circle', { cx: 12, cy: 12, r: 2 }]],
  calendario: [['rect', { x: 3, y: 5, width: 18, height: 16, rx: 2 }], ['path', { d: 'M3 10h18M8 3v4M16 3v4' }]],
};

export function icono(nombre, clase = '') {
  const svg = document.createElementNS(NS, 'svg');
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('fill', 'none');
  svg.setAttribute('stroke', 'currentColor');
  svg.setAttribute('stroke-width', '1.9');
  svg.setAttribute('stroke-linecap', 'round');
  svg.setAttribute('stroke-linejoin', 'round');
  svg.setAttribute('aria-hidden', 'true');
  svg.setAttribute('focusable', 'false');
  if (clase) svg.setAttribute('class', clase);
  for (const [etiqueta, atributos] of TRAZOS[nombre] || TRAZOS.info) {
    const el = document.createElementNS(NS, etiqueta);
    for (const [k, v] of Object.entries(atributos)) el.setAttribute(k, String(v));
    svg.append(el);
  }
  return svg;
}
