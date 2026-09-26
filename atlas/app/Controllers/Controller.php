<?php

declare(strict_types=1);

namespace Atlas\Controllers;

use Atlas\Core\App;
use Atlas\Core\Request;

/**
 * Los controladores solo coordinan: leen la petición, llaman a un servicio y
 * arman la respuesta (Tabla 17: "los controladores coordinan, los servicios
 * tienen la lógica, los repositorios hablan con la base").
 */
abstract class Controller
{
    public function __construct(protected readonly App $app)
    {
    }

    /** @return array<string, mixed> */
    protected function usuario(Request $p): array
    {
        return $p->atributo('usuario');
    }

    protected function consultaEntera(Request $p, string $clave): ?int
    {
        $v = $p->query[$clave] ?? null;

        return $v !== null && ctype_digit($v) ? (int) $v : null;
    }

    protected function consultaFecha(Request $p, string $clave): ?string
    {
        $v = $p->query[$clave] ?? null;

        return $v !== null && preg_match('/^\d{4}-\d{2}-\d{2}$/', $v) ? $v : null;
    }
}
