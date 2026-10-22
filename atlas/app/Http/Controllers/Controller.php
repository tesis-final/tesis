<?php

declare(strict_types=1);

namespace Atlas\Http\Controllers;

use Atlas\Core\App as Atlas;
use Atlas\Core\HttpException;
use Illuminate\Http\Request;

/**
 * Los controladores solo coordinan: leen la petición, llaman a un servicio y
 * arman la respuesta (Tabla 17: "los controladores coordinan, los servicios
 * tienen la lógica, los repositorios hablan con la base"). Los servicios son los
 * mismos de antes de Laravel: llegan por Atlas\Core\App (AtlasServiceProvider).
 */
abstract class Controller
{
    public function __construct(protected readonly Atlas $atlas)
    {
    }

    /** Usuario de la sesión, que dejó el middleware atlas.sesion. @return array<string, mixed> */
    protected function usuario(Request $p): array
    {
        return $p->attributes->get('usuario');
    }

    /**
     * Detalle para el middleware de auditoría (antes/después de un cambio, D-4). Va en
     * la petición original: un Form Request es una copia y el middleware no la ve.
     *
     * @param array{recurso_id?: string, detalle?: array<string, mixed>} $datos
     */
    protected function auditar(array $datos): void
    {
        app('request')->attributes->set('auditoria', $datos);
    }

    /** Parámetro numérico de la ruta ({id}, {pregunta}); si no es un número → 404. */
    protected function id(Request $p, string $nombre = 'id'): int
    {
        $valor = (string) $p->route($nombre);
        if (!ctype_digit($valor)) {
            throw HttpException::noEncontrado();
        }

        return (int) $valor;
    }

    protected function consultaEntera(Request $p, string $clave): ?int
    {
        $v = $p->query($clave);

        return is_string($v) && ctype_digit($v) ? (int) $v : null;
    }

    protected function consultaFecha(Request $p, string $clave): ?string
    {
        $v = $p->query($clave);

        return is_string($v) && preg_match('/^\d{4}-\d{2}-\d{2}$/', $v) ? $v : null;
    }
}
