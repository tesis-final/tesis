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
