<?php

declare(strict_types=1);

namespace Atlas\Http\Middleware;

use Atlas\Core\App as Atlas;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * [4] Se registra la acción (RF-15). Toda operación que modifica datos queda
 * auditada con su autor, sin que cada controlador tenga que acordarse:
 * ->middleware('atlas.auditoria:usuarios.crear').
 * Solo se registra lo que se hizo (respuesta 2xx): los rechazos 401/403 ya los
 * registran los pasos [1] y [2], y un 422 no cambió nada.
 * Si el controlador dejó en la petición el atributo `auditoria`
 * (['recurso_id' => ..., 'detalle' => [...]]), se agrega al registro: así queda
 * el antes y el después de un cambio sin triggers en la base (acta D-4).
 */
final class Auditoria
{
    public function __construct(private readonly Atlas $atlas)
    {
    }

    public function handle(Request $peticion, Closure $siguiente, string $accion): Response
    {
        $respuesta = $siguiente($peticion);
        $usuario = $peticion->attributes->get('usuario');
        if ($respuesta->getStatusCode() >= 400 || $usuario === null) {
            return $respuesta;
        }
        $extra = $peticion->attributes->get('auditoria', []);
        $id = $peticion->route('id');
        $this->atlas->auditoria()->registrar(
            (int) $usuario['id'],
            $accion,
            Ruta::de($peticion),
            $extra['recurso_id'] ?? ($id !== null ? (string) $id : null),
            'OK',
            ['estado_http' => $respuesta->getStatusCode()] + ($extra['detalle'] ?? []),
            (string) $peticion->ip()
        );

        return $respuesta;
    }
}
