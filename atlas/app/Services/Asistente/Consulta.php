<?php

declare(strict_types=1);

namespace Atlas\Services\Asistente;

/** Resultado de interpretar una pregunta del docente (sin intervención del LLM). */
final class Consulta
{
    public const ESTADO_GRUPO = 'ESTADO_GRUPO';
    public const DIFICULTAD = 'DIFICULTAD';
    public const EXPLICAR_RECOMENDACION = 'EXPLICAR_RECOMENDACION';
    public const NO_RECONOCIDA = 'NO_RECONOCIDA';

    public function __construct(
        public readonly string $tipo,
        public readonly ?int $grupoId = null,
        public readonly ?int $estudianteId = null,
        public readonly ?string $categoria = null,
        public readonly string $periodo = 'mes'
    ) {
    }
}
