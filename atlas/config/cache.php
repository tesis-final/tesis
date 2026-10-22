<?php

/*
 * ATLAS no guarda datos en la caché de Laravel (por defecto, en memoria). El almacén
 * en archivos solo se usa para los bloqueos de sesión (config/session.php: block),
 * que tienen que verse entre todos los procesos de php-fpm.
 */

return [
    'default' => 'array',
    'stores' => [
        'array' => ['driver' => 'array', 'serialize' => false],
        'file' => [
            'driver' => 'file',
            'path' => storage_path('framework/cache/data'),
            'lock_path' => storage_path('framework/cache/data'),
        ],
    ],
];
