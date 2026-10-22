<?php

/*
 * Configuración de Laravel para ATLAS. Lo que no se define acá toma el valor por
 * defecto del framework. La configuración propia (base de datos, servicio de
 * análisis, LLM) sigue en variables ATLAS_* (atlas.conf), leídas por Atlas\Core\Config.
 */

return [
    'name' => 'ATLAS',
    'env' => env('APP_ENV', 'production'),
    'debug' => (bool) env('APP_DEBUG', false),
    'url' => env('APP_URL', 'https://localhost'),
    'timezone' => 'UTC',
    'locale' => 'es',
    'fallback_locale' => 'es',
    // La API no cifra cookies ni usa el cifrador de Laravel: la clave es opcional.
    'key' => env('APP_KEY'),
    'cipher' => 'AES-256-CBC',
];
