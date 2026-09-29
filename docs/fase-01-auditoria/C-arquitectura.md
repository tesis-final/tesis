# C. Arquitectura identificada

Este apartado describe la arquitectura **tal como la define el PDF**. Donde el PDF se contradice o no define algo, se marca con la referencia a G. No incluye todavía decisiones de implementación: eso corresponde a la Fase 2.

## C.1 Vista lógica (§25.1, págs. 34–35)

```
USUARIOS  (Administrador · Docente · Estudiante)
   │ HTTPS
PRESENTACIÓN  (interfaz web responsiva: HTML5, CSS3, JS sin librerías externas)
   │ REST / JSON
MIDDLEWARE  ([1] Autenticación → 401 · [2] Permisos por rol → 403 · [3] Validación → 422 · [4] Auditoría)
   │
LÓGICA DE NEGOCIO  (Actividades · Aprobación · Registro · Motor de análisis Nivel 1)   ← PHP, clases propias
   │                                   └── API REST interna ──► SERVICIO DE ANÁLISIS (Python 3.11 + FastAPI)
ACCESO A DATOS  (Repositories)                                    · Nivel 2: K-means + regresión logística
   │                                                               · Nivel 3: cliente LLM (redacción)
BASE DE DATOS — MySQL                                                       │ HTTPS
                                                                    LLM de terceros (API)
```

Reglas de la arquitectura:

- **Cada capa habla solo con la de al lado** (§25.2, p. 35). Si cambia la interfaz, la lógica no se toca; si cambia el motor de BD, el cambio queda en la capa de acceso a datos.
- **La lógica de negocio no depende de un framework** (§25.2, p. 35; H5, p. 91). Si se usa alguno, es solo para ruteo y utilidades.
- **El análisis estadístico y de patrones vive en un servicio aparte** (§25.2, p. 36). Si ese servicio cae, ATLAS sigue registrando: solo se posterga el análisis (RNF-15).
- **El LLM es una capa de redacción**: no analiza, no calcula, no decide (§18, p. 14; §25.4, p. 38–39).

La arquitectura general de V1 (§11, p. 10) ubica el motor de análisis debajo de la BD. La V2 la reemplaza explícitamente: "La sección 11 plantea la arquitectura general. Acá la desarrollamos" (§25, p. 34). **Se implementa la V2** (ver ED-06).

## C.2 Componentes y responsabilidades

| Componente | Tecnología | Responsabilidad | Fuente |
| --- | --- | --- | --- |
| Frontend | HTML5, CSS3, JavaScript sin librerías externas | Interfaz por rol; mobile-first con cortes 480/768/1024; tarjetas o tabla según el ancho; nunca solo color | Tabla 16 (p. 41); §26.5 (p. 44); H7 (p. 94) |
| Servidor web | **Apache 2.4 o Nginx** (→ DISC-01) | TLS, proxy inverso, servir `public/` | Tabla 15 (p. 40) contra Tabla 16 (p. 41) |
| Backend | PHP 8 (`php:8.3-fpm`) | API REST/JSON, middleware, lógica de negocio, motor Nivel 1, acceso a datos | Tabla 15; Tabla 16; §26.2–26.3 |
| Base de datos | MySQL 8 (`mysql:8.0`) | Persistencia, integridad, vistas, procedimientos, triggers, privilegios | Tabla 15; §27 |
| Servicio de análisis | Python 3.11 + FastAPI; pandas, NumPy, scikit-learn | K-means, regresión logística, preparación de variables, cliente LLM | Tabla 15; Tabla 16; §26.2 (p. 42) |
| LLM | API de un modelo de terceros (proveedor no definido, → AMB-10) | Redactar respuestas sobre datos ya procesados | §18 (p. 14); Tabla 16; H7 |
| Contenedores | Docker + Docker Compose | Entorno idéntico en desarrollo y producción; un comando levanta la pila | §25.5 (p. 40); Tabla 16 |
| Control de versiones | Git / GitHub | Trazabilidad | Tabla 16; Tabla 8 |

## C.3 Contenedores (Tabla 15, pág. 40)

| Contenedor | Imagen base | Función | Puerto |
| --- | --- | --- | --- |
| atlas-web | nginx:alpine | Servidor web y proxy inverso | 80, 443 (publicados) |
| atlas-php | php:8.3-fpm | Aplicación PHP | interno |
| atlas-db | mysql:8.0 | Base de datos | interno |
| atlas-analysis | python:3.11-slim | Servicio de análisis y ML | interno |

Archivos definidos (§26.2, p. 42): `docker/php/Dockerfile`, `docker/nginx/default.conf`, `docker/mysql/init.sql`, `docker-compose.yml`, `.dockerignore`.

Implicancias que surgen del propio PDF:

1. El contenedor web es Nginx, pero otras cinco partes del PDF dicen Apache (→ DISC-01).
2. MySQL corre en un contenedor, pero la Tabla 22 lo describe como servicio de systemd con `bind-address = 127.0.0.1`. Así, los contenedores atlas-php y atlas-analysis no podrían conectarse (→ DISC-02).
3. Docker publica 80/443 escribiendo reglas de iptables propias, y eso saltea las restricciones de origen de UFW (→ R-01).
4. Zabbix no figura como contenedor ni como servicio de ningún servidor (→ AMB-13).

## C.4 Recorrido de una petición (§26.3, págs. 42–43)

```
Petición HTTPS ─► atlas-web ─► atlas-php (public/index.php ─► Core: ruteo)
  [1] Autenticación: ¿hay sesión válida?            no → 401
  [2] Permisos: ¿este rol puede hacer esto?         no → 403 (y se registra: RF-03)
  [3] Validación: ¿los datos sirven?                no → 422
  [4] Auditoría: se registra la acción              (RF-15)
  ─► Controller ─► Service (lógica) ─► Repository (SQL preparado) ─► MySQL
```

El PDF justifica la cadena porque el control de acceso queda en un solo lugar y "RF-15 se cumple solo" (p. 43).

## C.5 Flujo funcional y ciclo de la actividad (§25.3, págs. 36–37; RF-16/17)

```
DOCENTE crea ─► BORRADOR ─(envía a revisión)─► PENDIENTE DE APROBACIÓN ─► ADMINISTRADOR
                                                    ├─ Rechaza ─► RECHAZADA ─► vuelve al docente con observaciones
                                                    └─ Aprueba ─► APROBADA ─► PUBLICADA   (→ DISC-13: quién publica)
ESTUDIANTE resuelve ─► se registran respuestas, tiempo, intentos, resultado (e interacciones: RF-06)
MOTOR DE ANÁLISIS ─► individual + grupal ─► PERFIL + RECOMENDACIONES ─► DOCENTE
                                                                      └► ESTUDIANTE (→ DISC-14: H4 lo prohíbe)
```

Reglas del ciclo que fija el PDF:

- Una actividad sin preguntas no puede enviarse a aprobación (H24).
- Cada pregunta tiene múltiples opciones y **una** respuesta correcta identificada (H24).
- Cada transición queda registrada con su autor (H25).
- Solo las actividades publicadas son visibles para los estudiantes, y solo las de sus grupos (H12, H25).
- El administrador aprueba porque el centro necesita un punto de control, y así queda registrado quién aprobó y cuándo (p. 37).

## C.6 Motor de análisis en tres niveles (§25.4, págs. 37–39)

| Nivel | Dónde | Entrada | Salida | Restricciones |
| --- | --- | --- | --- | --- |
| 1 — Reglas explícitas | PHP (`app/Services/Analysis`) | Intentos, respuestas, tiempos | 4 indicadores (puntaje, eficiencia, mejora, persistencia) + recomendaciones por reglas si-entonces | Determinista; reglas en la BD (`reglas_analisis`), ajustables por el administrador; cada recomendación rastreable a su regla; ≥ 8 reglas (→ AMB-01); funciona desde el primer día |
| 2 — Aprendizaje automático | Python (`atlas-analysis`) | 6 variables: puntaje promedio, tiempo relativo al grupo, cantidad de intentos, variación entre intentos, actividades abandonadas, frecuencia de uso | Agrupamientos (K-means) y señal de riesgo (regresión logística) por grupo y período | Solo con volumen suficiente (→ AMB-03); "presentar ML sobre 20 registros sería incorrecto" |
| 3 — Asistente conversacional | Python (`atlas-analysis/app/llm`) + PHP | Indicadores ya calculados, contexto armado por ATLAS | Texto en lenguaje natural | No analiza ni decide; sin datos identificables; la asociación con la persona se resuelve en ATLAS después de recibir la respuesta |

Fórmulas que da el PDF (p. 37):

- **Puntaje** = correctas / total de preguntas × 100.
- **Eficiencia**: relaciona el puntaje con el tiempo de resolución respecto al promedio del grupo. La fórmula exacta no está definida (→ AMB-02).
- **Mejora** = resultado del último intento − resultado del primero.
- **Persistencia** = cantidad de intentos hasta el resultado final.

## C.7 Flujo del asistente conversacional

Lo que exige el PDF (p. 39) y tu prompt coinciden:

```
BASE DE DATOS ─► DATOS VERIFICADOS ─► INDICADORES (N1/N2) ─► CONTEXTO ANONIMIZADO ─► LLM ─► TEXTO ─► ATLAS re-identifica ─► RESPUESTA
```

El PDF no resuelve un punto que condiciona el diseño (→ AMB-10). La pregunta del docente puede traer un nombre ("…para Juan"), y enviarla tal cual al LLM ya sería enviar un dato identificable. Por eso **la interpretación de la pregunta** (qué estudiante, qué grupo, qué período, qué tipo de consulta) tiene que resolverla ATLAS localmente y de forma determinista, antes de llamar al modelo. El LLM solo debe recibir identificadores seudónimos y valores. Esto se decide en la Fase 2.

El historial de cada consulta y su respuesta se guarda en `conversaciones` (H28).

## C.8 Degradación ante fallas (RNF-15; H27; §25.2)

| Falla | Comportamiento exigido |
| --- | --- |
| atlas-analysis caído | Los estudiantes siguen resolviendo y se sigue registrando; el Nivel 1 sigue funcionando (es PHP); los agrupamientos y la señal de riesgo se muestran como "no disponibles" |
| LLM externo no disponible | El resto de la plataforma opera; el asistente informa que no está disponible |

## C.9 Estructura de código (§26.2, págs. 41–42)

```
atlas/
├── public/            ← lo único expuesto (index.php, css/, js/, assets/)
├── app/
│   ├── Core/          ← ruteo
│   ├── Middleware/    ← login, permisos, auditoría
│   ├── Controllers/
│   ├── Models/
│   ├── Services/      ← lógica de negocio
│   │   └── Analysis/  ← motor de análisis (Nivel 1)
│   └── Repositories/  ← acceso a datos
├── config/
├── database/{migrations,seeds}/
├── tests/
├── docker/{php/Dockerfile, nginx/default.conf, mysql/init.sql}
├── docker-compose.yml, .dockerignore, .env.example, README.md

atlas-analysis/        ← "repositorio aparte" según el PDF (→ AMB-24)
├── app/{main.py, features.py, models/{clustering.py, risk.py}, llm/{client.py, prompts.py}}
├── tests/, requirements.txt, README.md
```

## C.10 Modelo de datos identificado (§27, págs. 45–49)

Unión de las tablas de §27.1 y de la Tabla 19 (24 tablas; → DISC-15):

| Grupo | Tablas |
| --- | --- |
| Identidad | instituciones, usuarios, roles, permisos, rol_permiso\*, grupos_clase, usuario_grupo\* |
| Contenido | actividades, preguntas, opciones, niveles_dificultad\* |
| Interacción | intentos, respuestas, resultados, interacciones |
| Análisis | perfiles_aprendizaje, indicadores, reglas_analisis, recomendaciones, analisis_grupal, agrupamientos\*\* |
| Control | auditoria, estados_actividad, conversaciones\*\* |

\* aparecen en §27.1 pero no en la Tabla 19. \*\* aparecen en la Tabla 19 pero no en §27.1.

Relaciones exigidas por el PDF que **no tienen tabla** (→ DISC-15):

- actividad ↔ grupo, que necesitan RF-04 y RF-11;
- regla ↔ recomendación (N:M, Tabla 19);
- historial de transiciones de estado con autor y observaciones (RF-17);
- registro de respaldos ("backups" en §7).

Decisiones del PDF:

- 3FN, salvo el puntaje guardado en `resultados`, sincronizado con trigger.
- Intentos separados de resultados; interacciones separadas de respuestas.
- Reglas en la BD.
- FK, CHECK, índices (compuesto usuario_id + actividad_id en intentos), vistas, procedimientos, triggers y transacciones.
- Cinco usuarios MySQL con privilegios mínimos (Tabla 21).

## C.11 Seguridad de la aplicación

| Control | Fuente |
| --- | --- |
| Contraseñas con hash, nunca en texto plano | §27.5 (p. 48); Tabla 14 (p. 34) |
| Sentencias preparadas en todas las consultas | §27.5 (p. 48) |
| La app nunca usa un usuario administrador de BD | Tabla 21 (p. 48) |
| Error de login que no revela qué dato falló; bloqueo tras 3 intentos | H10 (p. 99) |
| 401 / 403 / 422 en la cadena de middleware; 403 registrado | §26.3; H11 |
| Auditoría no modificable desde la aplicación | H23 (p. 112) |
| Solo `public/` expuesto; código, configuración y credenciales fuera del alcance del servidor web | §26.2 (p. 42) |
| Credenciales fuera del código (`.env.example`) | §26.2 (p. 42) |
| MySQL no accesible desde la red | §27.5; H5 (p. 92) |
| Sin datos identificables hacia servicios externos | H5 (p. 92); H28 |

## C.12 Usuarios del sistema (H4, págs. 90–91)

| Usuario | Formación técnica | Qué hace | Qué no hace |
| --- | --- | --- | --- |
| Estudiante | Ninguna | Resuelve las actividades publicadas en sus grupos | No accede a información de análisis ni de otros estudiantes |
| Docente | Ninguna | Crea actividades, consulta la evolución individual y grupal de sus estudiantes, recibe recomendaciones. **Es el usuario principal** | No accede a la gestión administrativa (H11) |
| Administrador | Conocimientos informáticos generales | Gestiona usuarios, instituciones y permisos; aprueba o rechaza actividades (§25.3); consulta la auditoría | No es necesariamente un perfil técnico (p. 37) |
