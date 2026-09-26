-- =============================================================================
-- ATLAS — 001_esquema.sql
-- Esquema de la base atlas_db (29 tablas).
-- Fuente: PDF §27.1, Tabla 19, Tabla 20; decisiones DEC-15, DEC-16
-- (docs/fase-02-arquitectura/03-modelo-datos.md).
-- Motor InnoDB, utf8mb4, fechas en UTC (DATETIME(3)).
-- =============================================================================

CREATE DATABASE IF NOT EXISTS atlas_db
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE atlas_db;

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- -----------------------------------------------------------------------------
-- IDENTIDAD
-- -----------------------------------------------------------------------------

CREATE TABLE instituciones (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre      VARCHAR(150)    NOT NULL,
  activa      BOOLEAN         NOT NULL DEFAULT TRUE,
  creado_en   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_instituciones_nombre (nombre)
) ENGINE=InnoDB;

CREATE TABLE roles (
  id      TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  codigo  VARCHAR(20)      NOT NULL,
  nombre  VARCHAR(50)      NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_roles_codigo (codigo),
  CONSTRAINT ck_roles_codigo CHECK (codigo IN ('ADMIN', 'DOCENTE', 'ESTUDIANTE'))
) ENGINE=InnoDB;

CREATE TABLE permisos (
  id           SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  codigo       VARCHAR(60)       NOT NULL,
  descripcion  VARCHAR(200)      NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_permisos_codigo (codigo)
) ENGINE=InnoDB;

-- activo permite revocar sin DELETE (atlas_app no tiene DELETE, Tabla 21).
CREATE TABLE rol_permiso (
  rol_id      TINYINT UNSIGNED  NOT NULL,
  permiso_id  SMALLINT UNSIGNED NOT NULL,
  activo      BOOLEAN           NOT NULL DEFAULT TRUE,
  PRIMARY KEY (rol_id, permiso_id),
  KEY ix_rol_permiso_permiso (permiso_id),
  CONSTRAINT fk_rol_permiso_rol     FOREIGN KEY (rol_id)     REFERENCES roles (id),
  CONSTRAINT fk_rol_permiso_permiso FOREIGN KEY (permiso_id) REFERENCES permisos (id)
) ENGINE=InnoDB;

-- Campos mínimos (RNF-14, DEC-00a): sin cédula ni datos no necesarios.
CREATE TABLE usuarios (
  id                BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  institucion_id    BIGINT UNSIGNED  NOT NULL,
  rol_id            TINYINT UNSIGNED NOT NULL,
  nombre            VARCHAR(80)      NOT NULL,
  apellido          VARCHAR(80)      NOT NULL,
  correo            VARCHAR(190)     NOT NULL,
  hash_contrasena   VARCHAR(255)     NOT NULL,
  activo            BOOLEAN          NOT NULL DEFAULT TRUE,
  intentos_fallidos TINYINT UNSIGNED NOT NULL DEFAULT 0,
  bloqueado_hasta   DATETIME(3)      NULL,
  creado_en         DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  actualizado_en    DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_usuarios_correo (correo),
  KEY ix_usuarios_institucion (institucion_id),
  KEY ix_usuarios_rol (rol_id),
  CONSTRAINT fk_usuarios_institucion FOREIGN KEY (institucion_id) REFERENCES instituciones (id),
  CONSTRAINT fk_usuarios_rol         FOREIGN KEY (rol_id)         REFERENCES roles (id),
  CONSTRAINT ck_usuarios_nombre  CHECK (CHAR_LENGTH(TRIM(nombre)) > 0),
  CONSTRAINT ck_usuarios_apellido CHECK (CHAR_LENGTH(TRIM(apellido)) > 0),
  CONSTRAINT ck_usuarios_correo  CHECK (correo LIKE '%_@_%')
) ENGINE=InnoDB;

CREATE TABLE grupos_clase (
  id              BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT,
  institucion_id  BIGINT UNSIGNED   NOT NULL,
  nombre          VARCHAR(60)       NOT NULL,
  anio_lectivo    SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_grupos (institucion_id, nombre, anio_lectivo),
  CONSTRAINT fk_grupos_institucion FOREIGN KEY (institucion_id) REFERENCES instituciones (id),
  CONSTRAINT ck_grupos_anio CHECK (anio_lectivo BETWEEN 2000 AND 2100)
) ENGINE=InnoDB;

-- Pertenencia de docentes y estudiantes a grupos (RF-04, RF-11).
CREATE TABLE usuario_grupo (
  usuario_id  BIGINT UNSIGNED NOT NULL,
  grupo_id    BIGINT UNSIGNED NOT NULL,
  activo      BOOLEAN         NOT NULL DEFAULT TRUE,
  PRIMARY KEY (usuario_id, grupo_id),
  KEY ix_usuario_grupo_grupo (grupo_id),
  CONSTRAINT fk_usuario_grupo_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id),
  CONSTRAINT fk_usuario_grupo_grupo   FOREIGN KEY (grupo_id)   REFERENCES grupos_clase (id)
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- CONTENIDO
-- -----------------------------------------------------------------------------

CREATE TABLE niveles_dificultad (
  id      TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  codigo  VARCHAR(20)      NOT NULL,
  nombre  VARCHAR(50)      NOT NULL,
  orden   TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_niveles_codigo (codigo),
  UNIQUE KEY uq_niveles_orden (orden)
) ENGINE=InnoDB;

CREATE TABLE categorias (
  id      SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  codigo  VARCHAR(40)       NOT NULL,
  nombre  VARCHAR(80)       NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_categorias_codigo (codigo)
) ENGINE=InnoDB;

CREATE TABLE estados_actividad (
  id      TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
  codigo  VARCHAR(20)      NOT NULL,
  nombre  VARCHAR(50)      NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_estados_codigo (codigo),
  CONSTRAINT ck_estados_codigo CHECK (codigo IN ('BORRADOR', 'PENDIENTE', 'APROBADA', 'RECHAZADA', 'PUBLICADA'))
) ENGINE=InnoDB;

CREATE TABLE actividades (
  id              BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT,
  autor_id        BIGINT UNSIGNED   NOT NULL,
  nivel_id        TINYINT UNSIGNED  NOT NULL,
  categoria_id    SMALLINT UNSIGNED NOT NULL,
  estado_id       TINYINT UNSIGNED  NOT NULL,
  titulo          VARCHAR(150)      NOT NULL,
  descripcion     TEXT              NULL,
  creado_en       DATETIME(3)       NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  actualizado_en  DATETIME(3)       NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_actividades_autor (autor_id),
  KEY ix_actividades_nivel (nivel_id),
  KEY ix_actividades_categoria (categoria_id),
  KEY ix_actividades_estado (estado_id),
  CONSTRAINT fk_actividades_autor     FOREIGN KEY (autor_id)     REFERENCES usuarios (id),
  CONSTRAINT fk_actividades_nivel     FOREIGN KEY (nivel_id)     REFERENCES niveles_dificultad (id),
  CONSTRAINT fk_actividades_categoria FOREIGN KEY (categoria_id) REFERENCES categorias (id),
  CONSTRAINT fk_actividades_estado    FOREIGN KEY (estado_id)    REFERENCES estados_actividad (id),
  CONSTRAINT ck_actividades_titulo CHECK (CHAR_LENGTH(TRIM(titulo)) > 0)
) ENGINE=InnoDB;

CREATE TABLE preguntas (
  id            BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT,
  actividad_id  BIGINT UNSIGNED   NOT NULL,
  orden         SMALLINT UNSIGNED NOT NULL,
  enunciado     TEXT              NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_preguntas_orden (actividad_id, orden),
  UNIQUE KEY uq_preguntas_id_actividad (id, actividad_id),
  CONSTRAINT fk_preguntas_actividad FOREIGN KEY (actividad_id) REFERENCES actividades (id)
) ENGINE=InnoDB;

CREATE TABLE opciones (
  id           BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  pregunta_id  BIGINT UNSIGNED  NOT NULL,
  orden        TINYINT UNSIGNED NOT NULL,
  texto        VARCHAR(500)     NOT NULL,
  es_correcta  BOOLEAN          NOT NULL DEFAULT FALSE,
  PRIMARY KEY (id),
  UNIQUE KEY uq_opciones_orden (pregunta_id, orden),
  -- Clave candidata para que respuestas/interacciones garanticen que la opción
  -- pertenece a la pregunta respondida (FK compuesta).
  UNIQUE KEY uq_opciones_id_pregunta (id, pregunta_id),
  CONSTRAINT fk_opciones_pregunta FOREIGN KEY (pregunta_id) REFERENCES preguntas (id)
) ENGINE=InnoDB;

-- Historial del ciclo de aprobación con autor (RF-17, DEC-15).
CREATE TABLE transiciones_actividad (
  id                 BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  actividad_id       BIGINT UNSIGNED  NOT NULL,
  estado_origen_id   TINYINT UNSIGNED NULL,
  estado_destino_id  TINYINT UNSIGNED NOT NULL,
  usuario_id         BIGINT UNSIGNED  NOT NULL,
  observaciones      TEXT             NULL,
  creado_en          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_transiciones_actividad (actividad_id, creado_en),
  CONSTRAINT fk_transiciones_actividad FOREIGN KEY (actividad_id)      REFERENCES actividades (id),
  CONSTRAINT fk_transiciones_origen    FOREIGN KEY (estado_origen_id)  REFERENCES estados_actividad (id),
  CONSTRAINT fk_transiciones_destino   FOREIGN KEY (estado_destino_id) REFERENCES estados_actividad (id),
  CONSTRAINT fk_transiciones_usuario   FOREIGN KEY (usuario_id)        REFERENCES usuarios (id)
) ENGINE=InnoDB;

-- Publicación de una actividad en grupos (RF-04, DEC-12, DEC-15).
CREATE TABLE actividad_grupo (
  actividad_id   BIGINT UNSIGNED NOT NULL,
  grupo_id       BIGINT UNSIGNED NOT NULL,
  publicado_por  BIGINT UNSIGNED NOT NULL,
  publicado_en   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (actividad_id, grupo_id),
  KEY ix_actividad_grupo_grupo (grupo_id),
  CONSTRAINT fk_actividad_grupo_actividad FOREIGN KEY (actividad_id)  REFERENCES actividades (id),
  CONSTRAINT fk_actividad_grupo_grupo     FOREIGN KEY (grupo_id)      REFERENCES grupos_clase (id),
  CONSTRAINT fk_actividad_grupo_usuario   FOREIGN KEY (publicado_por) REFERENCES usuarios (id)
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- INTERACCIÓN
-- -----------------------------------------------------------------------------

CREATE TABLE intentos (
  id              BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT,
  usuario_id      BIGINT UNSIGNED   NOT NULL,
  actividad_id    BIGINT UNSIGNED   NOT NULL,
  numero_intento  SMALLINT UNSIGNED NOT NULL,
  estado          ENUM('EN_CURSO', 'FINALIZADO', 'ABANDONADO') NOT NULL DEFAULT 'EN_CURSO',
  iniciado_en     DATETIME(3)       NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  finalizado_en   DATETIME(3)       NULL,
  duracion_seg    INT UNSIGNED      NULL,
  PRIMARY KEY (id),
  -- Índice compuesto exigido por la Tabla 20.
  KEY ix_intentos_usuario_actividad (usuario_id, actividad_id),
  KEY ix_intentos_actividad (actividad_id),
  UNIQUE KEY uq_intentos_numero (usuario_id, actividad_id, numero_intento),
  CONSTRAINT fk_intentos_usuario   FOREIGN KEY (usuario_id)   REFERENCES usuarios (id),
  CONSTRAINT fk_intentos_actividad FOREIGN KEY (actividad_id) REFERENCES actividades (id),
  CONSTRAINT ck_intentos_numero CHECK (numero_intento >= 1),
  CONSTRAINT ck_intentos_duracion CHECK (duracion_seg IS NULL OR duracion_seg <= 86400),
  CONSTRAINT ck_intentos_cierre CHECK (
    (estado = 'EN_CURSO' AND finalizado_en IS NULL)
    OR (estado IN ('FINALIZADO', 'ABANDONADO') AND finalizado_en IS NOT NULL AND duracion_seg IS NOT NULL)
  )
) ENGINE=InnoDB;

-- Si una respuesta es correcta se deriva de opciones.es_correcta (3FN).
CREATE TABLE respuestas (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  intento_id     BIGINT UNSIGNED NOT NULL,
  pregunta_id    BIGINT UNSIGNED NOT NULL,
  opcion_id      BIGINT UNSIGNED NOT NULL,
  tiempo_seg     INT UNSIGNED    NOT NULL DEFAULT 0,
  respondido_en  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_respuestas_intento_pregunta (intento_id, pregunta_id),
  KEY ix_respuestas_pregunta (pregunta_id),
  KEY ix_respuestas_opcion (opcion_id, pregunta_id),
  CONSTRAINT fk_respuestas_intento  FOREIGN KEY (intento_id)             REFERENCES intentos (id),
  CONSTRAINT fk_respuestas_pregunta FOREIGN KEY (pregunta_id)            REFERENCES preguntas (id),
  CONSTRAINT fk_respuestas_opcion   FOREIGN KEY (opcion_id, pregunta_id) REFERENCES opciones (id, pregunta_id),
  CONSTRAINT ck_respuestas_tiempo CHECK (tiempo_seg <= 86400)
) ENGINE=InnoDB;

-- Eventos del proceso de resolución (RF-06, H14).
CREATE TABLE interacciones (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  intento_id   BIGINT UNSIGNED NOT NULL,
  secuencia    INT UNSIGNED    NOT NULL,
  tipo         ENUM('INICIO', 'VER_PREGUNTA', 'SELECCION', 'CAMBIO_OPCION', 'PAUSA',
                    'REANUDA', 'NAVEGACION', 'FIN', 'ABANDONO') NOT NULL,
  pregunta_id  BIGINT UNSIGNED NULL,
  opcion_id    BIGINT UNSIGNED NULL,
  ocurrido_en  DATETIME(3)     NOT NULL,
  duracion_ms  INT UNSIGNED    NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_interacciones_secuencia (intento_id, secuencia),
  KEY ix_interacciones_pregunta (pregunta_id),
  KEY ix_interacciones_opcion (opcion_id, pregunta_id),
  CONSTRAINT fk_interacciones_intento  FOREIGN KEY (intento_id)             REFERENCES intentos (id),
  CONSTRAINT fk_interacciones_pregunta FOREIGN KEY (pregunta_id)            REFERENCES preguntas (id),
  CONSTRAINT fk_interacciones_opcion   FOREIGN KEY (opcion_id, pregunta_id) REFERENCES opciones (id, pregunta_id),
  CONSTRAINT ck_interacciones_opcion CHECK (opcion_id IS NULL OR pregunta_id IS NOT NULL)
) ENGINE=InnoDB;

-- Única desnormalización del modelo (§27.3): puntaje guardado, mantenido por trigger.
CREATE TABLE resultados (
  id               BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT,
  intento_id       BIGINT UNSIGNED   NOT NULL,
  correctas        SMALLINT UNSIGNED NOT NULL,
  total_preguntas  SMALLINT UNSIGNED NOT NULL,
  puntaje          DECIMAL(5,2)      NOT NULL,
  calculado_en     DATETIME(3)       NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_resultados_intento (intento_id),
  CONSTRAINT fk_resultados_intento FOREIGN KEY (intento_id) REFERENCES intentos (id),
  CONSTRAINT ck_resultados_puntaje   CHECK (puntaje BETWEEN 0 AND 100),
  CONSTRAINT ck_resultados_correctas CHECK (correctas <= total_preguntas)
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- ANÁLISIS
-- -----------------------------------------------------------------------------

CREATE TABLE perfiles_aprendizaje (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  usuario_id      BIGINT UNSIGNED NOT NULL,
  periodo_inicio  DATE            NOT NULL,
  periodo_fin     DATE            NOT NULL,
  actualizado_en  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_perfiles_usuario_periodo (usuario_id, periodo_inicio),
  CONSTRAINT fk_perfiles_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id),
  CONSTRAINT ck_perfiles_periodo CHECK (periodo_fin >= periodo_inicio)
) ENGINE=InnoDB;

CREATE TABLE agrupamientos (
  id              BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  grupo_id        BIGINT UNSIGNED  NOT NULL,
  periodo_inicio  DATE             NOT NULL,
  periodo_fin     DATE             NOT NULL,
  k               TINYINT UNSIGNED NOT NULL,
  silueta         DECIMAL(5,4)     NOT NULL,
  n_muestras      INT UNSIGNED     NOT NULL,
  modelo_version  VARCHAR(40)      NOT NULL,
  generado_en     DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_agrupamientos_grupo (grupo_id, periodo_inicio),
  CONSTRAINT fk_agrupamientos_grupo FOREIGN KEY (grupo_id) REFERENCES grupos_clase (id),
  CONSTRAINT ck_agrupamientos_k       CHECK (k BETWEEN 2 AND 10),
  CONSTRAINT ck_agrupamientos_silueta CHECK (silueta BETWEEN -1 AND 1),
  CONSTRAINT ck_agrupamientos_periodo CHECK (periodo_fin >= periodo_inicio)
) ENGINE=InnoDB;

-- Valores calculados por el Nivel 1 (PHP) y el Nivel 2 (Python).
CREATE TABLE indicadores (
  id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  perfil_id        BIGINT UNSIGNED NOT NULL,
  actividad_id     BIGINT UNSIGNED NULL,
  agrupamiento_id  BIGINT UNSIGNED NULL,
  tipo             ENUM('PUNTAJE', 'EFICIENCIA', 'MEJORA', 'PERSISTENCIA', 'CLUSTER', 'RIESGO') NOT NULL,
  valor            DECIMAL(9,4)    NOT NULL,
  origen           ENUM('NIVEL1', 'NIVEL2') NOT NULL,
  calculado_en     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_indicadores_perfil_tipo (perfil_id, tipo),
  KEY ix_indicadores_actividad (actividad_id),
  KEY ix_indicadores_agrupamiento (agrupamiento_id),
  CONSTRAINT fk_indicadores_perfil       FOREIGN KEY (perfil_id)       REFERENCES perfiles_aprendizaje (id),
  CONSTRAINT fk_indicadores_actividad    FOREIGN KEY (actividad_id)    REFERENCES actividades (id),
  CONSTRAINT fk_indicadores_agrupamiento FOREIGN KEY (agrupamiento_id) REFERENCES agrupamientos (id),
  -- Coherencia entre tipo, origen y referencias.
  CONSTRAINT ck_indicadores_nivel1 CHECK (
    tipo NOT IN ('PUNTAJE', 'EFICIENCIA', 'MEJORA', 'PERSISTENCIA')
    OR (origen = 'NIVEL1' AND actividad_id IS NOT NULL AND agrupamiento_id IS NULL)
  ),
  CONSTRAINT ck_indicadores_nivel2 CHECK (
    tipo NOT IN ('CLUSTER', 'RIESGO') OR origen = 'NIVEL2'
  ),
  CONSTRAINT ck_indicadores_cluster CHECK (tipo <> 'CLUSTER' OR agrupamiento_id IS NOT NULL),
  CONSTRAINT ck_indicadores_puntaje CHECK (tipo <> 'PUNTAJE' OR valor BETWEEN 0 AND 100),
  CONSTRAINT ck_indicadores_eficiencia CHECK (tipo <> 'EFICIENCIA' OR valor BETWEEN 0 AND 5),
  CONSTRAINT ck_indicadores_mejora CHECK (tipo <> 'MEJORA' OR valor BETWEEN -100 AND 100),
  CONSTRAINT ck_indicadores_persistencia CHECK (tipo <> 'PERSISTENCIA' OR valor >= 1),
  CONSTRAINT ck_indicadores_riesgo CHECK (tipo <> 'RIESGO' OR valor BETWEEN 0 AND 1)
) ENGINE=InnoDB;

-- Reglas editables por el administrador (§27.3, DEC-23).
CREATE TABLE reglas_analisis (
  id                      SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  codigo                  VARCHAR(10)       NOT NULL,
  nombre                  VARCHAR(100)      NOT NULL,
  descripcion             VARCHAR(500)      NOT NULL,
  tipo                    ENUM('RIESGO', 'REFUERZO', 'AVANCE', 'RECONOCIMIENTO') NOT NULL,
  condicion               JSON              NOT NULL,
  sugerencia              JSON              NOT NULL,
  recomendacion_plantilla VARCHAR(500)      NOT NULL,
  prioridad               TINYINT UNSIGNED  NOT NULL DEFAULT 50,
  activa                  BOOLEAN           NOT NULL DEFAULT TRUE,
  version                 SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  actualizado_por         BIGINT UNSIGNED   NULL,
  actualizado_en          DATETIME(3)       NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_reglas_codigo (codigo),
  CONSTRAINT fk_reglas_usuario FOREIGN KEY (actualizado_por) REFERENCES usuarios (id),
  CONSTRAINT ck_reglas_condicion  CHECK (JSON_VALID(condicion)),
  CONSTRAINT ck_reglas_sugerencia CHECK (JSON_VALID(sugerencia)),
  CONSTRAINT ck_reglas_version    CHECK (version >= 1)
) ENGINE=InnoDB;

CREATE TABLE recomendaciones (
  id                     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  perfil_id              BIGINT UNSIGNED NOT NULL,
  actividad_sugerida_id  BIGINT UNSIGNED NULL,
  texto                  VARCHAR(1000)   NOT NULL,
  generado_en            DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_recomendaciones_perfil (perfil_id, generado_en),
  KEY ix_recomendaciones_actividad (actividad_sugerida_id),
  CONSTRAINT fk_recomendaciones_perfil    FOREIGN KEY (perfil_id)             REFERENCES perfiles_aprendizaje (id),
  CONSTRAINT fk_recomendaciones_actividad FOREIGN KEY (actividad_sugerida_id) REFERENCES actividades (id)
) ENGINE=InnoDB;

-- Trazabilidad "qué regla, qué versión y con qué datos" (H20, ANA-07, DEC-15).
CREATE TABLE recomendacion_regla (
  recomendacion_id  BIGINT UNSIGNED   NOT NULL,
  regla_id          SMALLINT UNSIGNED NOT NULL,
  version_regla     SMALLINT UNSIGNED NOT NULL,
  valores_entrada   JSON              NOT NULL,
  PRIMARY KEY (recomendacion_id, regla_id),
  KEY ix_recomendacion_regla_regla (regla_id),
  CONSTRAINT fk_recomendacion_regla_recomendacion FOREIGN KEY (recomendacion_id) REFERENCES recomendaciones (id),
  CONSTRAINT fk_recomendacion_regla_regla         FOREIGN KEY (regla_id)         REFERENCES reglas_analisis (id),
  CONSTRAINT ck_recomendacion_regla_valores CHECK (JSON_VALID(valores_entrada))
) ENGINE=InnoDB;

CREATE TABLE analisis_grupal (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  grupo_id        BIGINT UNSIGNED NOT NULL,
  actividad_id    BIGINT UNSIGNED NULL,
  periodo_inicio  DATE            NOT NULL,
  periodo_fin     DATE            NOT NULL,
  n_estudiantes   INT UNSIGNED    NOT NULL,
  promedio        DECIMAL(5,2)    NULL,
  mediana         DECIMAL(5,2)    NULL,
  minimo          DECIMAL(5,2)    NULL,
  maximo          DECIMAL(5,2)    NULL,
  generado_en     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_analisis_grupal_grupo (grupo_id, periodo_inicio),
  KEY ix_analisis_grupal_actividad (actividad_id),
  CONSTRAINT fk_analisis_grupal_grupo     FOREIGN KEY (grupo_id)     REFERENCES grupos_clase (id),
  CONSTRAINT fk_analisis_grupal_actividad FOREIGN KEY (actividad_id) REFERENCES actividades (id),
  CONSTRAINT ck_analisis_grupal_rangos CHECK (
    (promedio IS NULL OR promedio BETWEEN 0 AND 100) AND
    (mediana  IS NULL OR mediana  BETWEEN 0 AND 100) AND
    (minimo   IS NULL OR minimo   BETWEEN 0 AND 100) AND
    (maximo   IS NULL OR maximo   BETWEEN 0 AND 100)
  ),
  CONSTRAINT ck_analisis_grupal_periodo CHECK (periodo_fin >= periodo_inicio)
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- CONTROL
-- -----------------------------------------------------------------------------

-- Solo INSERT para la aplicación; inmutable por trigger (RF-15, H23).
CREATE TABLE auditoria (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  usuario_id  BIGINT UNSIGNED NULL,
  accion      VARCHAR(80)     NOT NULL,
  recurso     VARCHAR(60)     NULL,
  recurso_id  VARCHAR(40)     NULL,
  resultado   ENUM('OK', 'DENEGADO', 'ERROR') NOT NULL,
  ip          VARCHAR(45)     NULL,
  detalle     JSON            NULL,
  creado_en   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_auditoria_creado (creado_en),
  KEY ix_auditoria_usuario (usuario_id, creado_en),
  KEY ix_auditoria_accion (accion, creado_en),
  CONSTRAINT fk_auditoria_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id),
  CONSTRAINT ck_auditoria_detalle CHECK (detalle IS NULL OR JSON_VALID(detalle))
) ENGINE=InnoDB;

-- Historial del asistente; contexto_enviado es la evidencia de H28.
CREATE TABLE conversaciones (
  id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  docente_id        BIGINT UNSIGNED NOT NULL,
  pregunta          VARCHAR(1000)   NOT NULL,
  tipo_consulta     ENUM('ESTADO_GRUPO', 'DIFICULTAD', 'EXPLICAR_RECOMENDACION', 'NO_RECONOCIDA') NOT NULL,
  contexto_enviado  JSON            NULL,
  respuesta         TEXT            NULL,
  estado            ENUM('OK', 'NO_RECONOCIDA', 'LLM_NO_DISPONIBLE') NOT NULL,
  creado_en         DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_conversaciones_docente (docente_id, creado_en),
  CONSTRAINT fk_conversaciones_docente FOREIGN KEY (docente_id) REFERENCES usuarios (id),
  CONSTRAINT ck_conversaciones_contexto CHECK (contexto_enviado IS NULL OR JSON_VALID(contexto_enviado))
) ENGINE=InnoDB;

CREATE TABLE registro_respaldos (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  tipo           ENUM('COMPLETO', 'INCREMENTAL', 'CONFIG') NOT NULL,
  destino        ENUM('LOCAL', 'WINDOWS') NOT NULL,
  iniciado_en    DATETIME(3)     NOT NULL,
  finalizado_en  DATETIME(3)     NULL,
  resultado      ENUM('OK', 'FALLO') NOT NULL,
  archivo        VARCHAR(255)    NOT NULL,
  sha256         CHAR(64)        NULL,
  tamano_bytes   BIGINT UNSIGNED NULL,
  verificado     BOOLEAN         NOT NULL DEFAULT FALSE,
  PRIMARY KEY (id),
  KEY ix_registro_respaldos_inicio (iniciado_en),
  CONSTRAINT ck_registro_respaldos_sha CHECK (sha256 IS NULL OR sha256 REGEXP '^[0-9a-f]{64}$')
) ENGINE=InnoDB;
