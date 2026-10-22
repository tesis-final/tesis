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
-- Se aplica después de 001, 002 y 003. Es idempotente (IF EXISTS).
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
