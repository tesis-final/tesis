<?php

declare(strict_types=1);

namespace Atlas\Services\Analysis;

/**
 * Intérprete de las reglas si-entonces guardadas en `reglas_analisis` (PDF §25.4, §27.3).
 *
 * Formato de la condición: {"todas": [{"indicador"|"agregado": nombre, "op": "<", "valor": 50}, ...]}.
 * Todas las comparaciones deben cumplirse. Si falta un dato (por ejemplo, eficiencia
 * sin media de grupo), la comparación no se cumple y queda anotada como "sin dato".
 * Es determinista y devuelve exactamente qué valores se usaron (trazabilidad, H20).
 */
final class MotorReglas
{
    public const INDICADORES = ['puntaje', 'eficiencia', 'mejora', 'persistencia'];
    public const AGREGADOS = ['puntaje_medio_categoria', 'actividades_categoria'];
    public const OPERADORES = ['<', '<=', '>', '>=', '=', '!='];

    /**
     * @param list<array<string, mixed>> $reglas filas activas de reglas_analisis (condicion decodificada)
     * @param array<string, float|int|null> $contexto valores de indicadores y agregados
     * @return list<array{regla: array<string, mixed>, valores: array<string, mixed>}>
     */
    public static function evaluar(array $reglas, array $contexto): array
    {
        $disparadas = [];
        foreach ($reglas as $regla) {
            $resultado = self::evaluarRegla($regla['condicion'], $contexto);
            if ($resultado['cumple']) {
                $disparadas[] = ['regla' => $regla, 'valores' => $resultado['valores']];
            }
        }

        return $disparadas;
    }

    /**
     * @param array<string, mixed>          $condicion
     * @param array<string, float|int|null> $contexto
     * @return array{cumple: bool, valores: array<string, mixed>}
     */
    public static function evaluarRegla(array $condicion, array $contexto): array
    {
        $valores = [];
        $cumple = true;
        foreach ($condicion['todas'] ?? [] as $c) {
            $nombre = $c['indicador'] ?? $c['agregado'];
            $actual = $contexto[$nombre] ?? null;
            $valores[$nombre] = $actual;
            if ($actual === null) {
                $cumple = false;
                $valores['sin_dato'][] = $nombre;
                continue;
            }
            if (!self::comparar((float) $actual, $c['op'], (float) $c['valor'])) {
                $cumple = false;
            }
        }

        return ['cumple' => $cumple && !empty($condicion['todas']), 'valores' => $valores];
    }

    /**
     * Valida la estructura de una condición antes de guardarla (edición por el administrador).
     *
     * @param mixed $condicion
     * @return list<string> errores
     */
    public static function validarCondicion(mixed $condicion): array
    {
        if (
            !is_array($condicion) || !isset($condicion['todas']) || !is_array($condicion['todas'])
            || $condicion['todas'] === [] || count($condicion) !== 1
        ) {
            return ['La condición debe ser {"todas": [ ... ]} con al menos una comparación.'];
        }
        $errores = [];
        foreach ($condicion['todas'] as $i => $c) {
            $clave = isset($c['indicador']) ? 'indicador' : (isset($c['agregado']) ? 'agregado' : null);
            $permitidos = $clave === 'indicador' ? self::INDICADORES : self::AGREGADOS;
            if ($clave === null || !in_array($c[$clave], $permitidos, true)) {
                $errores[] = "Comparación {$i}: indicador o agregado no reconocido.";
            }
            if (!in_array($c['op'] ?? null, self::OPERADORES, true)) {
                $errores[] = "Comparación {$i}: operador no permitido.";
            }
            if (!isset($c['valor']) || !is_numeric($c['valor'])) {
                $errores[] = "Comparación {$i}: el valor debe ser numérico.";
            }
            if (count($c) !== 3) {
                $errores[] = "Comparación {$i}: solo se admiten las claves indicador/agregado, op y valor.";
            }
        }

        return $errores;
    }

    private static function comparar(float $a, string $op, float $b): bool
    {
        $epsilon = 1e-9;

        return match ($op) {
            '<' => $a < $b - $epsilon,
            '<=' => $a <= $b + $epsilon,
            '>' => $a > $b + $epsilon,
            '>=' => $a >= $b - $epsilon,
            '=' => abs($a - $b) <= $epsilon,
            '!=' => abs($a - $b) > $epsilon,
            default => throw new \InvalidArgumentException("Operador no permitido: {$op}"),
        };
    }
}
