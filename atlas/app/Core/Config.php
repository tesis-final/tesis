<?php

declare(strict_types=1);

namespace Atlas\Core;

/**
 * Configuración leída de variables de entorno (en producción, desde
 * /srv/atlas/config/atlas.conf — CT-12). Ningún secreto vive en el código.
 */
final class Config
{
    /** @param array<string, string> $valores */
    public function __construct(private array $valores)
    {
    }

    public static function desdeEntorno(): self
    {
        return new self(array_map('strval', getenv()));
    }

    public function texto(string $clave, ?string $defecto = null): string
    {
        $valor = $this->valores[$clave] ?? $defecto;
        if ($valor === null) {
            throw new \RuntimeException("Falta la variable de configuración {$clave}");
        }

        return $valor;
    }

    public function entero(string $clave, int $defecto): int
    {
        return isset($this->valores[$clave]) ? (int) $this->valores[$clave] : $defecto;
    }

    public function booleano(string $clave, bool $defecto): bool
    {
        if (!isset($this->valores[$clave])) {
            return $defecto;
        }

        return in_array(strtolower($this->valores[$clave]), ['1', 'true', 'si', 'sí', 'yes', 'on'], true);
    }
}
