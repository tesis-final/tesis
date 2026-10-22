<?php

declare(strict_types=1);

namespace Atlas\Http\Requests;

/** Inicio de sesión (RF-02). */
final class LoginRequest extends AtlasRequest
{
    public function rules(): array
    {
        return [
            'correo' => ['required', 'string', 'email:filter', 'max:190'],
            'contrasena' => ['required', 'string', 'max:200'],
        ];
    }
}
