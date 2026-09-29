<?php

declare(strict_types=1);

namespace Atlas\Middleware;

use Atlas\Core\Database;
use Atlas\Core\HttpException;
use Atlas\Core\Request;
use Atlas\Core\Response;
use Atlas\Core\Route;
use Atlas\Core\Session;
use Atlas\Repositories\UsuarioRepository;
use Atlas\Services\AuditoriaService;

/**
 * [1] ¿Hay sesión válida? Si no → 401. Además exige el token CSRF en toda
 * petición que modifica datos (protección de la sesión por cookie).
 */
final class Autenticacion implements Middleware
{
    public function __construct(
        private readonly Session $sesion,
        private readonly UsuarioRepository $usuarios,
        private readonly Database $db,
        private readonly AuditoriaService $auditoria
    ) {
    }

    public function procesar(Request $peticion, Route $ruta, callable $siguiente): Response
    {
        if (!$ruta->requiereSesion) {
            return $siguiente($peticion);
        }
        $id = $this->sesion->obtener('usuario_id');
        $usuario = is_int($id) ? $this->usuarios->porId($id) : null;
        if ($usuario === null || !$usuario['activo']) {
            throw HttpException::noAutenticado();
        }
        if (!in_array($peticion->metodo, ['GET', 'HEAD'], true)) {
            $esperado = (string) $this->sesion->obtener('csrf', '');
            $recibido = (string) $peticion->cabecera('x-csrf-token');
            if ($esperado === '' || !hash_equals($esperado, $recibido)) {
                $this->auditoria->registrar(
                    (int) $usuario['id'],
                    'seguridad.csrf',
                    $ruta->ruta,
                    null,
                    'DENEGADO',
                    [],
                    $peticion->ip
                );
                throw HttpException::prohibido('Token de seguridad inválido. Vuelva a iniciar sesión.');
            }
        }
        $this->db->identificarUsuario((int) $usuario['id']);
        $peticion->con('usuario', $usuario);

        return $siguiente($peticion);
    }
}
