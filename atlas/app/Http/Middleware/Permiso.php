<?php

declare(strict_types=1);

namespace Atlas\Http\Middleware;

use Atlas\Core\App as Atlas;
use Atlas\Core\HttpException;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * [2] ¿Este rol puede hacer esto? Si no → 403, y el intento queda registrado
 * (RF-03: "todo intento de acceso no autorizado devuelve 403 y queda registrado").
 * Los permisos de cada rol están en la tabla rol_permiso; la ruta dice cuál exige:
 * ->middleware('atlas.permiso:usuarios.gestionar').
 */
final class Permiso
{
    public function __construct(private readonly Atlas $atlas)
    {
    }

    public function handle(Request $peticion, Closure $siguiente, string $permiso): Response
    {
        $usuario = $peticion->attributes->get('usuario');
        if (!$this->atlas->usuarios()->rolTienePermiso((int) $usuario['rol_id'], $permiso)) {
            $this->atlas->auditoria()->registrar(
                (int) $usuario['id'],
                'acceso.denegado',
                Ruta::de($peticion),
                null,
                'DENEGADO',
                ['metodo' => $peticion->method(), 'permiso' => $permiso, 'rol' => $usuario['rol']],
                (string) $peticion->ip()
            );
            throw HttpException::prohibido();
        }

        return $siguiente($peticion);
    }
}
