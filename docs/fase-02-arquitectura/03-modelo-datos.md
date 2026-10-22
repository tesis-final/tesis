# 03 — Modelo de datos final

> **Actualización Hito 2 (22/10/2026).** Este es el diseño aprobado en la Fase 2 y se conserva como registro. Por el acta del Hito 2 (D-4), la migración `004_calculos_en_php.sql` cambió tres puntos: el puntaje lo calcula la aplicación en vez de `trg_intentos_finalizar`, el análisis grupal lo calcula la aplicación en vez de `sp_analisis_grupal`, y la versión de las reglas y la auditoría de cambios las escribe la aplicación en vez de triggers. También agregó `decisiones_recomendacion` (D-6) e `intentos.duracion_activa_seg` (D-8), y la aprobación pasó a no exigirse por defecto (D-2). El estado actual está en [fase-05-base-datos](../fase-05-base-datos/README.md) y en el [diccionario regenerado](../fase-05-base-datos/diccionario-datos.md).

Base `atlas_db` en MySQL 8.0, motor InnoDB, `utf8mb4`. Todas las relaciones tienen clave foránea (Tabla 20). Las 29 tablas son la unión de §27.1 y la Tabla 19 (24), más las 4 de DEC-15 y la de DEC-16.

Convenciones: `id` BIGINT UNSIGNED AUTO_INCREMENT como PK salvo en tablas de unión (PK compuesta); fechas `DATETIME(3)` en UTC.

## 1. Tablas

### Identidad (7)

| # | Tabla | Columnas principales | Claves y restricciones | Fuente |
| -- | --- | --- | --- | --- |
| 1 | `instituciones` | id, nombre, activa, creado_en | UNIQUE(nombre) | Tabla 19 |
| 2 | `roles` | id, codigo (`ADMIN`, `DOCENTE`, `ESTUDIANTE`), nombre | UNIQUE(codigo) | RF-03 |
| 3 | `permisos` | id, codigo (ej. `actividades.aprobar`), descripcion | UNIQUE(codigo) | RF-03, RF-14 |
| 4 | `rol_permiso` | rol_id, permiso_id, activo | PK(rol_id, permiso_id); FK a roles y permisos | §27.1 |
| 5 | `usuarios` | id, institucion_id, rol_id, nombre, apellido, correo, hash_contrasena, activo, intentos_fallidos, bloqueado_hasta, creado_en, actualizado_en | UNIQUE(correo); FK institucion_id, rol_id (N:1 con roles, Tabla 19); CHECK(intentos_fallidos ≥ 0) | RF-01, RF-02 |
| 6 | `grupos_clase` | id, institucion_id, nombre, anio_lectivo | UNIQUE(institucion_id, nombre, anio_lectivo) | Tabla 19 |
| 7 | `usuario_grupo` | usuario_id, grupo_id, activo | PK(usuario_id, grupo_id); docentes y estudiantes | §27.1 |

`rol_permiso.activo` y `usuario_grupo.activo` permiten revocar sin DELETE. `atlas_app` solo tiene SELECT, INSERT y UPDATE (Tabla 21).

### Contenido (8)

| # | Tabla | Columnas principales | Claves y restricciones | Fuente |
| -- | --- | --- | --- | --- |
| 8 | `niveles_dificultad` | id, codigo, nombre, orden | UNIQUE(codigo), UNIQUE(orden) | RF-05 |
| 9 | `categorias` | id, codigo, nombre | UNIQUE(codigo) | DEC-16 |
| 10 | `estados_actividad` | id, codigo (`BORRADOR`, `PENDIENTE`, `APROBADA`, `RECHAZADA`, `PUBLICADA`), nombre | UNIQUE(codigo) | RF-17, Tabla 19 |
| 11 | `actividades` | id, autor_id, nivel_id, categoria_id, estado_id, titulo, descripcion, creado_en, actualizado_en | FK autor_id → usuarios (N:1), nivel_id, categoria_id, estado_id (1:N desde estados) | RF-16 |
| 12 | `preguntas` | id, actividad_id, orden, enunciado | UNIQUE(actividad_id, orden) | RF-16 |
| 13 | `opciones` | id, pregunta_id, orden, texto, es_correcta | UNIQUE(pregunta_id, orden) | RF-16 |
| 14 | `transiciones_actividad` | id, actividad_id, estado_origen_id (NULL al crear), estado_destino_id, usuario_id, observaciones, creado_en | FK a actividades, estados_actividad (×2), usuarios | DEC-15, RF-17 |
| 15 | `actividad_grupo` | actividad_id, grupo_id, publicado_por, publicado_en | PK(actividad_id, grupo_id); FK publicado_por → usuarios | DEC-15, RF-04 |

"Exactamente una opción correcta por pregunta" y "sin preguntas no se envía a aprobación" (H24) se validan en la capa de servicio al enviar. Un trigger `BEFORE UPDATE` sobre `actividades` repite el control cuando el estado pasa a `PENDIENTE`, como segunda barrera.

### Interacción (4)

| # | Tabla | Columnas principales | Claves y restricciones | Fuente |
| -- | --- | --- | --- | --- |
| 16 | `intentos` | id, usuario_id, actividad_id, numero_intento, estado (`EN_CURSO`, `FINALIZADO`, `ABANDONADO`), iniciado_en, finalizado_en, duracion_seg | INDEX(usuario_id, actividad_id) (Tabla 20); UNIQUE(usuario_id, actividad_id, numero_intento); CHECK(duracion_seg ≥ 0) | RF-08, RF-09 |
| 17 | `respuestas` | id, intento_id, pregunta_id, opcion_id, tiempo_seg, respondido_en | UNIQUE(intento_id, pregunta_id); CHECK(tiempo_seg ≥ 0) | RF-06, RF-09 |
| 18 | `interacciones` | id, intento_id, secuencia, tipo (`INICIO`, `VER_PREGUNTA`, `SELECCION`, `CAMBIO_OPCION`, `PAUSA`, `REANUDA`, `NAVEGACION`, `FIN`, `ABANDONO`), pregunta_id, opcion_id, ocurrido_en, duracion_ms | UNIQUE(intento_id, secuencia); CHECK(duracion_ms ≥ 0) | RF-06, H14 |
| 19 | `resultados` | id, intento_id, correctas, total_preguntas, puntaje, calculado_en | UNIQUE(intento_id) (1:1); CHECK(puntaje BETWEEN 0 AND 100); CHECK(correctas BETWEEN 0 AND total_preguntas) | RF-07, §27.3 |

- Si una respuesta es correcta no se guarda en `respuestas`: se deriva de `opciones.es_correcta` (3FN).
- `resultados.puntaje` es la **única desnormalización** (§27.3). La crea el trigger `trg_intentos_finalizar` cuando el intento pasa a `FINALIZADO`. Los abandonados no generan resultado (H15).

### Análisis (7)

| # | Tabla | Columnas principales | Claves y restricciones | Fuente |
| -- | --- | --- | --- | --- |
| 20 | `perfiles_aprendizaje` | id, usuario_id, periodo_inicio, periodo_fin, actualizado_en | UNIQUE(usuario_id, periodo_inicio); N:1 con usuarios | RF-10 |
| 21 | `indicadores` | id, perfil_id, actividad_id (NULL en los de ML), agrupamiento_id (NULL salvo `CLUSTER`), tipo (`PUNTAJE`, `EFICIENCIA`, `MEJORA`, `PERSISTENCIA`, `CLUSTER`, `RIESGO`), valor, origen (`NIVEL1`, `NIVEL2`), calculado_en | N:1 con perfiles; INDEX(perfil_id, tipo) | RF-10, §25.4 |
| 22 | `reglas_analisis` | id, codigo, nombre, descripcion, tipo (`RIESGO`, `REFUERZO`, `AVANCE`, `RECONOCIMIENTO`), condicion (JSON), recomendacion_plantilla, prioridad, activa, version, actualizado_por, actualizado_en | UNIQUE(codigo) | ANA-05, §27.3 |
| 23 | `recomendaciones` | id, perfil_id, actividad_sugerida_id (NULL), texto, generado_en | N:1 con perfiles | RF-12 |
| 24 | `recomendacion_regla` | recomendacion_id, regla_id, version_regla, valores_entrada (JSON) | PK(recomendacion_id, regla_id) | DEC-15, ANA-07 |
| 25 | `analisis_grupal` | id, grupo_id, actividad_id (NULL = todas), periodo_inicio, periodo_fin, n_estudiantes, promedio, mediana, minimo, maximo, generado_en | N:1 con grupos_clase; CHECK de rango 0–100 | RF-18 |
| 26 | `agrupamientos` | id, grupo_id, periodo_inicio, periodo_fin, k, silueta, modelo_version, n_muestras, generado_en | N:1 con grupos_clase | RF-19 |

- El cluster y la probabilidad de riesgo de cada estudiante se guardan como filas de `indicadores` (tipos `CLUSTER` y `RIESGO`). Así `atlas_analysis` solo necesita **INSERT en tablas de análisis**, tal como dice la Tabla 21, sin tablas extra.
- `reglas_analisis.condicion` y `recomendacion_regla.valores_entrada` son JSON a propósito:
  - la condición es la definición editable de la regla (§27.3: el administrador la ajusta sin tocar código);
  - `valores_entrada` es la **foto** de los datos usados, que sostiene la trazabilidad pedida en H20.

  No son atributos repetidos que violen 1FN.

### Control (3)

| # | Tabla | Columnas principales | Claves y restricciones | Fuente |
| -- | --- | --- | --- | --- |
| 27 | `auditoria` | id, usuario_id (NULL si falla el login de un correo inexistente), accion, recurso, recurso_id, resultado (`OK`, `DENEGADO`, `ERROR`), ip, detalle (JSON), creado_en | INDEX(creado_en), INDEX(usuario_id) | RF-15 |
| 28 | `conversaciones` | id, docente_id, pregunta, tipo_consulta, contexto_enviado, respuesta, estado (`OK`, `NO_RECONOCIDA`, `LLM_NO_DISPONIBLE`), creado_en | N:1 con usuarios | RF-20, H28 |
| 29 | `registro_respaldos` | id, tipo (`COMPLETO`, `INCREMENTAL`, `CONFIG`), iniciado_en, finalizado_en, resultado (`OK`, `FALLO`), destino (`LOCAL`, `WINDOWS`), archivo, sha256, tamano_bytes, verificado | INDEX(iniciado_en) | DEC-15, §12 |

`contexto_enviado` guarda lo que efectivamente salió hacia el LLM (ya anonimizado): es la evidencia de H28.

## 2. Cobertura de §7 (qué debe almacenarse)

| Entidad de §7 | Dónde |
| --- | --- |
| estudiantes, docentes, usuarios | `usuarios` + `roles` |
| instituciones | `instituciones` |
| actividades | `actividades`, `preguntas`, `opciones` |
| resultados | `resultados` |
| intentos | `intentos` |
| tiempos | `intentos.duracion_seg`, `respuestas.tiempo_seg`, `interacciones.duracion_ms` |
| eventos | `interacciones` |
| perfiles | `perfiles_aprendizaje`, `indicadores` |
| recomendaciones | `recomendaciones`, `recomendacion_regla` |
| roles, permisos | `roles`, `permisos`, `rol_permiso` |
| auditoría | `auditoria` |
| backups | `registro_respaldos` |

## 3. Reglas de integridad del dominio

### 3.1 Transacciones (Tabla 20)

- Finalizar un intento (respuestas pendientes + cambio de estado + resultado por trigger + indicadores + recomendaciones) se guarda en **una** transacción.
- Cada transición de actividad (cambio de estado + fila en `transiciones_actividad` + auditoría) también es una sola transacción.

### 3.2 Triggers

| Trigger | Qué hace |
| --- | --- |
| `trg_intentos_finalizar` (AFTER UPDATE en intentos) | Crea el resultado al pasar a `FINALIZADO` |
| `trg_actividades_validar_envio` (BEFORE UPDATE) | Segunda barrera de H24 |
| `trg_usuarios_auditoria`, `trg_reglas_auditoria`, `trg_rol_permiso_auditoria` (AFTER UPDATE/INSERT) | "Auditoría automática" (Tabla 20) de los cambios administrativos |
| `trg_auditoria_inmutable` (BEFORE UPDATE / BEFORE DELETE en auditoria) | Rechaza cualquier modificación, además de que `atlas_app` no tiene esos privilegios (H23) |

### 3.3 Ciclo de estados (RF-17, DEC-12)

| Desde | Hacia | Quién | Condición |
| --- | --- | --- | --- |
| (creación) | BORRADOR | Docente | — |
| BORRADOR | PENDIENTE | Docente autor | ≥ 1 pregunta; cada pregunta con ≥ 2 opciones y exactamente 1 correcta |
| PENDIENTE | APROBADA | Administrador | — |
| PENDIENTE | RECHAZADA | Administrador | Observaciones obligatorias |
| RECHAZADA | BORRADOR | Docente autor | El docente edita a partir de las observaciones |
| APROBADA | PUBLICADA | Docente autor | Elige ≥ 1 de sus grupos (`actividad_grupo`) |

- Cualquier otra transición → 422.
- El contenido solo se edita en BORRADOR.
- Solo lo PUBLICADO es visible para los estudiantes de los grupos asignados (H12, H25).

## 4. Vistas y procedimientos

| Objeto | Para qué | Quién lo usa |
| --- | --- | --- |
| `v_resultados_detalle` | Intento + resultado + estudiante + actividad + grupo + nivel + categoría | atlas_read |
| `v_evolucion_estudiante` | Puntaje por actividad en el tiempo | atlas_read (RF-11) |
| `v_distribucion_puntajes` | Rangos 0–19 … 80–100 por grupo y actividad | atlas_read (RF-18) |
| `v_preguntas_error` | Proporción de error por pregunta y grupo | atlas_read (RF-18) |
| `v_recomendaciones_riesgo` | Recomendaciones de reglas de tipo RIESGO por estudiante y período | atlas_read (atención prioritaria) |
| `sp_analisis_grupal(grupo, desde, hasta)` | Calcula el agregado y lo inserta en `analisis_grupal` | atlas_app (EXECUTE) (DEC-11) |

El filtro "solo sus grupos" lo aplica siempre la aplicación, con el `usuario_grupo` del docente, sobre las vistas.

## 5. Usuarios de MySQL y privilegios (Tabla 21 + DEC-10)

Origen permitido: la subred de `atlas_back` (CT-07). Ningún usuario acepta conexiones desde otra red.

| Usuario | Privilegios | Para qué |
| --- | --- | --- |
| `atlas_app` | SELECT, INSERT, UPDATE sobre las tablas operativas; **solo** SELECT e INSERT sobre `auditoria`, `transiciones_actividad`, `conversaciones`; EXECUTE sobre `sp_analisis_grupal`; sin DELETE, DROP, ALTER ni GRANT | Aplicación web |
| `atlas_read` | SELECT sobre las vistas `v_*` | Panel docente y reportes |
| `atlas_analysis` | SELECT sobre intentos, respuestas, interacciones, resultados; SELECT(usuario_id, grupo_id, activo) sobre usuario_grupo; SELECT(id, usuario_id, periodo_inicio, periodo_fin) sobre perfiles_aprendizaje; INSERT sobre agrupamientos e indicadores | Nivel 2. Nunca lee nombres ni correos |
| `atlas_backup` | SELECT, LOCK TABLES, SHOW VIEW, TRIGGER, SHOW_ROUTINE; INSERT sobre `registro_respaldos` | Respaldos (DEC-10, CT-06) |
| `atlas_admin` | ALL PRIVILEGES sobre `atlas_db`, solo desde localhost del contenedor | Administración manual; la app nunca lo usa |

## 6. Datos semilla

- Roles (3), permisos y su asignación.
- Estados (5).
- Niveles: básico, intermedio, avanzado (el PDF no fija cuáles, así que se proponen tres, editables).
- Categorías iniciales: "resolución de problemas" (citada en p. 38), "razonamiento lógico", "memoria" y "atención" (variables de §2). Editables.
- Una institución: ITI (§17).
- Reglas del motor, según el borrador de 04-motor-analisis, **una vez aprobado**.
- Los datos de prueba son **sintéticos** y están marcados como tales (R-10, R-22).
