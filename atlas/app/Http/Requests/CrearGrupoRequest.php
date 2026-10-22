<?php

declare(strict_types=1);

namespace Atlas\Http\Requests;

/** Alta de grupo. */
final class CrearGrupoRequest extends AtlasRequest
{
    public function rules(): array
    {
        return [
            'nombre' => ['required', 'string', 'max:60'],
            'anio_lectivo' => ['required', 'integer', 'min:2000', 'max:2100'],
            'institucion_id' => ['required', 'integer', 'min:1'],
        ];
    }
}
