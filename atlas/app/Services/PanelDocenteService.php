<?php

declare(strict_types=1);

namespace Atlas\Services;

use Atlas\Core\Clock;
use Atlas\Core\HttpException;
use Atlas\Repositories\AnalisisRepository;
use Atlas\Repositories\OrganizacionRepository;
use Atlas\Repositories\ReporteRepository;
use Atlas\Services\Analysis\IndicadoresHabilidad;
use Atlas\Services\Analysis\Periodo;
use Atlas\Services\Analysis\ResumenGrupal;

/**
 * Panel docente (RF-11, RF-12, RF-13, RF-18; §20.4; H.2.3).
 *
 * La vista principal es grupal y responde "¿dónde intervengo hoy?": primero los
 * estudiantes que requieren atención prioritaria (reglas de RIESGO, explicables),
 * después las preguntas con más error y recién después los agregados. El docente
 * solo accede a sus propios grupos.
 */
final class PanelDocenteService
{
    public function __construct(
        private readonly OrganizacionRepository $organizacion,
        private readonly AnalisisRepository $analisis,
        private readonly ReporteRepository $reportes,
        private readonly AnalisisClient $cliente,
        private readonly Clock $reloj
    ) {
    }

    /** @return array<string, mixed> */
    public function analisisGrupal(array $usuario, int $grupo, ?int $actividad, ?string $desde, ?string $hasta): array
    {
        $this->exigirGrupo($usuario, $grupo);
        $periodo = Periodo::desdeTexto($desde, $hasta, $this->reloj->ahora());
        $estudiantes = $this->organizacion->miembros($grupo, 'ESTUDIANTE');
        $nombres = [];
        foreach ($estudiantes as $e) {
            $nombres[(int) $e['id']] = $e['nombre'] . ' ' . $e['apellido'];
        }

        // Atención prioritaria (DEC-23): ≥ 1 regla de RIESGO en el período.
        $prioritarios = [];
        foreach ($this->reportes->riesgoEnPeriodo(array_keys($nombres), $periodo->desde, $periodo->hasta) as $f) {
            $id = (int) $f['estudiante_id'];
            $p = &$prioritarios[$id];
            $p ??= [
                'estudiante_id' => $id,
                'nombre' => $nombres[$id],
                'reglas' => [],
                'recomendaciones' => [],
                'ultima' => $f['generado_en']
            ];
            $p['reglas'][$f['regla_codigo']] = $f['regla_nombre'];
            $p['recomendaciones'][] = (int) $f['recomendacion_id'];
            unset($p);
        }
        $prioritarios = array_values(array_map(function ($p) {
            $p['motivo'] = implode(
                ' · ',
                array_map(fn ($c, $n) => "{$c} {$n}", array_keys($p['reglas']), $p['reglas'])
            );
            $p['cantidad_reglas'] = count($p['reglas']);
            $p['reglas'] = array_keys($p['reglas']);
            $p['recomendaciones'] = array_values(array_unique($p['recomendaciones']));

            return $p;
        }, $prioritarios));
        usort(
            $prioritarios,
            fn ($a, $b) => [$b['cantidad_reglas'], $b['ultima']] <=> [$a['cantidad_reglas'], $a['ultima']]
        );

        // RF-18 (D-4): los agregados se calculan en PHP y la base solo guarda el historial.
        if ($periodo->hasta < $periodo->desde) {
            throw HttpException::conflicto('período inválido');
        }
        $agregados = ResumenGrupal::calcular(
            $this->reportes->ultimosPuntajes($grupo, $actividad, $periodo->desde, $periodo->hasta)
        );
        $this->reportes->guardarAnalisisGrupal($grupo, $actividad, $periodo->desde, $periodo->hasta, $agregados);

        return [
            'grupo' => $this->organizacion->grupo($grupo),
            'periodo' => ['desde' => $periodo->desde, 'hasta' => $periodo->hasta],
            'estudiantes' => count($estudiantes),
            'prioritarios' => $prioritarios,
            'preguntas_con_mas_error' => $this->reportes->preguntasConMasError($grupo, $actividad),
            'agregados' => [
                'n_estudiantes' => (int) ($agregados['n_estudiantes'] ?? 0),
                'promedio' => isset($agregados['promedio']) ? (float) $agregados['promedio'] : null,
                'mediana' => isset($agregados['mediana']) ? (float) $agregados['mediana'] : null,
                'minimo' => isset($agregados['minimo']) ? (float) $agregados['minimo'] : null,
                'maximo' => isset($agregados['maximo']) ? (float) $agregados['maximo'] : null,
            ],
            'distribucion' => $this->reportes->distribucion($grupo, $actividad),
            // D-3: acierto por habilidad del grupo, de la más débil a la más fuerte.
            'habilidades' => IndicadoresHabilidad::calcular($this->reportes->aciertosPorHabilidad(
                array_keys($nombres),
                $periodo->desde,
                $periodo->hasta,
                $grupo
            )),
            'aprendizaje_automatico' => $this->estadoNivel2($grupo, $periodo, $nombres),
        ];
    }

    /** @return array<string, mixed> */
    public function perfilEstudiante(array $usuario, int $estudiante, ?string $desde): array
    {
        $this->exigirEstudiante($usuario, $estudiante);
        $periodo = Periodo::desdeTexto(
            $desde,
            $desde !== null ? (new \DateTimeImmutable($desde))->format('Y-m-t') : null,
            $this->reloj->ahora()
        );
        $perfil = $this->analisis->perfilDe($estudiante, $periodo->desde);
        $grupos = array_values(array_intersect(
            $this->organizacion->gruposDelUsuario($estudiante),
            $usuario['rol'] === 'ADMIN'
                ? $this->organizacion->gruposDelUsuario($estudiante)
                : $this->organizacion->gruposDelUsuario($usuario['id'])
        ));

        return [
            'estudiante_id' => $estudiante,
            'periodo' => ['desde' => $periodo->desde, 'hasta' => $periodo->hasta],
            'indicadores' => $perfil ? $this->analisis->indicadoresDelPerfil((int) $perfil['id']) : [],
            'habilidades' => IndicadoresHabilidad::calcular(
                $this->reportes->aciertosPorHabilidad([$estudiante], $periodo->desde, $periodo->hasta)
            ),
            'nivel2' => $perfil ? $this->analisis->indicadoresNivel2((int) $perfil['id']) : [],
            'recomendaciones' => $perfil ? $this->analisis->recomendacionesDelPerfil((int) $perfil['id']) : [],
            'evolucion' => $grupos === [] ? [] : $this->reportes->evolucion($estudiante, $grupos[0]),
            'aviso' => 'Los indicadores describen el proceso de resolución; '
                . 'no diagnostican ni etiquetan al estudiante.',
        ];
    }

    /** "¿Por qué ATLAS recomienda esto?" (RF-12, H20). @return array<string, mixed> */
    public function fundamento(array $usuario, int $recomendacion): array
    {
        $rec = $this->analisis->recomendacion($recomendacion)
            ?? throw HttpException::noEncontrado('Recomendación no encontrada.');
        $this->exigirEstudiante($usuario, (int) $rec['estudiante_id']);
        $rec['reglas'] = $this->analisis->fundamento($recomendacion);

        return $rec;
    }

    /** @return array<string, mixed> */
    public function reporte(array $usuario, ?int $grupo, ?int $actividad, ?string $desde, ?string $hasta): array
    {
        $permitidos = $usuario['rol'] === 'ADMIN' ? null : $this->organizacion->gruposDelUsuario($usuario['id']);
        if ($grupo !== null && $permitidos !== null && !in_array($grupo, $permitidos, true)) {
            throw HttpException::prohibido('Solo puede consultar reportes de sus propios grupos.');
        }

        return $this->reportes->resultados($permitidos, $grupo, $actividad, $desde, $hasta)
            + ['filtros' => compact('grupo', 'actividad', 'desde', 'hasta')];
    }

    /** @param array<int, string> $nombres @return array<string, mixed> */
    private function estadoNivel2(int $grupo, Periodo $periodo, array $nombres): array
    {
        $agrupamiento = $this->reportes->agrupamiento($grupo, $periodo->desde);
        $estado = $this->cliente->estadoGrupo($grupo, $periodo->desde, $periodo->hasta);
        if ($agrupamiento !== null) {
            foreach ($agrupamiento['miembros'] as &$m) {
                $m['nombre'] = $nombres[(int) $m['estudiante_id']] ?? null;
            }
        }

        return [
            'servicio_disponible' => $estado !== null,
            'suficiencia' => $estado['suficiencia'] ?? null,
            'agrupamiento' => $agrupamiento,
            'aviso' => 'Estimación estadística sobre patrones de resolución; no es un diagnóstico.',
        ];
    }

    private function exigirGrupo(array $usuario, int $grupo): void
    {
        if ($this->organizacion->grupo($grupo) === null) {
            throw HttpException::noEncontrado('Grupo no encontrado.');
        }
        if ($usuario['rol'] !== 'ADMIN' && !$this->organizacion->perteneceAGrupo($usuario['id'], $grupo)) {
            throw HttpException::prohibido('Solo puede consultar sus propios grupos.');
        }
    }

    private function exigirEstudiante(array $usuario, int $estudiante): void
    {
        if (
            $usuario['rol'] !== 'ADMIN' && !$this->organizacion->docenteTieneAlEstudiante(
                $usuario['id'],
                $estudiante
            )
        ) {
            throw HttpException::prohibido('El estudiante no pertenece a sus grupos.');
        }
    }
}
