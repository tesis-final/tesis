<?php

declare(strict_types=1);

namespace Atlas\Core;

use RuntimeException;

/**
 * Error que se traduce en una respuesta HTTP con código y cuerpo JSON.
 */
final class HttpException extends RuntimeException
{
    /** @param array<string, mixed> $detalle */
    public function __construct(
        public readonly int $estado,
        string $mensaje,
        public readonly array $detalle = []
    ) {
        parent::__construct($mensaje, $estado);
    }

    public static function noAutenticado(): self
    {
        return new self(401, 'Se requiere iniciar sesión.');
    }

    public static function prohibido(string $mensaje = 'No tiene permiso para realizar esta acción.'): self
    {
        return new self(403, $mensaje);
    }

    public static function noEncontrado(string $mensaje = 'Recurso no encontrado.'): self
    {
        return new self(404, $mensaje);
    }

    /** @param array<string, string> $errores */
    public static function validacion(array $errores, string $mensaje = 'Los datos enviados no son válidos.'): self
    {
        return new self(422, $mensaje, ['errores' => $errores]);
    }

    public static function conflicto(string $mensaje): self
    {
        return new self(409, $mensaje);
    }
}
