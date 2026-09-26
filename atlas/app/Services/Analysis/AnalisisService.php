<?php

declare(strict_types=1);

namespace Atlas\Services\Analysis;

use Atlas\Repositories\AnalisisRepository;
use DateTimeImmutable;
use DateTimeZone;

/**
 * Motor de análisis Nivel 1 (PHP, PDF §25.4; DEC-11, DEC-23).
 *
 * Tras cada intento finalizado (H18):
 *  1. calcula puntaje, mejora, persistencia y eficiencia de la actividad;
 *  2. los guarda en el perfil del período (RF-10);
 *  3. evalúa las reglas activas guardadas en la BD;
 *  4. genera recomendaciones de actividades con la regla, su versión y los datos
 *     exactos que las dispararon (RF-12, H20: "¿por qué ATLAS recomienda esto?").
 * Las reglas que sugieren lo mismo se agrupan en una sola recomendación (N:M).
 */
final class AnalisisService
{
    public function __construct(private readonly AnalisisRepository $repo)
    {
    }

    /** @return array{indicadores: array<string, mixed>|null, recomendaciones: list<int>} */
    public function procesarIntento(int $intentoId): array
    {
        $ctx = $this->repo->contextoIntento($intentoId);
        $estudiante = (int) $ctx['usuario_id'];
        $actividad = (int) $ctx['actividad_id'];
        $grupo = $this->repo->duracionGrupo($estudiante, $actividad);
        $valores = Indicadores::calcular(
            $this->repo->intentosDeActividad($estudiante, $actividad),
            $grupo['media'],
            $grupo['n']
        );
        if ($valores === null) {
            return ['indicadores' => null, 'recomendaciones' => []];
        }

        $periodo = Periodo::mesDe(new DateTimeImmutable($ctx['finalizado_en'], new DateTimeZone('UTC')));
        $perfil = $this->repo->perfil($estudiante, $periodo->desde, $periodo->hasta);
        foreach (
            [
            'puntaje' => 'PUNTAJE',
            'mejora' => 'MEJORA',
            'persistencia' => 'PERSISTENCIA',
            'eficiencia' => 'EFICIENCIA'
            ] as $clave => $tipo
        ) {
            if ($valores[$clave] !== null) {
                $this->repo->guardarIndicador($perfil, $actividad, $tipo, (float) $valores[$clave]);
            }
        }

        $contexto = $valores + $this->repo->agregadosCategoria(
            $estudiante,
            (int) $ctx['categoria_id'],
            $periodo->desde,
            $periodo->hasta
        );
        $disparadas = MotorReglas::evaluar($this->repo->reglasActivas(), $contexto);

        // Agrupar por sugerencia idéntica: una recomendación puede venir de varias reglas.
        $porSugerencia = [];
        foreach ($disparadas as $d) {
            $porSugerencia[json_encode($d['regla']['sugerencia'])][] = $d;
        }

        $ids = [];
        foreach ($porSugerencia as $grupoReglas) {
            $sugerencia = $grupoReglas[0]['regla']['sugerencia'];
            [$actividadSugerida, $nota] = $this->elegirActividad($sugerencia, $estudiante, $ctx);
            $texto = implode(' ', array_map(fn ($d) => $d['regla']['recomendacion_plantilla'], $grupoReglas));
            $texto .= $actividadSugerida !== null
                ? ' Actividad sugerida: «' . $this->repo->tituloActividad($actividadSugerida) . '».'
                : ' ' . $nota;
            $rec = $this->repo->crearRecomendacion($perfil, $actividadSugerida, $texto);
            foreach ($grupoReglas as $d) {
                $this->repo->vincularRegla($rec, $d['regla']['id'], $d['regla']['version'], [
                    'intento_id' => $intentoId,
                    'actividad_id' => $actividad,
                    'periodo' => [$periodo->desde, $periodo->hasta],
                    'condicion' => $d['regla']['condicion'],
                    'valores' => $d['valores'],
                ]);
            }
            $ids[] = $rec;
        }

        return ['indicadores' => $valores, 'recomendaciones' => $ids];
    }

    /**
     * @param array<string, mixed> $sugerencia
     * @param array<string, mixed> $ctx
     * @return array{0: int|null, 1: string}
     */
    private function elegirActividad(array $sugerencia, int $estudiante, array $ctx): array
    {
        if (($sugerencia['actividad'] ?? null) === 'misma') {
            return [(int) $ctx['actividad_id'], ''];
        }
        $orden = (int) $ctx['nivel_orden'] + match ($sugerencia['nivel'] ?? 'mismo') {
            'siguiente' => 1,
            'inferior' => -1,
            default => 0,
        };
        if (!$this->repo->existeNivel($orden)) {
            return [
                null,
                'No existe un nivel ' . ($sugerencia['nivel'] ?? '') . ' para esta categoría; mantener el nivel actual.'
            ];
        }
        $id = $this->repo->actividadSugerida(
            $estudiante,
            (int) $ctx['categoria_id'],
            $orden,
            (int) $ctx['actividad_id']
        );

        return $id !== null
            ? [$id, '']
            : [
                null,
                'Todavía no hay una actividad publicada de esa categoría y nivel: conviene crear una (falta contenido).'
            ];
    }
}
