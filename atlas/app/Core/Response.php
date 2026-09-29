<?php

declare(strict_types=1);

namespace Atlas\Core;

/**
 * Respuesta HTTP. La API siempre responde JSON (PDF §25.2).
 */
final class Response
{
    /** @param array<string, string> $cabeceras */
    public function __construct(
        public readonly int $estado = 200,
        public readonly mixed $datos = null,
        public readonly array $cabeceras = []
    ) {
    }

    public static function json(mixed $datos, int $estado = 200): self
    {
        return new self($estado, $datos);
    }

    public static function creado(mixed $datos): self
    {
        return new self(201, $datos);
    }

    public static function sinContenido(): self
    {
        return new self(204);
    }

    public function cuerpo(): string
    {
        if ($this->estado === 204) {
            return '';
        }

        return (string) json_encode(
            $this->datos,
            JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION | JSON_THROW_ON_ERROR
        );
    }

    public function enviar(): void
    {
        http_response_code($this->estado);
        header('Content-Type: application/json; charset=utf-8');
        header('X-Content-Type-Options: nosniff');
        header('Cache-Control: no-store');
        foreach ($this->cabeceras as $nombre => $valor) {
            header("{$nombre}: {$valor}");
        }
        echo $this->cuerpo();
    }
}
