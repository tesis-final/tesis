<?php

declare(strict_types=1);

namespace Atlas\Middleware;

use Atlas\Core\HttpException;
use Atlas\Core\Request;
use Atlas\Core\Response;
use Atlas\Core\Route;
use Atlas\Core\Validator;

/**
 * [3] ¿Los datos que llegaron sirven? Si no → 422 con el detalle por campo.
 */
final class Validacion implements Middleware
{
    public function procesar(Request $peticion, Route $ruta, callable $siguiente): Response
    {
        if ($ruta->reglas !== []) {
            $fuente = $peticion->metodo === 'GET' ? $peticion->query : $peticion->cuerpo;
            [$validos, $errores] = Validator::validar($fuente, $ruta->reglas);
            if ($errores !== []) {
                throw HttpException::validacion($errores);
            }
            $peticion->con('validados', $validos);
        }

        return $siguiente($peticion);
    }
}
