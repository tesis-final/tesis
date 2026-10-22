<?php

/* ATLAS no usa la caché de Laravel; en memoria, para no depender de la base. */

return [
    'default' => 'array',
    'stores' => [
        'array' => ['driver' => 'array', 'serialize' => false],
    ],
];
