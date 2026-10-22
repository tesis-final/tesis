// ATLAS — registro de interacciones durante la resolución (RF-06, RF-09; DEC-23).
// Los eventos se numeran, se guardan en el navegador y se envían por lotes: si la
// conexión se corta no se pierden ni cambian de orden (el servidor ignora duplicados).

import { api } from './api.js';

const PAUSA_INACTIVIDAD_MS = 60_000;

export class Registro {
  constructor(intento) {
    this.intento = intento.id;
    this.clave = `atlas:eventos:${intento.id}`;
    const guardado = this.leer();
    this.cola = guardado.cola;
    this.secuencia = Math.max(guardado.secuencia, intento.proxima_secuencia);
    this.ultimaActividad = Date.now();
    this.pausado = false;
    this.enviando = false;
    this.alCambiarVisibilidad = () => (document.hidden ? this.pausa() : this.reanuda());
    document.addEventListener('visibilitychange', this.alCambiarVisibilidad);
    this.reloj = setInterval(() => {
      // D-8: la pausa por inactividad empieza en la última actividad, no al detectarla.
      if (!this.pausado && Date.now() - this.ultimaActividad >= PAUSA_INACTIVIDAD_MS) this.pausa(this.ultimaActividad);
      this.enviar();
    }, 5000);
  }

  leer() {
    try {
      return JSON.parse(localStorage.getItem(this.clave)) || { cola: [], secuencia: 2 };
    } catch {
      return { cola: [], secuencia: 2 };
    }
  }

  guardar() {
    try {
      localStorage.setItem(this.clave, JSON.stringify({ cola: this.cola, secuencia: this.secuencia }));
    } catch { /* almacenamiento lleno o deshabilitado: se sigue enviando en memoria */ }
  }

  evento(tipo, datos = {}) {
    if (tipo !== 'PAUSA' && tipo !== 'REANUDA') {
      if (this.pausado) this.reanuda();
      this.ultimaActividad = Date.now();
    }
    this.cola.push({ secuencia: this.secuencia++, tipo, ocurrido_en: new Date().toISOString(), ...datos });
    this.guardar();
    if (this.cola.length >= 10) this.enviar();
  }

  pausa(desde = Date.now()) {
    if (this.pausado) return;
    this.pausado = true;
    this.inicioPausa = desde;
    this.evento('PAUSA', { ocurrido_en: new Date(desde).toISOString() });
  }

  reanuda() {
    if (!this.pausado) return;
    this.pausado = false;
    this.ultimaActividad = Date.now();
    this.evento('REANUDA', { duracion_ms: Date.now() - this.inicioPausa });
  }

  async enviar() {
    if (this.enviando || !this.cola.length) return;
    this.enviando = true;
    const lote = this.cola.slice(0, 200);
    try {
      await api('POST', `/intentos/${this.intento}/eventos`, { eventos: lote });
      this.cola = this.cola.slice(lote.length);
      this.guardar();
    } catch {
      // Sin conexión: quedan en la cola y se reintentan.
    } finally {
      this.enviando = false;
    }
  }

  async cerrar() {
    await this.enviar();
    clearInterval(this.reloj);
    document.removeEventListener('visibilitychange', this.alCambiarVisibilidad);
    if (!this.cola.length) localStorage.removeItem(this.clave);
  }
}
