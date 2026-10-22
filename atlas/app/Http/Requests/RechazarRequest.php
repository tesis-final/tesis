<?php

declare(strict_types=1);

namespace Atlas\Http\Requests;

/** Rechazo de una actividad: las observaciones son obligatorias (§25.3). */
final class RechazarRequest extends AtlasRequest
{
    public function rules(): array
    {
        return [
            'observaciones' => ['required', 'string', 'max:2000'],
        ];
    }
}
