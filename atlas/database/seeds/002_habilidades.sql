-- =============================================================================
-- ATLAS — seeds/002_habilidades.sql  (Hito 2)
-- Habilidades iniciales: los cuatro ejemplos que propone la devolución de
-- Programación (4.a). Son un catálogo editable: la coordinación agrega o
-- desactiva habilidades sin tocar el esquema.
-- =============================================================================

USE atlas_db;

INSERT IGNORE INTO habilidades (codigo, nombre, descripcion) VALUES
  ('LOGICA',            'Lógica',                 'Deducir conclusiones válidas a partir de premisas'),
  ('COMPRENSION',       'Comprensión lectora',    'Entender e interpretar un texto'),
  ('CALCULO',           'Cálculo',                'Operar con números y expresiones'),
  ('RAZONAMIENTO_ESP',  'Razonamiento espacial',  'Imaginar y manipular figuras y posiciones');
