-- =============================================================================
-- ATLAS — 002_logica.sql
-- Triggers, vistas y procedimiento almacenado (PDF Tabla 20; DEC-11, DEC-12).
-- La aplicación identifica al usuario de cada operación con la variable de
-- sesión @atlas_usuario_id, que usan los triggers de auditoría automática.
-- =============================================================================

USE atlas_db;

DELIMITER $$

-- -----------------------------------------------------------------------------
-- Resultado automático al finalizar un intento (§27.3; RF-07).
-- Los intentos abandonados no generan resultado (H15).
-- -----------------------------------------------------------------------------
CREATE TRIGGER trg_intentos_finalizar
AFTER UPDATE ON intentos
FOR EACH ROW
BEGIN
  DECLARE v_total   INT DEFAULT 0;
  DECLARE v_correct INT DEFAULT 0;

  IF NEW.estado = 'FINALIZADO' AND OLD.estado <> 'FINALIZADO' THEN
    SELECT COUNT(*) INTO v_total
      FROM preguntas
     WHERE actividad_id = NEW.actividad_id;

    SELECT COUNT(*) INTO v_correct
      FROM respuestas r
      JOIN opciones o ON o.id = r.opcion_id
     WHERE r.intento_id = NEW.id
       AND o.es_correcta = TRUE;

    INSERT INTO resultados (intento_id, correctas, total_preguntas, puntaje)
    VALUES (NEW.id, v_correct, v_total,
            IF(v_total = 0, 0, ROUND(v_correct * 100 / v_total, 2)));
  END IF;
END$$

-- Un intento cerrado no se reabre ni cambia de estado.
CREATE TRIGGER trg_intentos_inmutable_cerrado
BEFORE UPDATE ON intentos
FOR EACH ROW
BEGIN
  IF OLD.estado IN ('FINALIZADO', 'ABANDONADO') AND NEW.estado <> OLD.estado THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ATLAS: un intento cerrado no puede cambiar de estado';
  END IF;
END$$

-- La respuesta debe corresponder a una pregunta de la actividad del intento,
-- y el intento debe estar en curso.
CREATE TRIGGER trg_respuestas_validar
BEFORE INSERT ON respuestas
FOR EACH ROW
BEGIN
  DECLARE v_ok INT DEFAULT 0;

  SELECT COUNT(*) INTO v_ok
    FROM intentos i
    JOIN preguntas p ON p.actividad_id = i.actividad_id
   WHERE i.id = NEW.intento_id
     AND p.id = NEW.pregunta_id
     AND i.estado = 'EN_CURSO';

  IF v_ok = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ATLAS: respuesta fuera del intento en curso o de su actividad';
  END IF;
END$$

CREATE TRIGGER trg_respuestas_validar_upd
BEFORE UPDATE ON respuestas
FOR EACH ROW
BEGIN
  DECLARE v_ok INT DEFAULT 0;

  SELECT COUNT(*) INTO v_ok
    FROM intentos i
   WHERE i.id = NEW.intento_id
     AND i.estado = 'EN_CURSO';

  IF v_ok = 0 OR NEW.pregunta_id <> OLD.pregunta_id OR NEW.intento_id <> OLD.intento_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ATLAS: solo se modifica la respuesta de un intento en curso';
  END IF;
END$$

-- -----------------------------------------------------------------------------
-- Ciclo de aprobación (RF-17, H24, H25, DEC-12). Segunda barrera: la capa de
-- servicio valida lo mismo antes de escribir.
-- -----------------------------------------------------------------------------
CREATE TRIGGER trg_actividades_ciclo
BEFORE UPDATE ON actividades
FOR EACH ROW
BEGIN
  DECLARE v_origen  VARCHAR(20);
  DECLARE v_destino VARCHAR(20);
  DECLARE v_preg    INT DEFAULT 0;
  DECLARE v_malas   INT DEFAULT 0;

  IF NEW.estado_id <> OLD.estado_id THEN
    SELECT codigo INTO v_origen  FROM estados_actividad WHERE id = OLD.estado_id;
    SELECT codigo INTO v_destino FROM estados_actividad WHERE id = NEW.estado_id;

    IF NOT (
         (v_origen = 'BORRADOR'  AND v_destino = 'PENDIENTE')
      OR (v_origen = 'PENDIENTE' AND v_destino IN ('APROBADA', 'RECHAZADA'))
      OR (v_origen = 'RECHAZADA' AND v_destino = 'BORRADOR')
      OR (v_origen = 'APROBADA'  AND v_destino = 'PUBLICADA')
    ) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ATLAS: transición de estado no permitida';
    END IF;

    IF v_destino = 'PENDIENTE' THEN
      SELECT COUNT(*) INTO v_preg FROM preguntas WHERE actividad_id = NEW.id;

      -- Preguntas con menos de 2 opciones o sin exactamente una correcta.
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

-- -----------------------------------------------------------------------------
-- Auditoría inmutable (RF-15, H23): ni siquiera un usuario con privilegios
-- puede modificar o borrar registros sin quitar primero este trigger.
-- -----------------------------------------------------------------------------
CREATE TRIGGER trg_auditoria_sin_update
BEFORE UPDATE ON auditoria
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ATLAS: la auditoría no se puede modificar';
END$$

CREATE TRIGGER trg_auditoria_sin_delete
BEFORE DELETE ON auditoria
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ATLAS: la auditoría no se puede borrar';
END$$

-- -----------------------------------------------------------------------------
-- Auditoría automática de cambios administrativos (Tabla 20).
-- -----------------------------------------------------------------------------
CREATE TRIGGER trg_usuarios_auditoria_ins
AFTER INSERT ON usuarios
FOR EACH ROW
BEGIN
  INSERT INTO auditoria (usuario_id, accion, recurso, recurso_id, resultado, detalle)
  VALUES (@atlas_usuario_id, 'usuarios.crear', 'usuarios', NEW.id, 'OK',
          JSON_OBJECT('rol_id', NEW.rol_id, 'institucion_id', NEW.institucion_id, 'activo', NEW.activo));
END$$

CREATE TRIGGER trg_usuarios_auditoria_upd
AFTER UPDATE ON usuarios
FOR EACH ROW
BEGIN
  -- Los cambios de intentos_fallidos/bloqueado_hasta los audita el login.
  IF NOT (NEW.nombre <=> OLD.nombre AND NEW.apellido <=> OLD.apellido
          AND NEW.correo <=> OLD.correo AND NEW.rol_id <=> OLD.rol_id
          AND NEW.institucion_id <=> OLD.institucion_id AND NEW.activo <=> OLD.activo
          AND NEW.hash_contrasena <=> OLD.hash_contrasena) THEN
    INSERT INTO auditoria (usuario_id, accion, recurso, recurso_id, resultado, detalle)
    VALUES (@atlas_usuario_id, 'usuarios.modificar', 'usuarios', NEW.id, 'OK',
            JSON_OBJECT(
              'rol_id', JSON_ARRAY(OLD.rol_id, NEW.rol_id),
              'institucion_id', JSON_ARRAY(OLD.institucion_id, NEW.institucion_id),
              'activo', JSON_ARRAY(OLD.activo, NEW.activo),
              'correo_cambiado', NOT (NEW.correo <=> OLD.correo),
              'contrasena_cambiada', NOT (NEW.hash_contrasena <=> OLD.hash_contrasena)));
  END IF;
END$$

CREATE TRIGGER trg_rol_permiso_auditoria_ins
AFTER INSERT ON rol_permiso
FOR EACH ROW
BEGIN
  INSERT INTO auditoria (usuario_id, accion, recurso, recurso_id, resultado, detalle)
  VALUES (@atlas_usuario_id, 'permisos.asignar', 'rol_permiso',
          CONCAT(NEW.rol_id, ':', NEW.permiso_id), 'OK', JSON_OBJECT('activo', NEW.activo));
END$$

CREATE TRIGGER trg_rol_permiso_auditoria_upd
AFTER UPDATE ON rol_permiso
FOR EACH ROW
BEGIN
  IF NOT (NEW.activo <=> OLD.activo) THEN
    INSERT INTO auditoria (usuario_id, accion, recurso, recurso_id, resultado, detalle)
    VALUES (@atlas_usuario_id, 'permisos.modificar', 'rol_permiso',
            CONCAT(NEW.rol_id, ':', NEW.permiso_id), 'OK',
            JSON_OBJECT('activo', JSON_ARRAY(OLD.activo, NEW.activo)));
  END IF;
END$$

-- Toda edición de una regla incrementa su versión y queda auditada (§27.3).
CREATE TRIGGER trg_reglas_version
BEFORE UPDATE ON reglas_analisis
FOR EACH ROW
BEGIN
  IF NOT (NEW.condicion <=> OLD.condicion AND NEW.sugerencia <=> OLD.sugerencia
          AND NEW.activa <=> OLD.activa AND NEW.recomendacion_plantilla <=> OLD.recomendacion_plantilla) THEN
    SET NEW.version = OLD.version + 1;
  END IF;
END$$

CREATE TRIGGER trg_reglas_auditoria
AFTER UPDATE ON reglas_analisis
FOR EACH ROW
BEGIN
  IF NEW.version <> OLD.version THEN
    INSERT INTO auditoria (usuario_id, accion, recurso, recurso_id, resultado, detalle)
    VALUES (@atlas_usuario_id, 'reglas.modificar', 'reglas_analisis', NEW.codigo, 'OK',
            JSON_OBJECT('version', JSON_ARRAY(OLD.version, NEW.version),
                        'condicion_anterior', OLD.condicion, 'condicion_nueva', NEW.condicion,
                        'activa', JSON_ARRAY(OLD.activa, NEW.activa)));
  END IF;
END$$

-- -----------------------------------------------------------------------------
-- Análisis grupal (RF-18, DEC-11): agrega el último intento finalizado de cada
-- estudiante en cada actividad del período y lo guarda en analisis_grupal.
-- p_actividad NULL = todas las actividades del grupo.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE sp_analisis_grupal(
  IN p_grupo     BIGINT UNSIGNED,
  IN p_actividad BIGINT UNSIGNED,
  IN p_desde     DATE,
  IN p_hasta     DATE
)
SQL SECURITY DEFINER
BEGIN
  IF p_hasta < p_desde THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ATLAS: período inválido';
  END IF;

  INSERT INTO analisis_grupal
    (grupo_id, actividad_id, periodo_inicio, periodo_fin, n_estudiantes, promedio, mediana, minimo, maximo)
  WITH ultimos AS (
    SELECT i.usuario_id, i.actividad_id, r.puntaje,
           ROW_NUMBER() OVER (PARTITION BY i.usuario_id, i.actividad_id
                              ORDER BY i.finalizado_en DESC, i.id DESC) AS rn
      FROM intentos i
      JOIN resultados r    ON r.intento_id = i.id
      JOIN usuarios u      ON u.id = i.usuario_id
      JOIN roles ro        ON ro.id = u.rol_id AND ro.codigo = 'ESTUDIANTE'
      JOIN usuario_grupo ug ON ug.usuario_id = i.usuario_id AND ug.grupo_id = p_grupo AND ug.activo
      JOIN actividad_grupo ag ON ag.actividad_id = i.actividad_id AND ag.grupo_id = p_grupo
     WHERE i.estado = 'FINALIZADO'
       AND DATE(i.finalizado_en) BETWEEN p_desde AND p_hasta
       AND (p_actividad IS NULL OR i.actividad_id = p_actividad)
  ),
  base AS (
    SELECT puntaje,
           ROW_NUMBER() OVER (ORDER BY puntaje) AS pos,
           COUNT(*) OVER () AS n,
           usuario_id
      FROM ultimos
     WHERE rn = 1
  )
  SELECT p_grupo, p_actividad, p_desde, p_hasta,
         COUNT(DISTINCT usuario_id),
         ROUND(AVG(puntaje), 2),
         ROUND(AVG(CASE WHEN pos IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2)) THEN puntaje END), 2),
         MIN(puntaje),
         MAX(puntaje)
    FROM base;

  SELECT * FROM analisis_grupal WHERE id = LAST_INSERT_ID();
END$$

DELIMITER ;

-- -----------------------------------------------------------------------------
-- Vistas para el panel docente y reportes (Tabla 20; usadas por atlas_read).
-- Ninguna expone correo ni hash. El filtro "solo sus grupos" lo aplica la app.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE SQL SECURITY DEFINER VIEW v_resultados_detalle AS
SELECT i.id               AS intento_id,
       i.usuario_id       AS estudiante_id,
       u.nombre           AS estudiante_nombre,
       u.apellido         AS estudiante_apellido,
       ug.grupo_id,
       i.actividad_id,
       a.titulo           AS actividad_titulo,
       n.codigo           AS nivel,
       c.codigo           AS categoria,
       i.numero_intento,
       i.estado,
       i.iniciado_en,
       i.finalizado_en,
       i.duracion_seg,
       r.correctas,
       r.total_preguntas,
       r.puntaje
  FROM intentos i
  JOIN usuarios u         ON u.id = i.usuario_id
  JOIN actividades a      ON a.id = i.actividad_id
  JOIN niveles_dificultad n ON n.id = a.nivel_id
  JOIN categorias c       ON c.id = a.categoria_id
  JOIN actividad_grupo ag ON ag.actividad_id = a.id
  JOIN usuario_grupo ug   ON ug.usuario_id = i.usuario_id AND ug.grupo_id = ag.grupo_id AND ug.activo
  LEFT JOIN resultados r  ON r.intento_id = i.id;

CREATE OR REPLACE SQL SECURITY DEFINER VIEW v_evolucion_estudiante AS
SELECT estudiante_id, grupo_id, actividad_id, actividad_titulo, categoria, nivel,
       numero_intento, finalizado_en, puntaje
  FROM v_resultados_detalle
 WHERE estado = 'FINALIZADO';

CREATE OR REPLACE SQL SECURITY DEFINER VIEW v_distribucion_puntajes AS
SELECT grupo_id, actividad_id,
       CASE
         WHEN puntaje < 20 THEN '00-19'
         WHEN puntaje < 40 THEN '20-39'
         WHEN puntaje < 60 THEN '40-59'
         WHEN puntaje < 80 THEN '60-79'
         ELSE '80-100'
       END AS rango,
       COUNT(*) AS cantidad
  FROM (
    SELECT d.*, ROW_NUMBER() OVER (PARTITION BY d.estudiante_id, d.actividad_id, d.grupo_id
                                   ORDER BY d.finalizado_en DESC, d.intento_id DESC) AS rn
      FROM v_resultados_detalle d
     WHERE d.estado = 'FINALIZADO'
  ) x
 WHERE rn = 1
 GROUP BY grupo_id, actividad_id, rango;

CREATE OR REPLACE SQL SECURITY DEFINER VIEW v_preguntas_error AS
SELECT ug.grupo_id,
       p.actividad_id,
       p.id               AS pregunta_id,
       p.orden,
       p.enunciado,
       COUNT(*)           AS respuestas,
       SUM(o.es_correcta = FALSE) AS errores,
       ROUND(SUM(o.es_correcta = FALSE) / COUNT(*), 4) AS proporcion_error
  FROM respuestas res
  JOIN intentos i         ON i.id = res.intento_id AND i.estado = 'FINALIZADO'
  JOIN preguntas p        ON p.id = res.pregunta_id
  JOIN opciones o         ON o.id = res.opcion_id
  JOIN actividad_grupo ag ON ag.actividad_id = p.actividad_id
  JOIN usuario_grupo ug   ON ug.usuario_id = i.usuario_id AND ug.grupo_id = ag.grupo_id AND ug.activo
 GROUP BY ug.grupo_id, p.actividad_id, p.id, p.orden, p.enunciado;

CREATE OR REPLACE SQL SECURITY DEFINER VIEW v_recomendaciones_riesgo AS
SELECT pa.usuario_id  AS estudiante_id,
       pa.periodo_inicio,
       pa.periodo_fin,
       rec.id         AS recomendacion_id,
       rec.generado_en,
       ra.codigo      AS regla_codigo,
       ra.nombre      AS regla_nombre,
       rr.version_regla,
       rr.valores_entrada
  FROM recomendaciones rec
  JOIN perfiles_aprendizaje pa ON pa.id = rec.perfil_id
  JOIN recomendacion_regla rr  ON rr.recomendacion_id = rec.id
  JOIN reglas_analisis ra      ON ra.id = rr.regla_id AND ra.tipo = 'RIESGO';

-- -----------------------------------------------------------------------------
-- CT-13: atlas_app puede borrar preguntas/opciones solo mientras la actividad
-- está en BORRADOR (edición del contenido, RF-16). Fuera de ese estado el
-- contenido es inmutable.
-- -----------------------------------------------------------------------------
DELIMITER $$

CREATE TRIGGER trg_preguntas_borrar_solo_borrador
BEFORE DELETE ON preguntas
FOR EACH ROW
BEGIN
  IF (SELECT e.codigo FROM actividades a JOIN estados_actividad e ON e.id = a.estado_id
       WHERE a.id = OLD.actividad_id) <> 'BORRADOR' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ATLAS: solo se editan actividades en borrador';
  END IF;
END$$

CREATE TRIGGER trg_opciones_borrar_solo_borrador
BEFORE DELETE ON opciones
FOR EACH ROW
BEGIN
  IF (SELECT e.codigo FROM preguntas p JOIN actividades a ON a.id = p.actividad_id
        JOIN estados_actividad e ON e.id = a.estado_id
       WHERE p.id = OLD.pregunta_id) <> 'BORRADOR' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ATLAS: solo se editan actividades en borrador';
  END IF;
END$$

CREATE TRIGGER trg_preguntas_editar_solo_borrador
BEFORE UPDATE ON preguntas
FOR EACH ROW
BEGIN
  IF (SELECT e.codigo FROM actividades a JOIN estados_actividad e ON e.id = a.estado_id
       WHERE a.id = OLD.actividad_id) <> 'BORRADOR' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ATLAS: solo se editan actividades en borrador';
  END IF;
END$$

CREATE TRIGGER trg_opciones_editar_solo_borrador
BEFORE UPDATE ON opciones
FOR EACH ROW
BEGIN
  IF (SELECT e.codigo FROM preguntas p JOIN actividades a ON a.id = p.actividad_id
        JOIN estados_actividad e ON e.id = a.estado_id
       WHERE p.id = OLD.pregunta_id) <> 'BORRADOR' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ATLAS: solo se editan actividades en borrador';
  END IF;
END$$

DELIMITER ;
