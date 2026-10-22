<?php

declare(strict_types=1);

namespace Atlas\Http\Requests;

/** Alta de institución (RF-14); sin requiere_aprobacion vale el defecto: sin aprobación (D-2). */
final class CrearInstitucionRequest extends AtlasRequest
{
    public function rules(): array
    {
        return [
            'nombre' => ['required', 'string', 'max:150'],
            'requiere_aprobacion' => ['nullable', 'boolean'],
        ];
    }
}
