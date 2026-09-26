<?php

declare(strict_types=1);

namespace Atlas\Core;

/**
 * Ruteo propio (sin framework, PDF §25.2): asocia método + ruta a una Route.
 */
final class Router
{
    /** @var list<Route> */
    private array $rutas = [];

    public function agregar(Route $ruta): void
    {
        $this->rutas[] = $ruta;
    }

    /**
     * @return array{0: Route, 1: array<string, string>}
     * @throws HttpException 404 o 405
     */
    public function resolver(string $metodo, string $ruta): array
    {
        $metodoIncorrecto = false;
        foreach ($this->rutas as $r) {
            $parametros = $r->coincide($metodo, $ruta);
            if ($parametros !== null) {
                return [$r, $parametros];
            }
            if ($r->coincide($r->metodo, $ruta) !== null) {
                $metodoIncorrecto = true;
            }
        }
        if ($metodoIncorrecto) {
            throw new HttpException(405, 'Método no permitido.');
        }
        throw HttpException::noEncontrado('Ruta no encontrada.');
    }
}
