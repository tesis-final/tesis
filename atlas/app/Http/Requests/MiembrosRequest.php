<?php

declare(strict_types=1);

namespace Atlas\Http\Requests;

/** Miembros de un grupo. */
final class MiembrosRequest extends AtlasRequest
{
    public function rules(): array
    {
        return [
            'usuarios' => ['required', 'array', 'list', 'max:500'],
        ];
    }
}
