<?php

declare(strict_types=1);

namespace Atlas\Services\Analysis;

/**
 * Los cuatro indicadores del Nivel 1 (PDF §25.4; fórmula de eficiencia aprobada en DEC-23).
 * Funciones puras: mismos datos → mismo resultado (determinismo, §25.4).
 */
final class Indicadores
{
    public const MINIMO_INTENTOS_GRUPO = 3;
    public const EFICIENCIA_MAXIMA = 5.0;

    /**
     * @param list<array{numero: int, estado: string, puntaje: float|null, duracion_seg: int|null}> $intentos
     *        todos los intentos del estudiante en la actividad
     * @param float|null $duracionMediaGrupo media de duración (s) de los intentos finalizados del grupo
     * @param int        $intentosGrupo      cantidad de intentos finalizados del grupo en la actividad
     * @return array{puntaje: float, mejora: float, persistencia: int, eficiencia: float|null}|null
     *         null si no hay intentos finalizados
     */
    public static function calcular(array $intentos, ?float $duracionMediaGrupo, int $intentosGrupo): ?array
    {
        usort($intentos, fn ($a, $b) => $a['numero'] <=> $b['numero']);
        $finalizados = array_values(array_filter(
            $intentos,
            fn ($i) => $i['estado'] === 'FINALIZADO' && $i['puntaje'] !== null
        ));
        if ($finalizados === []) {
            return null;
        }
        $primero = $finalizados[0];
        $ultimo = $finalizados[count($finalizados) - 1];

        // Puntaje: correctas / total × 100 del último intento (ya calculado por el trigger).
        $puntaje = (float) $ultimo['puntaje'];
        // Mejora: último − primero.
        $mejora = round($puntaje - (float) $primero['puntaje'], 2);
        // Persistencia: intentos (finalizados y abandonados) hasta el último finalizado.
        $persistencia = count(array_filter($intentos, fn ($i) => $i['numero'] <= $ultimo['numero']));

        return [
            'puntaje' => $puntaje,
            'mejora' => $mejora,
            'persistencia' => $persistencia,
            'eficiencia' => self::eficiencia($puntaje, $ultimo['duracion_seg'], $duracionMediaGrupo, $intentosGrupo),
        ];
    }

    /**
     * Eficiencia = (puntaje / 100) ÷ (duración propia / duración media del grupo), acotada a [0, 5].
     * Sin valor si el grupo tiene menos de 3 intentos finalizados (no se inventa una media).
     */
    public static function eficiencia(float $puntaje, ?int $duracion, ?float $media, int $intentosGrupo): ?float
    {
        if (
            $intentosGrupo < self::MINIMO_INTENTOS_GRUPO || $media === null || $media <= 0
            || $duracion === null || $duracion <= 0
        ) {
            return null;
        }
        $valor = ($puntaje / 100) / ($duracion / $media);

        return round(max(0.0, min(self::EFICIENCIA_MAXIMA, $valor)), 4);
    }
}
