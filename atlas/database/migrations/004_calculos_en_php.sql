-- =============================================================================
-- ATLAS — migrations/004_calculos_en_php.sql  (Hito 2)
--
-- Acta D-4 (devolución de Programación, 4.e): los indicadores y los cálculos se
-- hacen en PHP; MySQL solo guarda y protege la integridad de los datos.
--
--   - trg_intentos_finalizar  → el puntaje lo calcula IntentoService::finalizar
--                               (Indicadores::puntaje) y lo guarda en `resultados`.
--   - sp_analisis_grupal      → los agregados los calcula ResumenGrupal y
--                               PanelDocenteService los guarda en `analisis_grupal`.
--
--   - trg_reglas_version      → la versión de la regla la sube AdminController.
--   - trg_reglas_auditoria, trg_usuarios_auditoria_ins/upd,
--     trg_rol_permiso_auditoria_ins/upd
--                             → el middleware de Auditoría registra cada cambio
--                               con su detalle (antes/después); con los triggers
--                               quedaba registrado dos veces.
--
-- Se mantienen los triggers que solo protegen integridad (ciclo de estados,
-- intento cerrado inmutable, respuestas válidas, auditoría no modificable,
-- contenido editable solo en borrador). atlas_app pasa a poder agregar filas
-- en `resultados` y `analisis_grupal`, pero no modificarlas ni borrarlas
-- (02-usuarios.sh; en una base ya instalada, tools/actualizar_a_004.sh).
--
-- Incluye además D-2 (aprobación por defecto desactivada) y D-8 (tiempo activo).
-- Se aplica después de 001, 002 y 003. Es idempotente (IF EXISTS / chequeo previo).
-- =============================================================================

USE atlas_db;

DROP TRIGGER IF EXISTS trg_intentos_finalizar;
DROP PROCEDURE IF EXISTS sp_analisis_grupal;
DROP TRIGGER IF EXISTS trg_reglas_version;
DROP TRIGGER IF EXISTS trg_reglas_auditoria;
DROP TRIGGER IF EXISTS trg_usuarios_auditoria_ins;
DROP TRIGGER IF EXISTS trg_usuarios_auditoria_upd;
DROP TRIGGER IF EXISTS trg_rol_permiso_auditoria_ins;
DROP TRIGGER IF EXISTS trg_rol_permiso_auditoria_upd;

-- -----------------------------------------------------------------------------
-- Acta D-2 (devolución 4.c): la aprobación es configurable por institución y por
-- defecto NO se exige (el docente publica directo; la transición queda registrada
-- en transiciones_actividad y en la auditoría). Solo cambia el valor por defecto:
-- las instituciones ya cargadas conservan lo que tenían.
-- -----------------------------------------------------------------------------
ALTER TABLE instituciones ALTER COLUMN requiere_aprobacion SET DEFAULT FALSE;

-- -----------------------------------------------------------------------------
-- Acta D-8 (devolución 4.b): se muestra el tiempo activo (total menos pausas de
-- más de 60 s sin actividad) aparte del total. Lo calcula IntentoService al cerrar
-- el intento a partir de los eventos PAUSA/REANUDA (D-4) y la base lo guarda.
-- NULL en los intentos cerrados antes de esta migración (no se inventa el dato).
-- -----------------------------------------------------------------------------
SET @existe := (SELECT COUNT(*) FROM information_schema.columns
                 WHERE table_schema = 'atlas_db' AND table_name = 'intentos'
                   AND column_name = 'duracion_activa_seg');
SET @sql := IF(@existe = 0,
  'ALTER TABLE intentos
     ADD COLUMN duracion_activa_seg INT UNSIGNED NULL AFTER duracion_seg,
     ADD CONSTRAINT ck_intentos_duracion_activa
       CHECK (duracion_activa_seg IS NULL OR (duracion_seg IS NOT NULL AND duracion_activa_seg <= duracion_seg))',
  'DO 0');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;

-- La vista de reportes expone también el tiempo activo (mismas columnas + una).
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
       r.puntaje,
       i.duracion_activa_seg
  FROM intentos i
  JOIN usuarios u         ON u.id = i.usuario_id
  JOIN actividades a      ON a.id = i.actividad_id
  JOIN niveles_dificultad n ON n.id = a.nivel_id
  JOIN categorias c       ON c.id = a.categoria_id
  JOIN actividad_grupo ag ON ag.actividad_id = a.id
  JOIN usuario_grupo ug   ON ug.usuario_id = i.usuario_id AND ug.grupo_id = ag.grupo_id AND ug.activo
  LEFT JOIN resultados r  ON r.intento_id = i.id;
