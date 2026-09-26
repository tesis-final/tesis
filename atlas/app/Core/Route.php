<?php

declare(strict_types=1);

namespace Atlas\Core;

/**
 * Definición de una ruta: qué controlador la atiende y qué exige la cadena
 * de middleware (autenticación, permiso y reglas de validación).
 */
final class Route
{
    private string $patron;

    /**
     * @param array{0: class-string, 1: string} $manejador
     * @param array<string, string>             $reglas reglas del Validador
     */
    public function __construct(
        public readonly string $metodo,
        public readonly string $ruta,
        public readonly array $manejador,
        public readonly bool $requiereSesion = true,
        public readonly ?string $permiso = null,
        public readonly array $reglas = [],
        public readonly ?string $accionAuditoria = null,
        public readonly bool $auditar = true
    ) {
        $this->patron = '#^' . preg_replace('#\{(\w+)\}#', '(?P<$1>[^/]+)', $ruta) . '$#';
    }

    /** @return array<string, string>|null parámetros si coincide */
    public function coincide(string $metodo, string $ruta): ?array
    {
        if ($metodo !== $this->metodo || !preg_match($this->patron, $ruta, $m)) {
            return null;
        }

        return array_filter($m, 'is_string', ARRAY_FILTER_USE_KEY);
    }
}
