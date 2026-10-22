<?php

declare(strict_types=1);

namespace Atlas\Services;

use Atlas\Core\Clock;
use Atlas\Core\Database;
use Atlas\Core\HttpException;
use Atlas\Repositories\ActividadRepository;
use Atlas\Repositories\IntentoRepository;
use Atlas\Services\Analysis\AnalisisService;
use Atlas\Services\Analysis\Indicadores;
use Atlas\Services\Analysis\TiempoActivo;
use DateTimeImmutable;
use DateTimeZone;

/**
 * Resolución de actividades por el estudiante (RF-04, RF-06..RF-09; H14–H17; DEC-23):
 * - cada inicio es un intento distinguible (en curso / finalizado / abandonado);
 * - los eventos (cambio de opción, pausa, navegación…) se guardan con marca temporal
 *   y número de secuencia para reconstruir el proceso;
 * - el tiempo se registra en segundos, total y por pregunta;
 * - al finalizar, en una sola transacción: cierre + resultado (calculado en PHP, D-4) + Nivel 1.
 */
final class IntentoService
{
    public const TIPOS_EVENTO = ['VER_PREGUNTA', 'SELECCION', 'CAMBIO_OPCION', 'PAUSA', 'REANUDA', 'NAVEGACION'];
    public const MINUTOS_ABANDONO = 30;

    public function __construct(
        private readonly IntentoRepository $intentos,
        private readonly ActividadRepository $actividades,
        private readonly AnalisisService $analisis,
        private readonly Database $db,
        private readonly Clock $reloj
    ) {
    }

    /** @return array<string, mixed> intento + actividad sin respuestas correctas */
    public function iniciar(int $estudiante, int $actividad): array
    {
        if (!$this->actividades->visibleParaEstudiante($actividad, $estudiante)) {
            // RF-04: solo actividades publicadas de sus grupos.
            throw HttpException::noEncontrado('Actividad no disponible.');
        }
        $intento = $this->intentos->enCurso($estudiante, $actividad);
        $reanudado = $intento !== null;
        if (!$reanudado) {
            $id = $this->db->transaccion(function () use ($estudiante, $actividad): int {
                $id = $this->intentos->crear($estudiante, $actividad);
                $this->intentos->registrarEvento($id, 1, 'INICIO', null, null, $this->ahora(), null);

                return $id;
            });
            $intento = $this->intentos->obtener($id);
        }
        $detalle = $this->actividades->obtener($actividad);

        return [
            'intento' => $this->publico($intento),
            'reanudado' => $reanudado,
            'actividad' => [
                'id' => (int) $detalle['id'],
                'titulo' => $detalle['titulo'],
                'descripcion' => $detalle['descripcion'],
                'nivel' => $detalle['nivel_nombre'],
                'categoria' => $detalle['categoria_nombre'],
                'preguntas' => $this->actividades->preguntas($actividad, false),
            ],
        ];
    }

    /**
     * @param list<array<string, mixed>> $eventos
     * @return array{recibidos: int, nuevos: int}
     */
    public function registrarEventos(int $intentoId, int $estudiante, array $eventos): array
    {
        $intento = $this->propioEnCurso($intentoId, $estudiante);
        if (count($eventos) > 500) {
            throw HttpException::validacion(['eventos' => 'Máximo 500 eventos por lote.']);
        }
        $nuevos = 0;
        $this->db->transaccion(function () use ($intento, $eventos, &$nuevos): void {
            foreach ($eventos as $i => $e) {
                $this->validarEvento($intento, $e, $i);
                $nuevos += (int) $this->intentos->registrarEvento(
                    (int) $intento['id'],
                    (int) $e['secuencia'],
                    $e['tipo'],
                    isset($e['pregunta_id']) ? (int) $e['pregunta_id'] : null,
                    isset($e['opcion_id']) ? (int) $e['opcion_id'] : null,
                    $this->instante($e['ocurrido_en'] ?? null, $intento['iniciado_en']),
                    isset($e['duracion_ms']) ? max(0, (int) $e['duracion_ms']) : null
                );
            }
        });

        return ['recibidos' => count($eventos), 'nuevos' => $nuevos];
    }

    public function responder(int $intentoId, int $estudiante, int $pregunta, int $opcion, int $tiempoSeg): void
    {
        $intento = $this->propioEnCurso($intentoId, $estudiante);
        if (
            !$this->intentos->preguntaDeLaActividad($pregunta, (int) $intento['actividad_id'])
            || !$this->intentos->opcionDeLaPregunta($opcion, $pregunta)
        ) {
            throw HttpException::validacion([
                'opcion_id' => 'La opción no corresponde a una pregunta de esta actividad.',
            ]);
        }
        $this->intentos->responder($intentoId, $pregunta, $opcion, max(0, min($tiempoSeg, 86400)));
    }

    /** @return array<string, mixed> resultado */
    public function finalizar(int $intentoId, int $estudiante): array
    {
        $intento = $this->propioEnCurso($intentoId, $estudiante);
        $ahora = $this->reloj->ahora();
        $this->db->transaccion(function () use ($intento, $ahora): void {
            $secuencia = (int) $intento['ultima_secuencia'] + 1;
            $this->intentos->registrarEvento(
                (int) $intento['id'],
                $secuencia,
                'FIN',
                null,
                null,
                $this->formato($ahora),
                null
            );
            $this->cerrarConTiempos((int) $intento['id'], $intento['iniciado_en'], 'FINALIZADO', $ahora);
            // RF-07: el resultado lo calcula la aplicación (D-4); la base solo lo guarda.
            $conteo = $this->intentos->conteoParaResultado((int) $intento['id']);
            $this->intentos->guardarResultado(
                (int) $intento['id'],
                $conteo['correctas'],
                $conteo['total'],
                Indicadores::puntaje($conteo['correctas'], $conteo['total'])
            );
            // Nivel 1 en la misma transacción (Tabla 20: la resolución se guarda como una sola operación).
            $this->analisis->procesarIntento((int) $intento['id']);
        });

        return $this->resultado($intentoId, $estudiante);
    }

    /** Abandono explícito ("salir" sin finalizar): tiempo registrado hasta ahora (RF-09). */
    public function abandonar(int $intentoId, int $estudiante): array
    {
        $intento = $this->propioEnCurso($intentoId, $estudiante);
        $ahora = $this->reloj->ahora();
        $this->db->transaccion(function () use ($intento, $ahora): void {
            $this->intentos->registrarEvento(
                (int) $intento['id'],
                (int) $intento['ultima_secuencia'] + 1,
                'ABANDONO',
                null,
                null,
                $this->formato($ahora),
                null
            );
            $this->cerrarConTiempos((int) $intento['id'], $intento['iniciado_en'], 'ABANDONADO', $ahora);
        });

        return $this->publico($this->intentos->obtener($intentoId));
    }

    /**
     * Cierra como ABANDONADO los intentos sin eventos hace ≥ 30 min; el tiempo llega
     * hasta el último evento (DEC-23, RF-09). Lo ejecuta una tarea periódica.
     */
    public function cerrarAbandonados(int $minutos = self::MINUTOS_ABANDONO): int
    {
        $cerrados = 0;
        foreach ($this->intentos->inactivos($minutos) as $fila) {
            $ultimo = new DateTimeImmutable($fila['ultimo'], new DateTimeZone('UTC'));
            $this->db->transaccion(function () use ($fila, $ultimo): void {
                $intento = $this->intentos->obtener((int) $fila['id']);
                $this->intentos->registrarEvento(
                    (int) $fila['id'],
                    (int) $intento['ultima_secuencia'] + 1,
                    'ABANDONO',
                    null,
                    null,
                    $this->formato($ultimo),
                    null
                );
                $this->cerrarConTiempos((int) $fila['id'], $fila['iniciado_en'], 'ABANDONADO', $ultimo);
            });
            $cerrados++;
        }

        return $cerrados;
    }

    /** @return array<string, mixed> */
    public function resultado(int $intentoId, int $estudiante): array
    {
        $intento = $this->propio($intentoId, $estudiante);
        if ($intento['estado'] !== 'FINALIZADO') {
            throw HttpException::conflicto(
                'El intento no está finalizado; los intentos abandonados no generan resultado.'
            );
        }
        $r = $this->intentos->resultado($intentoId);

        return [
            'intento' => $this->publico($intento),
            'correctas' => (int) $r['correctas'],
            'total_preguntas' => (int) $r['total_preguntas'],
            'puntaje' => (float) $r['puntaje'],
            'detalle' => array_map(fn ($d) => [
                'pregunta_id' => (int) $d['pregunta_id'],
                'orden' => (int) $d['orden'],
                'enunciado' => $d['enunciado'],
                'opcion_elegida_id' => $d['opcion_id'] !== null ? (int) $d['opcion_id'] : null,
                'opcion_correcta_id' => (int) $d['opcion_correcta_id'],
                'acerto' => (bool) $d['acerto'],
                'tiempo_seg' => $d['tiempo_seg'] !== null ? (int) $d['tiempo_seg'] : null,
            ], $this->intentos->detalleRespuestas($intentoId)),
        ];
    }

    /** @param array<string, mixed> $intento @param array<string, mixed> $e */
    private function validarEvento(array $intento, array $e, int $i): void
    {
        if (
            !isset($e['secuencia']) || filter_var(
                $e['secuencia'],
                FILTER_VALIDATE_INT
            ) === false || (int) $e['secuencia'] < 2
        ) {
            throw HttpException::validacion(["eventos.{$i}.secuencia" => 'Secuencia entera ≥ 2 (la 1 es el INICIO).']);
        }
        if (!in_array($e['tipo'] ?? null, self::TIPOS_EVENTO, true)) {
            throw HttpException::validacion(["eventos.{$i}.tipo" => 'Tipo de evento no permitido.']);
        }
        if (
            isset($e['pregunta_id'])
            && !$this->intentos->preguntaDeLaActividad((int) $e['pregunta_id'], (int) $intento['actividad_id'])
        ) {
            throw HttpException::validacion(["eventos.{$i}.pregunta_id" => 'La pregunta no es de esta actividad.']);
        }
        if (
            isset($e['opcion_id']) && (!isset($e['pregunta_id'])
            || !$this->intentos->opcionDeLaPregunta((int) $e['opcion_id'], (int) $e['pregunta_id']))
        ) {
            throw HttpException::validacion(["eventos.{$i}.opcion_id" => 'La opción no corresponde a la pregunta.']);
        }
    }

    /** Hora del cliente acotada al intervalo [inicio del intento, ahora + 60 s]. */
    private function instante(mixed $valor, string $inicio): string
    {
        $ahora = $this->reloj->ahora();
        $desde = new DateTimeImmutable($inicio, new DateTimeZone('UTC'));
        $ts = is_string($valor) ? strtotime($valor) : false;
        if ($ts === false) {
            return $this->formato($ahora);
        }
        $t = (new DateTimeImmutable('@' . $ts))->setTimezone(new DateTimeZone('UTC'));
        if ($t < $desde) {
            $t = $desde;
        }
        if ($t > $ahora->modify('+60 seconds')) {
            $t = $ahora;
        }

        return $this->formato($t);
    }

    /** @return array<string, mixed> */
    private function propio(int $intentoId, int $estudiante): array
    {
        $intento = $this->intentos->obtener($intentoId);
        if ($intento === null || (int) $intento['usuario_id'] !== $estudiante) {
            throw HttpException::noEncontrado('Intento no encontrado.');
        }

        return $intento;
    }

    /** @return array<string, mixed> */
    private function propioEnCurso(int $intentoId, int $estudiante): array
    {
        $intento = $this->propio($intentoId, $estudiante);
        if ($intento['estado'] !== 'EN_CURSO') {
            throw HttpException::conflicto('El intento ya está cerrado.');
        }

        return $intento;
    }

    /** @param array<string, mixed>|null $i @return array<string, mixed> */
    private function publico(?array $i): array
    {
        return [
            'id' => (int) $i['id'],
            'actividad_id' => (int) $i['actividad_id'],
            'numero_intento' => (int) $i['numero_intento'],
            'estado' => $i['estado'],
            'iniciado_en' => $i['iniciado_en'],
            'finalizado_en' => $i['finalizado_en'],
            'duracion_seg' => $i['duracion_seg'] !== null ? (int) $i['duracion_seg'] : null,
            // D-8: tiempo activo (total menos pausas), aparte del total.
            'duracion_activa_seg' => $i['duracion_activa_seg'] !== null ? (int) $i['duracion_activa_seg'] : null,
            'proxima_secuencia' => (int) ($i['ultima_secuencia'] ?? 1) + 1,
        ];
    }

    /**
     * Cierra el intento con su tiempo total (RF-09) y su tiempo activo, total menos
     * pausas (D-8). Va después de registrar el evento FIN o ABANDONO.
     */
    private function cerrarConTiempos(int $id, string $iniciadoEn, string $estado, DateTimeImmutable $fin): void
    {
        $total = $this->segundosDesde($iniciadoEn, $fin);
        $eventos = $this->intentos->interacciones($id);
        $tiempos = TiempoActivo::calcular($eventos, $iniciadoEn, $this->formato($fin), $total);
        $this->intentos->cerrar($id, $estado, $this->formato($fin), $total, $tiempos['activo_seg']);
    }

    private function segundosDesde(string $inicio, DateTimeImmutable $fin): int
    {
        $desde = new DateTimeImmutable($inicio, new DateTimeZone('UTC'));

        return max(0, min(86400, $fin->getTimestamp() - $desde->getTimestamp()));
    }

    private function ahora(): string
    {
        return $this->formato($this->reloj->ahora());
    }

    private function formato(DateTimeImmutable $t): string
    {
        return $t->format('Y-m-d H:i:s.v');
    }
}
