<?php

declare(strict_types=1);

namespace Atlas\Core;

/**
 * Petición HTTP normalizada. Los atributos los completan el ruteo y el
 * middleware (usuario autenticado, parámetros de ruta, datos validados).
 */
final class Request
{
    /** @var array<string, mixed> */
    private array $atributos = [];

    /**
     * @param array<string, string> $query
     * @param array<string, mixed>  $cuerpo
     * @param array<string, string> $cabeceras claves en minúsculas
     */
    public function __construct(
        public readonly string $metodo,
        public readonly string $ruta,
        public readonly array $query = [],
        public readonly array $cuerpo = [],
        public readonly array $cabeceras = [],
        public readonly string $ip = ''
    ) {
    }

    public static function desdeGlobales(): self
    {
        $ruta = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
        $crudo = file_get_contents('php://input') ?: '';
        $cuerpo = [];
        if ($crudo !== '') {
            $decodificado = json_decode($crudo, true);
            $cuerpo = is_array($decodificado) ? $decodificado : [];
        }
        $cabeceras = [];
        foreach ($_SERVER as $clave => $valor) {
            if (str_starts_with($clave, 'HTTP_')) {
                $cabeceras[strtolower(str_replace('_', '-', substr($clave, 5)))] = (string) $valor;
            }
        }
        if (isset($_SERVER['CONTENT_TYPE'])) {
            $cabeceras['content-type'] = (string) $_SERVER['CONTENT_TYPE'];
        }

        return new self(
            strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET'),
            rtrim($ruta, '/') ?: '/',
            array_map('strval', $_GET),
            $cuerpo,
            $cabeceras,
            (string) ($_SERVER['REMOTE_ADDR'] ?? '')
        );
    }

    public function cabecera(string $nombre): ?string
    {
        return $this->cabeceras[strtolower($nombre)] ?? null;
    }

    public function con(string $clave, mixed $valor): self
    {
        $this->atributos[$clave] = $valor;

        return $this;
    }

    public function atributo(string $clave, mixed $defecto = null): mixed
    {
        return $this->atributos[$clave] ?? $defecto;
    }

    public function parametro(string $nombre): string
    {
        return (string) ($this->atributos['parametros'][$nombre] ?? '');
    }

    public function parametroEntero(string $nombre): int
    {
        $valor = $this->parametro($nombre);
        if (!ctype_digit($valor)) {
            throw HttpException::noEncontrado();
        }

        return (int) $valor;
    }

    /** @return array<string, mixed> Datos que pasaron la validación. */
    public function validados(): array
    {
        return $this->atributos['validados'] ?? [];
    }
}
