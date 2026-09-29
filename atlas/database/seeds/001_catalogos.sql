-- =============================================================================
-- ATLAS — seeds/001_catalogos.sql
-- Catálogos iniciales. No crea usuarios ni contraseñas: el primer
-- administrador se crea con `php bin/atlas usuario:crear-admin` leyendo
-- variables de entorno (nunca contraseñas en el código).
-- =============================================================================

USE atlas_db;

-- Roles (RF-03).
INSERT INTO roles (codigo, nombre) VALUES
  ('ADMIN', 'Administrador'),
  ('DOCENTE', 'Docente'),
  ('ESTUDIANTE', 'Estudiante');

-- Permisos (RF-03, RF-14; DEC-00b, DEC-00c).
INSERT INTO permisos (codigo, descripcion) VALUES
  ('usuarios.gestionar',     'Crear, modificar y desactivar usuarios'),
  ('instituciones.gestionar','Gestionar instituciones'),
  ('permisos.gestionar',     'Gestionar permisos de los roles'),
  ('grupos.gestionar',       'Gestionar grupos y sus miembros'),
  ('actividades.crear',      'Crear y editar actividades en borrador'),
  ('actividades.enviar',     'Enviar una actividad a aprobación'),
  ('actividades.aprobar',    'Aprobar o rechazar actividades'),
  ('actividades.publicar',   'Publicar una actividad aprobada en sus grupos'),
  ('actividades.resolver',   'Resolver actividades publicadas'),
  ('resultados.ver_propios', 'Ver los resultados propios'),
  ('panel.docente',          'Acceder al panel docente'),
  ('perfiles.ver',           'Ver perfiles de los estudiantes de sus grupos'),
  ('recomendaciones.ver',    'Ver recomendaciones y su fundamento'),
  ('reportes.ver',           'Consultar estadísticas y reportes'),
  ('reglas.gestionar',       'Ajustar las reglas del motor de análisis'),
  ('auditoria.ver',          'Consultar el registro de auditoría'),
  ('asistente.usar',         'Usar el asistente conversacional');

INSERT INTO rol_permiso (rol_id, permiso_id)
SELECT r.id, p.id
  FROM roles r
  JOIN permisos p ON (
       (r.codigo = 'ADMIN' AND p.codigo IN (
          'usuarios.gestionar', 'instituciones.gestionar', 'permisos.gestionar',
          'grupos.gestionar', 'actividades.aprobar', 'reportes.ver',
          'reglas.gestionar', 'auditoria.ver'))
    OR (r.codigo = 'DOCENTE' AND p.codigo IN (
          'actividades.crear', 'actividades.enviar', 'actividades.publicar',
          'panel.docente', 'perfiles.ver', 'recomendaciones.ver',
          'reportes.ver', 'asistente.usar'))
    OR (r.codigo = 'ESTUDIANTE' AND p.codigo IN (
          'actividades.resolver', 'resultados.ver_propios'))
  );

-- Estados del ciclo (RF-17).
INSERT INTO estados_actividad (codigo, nombre) VALUES
  ('BORRADOR',  'Borrador'),
  ('PENDIENTE', 'Pendiente de aprobación'),
  ('APROBADA',  'Aprobada'),
  ('RECHAZADA', 'Rechazada'),
  ('PUBLICADA', 'Publicada');

-- Niveles (RF-05). El PDF no fija cuáles: se proponen tres, editables.
INSERT INTO niveles_dificultad (codigo, nombre, orden) VALUES
  ('BASICO',     'Básico',     1),
  ('INTERMEDIO', 'Intermedio', 2),
  ('AVANZADO',   'Avanzado',   3);

-- Categorías (DEC-16): la de la consulta de ejemplo (p. 38) y variables de §2.
INSERT INTO categorias (codigo, nombre) VALUES
  ('RESOLUCION_PROBLEMAS', 'Resolución de problemas'),
  ('RAZONAMIENTO_LOGICO',  'Razonamiento lógico'),
  ('MEMORIA',              'Memoria'),
  ('ATENCION',             'Atención');

-- Institución del alcance (§17).
INSERT INTO instituciones (nombre) VALUES
  ('Instituto Tecnológico de Informática (ITI) — UTU');

-- -----------------------------------------------------------------------------
-- Reglas del motor, Nivel 1 (DEC-23, aprobadas el 26/09/2026).
-- condicion: todas las comparaciones deben cumplirse. Indicadores disponibles:
--   puntaje, eficiencia, mejora, persistencia (por actividad, último intento);
--   agregados: puntaje_medio_categoria, actividades_categoria (período).
-- sugerencia: qué actividad proponer (categoría/nivel relativos a la actual).
-- -----------------------------------------------------------------------------
INSERT INTO reglas_analisis
  (codigo, nombre, descripcion, tipo, condicion, sugerencia, recomendacion_plantilla, prioridad)
VALUES
  ('R01', 'Puntaje bajo',
   'El puntaje del último intento es menor a 50.',
   'RIESGO',
   '{"todas":[{"indicador":"puntaje","op":"<","valor":50}]}',
   '{"categoria":"misma","nivel":"mismo"}',
   'Reforzar con otra actividad de la misma categoría y nivel.', 80),

  ('R02', 'Listo para avanzar',
   'Puntaje de al menos 85 con eficiencia de al menos 1,0.',
   'AVANCE',
   '{"todas":[{"indicador":"puntaje","op":">=","valor":85},{"indicador":"eficiencia","op":">=","valor":1.0}]}',
   '{"categoria":"misma","nivel":"siguiente"}',
   'Proponer una actividad del nivel siguiente en la misma categoría.', 40),

  ('R03', 'Domina con lentitud',
   'Puntaje de al menos 85 pero eficiencia menor a 0,7.',
   'REFUERZO',
   '{"todas":[{"indicador":"puntaje","op":">=","valor":85},{"indicador":"eficiencia","op":"<","valor":0.7}]}',
   '{"categoria":"misma","nivel":"mismo"}',
   'Practicar en el mismo nivel para ganar fluidez.', 50),

  ('R04', 'Aprende con la práctica',
   'Mejora de al menos 20 puntos y puntaje de al menos 70.',
   'AVANCE',
   '{"todas":[{"indicador":"mejora","op":">=","valor":20},{"indicador":"puntaje","op":">=","valor":70}]}',
   '{"categoria":"misma","nivel":"siguiente"}',
   'Mantener la categoría y subir de nivel.', 45),

  ('R05', 'Estancamiento',
   'Tres o más intentos sin mejora.',
   'RIESGO',
   '{"todas":[{"indicador":"persistencia","op":">=","valor":3},{"indicador":"mejora","op":"<=","valor":0}]}',
   '{"categoria":"misma","nivel":"inferior"}',
   'Proponer el nivel inferior y considerar una intervención directa del docente.', 90),

  ('R06', 'Persistencia con logro',
   'Cuatro o más intentos y puntaje final de al menos 70.',
   'RECONOCIMIENTO',
   '{"todas":[{"indicador":"persistencia","op":">=","valor":4},{"indicador":"puntaje","op":">=","valor":70}]}',
   '{"categoria":"misma","nivel":"mismo"}',
   'Reconocer el esfuerzo y continuar en el mismo nivel.', 30),

  ('R07', 'No reintenta',
   'Un solo intento con puntaje menor a 50.',
   'RIESGO',
   '{"todas":[{"indicador":"persistencia","op":"=","valor":1},{"indicador":"puntaje","op":"<","valor":50}]}',
   '{"actividad":"misma"}',
   'Incentivar un nuevo intento de la misma actividad.', 70),

  ('R08', 'Dificultad sostenida en la categoría',
   'Puntaje medio menor a 50 en 2 o más actividades de la misma categoría en el período.',
   'RIESGO',
   '{"todas":[{"agregado":"puntaje_medio_categoria","op":"<","valor":50},{"agregado":"actividades_categoria","op":">=","valor":2}]}',
   '{"categoria":"misma","nivel":"inferior"}',
   'Priorizar esta categoría con actividades del nivel inferior.', 85);
