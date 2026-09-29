<?php

declare(strict_types=1);

namespace Atlas\Middleware;

use Atlas\Core\Request;
use Atlas\Core\Response;
use Atlas\Core\Route;
use Atlas\Services\AuditoriaService;

/**
 * [4] Se registra la acción (RF-15). Toda operación que modifica datos queda
 * auditada con su autor, sin que cada controlador tenga que acordarse.
 */
final class Auditoria implements Middleware
{
    public function __construct(private readonly AuditoriaService $auditoria)
    {
    }

    public function procesar(Request $peticion, Route $ruta, callable $siguiente): Response
    {
        $respuesta = $siguiente($peticion);
        if (!$ruta->auditar) {
            return $respuesta;
        }
        $accion = $ruta->accionAuditoria;
        if ($accion === null && !in_array($peticion->metodo, ['GET', 'HEAD'], true)) {
            $accion = strtolower($peticion->metodo) . ' ' . $ruta->ruta;
        }
        $usuario = $peticion->atributo('usuario');
        if ($accion !== null && $usuario !== null) {
            $parametros = $peticion->atributo('parametros', []);
            $this->auditoria->registrar(
                (int) $usuario['id'],
                $accion,
                $ruta->ruta,
                isset($parametros['id']) ? (string) $parametros['id'] : null,
                'OK',
                ['estado_http' => $respuesta->estado],
                $peticion->ip
            );
        }

        return $respuesta;
    }
}
