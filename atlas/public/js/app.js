// ATLAS — aplicación de una página: sesión, menú por rol, ruteo por hash y armazón
// (barra lateral, tema claro/oscuro y paleta de navegación con Ctrl/⌘ + K).

import { api, definirCsrf, nuevaNavegacion } from './api.js';
import { h, mensaje, esqueleto, avatar, icono } from './ui.js';
import { vistaLogin } from './vistas/login.js';
import * as admin from './vistas/admin.js';
import * as docente from './vistas/docente.js';
import * as estudiante from './vistas/estudiante.js';

export const estado = { usuario: null, permisos: [] };

// [hash, texto, ícono, sección del menú]
const MENUS = {
  ADMIN: [['#/', 'Actividades a revisar', 'revisar', 'Coordinación'], ['#/usuarios', 'Usuarios', 'usuarios', 'Coordinación'], ['#/grupos', 'Grupos', 'grupos', 'Coordinación'],
    ['#/instituciones', 'Instituciones', 'instituciones', 'Coordinación'], ['#/reglas', 'Reglas del motor', 'reglas', 'Análisis'], ['#/reportes', 'Reportes', 'reportes', 'Análisis'],
    ['#/auditoria', 'Auditoría', 'auditoria', 'Seguridad']],
  // D-5: las consultas guiadas son la forma principal; el asistente es opcional.
  DOCENTE: [['#/', 'Dónde intervenir', 'inicio', 'Seguimiento'], ['#/consultas', 'Consultas', 'consultas', 'Seguimiento'], ['#/reportes', 'Reportes', 'reportes', 'Seguimiento'],
    ['#/actividades', 'Mis actividades', 'actividades', 'Contenido'], ['#/asistente', 'Asistente (opcional)', 'asistente', 'Contenido']],
  ESTUDIANTE: [['#/', 'Mis actividades', 'actividades', '']],
};
const ROLES = { ADMIN: 'Coordinación', DOCENTE: 'Docente', ESTUDIANTE: 'Estudiante' };

const RUTAS = {
  ADMIN: [
    [/^#\/$/, admin.revisar], [/^#\/usuarios$/, admin.usuarios], [/^#\/grupos$/, admin.grupos], [/^#\/instituciones$/, admin.instituciones],
    [/^#\/reglas$/, admin.reglas], [/^#\/auditoria$/, admin.auditoria], [/^#\/reportes$/, docente.reportes],
    [/^#\/actividades\/(\d+)$/, admin.revisarActividad],
  ],
  DOCENTE: [
    [/^#\/$/, docente.inicio], [/^#\/consultas$/, docente.consultas], [/^#\/grupo\/(\d+)$/, docente.grupo], [/^#\/estudiante\/(\d+)$/, docente.estudiante],
    [/^#\/actividades$/, docente.actividades], [/^#\/actividades\/nueva$/, docente.editor],
    [/^#\/actividades\/(\d+)$/, docente.editor], [/^#\/reportes$/, docente.reportes], [/^#\/asistente$/, docente.asistente],
  ],
  ESTUDIANTE: [
    [/^#\/$/, estudiante.inicio], [/^#\/resolver\/(\d+)$/, estudiante.resolver], [/^#\/resultado\/(\d+)$/, estudiante.resultado],
  ],
};

// Al cambiar de usuario se recarga la página: así ninguna pantalla del usuario anterior
// que todavía estuviera cargando puede mostrarse con la sesión nueva (equipos compartidos).
// Después de recargar, /auth/me trae el usuario y el token CSRF de la sesión nueva.
export function iniciarSesion() {
  location.replace('/#/');
  location.reload();
}

// ---------- Tema claro / oscuro ----------
function temaActual() {
  const elegido = document.documentElement.getAttribute('data-tema');
  if (elegido) return elegido;
  return matchMedia('(prefers-color-scheme: dark)').matches ? 'oscuro' : 'claro';
}

function pintarBotonTema() {
  const boton = document.getElementById('tema');
  const oscuro = temaActual() === 'oscuro';
  boton.replaceChildren(icono(oscuro ? 'sol' : 'luna'));
  boton.setAttribute('aria-label', oscuro ? 'Usar tema claro' : 'Usar tema oscuro');
  boton.setAttribute('title', oscuro ? 'Tema claro' : 'Tema oscuro');
}

function alternarTema() {
  const nuevo = temaActual() === 'oscuro' ? 'claro' : 'oscuro';
  document.documentElement.setAttribute('data-tema', nuevo);
  try { localStorage.setItem('atlas:tema', nuevo); } catch { /* sin almacenamiento: vale para esta visita */ }
  pintarBotonTema();
}

// ---------- Menú lateral (en celular y tableta es un cajón) ----------
function abrirMenu(abrir) {
  const lateral = document.getElementById('lateral');
  const boton = document.getElementById('abrir-menu');
  lateral.classList.toggle('abierta', abrir);
  document.getElementById('velo').classList.toggle('visible', abrir);
  boton.setAttribute('aria-expanded', String(abrir));
  boton.replaceChildren(icono(abrir ? 'cerrar' : 'menu'));
  boton.setAttribute('aria-label', abrir ? 'Cerrar el menú' : 'Abrir el menú');
  if (abrir) lateral.querySelector('a')?.focus();
}

function pintarBarra() {
  const menu = document.getElementById('menu');
  const sesion = document.getElementById('sesion');
  const pie = document.getElementById('lateral-pie');
  document.body.className = estado.usuario ? `rol-${estado.usuario.rol}` : 'sin-sesion';
  if (!estado.usuario) {
    menu.replaceChildren();
    sesion.replaceChildren();
    pie.replaceChildren();
    return;
  }
  const items = [];
  let seccionActual = null;
  for (const [href, texto, nombreIcono, seccion] of MENUS[estado.usuario.rol] || []) {
    if (seccion && seccion !== seccionActual) {
      items.push(h('div', { clase: 'menu-titulo', 'aria-hidden': 'true' }, seccion));
      seccionActual = seccion;
    }
    items.push(h('a', { href }, icono(nombreIcono), h('span', {}, texto)));
  }
  menu.replaceChildren(...items);
  const nombre = `${estado.usuario.nombre} ${estado.usuario.apellido}`;
  sesion.replaceChildren(
    h('div', { clase: 'persona' }, avatar(nombre),
      h('div', { clase: 'persona-datos' }, h('strong', {}, nombre), h('span', {}, ROLES[estado.usuario.rol] || estado.usuario.rol))),
    h('button', { type: 'button', onclick: salir, title: 'Cerrar sesión' }, icono('salir'), h('span', {}, 'Salir')),
  );
  pie.replaceChildren(
    h('span', {}, h('strong', {}, 'Atajo: '), h('kbd', {}, 'Ctrl'), ' + ', h('kbd', {}, 'K'), ' para ir a cualquier pantalla.'),
    h('span', {}, 'ATLAS acompaña el trabajo docente: no diagnostica ni etiqueta a los estudiantes.'),
  );
  const buscar = document.getElementById('buscar');
  buscar.replaceChildren(icono('buscar'), h('span', {}, 'Ir a…'), h('kbd', {}, 'Ctrl K'));
}

// ---------- Paleta de navegación (Ctrl/⌘ + K) ----------
function abrirPaleta() {
  if (!estado.usuario || document.querySelector('dialog.paleta')) return;
  const opciones = (MENUS[estado.usuario.rol] || []).map(([href, texto, nombreIcono]) => ({ href, texto, nombreIcono }));
  const lista = h('ul', { role: 'listbox', id: 'paleta-lista', 'aria-label': 'Pantallas' });
  const entrada = h('input', { type: 'search', placeholder: 'Escribí el nombre de una pantalla…', 'aria-label': 'Buscar pantalla', 'aria-controls': 'paleta-lista', autocomplete: 'off' });
  const dialogo = h('dialog', { clase: 'paleta', 'aria-label': 'Ir a una pantalla' },
    h('div', { clase: 'paleta-entrada' }, icono('buscar'), entrada), lista,
    h('div', { clase: 'paleta-pie' }, h('span', {}, '↑ ↓ para elegir'), h('span', {}, 'Enter para abrir'), h('span', {}, 'Esc para cerrar')));
  let elegida = 0;
  const pintar = () => {
    const q = entrada.value.trim().toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
    const visibles = opciones.filter((o) => o.texto.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').includes(q));
    elegida = Math.min(elegida, Math.max(0, visibles.length - 1));
    lista.replaceChildren(...visibles.map((o, i) => h('li', {}, h('a', { href: o.href, role: 'option', 'aria-selected': String(i === elegida), onclick: () => dialogo.close() }, icono(o.nombreIcono), o.texto))));
    return visibles;
  };
  entrada.addEventListener('input', () => { elegida = 0; pintar(); });
  entrada.addEventListener('keydown', (ev) => {
    const visibles = pintar();
    if (ev.key === 'ArrowDown') { elegida = (elegida + 1) % Math.max(1, visibles.length); pintar(); ev.preventDefault(); }
    if (ev.key === 'ArrowUp') { elegida = (elegida - 1 + visibles.length) % Math.max(1, visibles.length); pintar(); ev.preventDefault(); }
    if (ev.key === 'Enter' && visibles[elegida]) { location.hash = visibles[elegida].href; dialogo.close(); }
  });
  dialogo.addEventListener('close', () => dialogo.remove());
  document.body.append(dialogo);
  pintar();
  dialogo.showModal();
  entrada.focus();
}

async function salir() {
  try { await api('POST', '/auth/logout'); } catch { /* ya vencida */ }
  location.replace('/#/login');
  location.reload();
}

async function navegar() {
  nuevaNavegacion();
  abrirMenu(false);
  const hash = location.hash || '#/';
  if (!estado.usuario) {
    vistaLogin();
    return;
  }
  document.querySelectorAll('#menu a').forEach((a) => {
    const ruta = a.getAttribute('href');
    const actual = ruta === hash || (ruta !== '#/' && hash.startsWith(`${ruta}/`));
    if (actual) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current');
  });
  if (hash === '#/login') location.hash = '#/';
  for (const [patron, vista] of RUTAS[estado.usuario.rol] || []) {
    const m = hash.match(patron);
    if (m) {
      esqueleto();
      try {
        await vista(...m.slice(1));
      } catch (e) {
        mensaje(e.message || 'Ocurrió un error.', 'error');
      }
      window.scrollTo({ top: 0 });
      return;
    }
  }
  location.hash = '#/';
}

window.addEventListener('hashchange', navegar);
window.addEventListener('atlas:sesion-vencida', () => {
  estado.usuario = null;
  pintarBarra();
  mensaje('La sesión venció. Vuelva a iniciar sesión.', 'error');
  vistaLogin();
});
document.getElementById('tema').addEventListener('click', alternarTema);
document.getElementById('abrir-menu').addEventListener('click', () => abrirMenu(!document.getElementById('lateral').classList.contains('abierta')));
document.getElementById('velo').addEventListener('click', () => abrirMenu(false));
document.getElementById('buscar').addEventListener('click', abrirPaleta);
document.addEventListener('keydown', (ev) => {
  if ((ev.ctrlKey || ev.metaKey) && ev.key.toLowerCase() === 'k') { ev.preventDefault(); abrirPaleta(); }
  if (ev.key === 'Escape' && document.getElementById('lateral').classList.contains('abierta')) abrirMenu(false);
});
matchMedia('(prefers-color-scheme: dark)').addEventListener('change', pintarBotonTema);
pintarBotonTema();
abrirMenu(false);

(async () => {
  try {
    const datos = await api('GET', '/auth/me');
    estado.usuario = datos.usuario;
    estado.permisos = datos.permisos;
    definirCsrf(datos.csrf);
  } catch { /* sin sesión */ }
  pintarBarra();
  navegar();
})();
