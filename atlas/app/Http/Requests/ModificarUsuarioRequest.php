<?php

declare(strict_types=1);

namespace Atlas\Http\Requests;

/** Cambios de un usuario (RF-14); todos los campos son opcionales. */
final class ModificarUsuarioRequest extends AtlasRequest
{
    public function rules(): array
    {
        return [
            'nombre' => ['nullable', 'string', 'max:80'],
            'apellido' => ['nullable', 'string', 'max:80'],
            'correo' => ['nullable', 'string', 'email:filter', 'max:190'],
            'contrasena' => ['nullable', 'string', 'max:200'],
            'institucion_id' => ['nullable', 'integer', 'min:1'],
            'activo' => ['nullable', 'boolean'],
        ];
    }
}
