<?php

declare(strict_types=1);

namespace Atlas\Http;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Response;

/**
 * Formato único de las respuestas de la API (mismo contrato que antes de la
 * migración a Laravel): JSON sin escapar tildes, nunca en caché del navegador.
 */
final class Json
{
    private const OPCIONES = JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION;
    private const CABECERAS = [
        'Content-Type' => 'application/json; charset=utf-8',
        'Cache-Control' => 'no-store',
        'X-Content-Type-Options' => 'nosniff',
    ];

    public static function ok(mixed $datos, int $estado = 200): JsonResponse
    {
        return new JsonResponse($datos, $estado, self::CABECERAS, self::OPCIONES);
    }

    public static function creado(mixed $datos): JsonResponse
    {
        return self::ok($datos, 201);
    }

    public static function sinContenido(): Response
    {
        return new Response('', 204, self::CABECERAS);
    }

    /** @param array<string, mixed> $detalle */
    public static function error(string $mensaje, int $estado, array $detalle = []): JsonResponse
    {
        return self::ok(['error' => $mensaje] + $detalle, $estado);
    }
}
