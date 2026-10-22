<?php

/*
 * Mensajes de validación (RNF-11): los mismos textos que usaba ATLAS antes de
 * Laravel, sin repetir el nombre del campo (la interfaz los muestra junto a él).
 */

return [
    'required' => 'Es obligatorio.',
    'string' => 'Debe ser un texto no vacío.',
    'integer' => 'Debe ser un número entero.',
    'numeric' => 'Debe ser un número.',
    'boolean' => 'Debe ser verdadero o falso.',
    'email' => 'No es un correo válido.',
    'in' => 'Valor no permitido.',
    'array' => 'Debe ser una lista.',
    'list' => 'Debe ser una lista.',
    'date_format' => 'Debe ser una fecha AAAA-MM-DD.',
    'max' => [
        'numeric' => 'Supera el máximo de :max.',
        'string' => 'Supera el máximo de :max.',
        'array' => 'Supera el máximo de :max.',
    ],
    'min' => [
        'numeric' => 'Debe ser al menos :min.',
        'string' => 'Debe ser al menos :min.',
        'array' => 'Debe ser al menos :min.',
    ],
];
