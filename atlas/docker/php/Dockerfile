# ATLAS — contenedor atlas-php (PDF Tabla 15: php:8.3-fpm).
FROM php:8.3-fpm

# Extensiones necesarias: PDO MySQL. Argon2id y JSON ya vienen en la imagen oficial.
RUN docker-php-ext-install pdo_mysql \
 && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY docker/php/atlas.ini "$PHP_INI_DIR/conf.d/zz-atlas.ini"
COPY docker/php/www.conf /usr/local/etc/php-fpm.d/zz-atlas.conf

WORKDIR /srv/atlas/web/app
# El código se monta en tiempo de ejecución desde /srv/atlas/web (§28.3), en solo lectura.
# El proceso corre con el UID/GID de atlasweb (5002), definido en docker-compose.yml.
