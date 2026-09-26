import { api } from '../api.js';
import { h, montar, errorEn } from '../ui.js';
import { iniciarSesion } from '../app.js';

// RF-02: el error no revela qué dato está mal; tras 3 fallos el acceso se bloquea un rato.
export function vistaLogin() {
  const form = h('form', { clase: 'tarjeta login', novalidate: true },
    h('h1', {}, 'Ingresar a ATLAS'),
    h('label', { for: 'correo' }, 'Correo'),
    h('input', { id: 'correo', name: 'correo', type: 'email', autocomplete: 'username', required: true }),
    h('label', { for: 'contrasena' }, 'Contraseña'),
    h('input', { id: 'contrasena', name: 'contrasena', type: 'password', autocomplete: 'current-password', required: true }),
    h('div', { clase: 'acciones' }, h('button', { type: 'submit' }, 'Ingresar')),
    h('p', { clase: 'suave pequeño' }, 'ATLAS acompaña el trabajo docente: no diagnostica ni etiqueta a los estudiantes.'),
  );
  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const boton = form.querySelector('button');
    boton.disabled = true;
    try {
      const datos = await api('POST', '/auth/login', { correo: form.correo.value, contrasena: form.contrasena.value });
      iniciarSesion(datos);
    } catch (e) {
      errorEn(form, e);
      form.contrasena.value = '';
    } finally {
      boton.disabled = false;
    }
  });
  montar(form);
  form.correo.focus();
}
