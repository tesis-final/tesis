<?php

declare(strict_types=1);

namespace Atlas\Middleware;

use Atlas\Core\HttpException;
use Atlas\Core\Request;
use Atlas\Core\Response;
use Atlas\Core\Route;
use Atlas\Repositories\UsuarioRepository;
use Atlas\Services\AuditoriaService;

/**
 * [2] ¿Este rol puede hacer esto? Si no → 403, y el intento queda registrado
 * (RF-03: "todo intento de acceso no autorizado devuelve 403 y queda registrado").
 */
final class Permisos implements Middleware
{
    public function __construct(
        private readonly UsuarioRepository $usuarios,
        private readonly AuditoriaService $auditoria
    ) {
    }

    public function procesar(Request $peticion, Route $ruta, callable $siguiente): Response
    {
        if ($ruta->permiso === null) {
            return $siguiente($peticion);
        }
        $usuario = $peticion->atributo('usuario');
        if (!$this->usuarios->rolTienePermiso((int) $usuario['rol_id'], $ruta->permiso)) {
            $this->auditoria->registrar(
                (int) $usuario['id'],
                'acceso.denegado',
                $ruta->ruta,
                null,
                'DENEGADO',
                ['metodo' => $peticion->metodo, 'permiso' => $ruta->permiso, 'rol' => $usuario['rol']],
                $peticion->ip
            );
            throw HttpException::prohibido();
        }

        return $siguiente($peticion);
    }
}
