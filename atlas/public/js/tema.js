// ATLAS — aplica el tema guardado antes de pintar la página (evita el parpadeo).
// Es un archivo aparte porque la CSP no permite scripts en línea. Si no hay
// preferencia guardada, manda la del sistema operativo (prefers-color-scheme).
(function () {
  try {
    var tema = localStorage.getItem('atlas:tema');
    if (tema === 'claro' || tema === 'oscuro') document.documentElement.setAttribute('data-tema', tema);
  } catch (e) { /* almacenamiento bloqueado: se usa el tema del sistema */ }
}());
