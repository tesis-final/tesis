// Vistas del administrador (perfil de coordinación, DEC-00c): revisión de
// actividades, usuarios, grupos, reglas del motor y auditoría (RF-01, RF-14, RF-15, RF-17).

import { api } from '../api.js';
import {
  h, montar, mensaje, tabla, etiquetaEstado, etiquetaTipo, etiquetaResultado, fecha, errorEn, formularioDatos,
  encabezado, seccion, cifra, avatar, icono, confirmar, enCurso,
} from '../ui.js';

export async function revisar() {
  const pendientes = await api('GET', '/actividades', null, { estado: 'PENDIENTE' });
  montar(
    encabezado('Actividades a revisar', {
      antetitulo: 'Coordinación',
      bajada: 'Solo llegan acá las actividades de instituciones que exigen aprobación previa (D-2). Cada decisión queda en el historial y en la auditoría.',
    }),
    tabla([
      { titulo: 'Título', valor: (a) => h('a', { href: `#/actividades/${a.id}` }, a.titulo) },
      { titulo: 'Docente', valor: (a) => h('span', { clase: 'celda-persona' }, avatar(a.autor), a.autor) }, { titulo: 'Nivel', valor: (a) => a.nivel_nombre },
      { titulo: 'Categoría', valor: (a) => a.categoria_nombre }, { titulo: 'Preguntas', valor: (a) => a.total_preguntas },
      { titulo: 'Enviada', valor: (a) => fecha(a.actualizado_en) },
    ], pendientes, 'No hay actividades pendientes de aprobación.'));
}

export async function revisarActividad(id) {
  const a = await api('GET', `/actividades/${id}`);
  const form = h('form', { clase: 'tarjeta destacada', novalidate: true },
    h('div', { clase: 'tarjeta-cabeza' }, h('h2', {}, icono('revisar'), 'Decisión')),
    h('label', { for: 'observaciones' }, 'Observaciones (obligatorias para rechazar)'),
    h('textarea', { id: 'observaciones', name: 'observaciones', placeholder: 'Qué tiene que cambiar el docente' }),
    h('div', { clase: 'acciones' },
      h('button', { type: 'button', onclick: () => decidir('aprobar') }, icono('check'), 'Aprobar'),
      h('button', { type: 'button', clase: 'peligro', onclick: () => decidir('rechazar') }, icono('cerrar'), 'Rechazar')));
  async function decidir(accion) {
    try {
      await api('POST', `/actividades/${a.id}/${accion}`, accion === 'rechazar' ? { observaciones: form.observaciones.value } : {});
      mensaje(accion === 'aprobar' ? 'Actividad aprobada.' : 'Actividad rechazada: vuelve al docente con las observaciones.');
      location.hash = '#/';
    } catch (e) { errorEn(form, e); }
  }
  montar(
    encabezado(a.titulo, { antetitulo: 'Revisión', bajada: `${a.autor} · ${a.nivel_nombre} · ${a.categoria_nombre}`, acciones: etiquetaEstado(a.estado) }),
    a.descripcion ? h('p', { clase: 'suave' }, a.descripcion) : null,
    seccion('Contenido', { icono: 'consultas' },
      h('ol', { clase: 'pila' }, a.preguntas.map((p) => h('li', {}, h('strong', {}, p.enunciado),
        p.habilidades?.length ? h('div', { clase: 'chips' }, p.habilidades.map((x) => h('span', { clase: 'etiqueta' }, x))) : null,
        h('ul', {}, p.opciones.map((o) => h('li', { clase: o.correcta ? 'acierto' : '' }, o.texto + (o.correcta ? ' (correcta)' : '')))))))),
    a.estado === 'PENDIENTE' ? form : null,
    seccion('Historial', { icono: 'reloj' },
      tabla([{ titulo: 'Fecha', valor: (t) => fecha(t.creado_en) }, { titulo: 'De', valor: (t) => t.desde || '—' }, { titulo: 'A', valor: (t) => t.hacia },
        { titulo: 'Autor', valor: (t) => t.autor }, { titulo: 'Observaciones', valor: (t) => t.observaciones || '' }], a.transiciones)));
}

const ROL_TEXTO = { ESTUDIANTE: 'Estudiante', DOCENTE: 'Docente', ADMIN: 'Coordinación' };

export async function usuarios() {
  const [lista, instituciones] = await Promise.all([api('GET', '/usuarios'), api('GET', '/instituciones')]);
  const form = h('form', { clase: 'tarjeta', novalidate: true },
    h('div', { clase: 'tarjeta-cabeza' }, h('h2', {}, icono('mas'), 'Nuevo usuario')),
    h('div', { clase: 'fila' },
      campo('nombre', 'Nombre'), campo('apellido', 'Apellido'), campo('correo', 'Correo', 'email'), campo('contrasena', 'Contraseña inicial (mín. 10)', 'password')),
    h('div', { clase: 'fila' },
      h('div', {}, h('label', { for: 'rol' }, 'Rol'), h('select', { id: 'rol', name: 'rol' }, ['ESTUDIANTE', 'DOCENTE', 'ADMIN'].map((r) => h('option', { value: r }, r)))),
      h('div', {}, h('label', { for: 'institucion_id' }, 'Institución'), h('select', { id: 'institucion_id', name: 'institucion_id' }, instituciones.map((i) => h('option', { value: i.id }, i.nombre))))),
    h('div', { clase: 'acciones' }, h('button', { type: 'submit' }, icono('mas'), 'Crear usuario')));
  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const d = formularioDatos(form);
    d.institucion_id = Number(d.institucion_id);
    // La contraseña inicial es para otra persona: se vacía el campo apenas se lee, así el
    // navegador no ofrece guardarla como si fuera la de la coordinación.
    form.contrasena.value = '';
    await enCurso(ev.submitter, async () => {
      try { await api('POST', '/usuarios', d); mensaje(`Usuario creado: ${d.nombre} ${d.apellido}.`); usuarios(); } catch (e) { form.contrasena.value = d.contrasena; errorEn(form, e); }
    });
  });
  const cuenta = (rol) => lista.filter((u) => u.rol === rol && u.activo).length;
  montar(
    encabezado('Usuarios', { antetitulo: 'Coordinación', bajada: 'Las contraseñas se guardan con Argon2id. Desactivar no borra: conserva el historial y la auditoría.' }),
    h('div', { clase: 'cifras' }, cifra(cuenta('ESTUDIANTE'), 'Estudiantes activos', { icono: 'usuarios' }), cifra(cuenta('DOCENTE'), 'Docentes activos', { icono: 'persona' }),
      cifra(cuenta('ADMIN'), 'Coordinación', { icono: 'escudo' })),
    form,
    tabla([
      { titulo: 'Nombre', valor: (u) => h('span', { clase: 'celda-persona' }, avatar(`${u.nombre} ${u.apellido}`), `${u.nombre} ${u.apellido}`) }, { titulo: 'Correo', valor: (u) => u.correo },
      { titulo: 'Rol', valor: (u) => h('span', { clase: 'etiqueta' }, ROL_TEXTO[u.rol] || u.rol) },
      { titulo: 'Estado', valor: (u) => (u.activo ? h('span', { clase: 'etiqueta ok' }, 'Activo') : h('span', { clase: 'etiqueta' }, 'Desactivado')) },
      { titulo: 'Acción', valor: (u) => (u.activo ? h('button', { type: 'button', clase: 'secundario chico', onclick: async () => {
        if (!(await confirmar(`${u.nombre} ${u.apellido} no podrá volver a entrar. Su historial y la auditoría se conservan.`, { titulo: '¿Desactivar este usuario?', aceptar: 'Desactivar', peligro: true }))) return;
        try { await api('POST', `/usuarios/${u.id}/desactivar`); mensaje('Usuario desactivado.'); usuarios(); } catch (e) { mensaje(e, 'error'); }
      } }, 'Desactivar') : '—') },
    ], lista));
}

// Instituciones (RF-14) y aprobación configurable (acta D-2): por defecto el docente
// publica directo; si la institución lo exige, las actividades pasan por "Actividades a revisar".
export async function instituciones() {
  const lista = await api('GET', '/instituciones');
  const form = h('form', { clase: 'tarjeta fila', novalidate: true },
    campo('nombre', 'Nueva institución'),
    h('div', { clase: 'encoger' }, h('label', { clase: 'opcion' }, h('input', { type: 'checkbox', name: 'requiere_aprobacion' }), 'Exige aprobación antes de publicar')),
    h('div', { clase: 'encoger' }, h('button', { type: 'submit' }, icono('mas'), 'Crear')));
  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    try {
      await api('POST', '/instituciones', { nombre: form.nombre.value, requiere_aprobacion: form.requiere_aprobacion.checked });
      mensaje('Institución creada.');
      instituciones();
    } catch (e) { errorEn(form, e); }
  });
  montar(encabezado('Instituciones', {
    antetitulo: 'Coordinación',
    bajada: 'Si una institución exige aprobación, sus docentes envían cada actividad a revisión antes de publicarla. Todo cambio queda en la auditoría.',
  }),
  form,
  tabla([
    { titulo: 'Institución', valor: (i) => h('span', { clase: 'celda-persona' }, icono('instituciones'), h('strong', {}, i.nombre)) },
    { titulo: 'Estado', valor: (i) => (i.activa ? h('span', { clase: 'etiqueta ok' }, 'Activa') : h('span', { clase: 'etiqueta' }, 'Inactiva')) },
    { titulo: 'Aprobación previa', valor: (i) => h('label', { clase: 'opcion' },
      h('input', { type: 'checkbox', checked: i.requiere_aprobacion, onchange: async (ev) => {
        try {
          await api('PATCH', `/instituciones/${i.id}`, { nombre: i.nombre, activa: i.activa, requiere_aprobacion: ev.target.checked });
          mensaje(ev.target.checked ? 'Ahora exige aprobación.' : 'Ya no exige aprobación: los docentes publican directo.');
          instituciones();
        } catch (e) { mensaje(e, 'error'); }
      } }),
      i.requiere_aprobacion ? 'Exige' : 'No exige') },
  ], lista));
}

function campo(nombre, etiqueta, tipo = 'text') {
  return h('div', {}, h('label', { for: nombre }, etiqueta),
    h('input', { id: nombre, name: nombre, type: tipo, autocomplete: tipo === 'password' ? 'new-password' : 'off', 'data-lpignore': 'true', 'data-1p-ignore': 'true' }));
}

export async function grupos() {
  const [lista, instituciones, usuariosLista] = await Promise.all([api('GET', '/grupos'), api('GET', '/instituciones'), api('GET', '/usuarios')]);
  const candidatos = usuariosLista.filter((u) => u.activo && u.rol !== 'ADMIN');
  const form = h('form', { clase: 'tarjeta fila', novalidate: true },
    campo('nombre', 'Nombre del grupo'),
    h('div', {}, h('label', { for: 'anio_lectivo' }, 'Año lectivo'), h('input', { id: 'anio_lectivo', name: 'anio_lectivo', type: 'number', value: new Date().getFullYear() })),
    h('div', {}, h('label', { for: 'inst' }, 'Institución'), h('select', { id: 'inst', name: 'institucion_id' }, instituciones.map((i) => h('option', { value: i.id }, i.nombre)))),
    h('div', { clase: 'encoger' }, h('button', { type: 'submit' }, icono('mas'), 'Crear grupo')));
  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const d = formularioDatos(form);
    try { await api('POST', '/grupos', { nombre: d.nombre, anio_lectivo: Number(d.anio_lectivo), institucion_id: Number(d.institucion_id) }); mensaje('Grupo creado.'); grupos(); } catch (e) { errorEn(form, e); }
  });
  const detalle = h('div', { 'aria-live': 'polite' });
  async function editarMiembros(g) {
    const actuales = new Set((await api('GET', `/grupos/${g.id}/miembros`)).map((m) => m.id));
    const casillas = candidatos.map((u) => h('label', { clase: 'opcion' }, h('input', { type: 'checkbox', value: u.id, checked: actuales.has(u.id) }),
      avatar(`${u.nombre} ${u.apellido}`), `${u.nombre} ${u.apellido}`, h('span', { clase: 'etiqueta' }, ROL_TEXTO[u.rol] || u.rol)));
    detalle.replaceChildren(h('section', { clase: 'tarjeta destacada' },
      h('div', { clase: 'tarjeta-cabeza' }, h('h2', {}, icono('usuarios'), `Miembros de ${g.nombre}`)),
      h('p', { clase: 'suave pequeño' }, 'Una docente solo puede publicar en los grupos de los que es miembro.'),
      h('div', { clase: 'rejilla dos' }, casillas),
      h('div', { clase: 'acciones' }, h('button', { type: 'button', onclick: async () => {
        const ids = casillas.map((c) => c.querySelector('input')).filter((i) => i.checked).map((i) => Number(i.value));
        try { await api('PUT', `/grupos/${g.id}/miembros`, { usuarios: ids }); mensaje('Miembros actualizados.'); grupos(); } catch (e) { mensaje(e, 'error'); }
      } }, icono('check'), 'Guardar miembros'))));
    detalle.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
  montar(encabezado('Grupos', { antetitulo: 'Coordinación', bajada: 'Cree los grupos del año y asigne estudiantes y docentes.' }), form,
    tabla([{ titulo: 'Grupo', valor: (g) => h('strong', {}, g.nombre) }, { titulo: 'Año', valor: (g) => g.anio_lectivo }, { titulo: 'Estudiantes', valor: (g) => g.estudiantes },
      { titulo: 'Acción', valor: (g) => h('button', { type: 'button', clase: 'secundario chico', onclick: () => editarMiembros(g) }, icono('usuarios'), 'Miembros') }], lista),
    detalle);
}

// Reglas del motor: umbrales editables sin programar (§27.3); cada cambio se versiona y audita.
export async function reglas() {
  const lista = await api('GET', '/reglas');
  montar(encabezado('Reglas del motor de análisis', {
    antetitulo: 'Análisis',
    bajada: 'Los cambios crean una nueva versión de la regla y quedan en la auditoría. Las recomendaciones anteriores conservan la versión con que se generaron.',
  }),
  h('div', { clase: 'rejilla dos' }, lista.map((r) => {
    const entradas = r.condicion.todas.map((c, i) => h('div', { clase: 'fila' },
      h('span', { clase: 'num pequeño' }, `${c.indicador || c.agregado} ${c.op}`),
      h('input', { type: 'number', step: 'any', value: c.valor, 'data-i': i, 'aria-label': `Umbral ${c.indicador || c.agregado}` })));
    const activa = h('input', { type: 'checkbox', checked: r.activa });
    return h('section', { clase: 'tarjeta' },
      h('div', { clase: 'tarjeta-cabeza' }, h('h2', {}, h('span', { clase: 'num' }, r.codigo), ` — ${r.nombre}`), etiquetaTipo(r.tipo)),
      h('p', { clase: 'suave pequeño' }, `${r.descripcion} Versión ${r.version}.`),
      entradas,
      h('label', { clase: 'opcion' }, activa, 'Regla activa'),
      h('div', { clase: 'acciones' }, h('button', { type: 'button', onclick: async () => {
        const condicion = { todas: r.condicion.todas.map((c, i) => ({ ...c, valor: Number(entradas[i].querySelector('input').value) })) };
        try { await api('PATCH', `/reglas/${r.codigo}`, { condicion, activa: activa.checked }); mensaje(`Regla ${r.codigo} actualizada.`); reglas(); } catch (e) { mensaje(e, 'error'); }
      } }, icono('check'), 'Guardar')));
  })));
}

export async function auditoria() {
  const form = h('form', { clase: 'tarjeta fila' },
    h('div', {}, h('label', { for: 'accion' }, 'Acción (prefijo)'), h('input', { id: 'accion', name: 'accion', placeholder: 'auth.login' })),
    h('div', {}, h('label', { for: 'resultado' }, 'Resultado'), h('select', { id: 'resultado', name: 'resultado' }, ['', 'OK', 'DENEGADO', 'ERROR'].map((x) => h('option', { value: x }, x || 'Todos')))),
    h('div', {}, h('label', { for: 'desde' }, 'Desde'), h('input', { id: 'desde', name: 'desde', type: 'date' })),
    h('div', { clase: 'encoger' }, h('button', { type: 'submit' }, icono('buscar'), 'Filtrar')));
  const resultado = h('div', {});
  form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const filas = await api('GET', '/auditoria', null, formularioDatos(form));
    const denegados = filas.filter((f) => f.resultado === 'DENEGADO').length;
    resultado.replaceChildren(
      h('div', { clase: 'cifras' }, cifra(filas.length, 'Registros en el filtro', { icono: 'auditoria' }), cifra(denegados, 'Accesos denegados', { icono: 'alerta' }),
        cifra(new Set(filas.map((f) => f.usuario_correo).filter(Boolean)).size, 'Usuarios distintos', { icono: 'usuarios' })),
      tabla([
        { titulo: 'Fecha', valor: (f) => fecha(f.creado_en) }, { titulo: 'Usuario', valor: (f) => f.usuario_correo || '—' },
        { titulo: 'Acción', valor: (f) => h('span', { clase: 'num pequeño' }, f.accion) }, { titulo: 'Recurso', valor: (f) => [f.recurso, f.recurso_id].filter(Boolean).join(' #') },
        { titulo: 'Resultado', valor: (f) => etiquetaResultado(f.resultado) }, { titulo: 'IP', valor: (f) => h('span', { clase: 'num pequeño' }, f.ip || '—') },
      ], filas, 'Sin registros para el filtro.'));
  });
  montar(encabezado('Auditoría', { antetitulo: 'Seguridad', bajada: 'Los registros no se pueden modificar ni borrar desde la aplicación (RF-15).' }), form, resultado);
  form.requestSubmit();
}
