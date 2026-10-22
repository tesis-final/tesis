<?php

declare(strict_types=1);

namespace Atlas\Tests\Unit;

use Atlas\Services\Analysis\ResumenGrupal;
use PHPUnit\Framework\TestCase;

/** Agregados del análisis grupal (RF-18, H26), calculados en PHP (acta D-4). */
final class ResumenGrupalTest extends TestCase
{
    /** @param list<float> $puntajes @return list<array{usuario_id: int, puntaje: float}> */
    private static function filas(array $puntajes): array
    {
        return array_map(fn ($p, $i) => ['usuario_id' => $i + 1, 'puntaje' => $p], $puntajes, array_keys($puntajes));
    }

    public function testAgregadosConDatosConocidos(): void
    {
        // Mismo caso que verificaba sp_analisis_grupal: 25, 50, 75 y 100.
        $this->assertSame([
            'n_estudiantes' => 4, 'promedio' => 62.5, 'mediana' => 62.5, 'minimo' => 25.0, 'maximo' => 100.0,
        ], ResumenGrupal::calcular(self::filas([100.0, 25.0, 75.0, 50.0])));
    }

    public function testMedianaConCantidadImpar(): void
    {
        $this->assertSame(40.0, ResumenGrupal::calcular(self::filas([90.0, 10.0, 40.0]))['mediana']);
    }

    public function testGrupoSinResultados(): void
    {
        $this->assertSame(
            ['n_estudiantes' => 0, 'promedio' => null, 'mediana' => null, 'minimo' => null, 'maximo' => null],
            ResumenGrupal::calcular([])
        );
    }

    public function testCuentaEstudiantesDistintosConVariasActividades(): void
    {
        // Un estudiante con dos actividades: dos puntajes, un estudiante.
        $r = ResumenGrupal::calcular([
            ['usuario_id' => 7, 'puntaje' => 80.0],
            ['usuario_id' => 7, 'puntaje' => 60.0],
        ]);
        $this->assertSame(1, $r['n_estudiantes']);
        $this->assertSame(70.0, $r['promedio']);
    }
}
