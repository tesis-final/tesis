<?php

declare(strict_types=1);

namespace Atlas\Http\Requests;

/** Respuesta a una pregunta (RF-07, RF-09). */
final class ResponderRequest extends AtlasRequest
{
    public function rules(): array
    {
        return [
            'opcion_id' => ['required', 'integer', 'min:1'],
            'tiempo_seg' => ['nullable', 'integer', 'min:0', 'max:86400'],
        ];
    }
}
