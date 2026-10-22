<?php

declare(strict_types=1);

namespace Atlas\Services\Analysis;

/**
 * Agregados del análisis grupal (RF-18, H26; D-4): n, promedio, mediana, mínimo
 * y máximo de los puntajes. Antes los calculaba sp_analisis_grupal en MySQL; ahora
 * los calcula PHP y la base solo guarda el resultado en `analisis_grupal`.
 * Función pura: mismos puntajes → mismo resumen.
 */
final class ResumenGrupal
{
    /**
     * @param list<array{usuario_id: int, puntaje: float}> $filas último intento
     *        finalizado de cada estudiante en cada actividad del período
     * @return array{n_estudiantes: int, promedio: float|null, mediana: float|null,
     *               minimo: float|null, maximo: float|null}
     */
    public static function calcular(array $filas): array
    {
        $puntajes = array_map(fn ($f) => (float) $f['puntaje'], $filas);
        $n = count($puntajes);
        $estudiantes = count(array_unique(array_map(fn ($f) => (int) $f['usuario_id'], $filas)));
        if ($n === 0) {
            return ['n_estudiantes' => 0, 'promedio' => null, 'mediana' => null, 'minimo' => null, 'maximo' => null];
        }
        sort($puntajes);

        return [
            'n_estudiantes' => $estudiantes,
            'promedio' => round(array_sum($puntajes) / $n, 2),
            'mediana' => self::mediana($puntajes),
            'minimo' => round($puntajes[0], 2),
            'maximo' => round($puntajes[$n - 1], 2),
        ];
    }

    /** @param list<float> $ordenados de menor a mayor, no vacía */
    public static function mediana(array $ordenados): float
    {
        $n = count($ordenados);
        $medio = intdiv($n, 2);

        return round($n % 2 === 1 ? $ordenados[$medio] : ($ordenados[$medio - 1] + $ordenados[$medio]) / 2, 2);
    }
}
