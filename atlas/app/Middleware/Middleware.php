<?php

declare(strict_types=1);

namespace Atlas\Middleware;

use Atlas\Core\Request;
use Atlas\Core\Response;
use Atlas\Core\Route;

/**
 * Eslabón de la cadena de §26.3: autenticación → permisos → validación →
 * auditoría → controlador.
 */
interface Middleware
{
    /** @param callable(Request): Response $siguiente */
    public function procesar(Request $peticion, Route $ruta, callable $siguiente): Response;
}
