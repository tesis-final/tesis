-- =============================================================================
-- ATLAS — docker/mysql/init.sql (PDF §26.2)
-- Punto de entrada que ejecuta el contenedor atlas-db la primera vez que
-- arranca con el datadir vacío. Aplica migraciones y catálogos en orden.
-- Los usuarios de MySQL con sus contraseñas los crea 02-usuarios.sh, que las
-- lee de variables de entorno (/srv/atlas/config/atlas.conf).
-- =============================================================================
SOURCE /atlas/database/migrations/001_esquema.sql;
SOURCE /atlas/database/migrations/002_logica.sql;
SOURCE /atlas/database/migrations/003_habilidades_aprobacion.sql;
SOURCE /atlas/database/migrations/004_calculos_en_php.sql;
SOURCE /atlas/database/seeds/001_catalogos.sql;
SOURCE /atlas/database/seeds/002_habilidades.sql;
