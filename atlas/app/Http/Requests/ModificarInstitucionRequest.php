<?php

declare(strict_types=1);

namespace Atlas\Http\Requests;

/** Cambios de una institución, incluida la aprobación configurable (D-2). */
final class ModificarInstitucionRequest extends AtlasRequest
{
    public function rules(): array
    {
        return [
            'nombre' => ['required', 'string', 'max:150'],
            'activa' => ['nullable', 'boolean'],
            'requiere_aprobacion' => ['nullable', 'boolean'],
        ];
    }
}
