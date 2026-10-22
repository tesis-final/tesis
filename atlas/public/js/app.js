// ATLAS — aplicación de una página: sesión, menú por rol y ruteo por hash.

import { api, definirCsrf, nuevaNavegacion } from './api.js';
import { h, mensaje } from './ui.js';
import { vistaLogin } from './vistas/login.js';
import * as admin from './vistas/admin.js';
import * as docente from './vistas/docente.js';
import * as estudiante from './vistas/estudiante.js';

export const estado = { usuario: null, permisos: [] };

const MENUS = {
  ADMIN: [['#/', 'Actividades a revisar'], ['#/usuarios', 'Usuarios'], ['#/grupos', 'Grupos'], ['#/instituciones', 'Instituciones'], ['#/reglas', 'Reglas del motor'], ['#/reportes', 'Reportes'], ['#/auditoria', 'Auditoría']],
  // D-5: las consultas guiadas son la forma principal; el asistente es opcional.
  DOCENTE: [['#/', 'Dónde intervenir'], ['#/consultas', 'Consultas'], ['#/actividades', 'Mis actividades'], ['#/reportes', 'Reportes'], ['#/asistente', 'Asistente (opcional)']],
  ESTUDIANTE: [['#/', 'Mis actividades']],
};

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

function pintarBarra() {
  const menu = document.getElementById('menu');
  const sesion = document.getElementById('sesion');
  if (!estado.usuario) {
    menu.replaceChildren();
    sesion.replaceChildren();
    return;
  }
  menu.replaceChildren(...(MENUS[estado.usuario.rol] || []).map(([href, texto]) => h('a', { href }, texto)));
  sesion.replaceChildren(
    h('span', {}, `${estado.usuario.nombre} ${estado.usuario.apellido}`),
    h('button', { type: 'button', onclick: salir }, 'Salir'),
  );
}

async function salir() {
  try { await api('POST', '/auth/logout'); } catch { /* ya vencida */ }
  location.replace('/#/login');
  location.reload();
}

async function navegar() {
  nuevaNavegacion();
  const hash = location.hash || '#/';
  if (!estado.usuario) {
    vistaLogin();
    return;
  }
  document.querySelectorAll('#menu a').forEach((a) => a.toggleAttribute('aria-current', a.getAttribute('href') === hash));
  if (hash === '#/login') location.hash = '#/';
  for (const [patron, vista] of RUTAS[estado.usuario.rol] || []) {
    const m = hash.match(patron);
    if (m) {
      try {
        await vista(...m.slice(1));
      } catch (e) {
        mensaje(e.message || 'Ocurrió un error.', 'error');
      }
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

(async () => {
  try {
    const datos = await api('GET', '/auth/me');
    estado.usuario = datos.usuario;
    estado.permisos = datos.permisos;
    definirCsrf(datos.csrf);
    pintarBarra();
  } catch { /* sin sesión */ }
  navegar();
})();
