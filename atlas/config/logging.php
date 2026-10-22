<?php

/*
 * Los errores van a la salida de error del contenedor (journald en el servidor,
 * §28.3). La auditoría de negocio NO va acá: va a la tabla `auditoria` y a
 * auditoria.log (AuditoriaService).
 */

use Monolog\Handler\StreamHandler;

return [
    'default' => env('LOG_CHANNEL', 'stderr'),
    'channels' => [
        'stderr' => [
            'driver' => 'monolog',
            'level' => env('LOG_LEVEL', 'warning'),
            'handler' => StreamHandler::class,
            'with' => ['stream' => 'php://stderr'],
        ],
    ],
];
