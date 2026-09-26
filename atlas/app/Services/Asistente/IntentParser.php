<?php

declare(strict_types=1);

namespace Atlas\Services\Asistente;

/**
 * Interpreta la pregunta del docente de forma LOCAL y DETERMINISTA (DEC-23, AMB-10).
 * Así se sabe a qué estudiante, grupo, categoría y período se refiere sin enviar
 * la pregunta con nombres a un servicio externo (H28). Solo reconoce entidades
 * dentro del alcance del docente (sus grupos y sus estudiantes).
 */
final class IntentParser
{
    private const PALABRAS_EXPLICAR = [
        'por que',
        'porque',
        'explica',
        'explicame',
        'explicar',
        'recomienda',
        'recomendacion',
        'fundamento'
    ];
    private const PALABRAS_DIFICULTAD = [
        'dificultad', 'dificultades', 'cuesta', 'costo', 'peor', 'atencion prioritaria',
        'prioritario', 'prioritarios', 'ayuda', 'riesgo', 'intervenir', 'problemas'];
    private const PALABRAS_ESTADO = [
        'como viene',
        'como va',
        'como anda',
        'como esta',
        'rendimiento',
        'resumen',
        'estado',
        'promedio'
    ];

    /**
     * @param list<array{id: int, nombre: string}>                     $grupos
     * @param list<array{id: int, nombre: string, apellido: string}>   $estudiantes
     * @param list<array{codigo: string, nombre: string}>              $categorias
     */
    public function interpretar(string $pregunta, array $grupos, array $estudiantes, array $categorias): Consulta
    {
        $texto = Texto::normalizar($pregunta);
        $periodo = str_contains($texto, 'semana') ? 'semana' : 'mes';

        $categoria = null;
        foreach ($categorias as $c) {
            if (Texto::contiene($texto, $c['nombre'])) {
                $categoria = $c['codigo'];
                // Se quita del texto para que "problemas" de la categoría no se lea como dificultad.
                $texto = trim(str_replace(Texto::normalizar($c['nombre']), ' ', $texto));
                break;
            }
        }

        $grupo = null;
        foreach ($grupos as $g) {
            if (Texto::contiene($texto, $g['nombre'])) {
                $grupo = (int) $g['id'];
                break;
            }
        }
        if ($grupo === null && count($grupos) === 1) {
            $grupo = (int) $grupos[0]['id'];
        }

        $estudiante = $this->estudiante($texto, $estudiantes);
        if (
            $estudiante !== null && ($this->alguna(
                $texto,
                self::PALABRAS_EXPLICAR
            ) || !$this->alguna($texto, self::PALABRAS_ESTADO))
        ) {
            return new Consulta(Consulta::EXPLICAR_RECOMENDACION, $grupo, $estudiante, $categoria, $periodo);
        }
        if ($this->alguna($texto, self::PALABRAS_DIFICULTAD)) {
            return new Consulta(Consulta::DIFICULTAD, $grupo, null, $categoria, $periodo);
        }
        if (
            $grupo !== null && ($this->alguna(
                $texto,
                self::PALABRAS_ESTADO
            ) || $categoria !== null || str_contains($texto, 'grupo'))
        ) {
            return new Consulta(Consulta::ESTADO_GRUPO, $grupo, null, $categoria, $periodo);
        }

        return new Consulta(Consulta::NO_RECONOCIDA, $grupo, null, $categoria, $periodo);
    }

    /** @param list<array{id: int, nombre: string, apellido: string}> $estudiantes */
    private function estudiante(string $texto, array $estudiantes): ?int
    {
        // Primero nombre + apellido (más específico), después solo nombre si es único.
        foreach ($estudiantes as $e) {
            if (Texto::contiene($texto, $e['nombre'] . ' ' . $e['apellido'])) {
                return (int) $e['id'];
            }
        }
        $candidatos = array_filter(
            $estudiantes,
            fn ($e) => Texto::contiene($texto, $e['nombre']) || Texto::contiene($texto, $e['apellido'])
        );

        return count($candidatos) === 1 ? (int) array_values($candidatos)[0]['id'] : null;
    }

    /** @param list<string> $palabras */
    private function alguna(string $texto, array $palabras): bool
    {
        foreach ($palabras as $p) {
            if (Texto::contiene($texto, $p)) {
                return true;
            }
        }

        return false;
    }
}
