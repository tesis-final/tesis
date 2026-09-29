# 02 — Arquitectura final

Integra el PDF (§25, §26, §28) con las decisiones de 01-registro-decisiones. Donde no se cita decisión, rige el PDF literal.

## 1. Vista de capas

```
Navegador (Administrador · Docente · Estudiante)        Cliente VPN docente (10.8.0.128/25)
        │ HTTPS 443 (certificado de ATLAS-CA, DEC-20)            │ WireGuard → fw01 → rt01
        ▼                                                        ▼
┌────────────────────────── atlas-srv01 (172.16.40.10) ────────────────────────────┐
│ atlas-web  nginx:alpine   :443 (y :80 solo redirección, bloqueado desde la red)  │
│     │ FastCGI :9000 (red atlas_front)                                            │
│ atlas-php  php:8.3-fpm    UID 5002 (atlasweb)                                    │
│     public/index.php → Core (ruteo) → Middleware [1]–[4] → Controllers           │
│     → Services (lógica, Nivel 1) → Repositories (PDO, sentencias preparadas)     │
│     │ TCP 3306 (red atlas_back, interna)      │ HTTP :8000 (red atlas_back)      │
│ atlas-db  mysql:8.0  UID 5003 (atlasdb)   atlas-analysis python:3.11-slim        │
│     datos: /srv/atlas/datos                   FastAPI · K-means · regr. logística │
│                                               cliente LLM ── red atlas_egress ──►│── HTTPS → API del LLM (regla 7)
└──────────────────────────────────────────────────────────────────────────────────┘
```

Reglas que se mantienen del PDF:

- Cada capa habla solo con la contigua.
- La lógica no depende de un framework: el ruteo (`app/Core`) es propio y Composer se usa solo para autoload y PHPUnit.
- El análisis estadístico va aparte.
- El LLM solo redacta.

## 2. Contenedores

| Contenedor | Imagen | Usuario | Redes | Puertos publicados | Montajes |
| --- | --- | --- | --- | --- | --- |
| atlas-web | `nginx:alpine` | master root, workers `nginx` | atlas_front | `172.16.40.10:443`, `172.16.40.10:80` (80 solo redirige a 443; la red no lo permite, DEC-05) | `/srv/atlas/web/public` (ro), certificado desde `/srv/atlas/config/tls` (ro) |
| atlas-php | `php:8.3-fpm` + extensiones `pdo_mysql` (Dockerfile propio) | 5002:5002 | atlas_front, atlas_back | ninguno | `/srv/atlas/web/app` (ro), `/srv/atlas/web/public` (ro), `/srv/atlas/logs` (rw por ACL) |
| atlas-db | `mysql:8.0` | 5003:5003 | atlas_back (interna) | **ninguno** | `/srv/atlas/datos` → `/var/lib/mysql` |
| atlas-analysis | `python:3.11-slim` + requirements | 65534 (CT-11) | atlas_back, atlas_egress | ninguno | ninguno |

- **Secretos**: `env_file: /srv/atlas/config/atlas.conf` (CT-12), con modo 640 root:atlas-admin y `chattr +i`. El repositorio solo lleva `.env.example`.
- **Salud y reinicio**: `restart: unless-stopped` y healthchecks (web `/api/v1/health`, db `mysqladmin ping`, analysis `/health`). La unidad systemd `atlas.service` ejecuta `docker compose up -d` al arrancar el servidor.
- **Logs**: driver `journald` de Docker para que `journalctl` y rsyslog los centralicen (Tabla 46). La aplicación escribe además `/srv/atlas/logs/auditoria.log` (append-only).

Monitoreo (DEC-19), en un proyecto Compose aparte (`infra/monitoring`): `zabbix-server-mysql`, `zabbix-web-nginx-mysql` (publicado solo en `127.0.0.1:8080`) y `zabbix-db` (`mysql:8.0`, red interna `zbx_back`), todos Zabbix 7.0 LTS. El agente `zabbix-agent2` se instala en el host srv01 y en dc01.

## 3. Mapeo al sistema de archivos de §28.3

| Ruta | Contenido | Dueño y modo (§28.3) |
| --- | --- | --- |
| `/srv/atlas/web/public/` | `atlas/public` del repositorio | atlasweb:atlas-web 755 |
| `/srv/atlas/web/app/` | `atlas/app`, `atlas/config`, `atlas/database`, `atlas/vendor` (sin dev) | atlasweb:atlas-web 750 |
| `/srv/atlas/datos/` | datadir de MySQL | atlasdb:atlas-db 770 |
| `/srv/atlas/logs/` | `auditoria.log`, logs de respaldo | atlasadmin:atlas-admin 770 + ACL |
| `/srv/atlas/scripts/` | scripts de respaldo, verificación, aprovisionamiento | atlasadmin:atlas-admin 750 + ACL |
| `/srv/atlas/config/` | `atlas.conf` (+i), `tls/`, `docker-compose.yml`, opciones de conexión de respaldo | atlasadmin:atlas-admin 750 + ACL |
| `/srv/atlas/backups/` | respaldos locales | atlasbkp:atlas-backup 700 + ACL |

## 4. API REST (JSON, prefijo `/api/v1`)

Todas las rutas pasan por la cadena de middleware ([1] 401, [2] 403, [3] 422, [4] auditoría), salvo `POST /auth/login` y `GET /health`, que no requieren sesión.

| Método y ruta | Rol | Requisito |
| --- | --- | --- |
| `POST /auth/login`, `POST /auth/logout`, `GET /auth/me` | todos | RF-02 |
| `GET/POST /usuarios`, `PATCH /usuarios/{id}`, `POST /usuarios/{id}/desactivar` | admin | RF-01, RF-14 |
| `GET/POST/PATCH /instituciones` | admin | RF-14 |
| `GET /roles`, `PUT /roles/{id}/permisos` | admin | RF-03, RF-14 |
| `GET/POST /grupos`, `PUT /grupos/{id}/miembros` | admin | RF-04, RF-11 |
| `GET/POST /actividades`, `GET/PATCH /actividades/{id}` (solo en borrador) | docente | RF-05, RF-16 |
| `POST /actividades/{id}/enviar` | docente autor | RF-17 |
| `POST /actividades/{id}/aprobar`, `POST /actividades/{id}/rechazar` (observaciones obligatorias) | admin | RF-17 |
| `POST /actividades/{id}/publicar` (grupos) | docente autor | RF-17, DEC-12 |
| `GET /actividades/{id}/transiciones` | docente autor, admin | RF-17 |
| `GET /estudiante/actividades` | estudiante | RF-04 |
| `POST /intentos` | estudiante | RF-08 |
| `POST /intentos/{id}/eventos` (lote) | estudiante | RF-06 |
| `PUT /intentos/{id}/respuestas/{pregunta}` | estudiante | RF-06, RF-09 |
| `POST /intentos/{id}/finalizar`, `POST /intentos/{id}/abandonar` | estudiante | RF-07, RF-08, RF-09 |
| `GET /intentos/{id}/resultado` | estudiante dueño | RF-07 |
| `GET /docente/grupos`, `GET /docente/grupos/{id}/analisis` | docente | RF-11, RF-18 |
| `GET /docente/estudiantes/{id}/perfil` | docente del grupo | RF-10, RF-11 |
| `GET /recomendaciones/{id}/fundamento` | docente del grupo | RF-12 |
| `GET /reportes?grupo=&actividad=&desde=&hasta=` | docente (sus grupos), admin | RF-13 |
| `GET/PATCH /reglas` | admin | ANA-05 |
| `GET /auditoria` | admin | RF-15 |
| `POST /asistente/consultas`, `GET /asistente/consultas` | docente | RF-20 |
| `GET /health` | público interno | RNF-02, RNF-03 |

## 5. Sesión y seguridad de la aplicación

- **Sesión**: sesión nativa de PHP; cookie `Secure`, `HttpOnly`, `SameSite=Strict`; se regenera el ID al iniciar sesión; expira por inactividad. Token CSRF en toda petición que cambie estado.
- **Contraseñas**: `password_hash` con Argon2id. El error de login es genérico. Tras 3 fallos por cuenta, la cuenta se bloquea durante el tiempo que fije el borrador aprobado (DEC-23); todo queda auditado.
- **Autorización**: permisos por rol desde `rol_permiso` y **alcance por grupo** (el docente solo ve sus grupos: RF-11, RF-13; el estudiante solo lo propio).
- **Datos**: todas las consultas usan PDO con sentencias preparadas. La app usa `atlas_app` para operar y `atlas_read` para las vistas de reportes. Nunca usa `atlas_admin`.
- **Auditoría**: el middleware [4] registra en `auditoria` (INSERT solamente) y en `auditoria.log` con `chattr +a`.

## 6. Degradación (RNF-15)

| Falla | Qué hace la app |
| --- | --- |
| atlas-analysis no responde | Cliente HTTP con timeout corto (conexión 2 s, total 5 s): registro, resolución, Nivel 1, panel y reportes siguen; los agrupamientos y la señal de riesgo se muestran como "no disponibles" |
| LLM no disponible | El asistente responde "no disponible" y guarda la consulta con estado `LLM_NO_DISPONIBLE`; el resto no se afecta |

## 7. Frontend

- HTML5, CSS3 y JavaScript propios, sin librerías externas ni CDN (Tabla 16).
- Mobile-first con cortes en 480, 768 y 1024 px; tarjetas en pantalla chica y tablas en grande.
- Los indicadores usan color **y** texto o ícono (nunca solo color).
- Panel docente con la vista grupal primero: dónde intervenir, preguntas con más error y estudiantes prioritarios. Después viene el detalle individual (§20.4, H.2.3).
- El registro de interacciones del cliente capta: inicio, ver pregunta, selección, cambio de opción, pausa y reanudación (`visibilitychange` e inactividad), navegación, fin y abandono. Envía por lotes con marca de tiempo y número de secuencia; si la red falla, reintenta sin perder el orden.

## 8. Flujo del asistente (RF-20)

```
Pregunta del docente
  → IntentParser local (determinista): tipo de consulta + entidades dentro de SU alcance
      tipos: ESTADO_GRUPO(grupo, categoría?, período) · DIFICULTAD(grupo?, período) · EXPLICAR_RECOMENDACION(estudiante)
      si no se reconoce: ayuda, sin llamar al LLM
  → Datos verificados (BD) → indicadores N1/N2 ya calculados
  → Anonimizador: nombres → E1..En, grupo → G1; sin cédulas, correos ni nombres; solo valores
  → POST atlas-analysis /v1/llm/redactar {tipo, pregunta_sanitizada, contexto}
  → Proveedor LLM (DEC-24 pendiente; configurado por variables de entorno)
  → Texto con seudónimos → PHP re-identifica → respuesta al docente
  → conversaciones: pregunta original, contexto anonimizado enviado, respuesta, estado
```

Nunca hay un camino BD → LLM → decisión: el LLM recibe números ya calculados y devuelve texto.

## 9. Integración con la infraestructura

| Aspecto | Cómo |
| --- | --- |
| Nombre | `atlas-srv01.atlas.local` (registro A y PTR en el DNS del DC) |
| Hora | chrony → atlas-dc01 (Tabla 35) |
| Identidades del SO | SSSD unido a atlas.local; GG_SoporteTI → atlas-admin y atlas-audit (Tabla 36, DEC-18) |
| Carpetas compartidas | Samba: `administracion`, `docentes` (CT-10) |
| Respaldos externos | CIFS hacia `\\atlas-dc01\atlas-backups` con `svc_atlas_backup` (CT-09) |
| Salida a Internet | apt, imágenes Docker y API del LLM por fw01 (reglas 5 y 7). El DNS lo resuelve el DC (nota b de la Tabla 44) |
