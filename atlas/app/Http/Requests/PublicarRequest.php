<?php

declare(strict_types=1);

namespace Atlas\Http\Requests;

/** Grupos donde se publica la actividad. */
final class PublicarRequest extends AtlasRequest
{
    public function rules(): array
    {
        return [
            'grupos' => ['required', 'array', 'list', 'min:1', 'max:50'],
        ];
    }
}
