<?php

declare(strict_types=1);

namespace Atlas\Http\Requests;

/** Alta de usuario por el administrador (RF-01). */
final class CrearUsuarioRequest extends AtlasRequest
{
    public function rules(): array
    {
        return [
            'nombre' => ['required', 'string', 'max:80'],
            'apellido' => ['required', 'string', 'max:80'],
            'correo' => ['required', 'string', 'email:filter', 'max:190'],
            'contrasena' => ['required', 'string', 'max:200'],
            'rol' => ['required', 'in:ADMIN,DOCENTE,ESTUDIANTE'],
            'institucion_id' => ['required', 'integer', 'min:1'],
        ];
    }
}
