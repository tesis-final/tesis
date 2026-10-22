// ATLAS — cliente de la API REST/JSON (PDF §25.2). Envía el token CSRF en toda
// petición que modifica datos y traduce los errores a mensajes legibles.

let csrf = null;
let navegacion = 0;

export function definirCsrf(token) {
  csrf = token;
}

// Cada cambio de pantalla abre una "navegación" nueva (app.js). Una lectura que vuelve
// cuando el usuario ya está en otra pantalla se descarta (no resuelve nunca): así una
// pantalla lenta no pisa a la que el usuario abrió después. Las escrituras no se tocan.
export function nuevaNavegacion() {
  navegacion++;
}

export class ErrorApi extends Error {
  constructor(estado, datos) {
    super(datos?.error || `Error ${estado}`);
    this.estado = estado;
    this.errores = datos?.errores || {};
  }
}

export async function api(metodo, ruta, cuerpo = null, consulta = null) {
  let url = `/api/v1${ruta}`;
  if (consulta) {
    const qs = new URLSearchParams(Object.entries(consulta).filter(([, v]) => v !== null && v !== undefined && v !== ''));
    if ([...qs].length) url += `?${qs}`;
  }
  const cabeceras = { Accept: 'application/json' };
  if (cuerpo !== null) cabeceras['Content-Type'] = 'application/json';
  if (metodo !== 'GET' && csrf) cabeceras['X-CSRF-Token'] = csrf;
  const desde = navegacion;
  const respuesta = await fetch(url, {
    method: metodo,
    headers: cabeceras,
    body: cuerpo !== null ? JSON.stringify(cuerpo) : undefined,
    credentials: 'same-origin',
  });
  const texto = await respuesta.text();
  if (metodo === 'GET' && desde !== navegacion) return new Promise(() => {});
  const datos = texto ? JSON.parse(texto) : null;
  if (!respuesta.ok) {
    if (respuesta.status === 401 && !ruta.startsWith('/auth/')) {
      window.dispatchEvent(new CustomEvent('atlas:sesion-vencida'));
    }
    throw new ErrorApi(respuesta.status, datos);
  }
  return datos;
}
