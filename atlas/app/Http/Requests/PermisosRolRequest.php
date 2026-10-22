<?php

declare(strict_types=1);

namespace Atlas\Http\Requests;

/** Permisos de un rol (RF-14). */
final class PermisosRolRequest extends AtlasRequest
{
    public function rules(): array
    {
        return [
            'permisos' => ['required', 'array', 'list', 'max:100'],
        ];
    }
}
