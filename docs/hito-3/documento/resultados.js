// Resultados que cita el documento. Cada valor sale de un archivo de evidencia del repositorio
// (docs/evidencias/...). Si se vuelve a correr una prueba, se actualiza acá y se regenera.
module.exports = {
  fechaDocumento: '20 de noviembre de 2026',
  fechaCorta: '20/11/2026',
  fechaLab: '19/11/2026',
  commit: 'rama claude/intelligent-cannon-iecvmy',

  // Corrida completa de probar-todo.sh (E-TST-010)
  todo: {
    fecha: '12/11/2026',
    filas: [
      ['unit', 'Unitarias PHP (Laravel, servicios, motor de reglas)', 'Aprobada', '37 pruebas, 146 aserciones'],
      ['psr12', 'Estándar PSR-12 (phpcs)', 'Aprobada', 'Sin errores ni advertencias'],
      ['bd', 'Base de datos contra MySQL 8.0 real', 'Aprobada', '58 pruebas, 189 aserciones'],
      ['api', 'API /api/v1 contra MySQL 8.0 real', 'Aprobada', '71 pruebas, 1369 aserciones'],
      ['analisis', 'Servicio Python (pytest)', 'Aprobada', '23 pruebas'],
      ['firewall', 'Firewall de router-lab con tráfico real, con VPN', 'Aprobada', '46 PASS, 0 FAIL'],
      ['windows', 'Módulo y scripts de atlas-dc01 (PowerShell 7)', 'Aprobada', '52 PASS, 0 FAIL'],
      ['linux', 'Scripts de atlas-srv01 en Ubuntu 24.04 real', 'Aprobada', '67 PASS, 1 FAIL esperado (smbd sin systemd)'],
      ['laboratorio', 'Ajustes del laboratorio y script de VPN', 'Aprobada', '29 PASS, 0 FAIL'],
      ['respaldos', 'atlas-respaldo contra MySQL 8.0 real', 'Aprobada', '17 PASS, 0 FAIL'],
      ['monitoreo', 'Zabbix 7.0 LTS real (agente, salud, SLA, alerta)', 'Aprobada', '14 PASS, 0 FAIL'],
    ],
  },

  interfaz: '29 de 29 controles (E-APP-015)',
  gemeloVpn: '46 de 46 controles, E-RED-011',
  monitoreo: '14 de 14 controles, E-RED-013',
  trazado: '6 de 6 controles (E-BD-016)',
  restauracion: '13 de 13 comparaciones iguales, en 1 s (E-BD-018)',
  comparacion: { medianaA: '5,61 ms', medianaB: '49,35 ms', p95A: '7,28 ms', p95B: '54,21 ms' },
  rendimiento: { p95max: '58 ms', consultas: 7 },
  disponibilidad: '100 % (119 de 119 respuestas en 10 minutos)',

  // Laboratorio Proxmox, jornada del 19/11/2026 (capturas en docs/hito-3/capturas/)
  lab: {
    seguir: 'intento 3: 4 interacciones, una respuesta final, un único resultado de 100,00 igual al recalculado',
    restauracion: '13 de 13 comparaciones iguales; respaldo en 165 ms y restauración en 1004 ms',
    metricas: '6 PASS, 0 FAIL y 5 informativas',
    vzdump: '30 GiB leídos en 124 s; archivo de 5,2 GB',
    qmrestore: '81 s (de 23:46:48 a 23:48:09)',
    verificarSrv: '86 PASS y 31 FAIL',
    verificarDc: '63 PASS y 5 FAIL',
  },
};
