# Diccionario de datos — atlas_db

Generado automáticamente desde `information_schema` de la base en ejecución (`database/tools/generar_documentacion.py`). No editar a mano.

## Identidad

### `instituciones`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | bigint unsigned | NO | PRI | auto_increment |  |
| `nombre` | varchar(150) | NO | UNI |  |  |
| `activa` | tinyint(1) | NO |  | 1 |  |
| `creado_en` | datetime(3) | NO |  | CURRENT_TIMESTAMP(3) DEFAULT_GENERATED |  |

### `roles`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | tinyint unsigned | NO | PRI | auto_increment |  |
| `codigo` | varchar(20) | NO | UNI |  |  |
| `nombre` | varchar(50) | NO |  |  |  |

Restricciones CHECK:

- `ck_roles_codigo`: `(codigo in (_utf8mb4\\'ADMIN\\',_utf8mb4\\'DOCENTE\\',_utf8mb4\\'ESTUDIANTE\\'))`

### `permisos`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | smallint unsigned | NO | PRI | auto_increment |  |
| `codigo` | varchar(60) | NO | UNI |  |  |
| `descripcion` | varchar(200) | NO |  |  |  |

### `rol_permiso`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `rol_id` | tinyint unsigned | NO | PRI |  | → `roles.id` |
| `permiso_id` | smallint unsigned | NO | PRI |  | → `permisos.id` |
| `activo` | tinyint(1) | NO |  | 1 |  |

### `usuarios`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | bigint unsigned | NO | PRI | auto_increment |  |
| `institucion_id` | bigint unsigned | NO | MUL |  | → `instituciones.id` |
| `rol_id` | tinyint unsigned | NO | MUL |  | → `roles.id` |
| `nombre` | varchar(80) | NO |  |  |  |
| `apellido` | varchar(80) | NO |  |  |  |
| `correo` | varchar(190) | NO | UNI |  |  |
| `hash_contrasena` | varchar(255) | NO |  |  |  |
| `activo` | tinyint(1) | NO |  | 1 |  |
| `intentos_fallidos` | tinyint unsigned | NO |  | 0 |  |
| `bloqueado_hasta` | datetime(3) | YES |  |  |  |
| `creado_en` | datetime(3) | NO |  | CURRENT_TIMESTAMP(3) DEFAULT_GENERATED |  |
| `actualizado_en` | datetime(3) | NO |  | CURRENT_TIMESTAMP(3) DEFAULT_GENERATED on update CURRENT_TIMESTAMP(3) |  |

Restricciones CHECK:

- `ck_usuarios_apellido`: `(char_length(trim(apellido)) > 0)`
- `ck_usuarios_correo`: `(correo like _utf8mb4\\'%_@_%\\')`
- `ck_usuarios_nombre`: `(char_length(trim(nombre)) > 0)`

### `grupos_clase`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | bigint unsigned | NO | PRI | auto_increment |  |
| `institucion_id` | bigint unsigned | NO | MUL |  | → `instituciones.id` |
| `nombre` | varchar(60) | NO |  |  |  |
| `anio_lectivo` | smallint unsigned | NO |  |  |  |

Restricciones CHECK:

- `ck_grupos_anio`: `(anio_lectivo between 2000 and 2100)`

### `usuario_grupo`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `usuario_id` | bigint unsigned | NO | PRI |  | → `usuarios.id` |
| `grupo_id` | bigint unsigned | NO | PRI |  | → `grupos_clase.id` |
| `activo` | tinyint(1) | NO |  | 1 |  |

## Contenido

### `niveles_dificultad`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | tinyint unsigned | NO | PRI | auto_increment |  |
| `codigo` | varchar(20) | NO | UNI |  |  |
| `nombre` | varchar(50) | NO |  |  |  |
| `orden` | tinyint unsigned | NO | UNI |  |  |

### `categorias`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | smallint unsigned | NO | PRI | auto_increment |  |
| `codigo` | varchar(40) | NO | UNI |  |  |
| `nombre` | varchar(80) | NO |  |  |  |

### `estados_actividad`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | tinyint unsigned | NO | PRI | auto_increment |  |
| `codigo` | varchar(20) | NO | UNI |  |  |
| `nombre` | varchar(50) | NO |  |  |  |

Restricciones CHECK:

- `ck_estados_codigo`: `(codigo in (_utf8mb4\\'BORRADOR\\',_utf8mb4\\'PENDIENTE\\',_utf8mb4\\'APROBADA\\',_utf8mb4\\'RECHAZADA\\',_utf8mb4\\'PUBLICADA\\'))`

### `actividades`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | bigint unsigned | NO | PRI | auto_increment |  |
| `autor_id` | bigint unsigned | NO | MUL |  | → `usuarios.id` |
| `nivel_id` | tinyint unsigned | NO | MUL |  | → `niveles_dificultad.id` |
| `categoria_id` | smallint unsigned | NO | MUL |  | → `categorias.id` |
| `estado_id` | tinyint unsigned | NO | MUL |  | → `estados_actividad.id` |
| `titulo` | varchar(150) | NO |  |  |  |
| `descripcion` | text | YES |  |  |  |
| `creado_en` | datetime(3) | NO |  | CURRENT_TIMESTAMP(3) DEFAULT_GENERATED |  |
| `actualizado_en` | datetime(3) | NO |  | CURRENT_TIMESTAMP(3) DEFAULT_GENERATED on update CURRENT_TIMESTAMP(3) |  |

Restricciones CHECK:

- `ck_actividades_titulo`: `(char_length(trim(titulo)) > 0)`

### `preguntas`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | bigint unsigned | NO | PRI | auto_increment |  |
| `actividad_id` | bigint unsigned | NO | MUL |  | → `actividades.id` |
| `orden` | smallint unsigned | NO |  |  |  |
| `enunciado` | text | NO |  |  |  |

### `opciones`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | bigint unsigned | NO | PRI | auto_increment |  |
| `pregunta_id` | bigint unsigned | NO | MUL |  | → `preguntas.id` |
| `orden` | tinyint unsigned | NO |  |  |  |
| `texto` | varchar(500) | NO |  |  |  |
| `es_correcta` | tinyint(1) | NO |  | 0 |  |

### `transiciones_actividad`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | bigint unsigned | NO | PRI | auto_increment |  |
| `actividad_id` | bigint unsigned | NO | MUL |  | → `actividades.id` |
| `estado_origen_id` | tinyint unsigned | YES | MUL |  | → `estados_actividad.id` |
| `estado_destino_id` | tinyint unsigned | NO | MUL |  | → `estados_actividad.id` |
| `usuario_id` | bigint unsigned | NO | MUL |  | → `usuarios.id` |
| `observaciones` | text | YES |  |  |  |
| `creado_en` | datetime(3) | NO |  | CURRENT_TIMESTAMP(3) DEFAULT_GENERATED |  |

### `actividad_grupo`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `actividad_id` | bigint unsigned | NO | PRI |  | → `actividades.id` |
| `grupo_id` | bigint unsigned | NO | PRI |  | → `grupos_clase.id` |
| `publicado_por` | bigint unsigned | NO | MUL |  | → `usuarios.id` |
| `publicado_en` | datetime(3) | NO |  | CURRENT_TIMESTAMP(3) DEFAULT_GENERATED |  |

## Interacción

### `intentos`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | bigint unsigned | NO | PRI | auto_increment |  |
| `usuario_id` | bigint unsigned | NO | MUL |  | → `usuarios.id` |
| `actividad_id` | bigint unsigned | NO | MUL |  | → `actividades.id` |
| `numero_intento` | smallint unsigned | NO |  |  |  |
| `estado` | enum('EN_CURSO','FINALIZADO','ABANDONADO') | NO |  | EN_CURSO |  |
| `iniciado_en` | datetime(3) | NO |  | CURRENT_TIMESTAMP(3) DEFAULT_GENERATED |  |
| `finalizado_en` | datetime(3) | YES |  |  |  |
| `duracion_seg` | int unsigned | YES |  |  |  |

Restricciones CHECK:

- `ck_intentos_cierre`: `(((estado = _utf8mb4\\'EN_CURSO\\') and (finalizado_en is null)) or ((estado in (_utf8mb4\\'FINALIZADO\\',_utf8mb4\\'ABANDONADO\\')) and (finalizado_en is not null) and (duracion_seg is not null)))`
- `ck_intentos_duracion`: `((duracion_seg is null) or (duracion_seg <= 86400))`
- `ck_intentos_numero`: `(numero_intento >= 1)`

### `respuestas`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | bigint unsigned | NO | PRI | auto_increment |  |
| `intento_id` | bigint unsigned | NO | MUL |  | → `intentos.id` |
| `pregunta_id` | bigint unsigned | NO | MUL |  | → `preguntas.id` |
| `opcion_id` | bigint unsigned | NO | MUL |  | → `opciones.id` |
| `tiempo_seg` | int unsigned | NO |  | 0 |  |
| `respondido_en` | datetime(3) | NO |  | CURRENT_TIMESTAMP(3) DEFAULT_GENERATED |  |

Restricciones CHECK:

- `ck_respuestas_tiempo`: `(tiempo_seg <= 86400)`

### `interacciones`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | bigint unsigned | NO | PRI | auto_increment |  |
| `intento_id` | bigint unsigned | NO | MUL |  | → `intentos.id` |
| `secuencia` | int unsigned | NO |  |  |  |
| `tipo` | enum('INICIO','VER_PREGUNTA','SELECCION','CAMBIO_OPCION','PAUSA','REANUDA','NAVEGACION','FIN','ABANDONO') | NO |  |  |  |
| `pregunta_id` | bigint unsigned | YES | MUL |  | → `preguntas.id` |
| `opcion_id` | bigint unsigned | YES | MUL |  | → `opciones.id` |
| `ocurrido_en` | datetime(3) | NO |  |  |  |
| `duracion_ms` | int unsigned | YES |  |  |  |

Restricciones CHECK:

- `ck_interacciones_opcion`: `((opcion_id is null) or (pregunta_id is not null))`

### `resultados`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | bigint unsigned | NO | PRI | auto_increment |  |
| `intento_id` | bigint unsigned | NO | UNI |  | → `intentos.id` |
| `correctas` | smallint unsigned | NO |  |  |  |
| `total_preguntas` | smallint unsigned | NO |  |  |  |
| `puntaje` | decimal(5,2) | NO |  |  |  |
| `calculado_en` | datetime(3) | NO |  | CURRENT_TIMESTAMP(3) DEFAULT_GENERATED |  |

Restricciones CHECK:

- `ck_resultados_correctas`: `(correctas <= total_preguntas)`
- `ck_resultados_puntaje`: `(puntaje between 0 and 100)`

## Análisis

### `perfiles_aprendizaje`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | bigint unsigned | NO | PRI | auto_increment |  |
| `usuario_id` | bigint unsigned | NO | MUL |  | → `usuarios.id` |
| `periodo_inicio` | date | NO |  |  |  |
| `periodo_fin` | date | NO |  |  |  |
| `actualizado_en` | datetime(3) | NO |  | CURRENT_TIMESTAMP(3) DEFAULT_GENERATED on update CURRENT_TIMESTAMP(3) |  |

Restricciones CHECK:

- `ck_perfiles_periodo`: `(periodo_fin >= periodo_inicio)`

### `indicadores`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | bigint unsigned | NO | PRI | auto_increment |  |
| `perfil_id` | bigint unsigned | NO | MUL |  | → `perfiles_aprendizaje.id` |
| `actividad_id` | bigint unsigned | YES | MUL |  | → `actividades.id` |
| `agrupamiento_id` | bigint unsigned | YES | MUL |  | → `agrupamientos.id` |
| `tipo` | enum('PUNTAJE','EFICIENCIA','MEJORA','PERSISTENCIA','CLUSTER','RIESGO') | NO |  |  |  |
| `valor` | decimal(9,4) | NO |  |  |  |
| `origen` | enum('NIVEL1','NIVEL2') | NO |  |  |  |
| `calculado_en` | datetime(3) | NO |  | CURRENT_TIMESTAMP(3) DEFAULT_GENERATED |  |

Restricciones CHECK:

- `ck_indicadores_cluster`: `((tipo <> _utf8mb4\\'CLUSTER\\') or (agrupamiento_id is not null))`
- `ck_indicadores_eficiencia`: `((tipo <> _utf8mb4\\'EFICIENCIA\\') or (valor between 0 and 5))`
- `ck_indicadores_mejora`: `((tipo <> _utf8mb4\\'MEJORA\\') or (valor between -(100) and 100))`
- `ck_indicadores_nivel1`: `((tipo not in (_utf8mb4\\'PUNTAJE\\',_utf8mb4\\'EFICIENCIA\\',_utf8mb4\\'MEJORA\\',_utf8mb4\\'PERSISTENCIA\\')) or ((origen = _utf8mb4\\'NIVEL1\\') and (actividad_id is not null) and (agrupamiento_id is null)))`
- `ck_indicadores_nivel2`: `((tipo not in (_utf8mb4\\'CLUSTER\\',_utf8mb4\\'RIESGO\\')) or (origen = _utf8mb4\\'NIVEL2\\'))`
- `ck_indicadores_persistencia`: `((tipo <> _utf8mb4\\'PERSISTENCIA\\') or (valor >= 1))`
- `ck_indicadores_puntaje`: `((tipo <> _utf8mb4\\'PUNTAJE\\') or (valor between 0 and 100))`
- `ck_indicadores_riesgo`: `((tipo <> _utf8mb4\\'RIESGO\\') or (valor between 0 and 1))`

### `reglas_analisis`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | smallint unsigned | NO | PRI | auto_increment |  |
| `codigo` | varchar(10) | NO | UNI |  |  |
| `nombre` | varchar(100) | NO |  |  |  |
| `descripcion` | varchar(500) | NO |  |  |  |
| `tipo` | enum('RIESGO','REFUERZO','AVANCE','RECONOCIMIENTO') | NO |  |  |  |
| `condicion` | json | NO |  |  |  |
| `sugerencia` | json | NO |  |  |  |
| `recomendacion_plantilla` | varchar(500) | NO |  |  |  |
| `prioridad` | tinyint unsigned | NO |  | 50 |  |
| `activa` | tinyint(1) | NO |  | 1 |  |
| `version` | smallint unsigned | NO |  | 1 |  |
| `actualizado_por` | bigint unsigned | YES | MUL |  | → `usuarios.id` |
| `actualizado_en` | datetime(3) | NO |  | CURRENT_TIMESTAMP(3) DEFAULT_GENERATED on update CURRENT_TIMESTAMP(3) |  |

Restricciones CHECK:

- `ck_reglas_condicion`: `json_valid(condicion)`
- `ck_reglas_sugerencia`: `json_valid(sugerencia)`
- `ck_reglas_version`: `(version >= 1)`

### `recomendaciones`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | bigint unsigned | NO | PRI | auto_increment |  |
| `perfil_id` | bigint unsigned | NO | MUL |  | → `perfiles_aprendizaje.id` |
| `actividad_sugerida_id` | bigint unsigned | YES | MUL |  | → `actividades.id` |
| `texto` | varchar(1000) | NO |  |  |  |
| `generado_en` | datetime(3) | NO |  | CURRENT_TIMESTAMP(3) DEFAULT_GENERATED |  |

### `recomendacion_regla`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `recomendacion_id` | bigint unsigned | NO | PRI |  | → `recomendaciones.id` |
| `regla_id` | smallint unsigned | NO | PRI |  | → `reglas_analisis.id` |
| `version_regla` | smallint unsigned | NO |  |  |  |
| `valores_entrada` | json | NO |  |  |  |

Restricciones CHECK:

- `ck_recomendacion_regla_valores`: `json_valid(valores_entrada)`

### `analisis_grupal`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | bigint unsigned | NO | PRI | auto_increment |  |
| `grupo_id` | bigint unsigned | NO | MUL |  | → `grupos_clase.id` |
| `actividad_id` | bigint unsigned | YES | MUL |  | → `actividades.id` |
| `periodo_inicio` | date | NO |  |  |  |
| `periodo_fin` | date | NO |  |  |  |
| `n_estudiantes` | int unsigned | NO |  |  |  |
| `promedio` | decimal(5,2) | YES |  |  |  |
| `mediana` | decimal(5,2) | YES |  |  |  |
| `minimo` | decimal(5,2) | YES |  |  |  |
| `maximo` | decimal(5,2) | YES |  |  |  |
| `generado_en` | datetime(3) | NO |  | CURRENT_TIMESTAMP(3) DEFAULT_GENERATED |  |

Restricciones CHECK:

- `ck_analisis_grupal_periodo`: `(periodo_fin >= periodo_inicio)`
- `ck_analisis_grupal_rangos`: `(((promedio is null) or (promedio between 0 and 100)) and ((mediana is null) or (mediana between 0 and 100)) and ((minimo is null) or (minimo between 0 and 100)) and ((maximo is null) or (maximo between 0 and 100)))`

### `agrupamientos`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | bigint unsigned | NO | PRI | auto_increment |  |
| `grupo_id` | bigint unsigned | NO | MUL |  | → `grupos_clase.id` |
| `periodo_inicio` | date | NO |  |  |  |
| `periodo_fin` | date | NO |  |  |  |
| `k` | tinyint unsigned | NO |  |  |  |
| `silueta` | decimal(5,4) | NO |  |  |  |
| `n_muestras` | int unsigned | NO |  |  |  |
| `modelo_version` | varchar(40) | NO |  |  |  |
| `generado_en` | datetime(3) | NO |  | CURRENT_TIMESTAMP(3) DEFAULT_GENERATED |  |

Restricciones CHECK:

- `ck_agrupamientos_k`: `(k between 2 and 10)`
- `ck_agrupamientos_periodo`: `(periodo_fin >= periodo_inicio)`
- `ck_agrupamientos_silueta`: `(silueta between -(1) and 1)`

## Control

### `auditoria`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | bigint unsigned | NO | PRI | auto_increment |  |
| `usuario_id` | bigint unsigned | YES | MUL |  | → `usuarios.id` |
| `accion` | varchar(80) | NO | MUL |  |  |
| `recurso` | varchar(60) | YES |  |  |  |
| `recurso_id` | varchar(40) | YES |  |  |  |
| `resultado` | enum('OK','DENEGADO','ERROR') | NO |  |  |  |
| `ip` | varchar(45) | YES |  |  |  |
| `detalle` | json | YES |  |  |  |
| `creado_en` | datetime(3) | NO | MUL | CURRENT_TIMESTAMP(3) DEFAULT_GENERATED |  |

Restricciones CHECK:

- `ck_auditoria_detalle`: `((detalle is null) or json_valid(detalle))`

### `conversaciones`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | bigint unsigned | NO | PRI | auto_increment |  |
| `docente_id` | bigint unsigned | NO | MUL |  | → `usuarios.id` |
| `pregunta` | varchar(1000) | NO |  |  |  |
| `tipo_consulta` | enum('ESTADO_GRUPO','DIFICULTAD','EXPLICAR_RECOMENDACION','NO_RECONOCIDA') | NO |  |  |  |
| `contexto_enviado` | json | YES |  |  |  |
| `respuesta` | text | YES |  |  |  |
| `estado` | enum('OK','NO_RECONOCIDA','LLM_NO_DISPONIBLE') | NO |  |  |  |
| `creado_en` | datetime(3) | NO |  | CURRENT_TIMESTAMP(3) DEFAULT_GENERATED |  |

Restricciones CHECK:

- `ck_conversaciones_contexto`: `((contexto_enviado is null) or json_valid(contexto_enviado))`

### `registro_respaldos`

| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |
| --- | --- | --- | --- | --- | --- |
| `id` | bigint unsigned | NO | PRI | auto_increment |  |
| `tipo` | enum('COMPLETO','INCREMENTAL','CONFIG') | NO |  |  |  |
| `destino` | enum('LOCAL','WINDOWS') | NO |  |  |  |
| `iniciado_en` | datetime(3) | NO | MUL |  |  |
| `finalizado_en` | datetime(3) | YES |  |  |  |
| `resultado` | enum('OK','FALLO') | NO |  |  |  |
| `archivo` | varchar(255) | NO |  |  |  |
| `sha256` | char(64) | YES |  |  |  |
| `tamano_bytes` | bigint unsigned | YES |  |  |  |
| `verificado` | tinyint(1) | NO |  | 0 |  |

Restricciones CHECK:

- `ck_registro_respaldos_sha`: `((sha256 is null) or regexp_like(sha256,_utf8mb4\\'^[0-9a-f]{64}$\\'))`
