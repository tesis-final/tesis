<?php

declare(strict_types=1);

namespace Atlas\Http\Middleware;

use Atlas\Core\App as Atlas;
use Atlas\Core\HttpException;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * [1] ¿Hay sesión válida? Si no → 401. Además exige el token CSRF (cabecera
 * X-CSRF-Token) en toda petición que modifica datos (protección de la sesión por cookie).
 */
final class Autenticacion
{
    public function __construct(private readonly Atlas $atlas)
    {
    }

    public function handle(Request $peticion, Closure $siguiente): Response
    {
        $id = $this->atlas->sesion()->obtener('usuario_id');
        $usuario = is_int($id) ? $this->atlas->usuarios()->porId($id) : null;
        if ($usuario === null || !$usuario['activo']) {
            throw HttpException::noAutenticado();
        }
        if (!in_array($peticion->method(), ['GET', 'HEAD'], true)) {
            $esperado = (string) $this->atlas->sesion()->obtener('csrf', '');
            $recibido = (string) $peticion->header('X-CSRF-Token', '');
            if ($esperado === '' || !hash_equals($esperado, $recibido)) {
                $this->atlas->auditoria()->registrar(
                    (int) $usuario['id'],
                    'seguridad.csrf',
                    Ruta::de($peticion),
                    null,
                    'DENEGADO',
                    [],
                    (string) $peticion->ip()
                );
                throw HttpException::prohibido('Token de seguridad inválido. Vuelva a iniciar sesión.');
            }
        }
        $peticion->attributes->set('usuario', $usuario);

        return $siguiente($peticion);
    }
}
