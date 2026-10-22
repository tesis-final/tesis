<?php

/*
 * Sesión del servidor (RF-02). Mismas condiciones que antes de la migración:
 * cookie ATLASSID Secure, HttpOnly y SameSite=Strict, que vence por inactividad.
 * Driver file: atlas_app no tiene permisos de DDL, así que no hay tabla de sesiones.
 */

return [
    'driver' => 'file',
    'lifetime' => (int) env('ATLAS_SESSION_IDLE_MINUTES', 30),
    'expire_on_close' => true,
    'encrypt' => false,
    'files' => storage_path('framework/sessions'),
    'lottery' => [2, 100],
    'cookie' => 'ATLASSID',
    'path' => '/',
    'domain' => null,
    'secure' => filter_var(env('ATLAS_COOKIE_SECURE', true), FILTER_VALIDATE_BOOL),
    'http_only' => true,
    'same_site' => 'strict',
    'partitioned' => false,

    // Las peticiones de una misma sesión se atienden de a una, como las sesiones nativas
    // de PHP. Sin esto, una petición que empezó antes del logout podía volver a guardar
    // la sesión al terminar y dejar al usuario adentro (verificado en la prueba de interfaz).
    'block' => true,
    'block_store' => 'file',
    'block_lock_seconds' => 10,
    'block_wait_seconds' => 10,
];
