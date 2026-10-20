-- =============================================================================
-- ATLAS — migrations/003_habilidades_aprobacion.sql  (Hito 2)
--
-- 1) Habilidades (devolución de Programación, 4.a): una tabla de habilidades y
--    la relación muchos a muchos pregunta ↔ habilidad, para poder calcular
--    indicadores por habilidad y no solo por actividad.
-- 2) Aprobación configurable por institución (devolución de Programación, 4.c):
--    si la institución no la exige, la actividad pasa de BORRADOR a PUBLICADA
--    directamente. El valor por defecto mantiene el comportamiento actual
--    (requiere aprobación), así nada de lo existente cambia sin decidirlo.
--
-- Se aplica después de 001 y 002. Es idempotente en lo posible (IF NOT EXISTS).
-- =============================================================================

USE atlas_db;

-- -----------------------------------------------------------------------------
-- 1. HABILIDADES
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS habilidades (
  id           SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  codigo       VARCHAR(40)       NOT NULL,
  nombre       VARCHAR(80)       NOT NULL,
  descripcion  VARCHAR(255)      NULL,
  activa       BOOLEAN           NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id),
  UNIQUE KEY uq_habilidades_codigo (codigo),
  UNIQUE KEY uq_habilidades_nombre (nombre),
  CONSTRAINT ck_habilidades_codigo CHECK (REGEXP_LIKE(codigo, '^[A-Z][A-Z0-9_]*$', 'c')),
  CONSTRAINT ck_habilidades_nombre CHECK (CHAR_LENGTH(TRIM(nombre)) > 0)
) ENGINE=InnoDB;

-- Una pregunta mide una o más habilidades; una habilidad la miden muchas preguntas.
-- PK compuesta = no se repite el par. El índice inverso sirve para "todas las
-- preguntas de una habilidad" (indicadores por habilidad).
CREATE TABLE IF NOT EXISTS pregunta_habilidad (
  pregunta_id   BIGINT UNSIGNED   NOT NULL,
  habilidad_id  SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (pregunta_id, habilidad_id),
  KEY ix_pregunta_habilidad_habilidad (habilidad_id, pregunta_id),
  -- Si se borra la pregunta (solo posible en BORRADOR), se borran sus vínculos.
  CONSTRAINT fk_pregunta_habilidad_pregunta  FOREIGN KEY (pregunta_id)  REFERENCES preguntas (id) ON DELETE CASCADE,
  -- Una habilidad en uso no se puede borrar (se desactiva con `activa`).
  CONSTRAINT fk_pregunta_habilidad_habilidad FOREIGN KEY (habilidad_id) REFERENCES habilidades (id)
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 2. APROBACIÓN CONFIGURABLE POR INSTITUCIÓN
-- -----------------------------------------------------------------------------
SET @existe := (SELECT COUNT(*) FROM information_schema.columns
                 WHERE table_schema = 'atlas_db' AND table_name = 'instituciones'
                   AND column_name = 'requiere_aprobacion');
SET @sql := IF(@existe = 0,
  'ALTER TABLE instituciones ADD COLUMN requiere_aprobacion BOOLEAN NOT NULL DEFAULT TRUE AFTER activa',
  'DO 0');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;

DELIMITER $$

-- Los vínculos pregunta-habilidad son contenido de la actividad: igual que
-- preguntas y opciones (CT-13), solo se cambian mientras está en BORRADOR.
DROP TRIGGER IF EXISTS trg_pregunta_habilidad_ins$$
CREATE TRIGGER trg_pregunta_habilidad_ins
BEFORE INSERT ON pregunta_habilidad
FOR EACH ROW
BEGIN
  IF (SELECT e.codigo FROM preguntas p JOIN actividades a ON a.id = p.actividad_id
        JOIN estados_actividad e ON e.id = a.estado_id
       WHERE p.id = NEW.pregunta_id) <> 'BORRADOR' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ATLAS: solo se editan actividades en borrador';
  END IF;
  IF (SELECT activa FROM habilidades WHERE id = NEW.habilidad_id) = FALSE THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ATLAS: la habilidad está desactivada';
  END IF;
END$$

-- El borrado en cascada desde preguntas no dispara este trigger (MySQL no
-- ejecuta triggers en acciones de claves foráneas): por eso controla solo el
-- borrado directo, que es el que hace la aplicación al editar.
DROP TRIGGER IF EXISTS trg_pregunta_habilidad_del$$
CREATE TRIGGER trg_pregunta_habilidad_del
BEFORE DELETE ON pregunta_habilidad
FOR EACH ROW
BEGIN
  IF (SELECT e.codigo FROM preguntas p JOIN actividades a ON a.id = p.actividad_id
        JOIN estados_actividad e ON e.id = a.estado_id
       WHERE p.id = OLD.pregunta_id) <> 'BORRADOR' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ATLAS: solo se editan actividades en borrador';
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_pregunta_habilidad_upd$$
CREATE TRIGGER trg_pregunta_habilidad_upd
BEFORE UPDATE ON pregunta_habilidad
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ATLAS: un vínculo pregunta-habilidad no se modifica; se borra y se crea';
END$$

-- Ciclo de aprobación (RF-17, DEC-12) + aprobación configurable (4.c).
-- Igual que en 002, más una transición: BORRADOR -> PUBLICADA cuando la
-- institución del autor no exige aprobación. Las validaciones de contenido
-- (preguntas y opciones) se aplican tanto al enviar como al publicar directo.
DROP TRIGGER IF EXISTS trg_actividades_ciclo$$
CREATE TRIGGER trg_actividades_ciclo
BEFORE UPDATE ON actividades
FOR EACH ROW
BEGIN
  DECLARE v_origen    VARCHAR(20);
  DECLARE v_destino   VARCHAR(20);
  DECLARE v_requiere  BOOLEAN DEFAULT TRUE;
  DECLARE v_preg      INT DEFAULT 0;
  DECLARE v_malas     INT DEFAULT 0;

  IF NEW.estado_id <> OLD.estado_id THEN
    SELECT codigo INTO v_origen  FROM estados_actividad WHERE id = OLD.estado_id;
    SELECT codigo INTO v_destino FROM estados_actividad WHERE id = NEW.estado_id;
    SELECT i.requiere_aprobacion INTO v_requiere
      FROM usuarios u JOIN instituciones i ON i.id = u.institucion_id
     WHERE u.id = NEW.autor_id;

    IF NOT (
         (v_origen = 'BORRADOR'  AND v_destino = 'PENDIENTE' AND v_requiere)
      OR (v_origen = 'BORRADOR'  AND v_destino = 'PUBLICADA' AND NOT v_requiere)
      OR (v_origen = 'PENDIENTE' AND v_destino IN ('APROBADA', 'RECHAZADA'))
      OR (v_origen = 'RECHAZADA' AND v_destino = 'BORRADOR')
      OR (v_origen = 'APROBADA'  AND v_destino = 'PUBLICADA')
    ) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ATLAS: transición de estado no permitida';
    END IF;

    IF (v_origen = 'BORRADOR' AND v_destino IN ('PENDIENTE', 'PUBLICADA')) THEN
      SELECT COUNT(*) INTO v_preg FROM preguntas WHERE actividad_id = NEW.id;

      SELECT COUNT(*) INTO v_malas
        FROM (
          SELECT p.id
            FROM preguntas p
            LEFT JOIN opciones o ON o.pregunta_id = p.id
           WHERE p.actividad_id = NEW.id
           GROUP BY p.id
          HAVING COUNT(o.id) < 2 OR COALESCE(SUM(o.es_correcta), 0) <> 1
        ) x;

      IF v_preg = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ATLAS: una actividad sin preguntas no puede enviarse a aprobación';
      END IF;
      IF v_malas > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ATLAS: cada pregunta necesita al menos 2 opciones y exactamente 1 correcta';
      END IF;
    END IF;
  END IF;
END$$

DELIMITER ;
