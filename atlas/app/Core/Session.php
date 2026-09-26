<?php

declare(strict_types=1);

namespace Atlas\Core;

/**
 * Sesión del usuario. En producción es la sesión nativa de PHP (PhpSession);
 * en los tests, una implementación en memoria (ArraySession).
 */
interface Session
{
    public function obtener(string $clave, mixed $defecto = null): mixed;

    public function guardar(string $clave, mixed $valor): void;

    /** Nuevo identificador de sesión (evita la fijación de sesión al iniciar). */
    public function regenerar(): void;

    public function destruir(): void;
}
