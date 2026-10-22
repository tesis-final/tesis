<?php

declare(strict_types=1);

namespace Atlas\Http\Requests;

/** Inicio de un intento (RF-08). */
final class IniciarIntentoRequest extends AtlasRequest
{
    public function rules(): array
    {
        return [
            'actividad_id' => ['required', 'integer', 'min:1'],
        ];
    }
}
