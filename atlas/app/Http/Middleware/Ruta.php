<?php

declare(strict_types=1);

namespace Atlas\Http\Middleware;

use Illuminate\Http\Request;

/** Patrón de la ruta para la auditoría, igual que antes de Laravel: "/api/v1/usuarios/{id}". */
final class Ruta
{
    public static function de(Request $peticion): string
    {
        $ruta = $peticion->route();

        return '/' . ltrim($ruta !== null ? $ruta->uri() : $peticion->path(), '/');
    }
}
