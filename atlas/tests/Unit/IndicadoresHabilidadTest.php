<?php

declare(strict_types=1);

namespace Atlas\Tests\Unit;

use Atlas\Services\Analysis\IndicadoresHabilidad;
use PHPUnit\Framework\TestCase;

/** Indicadores por habilidad (acta D-3), calculados en PHP (D-4). */
final class IndicadoresHabilidadTest extends TestCase
{
    private static function f(int $usuario, string $codigo, bool $acerto): array
    {
        return ['usuario_id' => $usuario, 'codigo' => $codigo, 'nombre' => ucfirst(strtolower($codigo)),
            'acerto' => $acerto];
    }

    public function testPorcentajePorHabilidadDeLaMasDebilALaMasFuerte(): void
    {
        $r = IndicadoresHabilidad::calcular([
            self::f(1, 'LOGICA', true), self::f(1, 'LOGICA', true), self::f(1, 'CALCULO', false),
            self::f(2, 'LOGICA', false), self::f(2, 'CALCULO', true), self::f(2, 'CALCULO', false),
        ]);

        $this->assertSame(['CALCULO', 'LOGICA'], array_column($r, 'codigo'));
        $this->assertSame([1, 3, 33.33, true], [$r[0]['correctas'], $r[0]['preguntas'], $r[0]['porcentaje'],
            $r[0]['a_reforzar']]);
        $this->assertSame([2, 3, 66.67, false], [$r[1]['correctas'], $r[1]['preguntas'], $r[1]['porcentaje'],
            $r[1]['a_reforzar']]);
    }

    public function testCuentaEstudiantesPorDebajoDelUmbral(): void
    {
        // Estudiante 1: 0 de 2 (0 %); estudiante 2: 1 de 2 (50 %, no está por debajo).
        $r = IndicadoresHabilidad::calcular([
            self::f(1, 'LOGICA', false), self::f(1, 'LOGICA', false),
            self::f(2, 'LOGICA', true), self::f(2, 'LOGICA', false),
        ]);
        $this->assertSame([2, 1], [$r[0]['estudiantes'], $r[0]['estudiantes_bajo_umbral']]);
    }

    public function testSinDatosNoInventaIndicadores(): void
    {
        $this->assertSame([], IndicadoresHabilidad::calcular([]));
    }
}
