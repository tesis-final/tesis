-- =============================================================================
-- ATLAS — tools/datos_representativos.sql  (Hito 2, Base de Datos)
--
-- Carga datos SINTÉTICOS y REPRODUCIBLES para probar el modelo y medir el
-- rendimiento de las consultas (devolución de Base de Datos, punto 4).
-- No usa RAND(): todo sale de CRC32 de los identificadores, así cada ejecución
-- produce exactamente los mismos datos.
--
-- Volumen por defecto (variables al principio):
--   10 grupos x 30 estudiantes = 300 estudiantes, 5 docentes, 30 actividades
--   de 10 preguntas con 4 opciones, publicadas en los 10 grupos
--   -> 9.000 intentos, ~87.000 respuestas e interacciones, ~8.700 resultados.
--
-- Pasa por las mismas reglas que la aplicación: las actividades recorren el
-- ciclo BORRADOR -> PENDIENTE -> APROBADA -> PUBLICADA (trigger del ciclo), las
-- respuestas se validan (trigger) y los resultados se guardan con el mismo
-- cálculo que hace la aplicación (acta D-4). Ninguna regla se desactiva.
--
-- Uso (solo en una base de PRUEBA, como root):
--   mysql -uroot -p atlas_db < datos_representativos.sql
-- Las cuentas creadas no pueden iniciar sesión (hash inválido a propósito).
-- =============================================================================

USE atlas_db;

SET @grupos          := 10;
SET @est_por_grupo   := 30;
SET @docentes        := 5;
SET @actividades     := 30;
SET @preguntas       := 10;
SET @inicio          := TIMESTAMP('2026-08-03 12:00:00');
SET @hash_sin_acceso := '!sin-acceso-datos-sinteticos';
SET SESSION cte_max_recursion_depth = 10000;

-- Institución propia: no se mezcla con datos reales.
-- Exige aprobación (D-2 la hace configurable) para recorrer el ciclo completo.
INSERT INTO instituciones (nombre, requiere_aprobacion) VALUES ('Liceo de prueba (datos sintéticos)', TRUE);
SET @inst := LAST_INSERT_ID();

-- Docentes
INSERT INTO usuarios (institucion_id, rol_id, nombre, apellido, correo, hash_contrasena)
WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < @docentes)
SELECT @inst, (SELECT id FROM roles WHERE codigo = 'DOCENTE'),
       CONCAT('Docente', i), 'Sintético', CONCAT('docente', i, '@sintetico.atlas.local'), @hash_sin_acceso
  FROM n;

-- Grupos
INSERT INTO grupos_clase (institucion_id, nombre, anio_lectivo)
WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < @grupos)
SELECT @inst, CONCAT('S', LPAD(i, 2, '0')), 2026 FROM n;

-- Estudiantes (nombres genéricos: ningún dato personal real)
INSERT INTO usuarios (institucion_id, rol_id, nombre, apellido, correo, hash_contrasena)
WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < @grupos * @est_por_grupo)
SELECT @inst, (SELECT id FROM roles WHERE codigo = 'ESTUDIANTE'),
       CONCAT('Estudiante', i), 'Sintético', CONCAT('est', i, '@sintetico.atlas.local'), @hash_sin_acceso
  FROM n;

-- Pertenencia: estudiante k va al grupo ((k-1) div 30) + 1; cada docente tiene 2 grupos.
INSERT INTO usuario_grupo (usuario_id, grupo_id)
SELECT u.id, g.id
  FROM usuarios u
  JOIN grupos_clase g ON g.institucion_id = @inst
   AND g.nombre = CONCAT('S', LPAD(((CAST(SUBSTRING(u.correo, 4, LOCATE('@', u.correo) - 4) AS UNSIGNED) - 1) DIV @est_por_grupo) + 1, 2, '0'))
 WHERE u.institucion_id = @inst AND u.correo LIKE 'est%';

INSERT INTO usuario_grupo (usuario_id, grupo_id)
SELECT d.id, g.id
  FROM usuarios d
  JOIN grupos_clase g ON g.institucion_id = @inst
 WHERE d.institucion_id = @inst AND d.correo LIKE 'docente%'
   AND ((CAST(SUBSTRING(g.nombre, 2) AS UNSIGNED) - 1) MOD @docentes) + 1
       = CAST(SUBSTRING(d.correo, 8, LOCATE('@', d.correo) - 8) AS UNSIGNED);

-- Actividades en BORRADOR (autor rotativo, categoría y nivel por CRC32)
INSERT INTO actividades (autor_id, nivel_id, categoria_id, estado_id, titulo)
WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < @actividades)
SELECT (SELECT id FROM usuarios WHERE correo = CONCAT('docente', ((i - 1) MOD @docentes) + 1, '@sintetico.atlas.local')),
       (SELECT MIN(id) FROM niveles_dificultad) + (CRC32(CONCAT('niv', i)) MOD (SELECT COUNT(*) FROM niveles_dificultad)),
       (SELECT MIN(id) FROM categorias) + (CRC32(CONCAT('cat', i)) MOD (SELECT COUNT(*) FROM categorias)),
       (SELECT id FROM estados_actividad WHERE codigo = 'BORRADOR'),
       CONCAT('Actividad sintética ', LPAD(i, 2, '0'))
  FROM n;

DROP TEMPORARY TABLE IF EXISTS tmp_act;
CREATE TEMPORARY TABLE tmp_act AS
SELECT a.id, a.autor_id, CAST(SUBSTRING(a.titulo, 21) AS UNSIGNED) AS nro
  FROM actividades a JOIN usuarios u ON u.id = a.autor_id
 WHERE u.institucion_id = @inst;

-- Preguntas
INSERT INTO preguntas (actividad_id, orden, enunciado)
WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < @preguntas)
SELECT t.id, n.i, CONCAT('Pregunta ', n.i, ' de la actividad ', t.nro)
  FROM tmp_act t CROSS JOIN n;

-- 4 opciones por pregunta; la correcta cambia de lugar según CRC32.
INSERT INTO opciones (pregunta_id, orden, texto, es_correcta)
WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 4)
SELECT p.id, n.i, CONCAT('Opción ', CHAR(64 + n.i)), (n.i = (CRC32(CONCAT('ok', p.id)) MOD 4) + 1)
  FROM preguntas p JOIN tmp_act t ON t.id = p.actividad_id CROSS JOIN n;

-- Habilidades: cada pregunta mide 1 habilidad, y 1 de cada 3 mide además otra.
INSERT INTO pregunta_habilidad (pregunta_id, habilidad_id)
SELECT p.id, h.id
  FROM preguntas p JOIN tmp_act t ON t.id = p.actividad_id
  JOIN (SELECT id, ROW_NUMBER() OVER (ORDER BY id) - 1 AS k FROM habilidades WHERE activa) h
    ON h.k = CRC32(CONCAT('h1', p.id)) MOD (SELECT COUNT(*) FROM habilidades WHERE activa);

INSERT IGNORE INTO pregunta_habilidad (pregunta_id, habilidad_id)
SELECT p.id, h.id
  FROM preguntas p JOIN tmp_act t ON t.id = p.actividad_id
  JOIN (SELECT id, ROW_NUMBER() OVER (ORDER BY id) - 1 AS k FROM habilidades WHERE activa) h
    ON h.k = CRC32(CONCAT('h2', p.id)) MOD (SELECT COUNT(*) FROM habilidades WHERE activa)
 WHERE CRC32(CONCAT('h2?', p.id)) MOD 3 = 0;

-- Ciclo completo por el trigger (la institución exige aprobación).
UPDATE actividades SET estado_id = (SELECT id FROM estados_actividad WHERE codigo = 'PENDIENTE') WHERE id IN (SELECT id FROM tmp_act);
UPDATE actividades SET estado_id = (SELECT id FROM estados_actividad WHERE codigo = 'APROBADA')  WHERE id IN (SELECT id FROM tmp_act);
UPDATE actividades SET estado_id = (SELECT id FROM estados_actividad WHERE codigo = 'PUBLICADA') WHERE id IN (SELECT id FROM tmp_act);

INSERT INTO actividad_grupo (actividad_id, grupo_id, publicado_por, publicado_en)
SELECT t.id, g.id, t.autor_id, @inicio + INTERVAL (t.nro - 1) * 2 DAY
  FROM tmp_act t JOIN grupos_clase g ON g.institucion_id = @inst;

-- Intentos: cada estudiante resuelve cada actividad publicada en su grupo.
-- "Capacidad" del estudiante entre 35 y 95 (sirve para que haya diferencias).
INSERT INTO intentos (usuario_id, actividad_id, numero_intento, estado, iniciado_en)
SELECT ug.usuario_id, ag.actividad_id, 1, 'EN_CURSO',
       ag.publicado_en + INTERVAL (CRC32(CONCAT('ini', ug.usuario_id, '-', ag.actividad_id)) MOD 72) HOUR
  FROM actividad_grupo ag
  JOIN tmp_act t ON t.id = ag.actividad_id
  JOIN usuario_grupo ug ON ug.grupo_id = ag.grupo_id
  JOIN usuarios u ON u.id = ug.usuario_id AND u.correo LIKE 'est%';

DROP TEMPORARY TABLE IF EXISTS tmp_int;
CREATE TEMPORARY TABLE tmp_int (PRIMARY KEY (id)) AS
SELECT i.id, i.usuario_id, i.actividad_id, i.iniciado_en,
       35 + (CRC32(CONCAT('cap', i.usuario_id)) MOD 61) AS capacidad,
       (CRC32(CONCAT('aband', i.id)) MOD 100) < 3 AS abandona
  FROM intentos i JOIN tmp_act t ON t.id = i.actividad_id;

-- Respuestas (los que abandonan responden solo la mitad).
-- Acierta si un número pseudoaleatorio 0-99 queda debajo de su capacidad.
INSERT INTO respuestas (intento_id, pregunta_id, opcion_id, tiempo_seg, respondido_en)
SELECT x.id, p.id,
       IF((CRC32(CONCAT('r', x.id, '-', p.id)) MOD 100) < x.capacidad, oc.id, oi.id),
       10 + (CRC32(CONCAT('t', x.id, '-', p.id)) MOD 81),
       x.iniciado_en + INTERVAL p.orden * 60 SECOND
  FROM tmp_int x
  JOIN preguntas p ON p.actividad_id = x.actividad_id
  JOIN opciones oc ON oc.pregunta_id = p.id AND oc.es_correcta
  JOIN opciones oi ON oi.pregunta_id = p.id AND NOT oi.es_correcta
                  AND oi.orden = (SELECT MIN(orden) FROM opciones WHERE pregunta_id = p.id AND NOT es_correcta)
 WHERE NOT x.abandona OR p.orden <= @preguntas / 2;

-- Un evento SELECCION por respuesta (secuencia 2..11; la 1 sería INICIO).
INSERT INTO interacciones (intento_id, secuencia, tipo, pregunta_id, opcion_id, ocurrido_en, duracion_ms)
SELECT r.intento_id, p.orden + 1, 'SELECCION', r.pregunta_id, r.opcion_id, r.respondido_en, r.tiempo_seg * 1000
  FROM respuestas r JOIN preguntas p ON p.id = r.pregunta_id
  JOIN tmp_int x ON x.id = r.intento_id;

-- Cierre de los intentos.
UPDATE intentos i JOIN tmp_int x ON x.id = i.id
   SET i.estado = IF(x.abandona, 'ABANDONADO', 'FINALIZADO'),
       i.finalizado_en = x.iniciado_en + INTERVAL (@preguntas * 60 + 30) SECOND,
       i.duracion_seg = @preguntas * 60 + 30;

-- Resultado de cada intento finalizado. Desde 004 (acta D-4) la base no lo calcula:
-- en la plataforma lo hace IntentoService::finalizar; este script de carga de
-- prueba guarda lo mismo (correctas / total × 100) para tener datos completos.
INSERT INTO resultados (intento_id, correctas, total_preguntas, puntaje)
SELECT i.id, COALESCE(c.correctas, 0), t.total, ROUND(COALESCE(c.correctas, 0) * 100 / t.total, 2)
  FROM intentos i JOIN tmp_int x ON x.id = i.id
  JOIN (SELECT actividad_id, COUNT(*) AS total FROM preguntas GROUP BY actividad_id) t ON t.actividad_id = i.actividad_id
  LEFT JOIN (SELECT r.intento_id, SUM(o.es_correcta) AS correctas
          FROM respuestas r JOIN opciones o ON o.id = r.opcion_id GROUP BY r.intento_id) c ON c.intento_id = i.id
 WHERE i.estado = 'FINALIZADO';

DROP TEMPORARY TABLE IF EXISTS tmp_int;
DROP TEMPORARY TABLE IF EXISTS tmp_act;

-- Resumen de lo cargado
SELECT (SELECT COUNT(*) FROM usuarios WHERE institucion_id = @inst) AS usuarios,
       (SELECT COUNT(*) FROM grupos_clase WHERE institucion_id = @inst) AS grupos,
       (SELECT COUNT(*) FROM actividades a JOIN usuarios u ON u.id = a.autor_id WHERE u.institucion_id = @inst) AS actividades,
       (SELECT COUNT(*) FROM intentos) AS intentos,
       (SELECT COUNT(*) FROM respuestas) AS respuestas,
       (SELECT COUNT(*) FROM interacciones) AS interacciones,
       (SELECT COUNT(*) FROM resultados) AS resultados,
       (SELECT COUNT(*) FROM pregunta_habilidad) AS vinculos_habilidad;
