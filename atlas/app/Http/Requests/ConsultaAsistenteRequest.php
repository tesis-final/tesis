<?php

declare(strict_types=1);

namespace Atlas\Http\Requests;

/** Consulta al asistente (RF-20, opcional según D-5). */
final class ConsultaAsistenteRequest extends AtlasRequest
{
    public function rules(): array
    {
        return [
            'pregunta' => ['required', 'string', 'max:1000'],
        ];
    }
}
