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
];
