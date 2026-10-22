<?php

declare(strict_types=1);

namespace Atlas\Tests\Unit;

use Atlas\Services\Analysis\Indicadores;
use PHPUnit\Framework\TestCase;

/** Los 4 indicadores de §25.4 (ANA-01..ANA-04; eficiencia según DEC-23). */
final class IndicadoresTest extends TestCase
{
    private static function i(int $n, string $estado, ?float $p, ?int $d = 60): array
    {
        return ['numero' => $n, 'estado' => $estado, 'puntaje' => $p, 'duracion_seg' => $d];
    }

    public function testPuntajeMejoraYPersistencia(): void
    {
        $r = Indicadores::calcular([
            self::i(1, 'FINALIZADO', 40.0),
            self::i(2, 'ABANDONADO', null),
            self::i(3, 'FINALIZADO', 75.0, 90),
            self::i(4, 'EN_CURSO', null, null),
        ], null, 0);

        $this->assertSame(75.0, $r['puntaje'], 'puntaje del último intento finalizado');
        $this->assertSame(35.0, $r['mejora'], 'último − primero');
        $this->assertSame(3, $r['persistencia'], 'intentos (incluye abandonados) hasta el último finalizado');
        $this->assertNull($r['eficiencia'], 'sin media de grupo no se inventa eficiencia');
    }

    public function testPuntajeDeUnIntento(): void
    {
        // RF-07 (D-4): correctas / total × 100, calculado en PHP.
        $this->assertSame(75.0, Indicadores::puntaje(3, 4));
        $this->assertSame(66.67, Indicadores::puntaje(2, 3));
        $this->assertSame(0.0, Indicadores::puntaje(0, 5));
        $this->assertSame(100.0, Indicadores::puntaje(5, 5));
        $this->assertSame(0.0, Indicadores::puntaje(0, 0), 'actividad sin preguntas: sin división por cero');
    }

    public function testSinIntentosFinalizadosNoHayIndicadores(): void
    {
        $this->assertNull(Indicadores::calcular([self::i(1, 'ABANDONADO', null)], 60.0, 10));
    }

    public function testEficiencia(): void
    {
        // 100 % en el tiempo medio del grupo → 1,0
        $this->assertSame(1.0, Indicadores::eficiencia(100, 60, 60.0, 5));
        // 80 % en la mitad del tiempo medio → 1,6
        $this->assertSame(1.6, Indicadores::eficiencia(80, 30, 60.0, 5));
        // 50 % tardando el doble → 0,25
        $this->assertSame(0.25, Indicadores::eficiencia(50, 120, 60.0, 5));
        // Acotada a 5
        $this->assertSame(5.0, Indicadores::eficiencia(100, 1, 60.0, 5));
        // Menos de 3 intentos en el grupo → sin valor
        $this->assertNull(Indicadores::eficiencia(100, 60, 60.0, 2));
    }

    public function testDeterminismo(): void
    {
        $datos = [self::i(2, 'FINALIZADO', 50.0), self::i(1, 'FINALIZADO', 20.0)];
        $this->assertSame(
            Indicadores::calcular($datos, 60.0, 4),
            Indicadores::calcular(array_reverse($datos), 60.0, 4)
        );
    }
}
