<?php

declare(strict_types=1);

namespace Atlas\Core;

/**
 * Validación declarativa de la cadena de middleware (paso [3], 422).
 * Reglas separadas por "|": requerido, opcional, texto, max:N, min:N,
 * entero, positivo, numero, booleano, correo, en:a,b,c, lista, fecha, fechahora.
 */
final class Validator
{
    /**
     * @param array<string, mixed>  $datos
     * @param array<string, string> $reglas
     * @return array{0: array<string, mixed>, 1: array<string, string>} [válidos, errores]
     */
    public static function validar(array $datos, array $reglas): array
    {
        $validos = [];
        $errores = [];
        foreach ($reglas as $campo => $definicion) {
            $partes = explode('|', $definicion);
            $presente = array_key_exists($campo, $datos) && $datos[$campo] !== null && $datos[$campo] !== '';
            if (!$presente) {
                if (in_array('requerido', $partes, true)) {
                    $errores[$campo] = 'Es obligatorio.';
                }
                continue;
            }
            // Se recortan los espacios antes de validar (" ana@x.uy " es un correo válido).
            $valor = is_string($datos[$campo]) ? trim($datos[$campo]) : $datos[$campo];
            foreach ($partes as $regla) {
                [$nombre, $arg] = array_pad(explode(':', $regla, 2), 2, null);
                $error = self::aplicar($nombre, $arg, $valor);
                if ($error !== null) {
                    $errores[$campo] = $error;
                    continue 2;
                }
            }
            $validos[$campo] = self::normalizar($partes, $valor);
        }

        return [$validos, $errores];
    }

    private static function aplicar(string $regla, ?string $arg, mixed &$valor): ?string
    {
        return match ($regla) {
            'requerido', 'opcional' => null,
            'texto' => is_string($valor) && trim($valor) !== '' ? null : 'Debe ser un texto no vacío.',
            'max' => (is_string($valor) ? mb_strlen($valor) : (is_array($valor) ? count($valor) : $valor)) <= (int) $arg
                ? null : "Supera el máximo de {$arg}.",
            'min' => (is_string($valor) ? mb_strlen($valor) : (is_array($valor) ? count($valor) : $valor)) >= (int) $arg
                ? null : "Debe ser al menos {$arg}.",
            'entero' => filter_var($valor, FILTER_VALIDATE_INT) !== false ? null : 'Debe ser un número entero.',
            'positivo' => (int) $valor > 0 ? null : 'Debe ser mayor que cero.',
            'numero' => is_numeric($valor) ? null : 'Debe ser un número.',
            'booleano' => is_bool($valor) || in_array(
                $valor,
                [0, 1, '0', '1'],
                true
            ) ? null : 'Debe ser verdadero o falso.',
            'correo' => filter_var($valor, FILTER_VALIDATE_EMAIL) !== false ? null : 'No es un correo válido.',
            'en' => in_array((string) $valor, explode(',', (string) $arg), true) ? null : 'Valor no permitido.',
            'lista' => is_array($valor) && array_is_list($valor) ? null : 'Debe ser una lista.',
            'fecha' => self::esFecha($valor, 'Y-m-d') ? null : 'Debe ser una fecha AAAA-MM-DD.',
            'fechahora' => is_string($valor) && strtotime($valor) !== false
                ? null : 'Debe ser una fecha y hora válida.',
            default => throw new \LogicException("Regla de validación desconocida: {$regla}"),
        };
    }

    /** @param list<string> $partes */
    private static function normalizar(array $partes, mixed $valor): mixed
    {
        if (in_array('entero', $partes, true)) {
            return (int) $valor;
        }
        if (in_array('numero', $partes, true)) {
            return (float) $valor;
        }
        if (in_array('booleano', $partes, true)) {
            return (bool) $valor;
        }
        if (in_array('correo', $partes, true)) {
            return mb_strtolower(trim((string) $valor));
        }

        return is_string($valor) ? trim($valor) : $valor;
    }

    private static function esFecha(mixed $valor, string $formato): bool
    {
        if (!is_string($valor)) {
            return false;
        }
        $d = \DateTimeImmutable::createFromFormat('!' . $formato, $valor);

        return $d !== false && $d->format($formato) === $valor;
    }
}
