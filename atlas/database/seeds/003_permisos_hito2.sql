-- =============================================================================
-- ATLAS — seeds/003_permisos_hito2.sql  (Hito 2)
-- Permiso nuevo de la migración 004 (acta D-6): el docente confirma o cambia la
-- actividad que el sistema sugiere a un estudiante. Va después de 001_catalogos
-- porque necesita los roles. Idempotente (INSERT IGNORE).
-- =============================================================================

USE atlas_db;

INSERT IGNORE INTO permisos (codigo, descripcion) VALUES
  ('recomendaciones.decidir', 'Confirmar o cambiar la actividad sugerida a un estudiante');

INSERT IGNORE INTO rol_permiso (rol_id, permiso_id)
SELECT r.id, p.id
  FROM roles r JOIN permisos p ON p.codigo = 'recomendaciones.decidir'
 WHERE r.codigo = 'DOCENTE';
