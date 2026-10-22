<?php

declare(strict_types=1);

namespace Atlas\Http\Requests;

/** Lote de eventos de interacción (RF-06); cada evento lo valida IntentoService. */
final class EventosRequest extends AtlasRequest
{
    public function rules(): array
    {
        return [
            'eventos' => ['required', 'array', 'list', 'max:500'],
        ];
    }
}
