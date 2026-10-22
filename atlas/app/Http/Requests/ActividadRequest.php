<?php

declare(strict_types=1);

namespace Atlas\Http\Requests;

/** Datos de una actividad (RF-05, RF-16). Las preguntas las valida ActividadService. */
final class ActividadRequest extends AtlasRequest
{
    public function rules(): array
    {
        return [
            'titulo' => ['required', 'string', 'max:150'],
            'descripcion' => ['nullable', 'string', 'max:5000'],
            'nivel' => ['required', 'string', 'max:20'],
            'categoria' => ['required', 'string', 'max:40'],
        ];
    }
}
