<?php

/* Contraseñas con Argon2id (RF-02), igual que AuthService::hash. */

return [
    'driver' => 'argon2id',
    'argon' => [
        'memory' => 65536,
        'threads' => 1,
        'time' => 4,
        'verify' => true,
    ],
    'rehash_on_login' => false,
];
