<?php

declare(strict_types=1);

namespace Atlas\Services\Asistente;

use Atlas\Core\Clock;
use Atlas\Repositories\ActividadRepository;
use Atlas\Repositories\AnalisisRepository;
use Atlas\Repositories\ConversacionRepository;
use Atlas\Repositories\OrganizacionRepository;
use Atlas\Repositories\ReporteRepository;
use Atlas\Services\AnalisisClient;
use Atlas\Services\Analysis\Periodo;

/**
 * Asistente conversacional, Nivel 3 (RF-20; PDF §25.4; H28; DEC-24):
 *
 *   BD → datos verificados → indicadores (N1/N2) → contexto anonimizado → LLM → texto → re-identificación
 *
 * El LLM solo redacta: nunca recibe filas crudas ni nombres, y no decide nada.
 * Si el modelo no está disponible, el docente igual recibe los datos verificados (RNF-15).
 */
final class AsistenteService
{
    public function __construct(
        private readonly IntentParser $parser,
        private readonly OrganizacionRepository $organizacion,
        private readonly ActividadRepository $actividades,
        private readonly AnalisisRepository $analisis,
        private readonly ReporteRepository $reportes,
        private readonly ConversacionRepository $conversaciones,
        private readonly AnalisisClient $cliente,
        private readonly Clock $reloj
    ) {
    }

    /** @return array<string, mixed> */
    public function consultar(array $docente, string $pregunta): array
    {
        $grupos = $this->organizacion->grupos($docente['id']);
        $estudiantes = [];
        foreach ($grupos as $g) {
            foreach ($this->organizacion->miembros((int) $g['id'], 'ESTUDIANTE') as $e) {
                $estudiantes[(int) $e['id']] = $e + ['grupo_id' => (int) $g['id']];
            }
        }
        $consulta = $this->parser->interpretar(
            $pregunta,
            array_map(fn ($g) => ['id' => (int) $g['id'], 'nombre' => $g['nombre']], $grupos),
            array_values(array_map(
                fn ($e) => ['id' => (int) $e['id'], 'nombre' => $e['nombre'], 'apellido' => $e['apellido']],
                $estudiantes
            )),
            $this->actividades->catalogo('categorias')
        );

        $anon = new Anonimizador();
        foreach ($estudiantes as $e) {
            $anon->conocer($e['nombre'] . ' ' . $e['apellido'], $e['nombre'], $e['apellido']);
        }
        foreach ($grupos as $g) {
            $anon->grupo((int) $g['id'], $g['nombre']);
        }

        $datos = match ($consulta->tipo) {
            Consulta::ESTADO_GRUPO => $this->datosEstadoGrupo($consulta, $grupos, $anon),
            Consulta::DIFICULTAD => $this->datosDificultad($consulta, $grupos, $estudiantes, $anon),
            Consulta::EXPLICAR_RECOMENDACION => $this->datosExplicacion(
                $consulta,
                $estudiantes[$consulta->estudianteId],
                $anon
            ),
            default => null,
        };

        if ($datos === null) {
            $respuesta = 'No pude interpretar la consulta. Puede preguntar, por ejemplo: '
                . '"¿Cómo viene el grupo 3A en resolución de problemas?", '
                . '"¿Qué estudiantes tuvieron más dificultad esta semana?" o '
                . '"Explicame por qué ATLAS recomienda esto para Juan".';
            $id = $this->conversaciones->guardar(
                $docente['id'],
                $pregunta,
                Consulta::NO_RECONOCIDA,
                null,
                $respuesta,
                'NO_RECONOCIDA'
            );

            return [
                'id' => $id, 'tipo' => Consulta::NO_RECONOCIDA, 'estado' => 'NO_RECONOCIDA',
                'respuesta' => $respuesta, 'datos' => null, 'contexto_enviado' => null,
            ];
        }

        $preguntaSanitizada = $anon->sanitizar($pregunta);
        $contexto = ['tipo' => $consulta->tipo, 'pregunta' => $preguntaSanitizada, 'datos' => $datos['anonimos']];
        $serializado = json_encode($contexto, JSON_UNESCAPED_UNICODE);
        if ($anon->contieneIdentificables((string) $serializado)) {
            // Barrera final: si quedara algo identificable, no se envía nada al exterior.
            $contexto = null;
            $redaccion = null;
        } else {
            $redaccion = $this->cliente->redactar($consulta->tipo, $preguntaSanitizada, $datos['anonimos']);
        }

        if ($redaccion !== null && isset($redaccion['texto']) && is_string($redaccion['texto'])) {
            $respuesta = $anon->reidentificar($redaccion['texto']);
            $estado = 'OK';
        } else {
            $respuesta = 'El asistente de redacción no está disponible en este momento. '
                . 'Estos son los datos verificados de ATLAS: '
                . $anon->reidentificar($datos['resumen']);
            $estado = 'LLM_NO_DISPONIBLE';
        }
        $id = $this->conversaciones->guardar(
            $docente['id'],
            $pregunta,
            $consulta->tipo,
            $contexto,
            $respuesta,
            $estado
        );

        return [
            'id' => $id,
            'tipo' => $consulta->tipo,
            'estado' => $estado,
            'respuesta' => $respuesta,
            'datos' => $datos['verificados'],
            'seudonimos' => $anon->mapa(),
            // Privacidad verificable: exactamente lo que salió hacia el modelo.
            'contexto_enviado' => $contexto,
        ];
    }

    private function periodo(Consulta $c): Periodo
    {
        $ahora = $this->reloj->ahora();

        return $c->periodo === 'semana'
            ? new Periodo($ahora->modify('-6 days')->format('Y-m-d'), $ahora->format('Y-m-d'))
            : Periodo::mesDe($ahora);
    }

    /** @return array{anonimos: array<string, mixed>, verificados: array<string, mixed>, resumen: string}|null */
    private function datosEstadoGrupo(Consulta $c, array $grupos, Anonimizador $anon): ?array
    {
        if ($c->grupoId === null) {
            return null;
        }
        $p = $this->periodo($c);
        $filas = $this->reportes->resultados([$c->grupoId], $c->grupoId, null, $p->desde, $p->hasta)['filas'];
        if ($c->categoria !== null) {
            $filas = array_values(array_filter($filas, fn ($f) => $f['categoria'] === $c->categoria));
        }
        $puntajes = array_map(fn ($f) => (float) $f['puntaje'], $filas);
        $estudiantes = count(array_unique(array_column($filas, 'estudiante_id')));
        $errores = array_map(fn ($q) => [
            'pregunta' => 'Pregunta ' . $q['orden'],
            'proporcion_error' => (float) $q['proporcion_error'],
        ], $this->reportes->preguntasConMasError($c->grupoId, null, $p->desde, $p->hasta, 3));
        $promedio = $puntajes === [] ? null : round(array_sum($puntajes) / count($puntajes), 1);
        $g = $anon->grupo($c->grupoId, $this->nombreGrupo($grupos, $c->grupoId));
        $anonimos = [
            'grupo' => $g,
            'categoria' => $c->categoria,
            'periodo' => [$p->desde, $p->hasta],
            'intentos_finalizados' => count($filas),
            'estudiantes_con_datos' => $estudiantes,
            'puntaje_promedio' => $promedio,
            'puntaje_minimo' => $puntajes === [] ? null : min($puntajes),
            'puntaje_maximo' => $puntajes === [] ? null : max($puntajes),
            'preguntas_con_mas_error' => $errores,
        ];
        $resumen = $promedio === null
            ? "{$g} no tiene intentos finalizados en el período."
            : "{$g}: {$estudiantes} estudiantes con datos, promedio {$promedio} en "
                . count($filas) . ' intentos finalizados.';

        return ['anonimos' => $anonimos, 'verificados' => $anonimos, 'resumen' => $resumen];
    }

    /** @param array<int, array<string, mixed>> $estudiantes @return array<string, mixed>|null */
    private function datosDificultad(Consulta $c, array $grupos, array $estudiantes, Anonimizador $anon): ?array
    {
        $p = $this->periodo($c);
        $ids = array_keys(array_filter(
            $estudiantes,
            fn ($e) => $c->grupoId === null || $e['grupo_id'] === $c->grupoId
        ));
        $porEstudiante = [];
        foreach ($this->reportes->riesgoEnPeriodo($ids, $p->desde, $p->hasta) as $f) {
            $porEstudiante[(int) $f['estudiante_id']][$f['regla_codigo']] = $f['regla_nombre'];
        }
        uasort($porEstudiante, fn ($a, $b) => count($b) <=> count($a));
        $lista = [];
        foreach (array_slice($porEstudiante, 0, 10, true) as $id => $reglas) {
            $e = $estudiantes[$id];
            $lista[] = [
                'estudiante' => $anon->estudiante($id, $e['nombre'], $e['apellido']),
                'reglas_de_riesgo' => array_map(fn ($cod, $nom) => "{$cod} {$nom}", array_keys($reglas), $reglas),
            ];
        }
        $anonimos = [
            'grupo' => $c->grupoId !== null ? $anon->grupo(
                $c->grupoId,
                $this->nombreGrupo($grupos, $c->grupoId)
            ) : 'todos sus grupos',
            'periodo' => [$p->desde, $p->hasta],
            'estudiantes_con_senales_de_riesgo' => $lista,
        ];
        $resumen = $lista === []
            ? 'Ningún estudiante disparó reglas de riesgo en el período.'
            : implode(
                '; ',
                array_map(fn ($x) => $x['estudiante'] . ' (' . implode(', ', $x['reglas_de_riesgo']) . ')', $lista)
            ) . '.';

        return ['anonimos' => $anonimos, 'verificados' => $anonimos, 'resumen' => $resumen];
    }

    /** @param array<string, mixed> $estudiante @return array<string, mixed>|null */
    private function datosExplicacion(Consulta $c, array $estudiante, Anonimizador $anon): ?array
    {
        $e = $anon->estudiante((int) $estudiante['id'], $estudiante['nombre'], $estudiante['apellido']);
        $perfil = $this->analisis->perfilDe((int) $estudiante['id'], Periodo::mesDe($this->reloj->ahora())->desde);
        $recs = $perfil ? $this->analisis->recomendacionesDelPerfil((int) $perfil['id']) : [];
        if ($recs === []) {
            $anonimos = ['estudiante' => $e, 'recomendaciones' => []];

            return [
                'anonimos' => $anonimos,
                'verificados' => $anonimos,
                'resumen' => "{$e} no tiene recomendaciones en el período."
            ];
        }
        // Todas las recomendaciones que produjo el último análisis (mismo intento).
        $fundamentos = [];
        foreach ($recs as $r) {
            $fundamentos[(int) $r['id']] = $this->analisis->fundamento((int) $r['id']);
        }
        $intentoUltimo = $fundamentos[(int) $recs[0]['id']][0]['valores_entrada']['intento_id'] ?? null;
        $ultimas = array_values(array_filter($recs, fn ($r) =>
            ($fundamentos[(int) $r['id']][0]['valores_entrada']['intento_id'] ?? null) === $intentoUltimo));
        $reglas = [];
        foreach ($ultimas as $r) {
            foreach ($fundamentos[(int) $r['id']] as $f) {
                $reglas[] = [
                    'codigo' => $f['codigo'],
                    'nombre' => $f['nombre'],
                    'descripcion' => $f['descripcion'],
                    'version' => (int) $f['version_regla'],
                    'valores' => $f['valores_entrada']['valores'] ?? [],
                ];
            }
        }
        usort($reglas, fn ($a, $b) => strcmp($a['codigo'], $b['codigo']));
        $anonimos = [
            'estudiante' => $e,
            'recomendaciones' => array_map(fn ($r) => ['texto' => $r['texto'], 'fecha' => $r['generado_en']], $ultimas),
            'reglas_que_la_generaron' => $reglas,
        ];
        $resumen = "{$e}: " . implode(' ', array_column($ultimas, 'texto')) . ' Reglas: '
            . implode(', ', array_map(fn ($r) => $r['codigo'] . ' ' . $r['nombre'], $reglas)) . '.';
        $rec = $ultimas[0];

        return [
            'anonimos' => $anonimos,
            'verificados' => $anonimos + ['recomendacion_ids' => array_map(fn ($r) => (int) $r['id'], $ultimas)],
            'resumen' => $resumen
        ];
    }

    private function nombreGrupo(array $grupos, int $id): string
    {
        foreach ($grupos as $g) {
            if ((int) $g['id'] === $id) {
                return $g['nombre'];
            }
        }

        return 'grupo';
    }
}
