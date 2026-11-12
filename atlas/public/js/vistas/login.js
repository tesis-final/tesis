import { api } from '../api.js';
import { h, montar, errorEn, icono } from '../ui.js';
import { iniciarSesion } from '../app.js';

// RF-02: el error no revela qué dato está mal; tras 3 fallos el acceso se bloquea un rato.
export function vistaLogin() {
  const clave = h('input', { id: 'contrasena', name: 'contrasena', type: 'password', autocomplete: 'current-password', required: true });
  const verClave = h('button', { type: 'button', clase: 'ver-clave', 'aria-label': 'Mostrar la contraseña', 'aria-pressed': 'false' }, icono('ojo'));
  verClave.addEventListener('click', () => {
    const visible = clave.type === 'password';
    clave.type = visible ? 'text' : 'password';
    verClave.setAttribute('aria-pressed', String(visible));
    verClave.setAttribute('aria-label', visible ? 'Ocultar la contraseña' : 'Mostrar la contraseña');
    verClave.replaceChildren(icono(visible ? 'ojoTachado' : 'ojo'));
  });
  const form = h('form', { clase: 'tarjeta login', novalidate: true },
    h('span', { clase: 'placa-logo' }, h('img', { clase: 'logotipo', src: '/assets/logotipo.png', alt: 'ATLAS', width: 640, height: 226 })),
    h('h1', {}, 'Ingresar a ATLAS'),
    h('p', { clase: 'bajada' }, 'Usá la cuenta que te dio tu institución.'),
    h('label', { for: 'correo' }, 'Correo'),
    h('input', { id: 'correo', name: 'correo', type: 'email', autocomplete: 'username', required: true, placeholder: 'nombre@atlas.local', inputmode: 'email' }),
    h('label', { for: 'contrasena' }, 'Contraseña'),
    h('div', { clase: 'campo-clave' }, clave, verClave),
    h('div', { clase: 'acciones' }, h('button', { type: 'submit' }, 'Ingresar', icono('derecha'))),
    h('p', { clase: 'nota-etica' }, icono('escudo'), h('span', {}, 'ATLAS acompaña el trabajo docente: no diagnostica ni etiqueta a los estudiantes. Tres intentos fallidos bloquean el acceso por unos minutos.')),
  );
  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const boton = form.querySelector('button[type=submit]');
    boton.disabled = true;
    try {
      const datos = await api('POST', '/auth/login', { correo: form.correo.value, contrasena: clave.value });
      iniciarSesion(datos);
    } catch (e) {
      errorEn(form, e);
      clave.value = '';
      clave.focus();
    } finally {
      boton.disabled = false;
    }
  });

  // Panel de presentación: decorativo para lectores de pantalla salvo el texto principal.
  const punto = (nombre, titulo, texto) => h('li', {}, h('span', {}, icono(nombre)), h('span', {}, h('strong', {}, titulo), texto));
  const arte = h('section', { clase: 'acceso-arte', 'aria-labelledby': 'acceso-titulo' },
    h('a', { clase: 'marca', href: '#/' }, h('img', { clase: 'isotipo', src: '/assets/isotipo.png', alt: '', width: 40, height: 40 }),
      h('span', { clase: 'marca-texto' }, h('strong', {}, 'ATLAS'), h('small', {}, 'Plataforma inteligente de aprendizaje adaptativo'))),
    h('h2', { clase: 'acceso-titulo', id: 'acceso-titulo' }, 'Ver el proceso, ', h('span', { clase: 'serif' }, 'no solo el resultado.')),
    h('p', { clase: 'acceso-bajada' }, 'ATLAS registra cómo resuelven los estudiantes cada actividad y le muestra al docente dónde conviene intervenir hoy.'),
    h('ul', { clase: 'acceso-puntos' },
      punto('inicio', 'Dónde intervenir', 'Quiénes requieren atención y qué preguntas cuestan más, con la regla que lo explica.'),
      punto('reloj', 'El proceso registrado', 'Respuestas, cambios, intentos, tiempo total y tiempo activo.'),
      punto('persona', 'El docente decide', 'El sistema sugiere la siguiente actividad; la decisión es siempre del docente.')),
    h('div', { clase: 'acceso-vista', 'aria-hidden': 'true' }, miniaturas()));

  montar(h('div', { clase: 'acceso' }, arte, h('div', { clase: 'acceso-formulario' }, form)));
  form.correo.focus();
}

// Ilustración: el emblema del logotipo y dos paneles abstractos (sin datos reales).
function miniaturas() {
  const barra = (ancho) => { const b = h('b'); b.style.width = ancho; return h('span', { clase: 'linea' }, b); };
  const a = h('div', { clase: 'mini' }, h('div', { clase: 'mini-titulo' }, 'Acierto por habilidad'), barra('82%'), barra('64%'), barra('47%'));
  const b = h('div', { clase: 'mini' }, h('div', { clase: 'mini-titulo' }, 'Atención prioritaria'), barra('100%'), barra('70%'));
  a.style.left = '0'; a.style.top = '28px'; a.style.width = '42%';
  b.style.right = '0'; b.style.bottom = '18px'; b.style.width = '38%';
  const emblema = h('div', { clase: 'acceso-emblema' }, h('span', { clase: 'brillo' }), h('img', { src: '/assets/isotipo.png', alt: '', width: 256, height: 256 }));
  return [emblema, a, b];
}
