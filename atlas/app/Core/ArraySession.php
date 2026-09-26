<?php

declare(strict_types=1);

namespace Atlas\Core;

/** Sesión en memoria para tests y CLI. */
final class ArraySession implements Session
{
    /** @var array<string, mixed> */
    private array $datos = [];
    public int $regeneraciones = 0;

    public function obtener(string $clave, mixed $defecto = null): mixed
    {
        return $this->datos[$clave] ?? $defecto;
    }

    public function guardar(string $clave, mixed $valor): void
    {
        $this->datos[$clave] = $valor;
    }

    public function regenerar(): void
    {
        $this->regeneraciones++;
    }

    public function destruir(): void
    {
        $this->datos = [];
    }
}
