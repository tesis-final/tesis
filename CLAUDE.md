# CLAUDE.md — Contexto del proyecto ATLAS (leer antes de tocar nada)

Este archivo es para Claude Code. Describe el estado **real** del repositorio y las decisiones ya tomadas.
Si algo de lo que vas a hacer contradice este archivo, **pará y preguntá**: no supongas.

> **Actualización 22/10/2026 (leer primero).** Varias cosas de este archivo ya se hicieron y lo que diga
> abajo en tiempo futuro se lee como historia: la app **ya está en Laravel 12** (PR #7, D-1), la **migración 004**
> ya pasó el puntaje y el análisis grupal a PHP (D-4), la aprobación ya es **sin aprobación por defecto** (D-2) y
> D-3, D-5, D-6 y D-8 están implementadas (ver `docs/hito-2/README.md`). La sección 7 queda como referencia de
> cómo se hizo la migración. Redes del Hito 2: todo en **Proxmox**, sin Packet Tracer; router-lab hace de
> rt01 + fw01 con nftables (`infra/proxmox/04-router-lab.sh`). El código de verdad manda sobre este archivo.

## 1. Qué es ATLAS

Proyecto final del equipo **Error404** (ITI-CETP/UTU, Tecnicatura en Redes y Software): plataforma web donde
los estudiantes resuelven actividades de múltiple opción, el sistema registra el **proceso** (tiempos,
intentos, cambios de respuesta, abandonos) y el docente ve indicadores para saber **dónde intervenir**.

Equipo: Santiago Viñas (coordinador, PO), Juan Pablo Beracochea (subcoordinador, Scrum Master),
Aaron Britos, Brian Reyes, Sergio Rodríguez.

Hitos: Hito 1 entregado (18/09). **Hito 2: viernes 23/10/2026** ("prototipo o avance validado"). Hito 3: 20/11/2026.

## 2. Reglas que no se rompen

1. **Manda el PDF**: `docs/especificacion/TC4-Error404-ATLAS-V2.2.pdf`. Después, las devoluciones de los
   profesores y el acta de decisiones (`docs/evidencias/F/`). No inventes requisitos, tablas ni funciones.
2. **Nunca inventes resultados.** Una prueba es *Aprobada* solo si se ejecutó y pasó. Si no se pudo correr:
   *No ejecutada* y el motivo. Separá siempre diseñado / configurado / ejecutado / verificado.
3. **Secretos fuera del código**: contraseñas y claves van en variables de entorno (`atlas.conf` / `.env`,
   que no están en Git). Nunca en el repo, en commits ni en logs.
4. **Nunca se mandan datos personales al LLM** (nombres, correos, cédulas). Ya hay anonimización; no la saques.
5. Trabajo en ramas + pull request. Nadie sube directo a `main`. Antes de abrir un PR, las pruebas tienen que pasar.
6. Idioma: código de dominio y mensajes en **español** (tablas `actividades`, `intentos`, etc.), como está hoy.

## 3. Estructura del repositorio (hoy)

```
atlas/                  Aplicación Laravel 12 (PHP 8.3) + Docker
  app/                  Controllers, Core (router, kernel, sesión, validador), Middleware,
                        Repositories, Services (incluye Analysis/ y Asistente/), autoload.php
  config/rutas.php      Tabla de las 43 rutas de la API /api/v1 (permiso y reglas de validación por ruta)
  public/               index.php (entrada), app.html + js/ (SPA en JavaScript sin framework), css/
  database/migrations/  001_esquema.sql, 002_logica.sql, 003_habilidades_aprobacion.sql  ← FUENTE DE VERDAD de la BD
  database/seeds/       001_catalogos.sql, 002_habilidades.sql
  database/tools/       datos_representativos.sql, pruebas_hito2.sh, actualizar_a_003.sh, generar_documentacion.py
  docker/               php (Dockerfile php:8.3-fpm), nginx (default.conf), mysql (init.sql, 02-usuarios.sh)
  docker-compose.yml    atlas-web (nginx), atlas-php, atlas-db (mysql:8.0), atlas-analysis
  tests/                Unit, Api (contra MySQL real), Database (contra MySQL real), e2e (Playwright)
atlas-analysis/         Servicio Python (FastAPI): K-means, regresión logística, cliente LLM (Groq) con anonimización
infra/                  linux/, windows/, red/, proxmox/, laboratorio/  (infraestructura, NO es tu tarea)
docs/                   Documentación por fase, evidencias (docs/evidencias/B..G), especificación PDF
probar-local.sh         Levanta todo en la notebook con datos de demo
```

## 4. Estado actual (lo que YA funciona, con pruebas)

- Login con sesión del servidor, token **CSRF** (cabecera `X-CSRF-Token`), bloqueo por intentos fallidos,
  contraseñas con **Argon2id**.
- Tres roles: ADMIN (coordinación), DOCENTE, ESTUDIANTE, con permisos por rol (tabla `rol_permiso`).
- Ciclo de la actividad: BORRADOR → PENDIENTE → APROBADA/RECHAZADA → PUBLICADA (validado también en la BD).
- Resolución con registro de interacciones: `public/js/registro.js` numera los eventos, los guarda en el
  navegador y los manda **por lotes**; si se corta la conexión, se reenvían y el servidor ignora duplicados.
  **Inicio y fin del intento los pone el servidor**; la hora de los eventos del cliente se acota.
- Indicadores y panel del docente por actividad y por grupo; motor de reglas; servicio Python separado.
- Middleware en cadena: autenticación → permisos → validación → auditoría (`app/Middleware/`).
- Pruebas: 26 unitarias, 58 de API, 58 de base de datos (todas pasan en `main`).

Cómo correr las pruebas (Docker necesario):
```
cd atlas && composer install
vendor/bin/phpunit --testsuite unit
ATLAS_TEST_SUITES=api tests/Database/run.sh        # API contra MySQL 8.0 real descartable
tests/Database/run.sh                              # base de datos
cd ../atlas-analysis && python -m pytest
```
Probar la app en la notebook: `./probar-local.sh` (muestra las cuentas demo al final).

## 5. Base de datos (NO se rehace)

- MySQL 8.0, 31 tablas InnoDB, 45 FK, 37 CHECK, 20 triggers, 5 vistas, 1 procedimiento. Diccionario y DER:
  `docs/fase-05-base-datos/diccionario-datos.md` y `der.mmd`. Informe del Hito 2 aprobado por el equipo.
- **Los scripts SQL de `database/migrations/` son la fuente de verdad** (los evaluó el profesor de Base de Datos).
  **No los reemplaces por migraciones de Laravel** ni generes el esquema con `artisan migrate`.
- Usuarios MySQL con mínimo privilegio (`docker/mysql/02-usuarios.sh`). La app usa **`atlas_app`**, que
  **no tiene permisos de DDL** (no puede crear tablas). Consecuencias para Laravel:
  - no usar la tabla `migrations` de Laravel ni `migrate` contra la base real;
  - sesiones y caché **no** en base de datos (usar driver `file` o similar);
  - no crear tablas `users`, `password_resets`, `jobs`, etc.: los usuarios son la tabla `usuarios`
    (columna `hash_contrasena`, `rol_id`, `institucion_id`, `activo`, `intentos_fallidos`, `bloqueado_hasta`).
- Si hace falta un cambio de esquema: nuevo archivo `database/migrations/004_...sql` + permisos en
  `02-usuarios.sh` + prueba en `tests/Database/`. Se coordina con Brian (Base de Datos).
- Nuevo en el Hito 2 (ya en la base): tablas `habilidades` y `pregunta_habilidad` (N:M);
  columna `instituciones.requiere_aprobacion` (transición BORRADOR → PUBLICADA directa si es FALSE).
  Por el acta (D-2) el valor por defecto ya es FALSE (migración 004).

## 6. Decisiones del equipo (acta en docs/evidencias/F/) — obligatorias

- **D-1 Laravel en este hito**: la aplicación se migra a Laravel. Python sigue separado (eso cumple
  "independencia de un único framework"). La lógica propia (Services, Analysis/MotorReglas, Indicadores,
  Asistente) **se reutiliza** dentro de Laravel, no se reescribe desde cero.
- **D-2** Aprobación configurable por institución, **por defecto sin aprobación**; todo queda auditado.
- **D-3** Habilidades: cada pregunta mide una o más; indicadores por habilidad.
- **D-4** Indicadores y reglas en **PHP**; MySQL solo guarda y protege integridad; Python solo análisis adicional.
  Hoy el puntaje lo calcula el trigger `trg_intentos_finalizar` y el análisis grupal el procedimiento
  `sp_analisis_grupal`: hay que pasarlos a PHP y borrarlos con una migración **en el mismo PR** que el código.
- **D-5** Consultas guiadas (grupo + período + qué ver) como consulta principal; el LLM es opcional.
- **D-6** "Adaptativo" = el sistema recomienda la siguiente actividad y el docente decide.
- **D-7** "Requieren atención" con reglas simples y explicables; el ML queda como experimento.
- **D-8** De los tiempos se concluye acierto, tiempo, cambios e intentos; nada de memoria/atención.
  Mostrar tiempo activo (total menos pausas) aparte del total.

## 7. Cómo encarar la migración a Laravel (para que no se rompa nada)

1. **Laravel 11 o 12 en la carpeta `atlas/`**, PHP 8.3. Mantener `docker/`, `database/` y `tests/Database/`.
2. **Mismo contrato de API**: las 43 rutas de `config/rutas.php` con los mismos métodos, URLs (`/api/v1/...`),
   códigos (401 sin sesión, 403 sin permiso, 422 validación) y forma del JSON. Así el frontend
   (`public/js/`) sigue andando sin cambios y las pruebas de `tests/Api/` sirven como **red de seguridad**:
   tienen que seguir pasando.
3. Mapear lo que hay a Laravel:
   - `config/rutas.php` → `routes/api.php` (prefijo `v1`), con middleware de permiso por ruta;
   - `app/Middleware/*` → middleware de Laravel (autenticación de sesión, permiso, auditoría);
     validación con Form Requests usando las mismas reglas;
   - `Controllers/*` → controladores de Laravel finos que llaman a los **mismos Services**;
   - `Repositories/*` → pueden quedarse con PDO/Query Builder sobre las tablas existentes, o usar Eloquent
     con `$table`, claves y timestamps configurados a mano (las tablas no usan `created_at`/`updated_at`;
     usan `creado_en`/`actualizado_en`);
   - CSRF: el frontend manda `X-CSRF-Token`; mantener ese comportamiento.
   - Hash: Argon2id (`config/hashing.php`).
4. Configuración por variables de entorno que ya existen (`atlas/.env.example`, `ATLAS_DB_*`). No hardcodear nada.
5. Actualizar `docker/php/Dockerfile` solo con lo necesario (Composer, extensiones que pida Laravel).
6. Al final: pruebas unit + API + BD en verde, `./probar-local.sh` levanta la app y el circuito completo funciona
   (docente crea → estudiante resuelve → todo registrado → docente ve indicadores).

## 8. Lo que pide el profesor de Programación para el Hito 2

Circuito completo funcionando: **el docente crea, el estudiante resuelve, queda todo registrado y el docente
ve los indicadores**; preguntas vinculadas a habilidades; indicadores por estudiante, habilidad y grupo con
lista clara de "requieren atención"; consultas guiadas; aprobación flexible; middleware implementado y
explicable; diseño responsivo (no depender solo del color); unificar en la documentación **Nginx** (no Apache).

## 9. Hallazgos que ya se conocen (no los "descubras" de nuevo)

- `v_preguntas_error` es lenta con muchos datos (~490 ms, la vista se materializa entera). Para un grupo,
  usar una consulta que arranque por el grupo (~41 ms). Ver `docs/evidencias/G/E-BD-006`.
- La imagen `mysql:8.0` no trae `mysqlbinlog` (relevante solo para respaldos).
- Hoy la duración del intento no descuenta las pausas.

## 10. Si dudás

Preguntá antes de: borrar archivos, cambiar el esquema, cambiar la forma del JSON de la API, tocar `infra/`,
agregar dependencias grandes o cambiar algo que diga el PDF. Mejor una pregunta que una suposición.
