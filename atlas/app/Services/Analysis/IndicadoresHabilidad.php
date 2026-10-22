<?php

declare(strict_types=1);

namespace Atlas\Services\Analysis;

/**
 * Indicadores por habilidad (acta D-3, devolución 4.a): de las preguntas que miden
 * cada habilidad, qué porcentaje se acertó. Se toma el último intento finalizado de
 * cada actividad; una pregunta sin responder cuenta como error (igual que el puntaje).
 * Solo describe aciertos (D-8): no se concluye nada sobre memoria ni atención.
 * Función pura: mismos datos → mismo resultado.
 */
final class IndicadoresHabilidad
{
    /** Por debajo de este porcentaje de acierto la habilidad se marca "a reforzar" (mismo umbral que R01). */
    public const UMBRAL_REFUERZO = 50.0;

    /**
     * @param list<array{usuario_id: int, codigo: string, nombre: string, acerto: bool}> $filas
     *        una fila por (pregunta respondida o no, habilidad que mide)
     * @return list<array{codigo: string, nombre: string, preguntas: int, correctas: int, porcentaje: float,
     *                    a_reforzar: bool, estudiantes: int, estudiantes_bajo_umbral: int}>
     *         ordenadas de la más débil a la más fuerte
     */
    public static function calcular(array $filas): array
    {
        $porHabilidad = [];
        foreach ($filas as $f) {
            $h = &$porHabilidad[$f['codigo']];
            $h ??= ['codigo' => $f['codigo'], 'nombre' => $f['nombre'], 'preguntas' => 0, 'correctas' => 0,
                'por' => []];
            $h['preguntas']++;
            $h['correctas'] += (int) $f['acerto'];
            $e = &$h['por'][$f['usuario_id']];
            $e ??= [0, 0];
            $e[0]++;
            $e[1] += (int) $f['acerto'];
            unset($h, $e);
        }
        $salida = [];
        foreach ($porHabilidad as $h) {
            $porcentaje = round($h['correctas'] * 100 / $h['preguntas'], 2);
            $bajo = count(array_filter(
                $h['por'],
                fn ($e) => $e[1] * 100 / $e[0] < self::UMBRAL_REFUERZO
            ));
            $salida[] = [
                'codigo' => $h['codigo'],
                'nombre' => $h['nombre'],
                'preguntas' => $h['preguntas'],
                'correctas' => $h['correctas'],
                'porcentaje' => $porcentaje,
                'a_reforzar' => $porcentaje < self::UMBRAL_REFUERZO,
                'estudiantes' => count($h['por']),
                'estudiantes_bajo_umbral' => $bajo,
            ];
        }
        usort($salida, fn ($a, $b) => [$a['porcentaje'], $a['codigo']] <=> [$b['porcentaje'], $b['codigo']]);

        return $salida;
    }
}
