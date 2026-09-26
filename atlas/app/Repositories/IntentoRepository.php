<?php

declare(strict_types=1);

namespace Atlas\Repositories;

/**
 * Intentos, respuestas, interacciones y resultados (RF-06..RF-09).
 */
final class IntentoRepository extends Repository
{
    /** @return array<string, mixed>|null */
    public function obtener(int $id): ?array
    {
        return $this->uno(
            'SELECT i.id, i.usuario_id, i.actividad_id, i.numero_intento, i.estado, i.iniciado_en,
                    i.finalizado_en, i.duracion_seg,
                    (SELECT MAX(secuencia) FROM interacciones x WHERE x.intento_id = i.id) AS ultima_secuencia,
                    (SELECT MAX(ocurrido_en) FROM interacciones x WHERE x.intento_id = i.id) AS ultimo_evento
               FROM intentos i WHERE i.id = ?',
            [$id]
        );
    }

    /** @return array<string, mixed>|null */
    public function enCurso(int $estudiante, int $actividad): ?array
    {
        $id = $this->valor(
            "SELECT id FROM intentos WHERE usuario_id = ? AND actividad_id = ? AND estado = 'EN_CURSO'
              ORDER BY id DESC LIMIT 1",
            [$estudiante, $actividad]
        );

        return $id === false ? null : $this->obtener((int) $id);
    }

    public function crear(int $estudiante, int $actividad): int
    {
        $numero = (int) $this->valor(
            'SELECT COALESCE(MAX(numero_intento), 0) + 1 FROM intentos
              WHERE usuario_id = ? AND actividad_id = ? FOR UPDATE',
            [$estudiante, $actividad]
        );

        return $this->ejecutar(
            'INSERT INTO intentos (usuario_id, actividad_id, numero_intento) VALUES (?, ?, ?)',
            [$estudiante, $actividad, $numero]
        );
    }

    /** Inserción idempotente: reenviar un lote no duplica eventos (misma secuencia). */
    public function registrarEvento(
        int $intento,
        int $secuencia,
        string $tipo,
        ?int $pregunta,
        ?int $opcion,
        string $ocurridoEn,
        ?int $duracionMs
    ): bool {
        return $this->afectadas(
            'INSERT INTO interacciones (intento_id, secuencia, tipo, pregunta_id, opcion_id, ocurrido_en, duracion_ms)
             VALUES (?, ?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE id = id',
            [$intento, $secuencia, $tipo, $pregunta, $opcion, $ocurridoEn, $duracionMs]
        ) === 1;
    }

    public function preguntaDeLaActividad(int $pregunta, int $actividad): bool
    {
        return (bool) $this->valor(
            'SELECT COUNT(*) FROM preguntas WHERE id = ? AND actividad_id = ?',
            [$pregunta, $actividad]
        );
    }

    public function opcionDeLaPregunta(int $opcion, int $pregunta): bool
    {
        return (bool) $this->valor(
            'SELECT COUNT(*) FROM opciones WHERE id = ? AND pregunta_id = ?',
            [$opcion, $pregunta]
        );
    }

    public function responder(int $intento, int $pregunta, int $opcion, int $tiempoSeg): void
    {
        $this->afectadas(
            'INSERT INTO respuestas (intento_id, pregunta_id, opcion_id, tiempo_seg) VALUES (?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE opcion_id = VALUES(opcion_id), tiempo_seg = VALUES(tiempo_seg),
                                     respondido_en = CURRENT_TIMESTAMP(3)',
            [$intento, $pregunta, $opcion, $tiempoSeg]
        );
    }

    public function cerrar(int $intento, string $estado, string $finalizadoEn, int $duracionSeg): void
    {
        $this->afectadas(
            "UPDATE intentos SET estado = ?, finalizado_en = ?, duracion_seg = ? WHERE id = ? AND estado = 'EN_CURSO'",
            [$estado, $finalizadoEn, $duracionSeg, $intento]
        );
    }

    /** @return array<string, mixed>|null */
    public function resultado(int $intento): ?array
    {
        return $this->uno(
            'SELECT correctas, total_preguntas, puntaje, calculado_en FROM resultados WHERE intento_id = ?',
            [$intento]
        );
    }

    /** @return list<array<string, mixed>> detalle por pregunta tras finalizar */
    public function detalleRespuestas(int $intento): array
    {
        return $this->todos(
            'SELECT p.id AS pregunta_id, p.orden, p.enunciado, r.opcion_id, o.es_correcta AS acerto,
                    (SELECT oc.id FROM opciones oc
                      WHERE oc.pregunta_id = p.id AND oc.es_correcta LIMIT 1) AS opcion_correcta_id,
                    r.tiempo_seg
               FROM intentos i
               JOIN preguntas p ON p.actividad_id = i.actividad_id
               LEFT JOIN respuestas r ON r.intento_id = i.id AND r.pregunta_id = p.id
               LEFT JOIN opciones o ON o.id = r.opcion_id
              WHERE i.id = ? ORDER BY p.orden',
            [$intento]
        );
    }

    /** @return list<array<string, mixed>> secuencia completa (RF-06: reconstrucción) */
    public function interacciones(int $intento): array
    {
        return $this->todos(
            'SELECT secuencia, tipo, pregunta_id, opcion_id, ocurrido_en, duracion_ms
               FROM interacciones WHERE intento_id = ? ORDER BY secuencia',
            [$intento]
        );
    }

    /** Intentos en curso sin actividad desde hace $minutos (abandono por inactividad, DEC-23). @return list<array<string, mixed>> */
    public function inactivos(int $minutos): array
    {
        return $this->todos(
            "SELECT i.id, i.iniciado_en,
                    COALESCE(
                        (SELECT MAX(x.ocurrido_en) FROM interacciones x WHERE x.intento_id = i.id),
                        i.iniciado_en
                    ) AS ultimo
               FROM intentos i
              WHERE i.estado = 'EN_CURSO'
             HAVING ultimo < UTC_TIMESTAMP(3) - INTERVAL ? MINUTE",
            [$minutos]
        );
    }
}
