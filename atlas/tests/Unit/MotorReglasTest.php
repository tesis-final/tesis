<?php

declare(strict_types=1);

namespace Atlas\Tests\Unit;

use Atlas\Services\Analysis\MotorReglas;
use PHPUnit\Framework\TestCase;

/**
 * Las 8 reglas aprobadas (DEC-23), leídas del mismo archivo de semillas que usa la BD,
 * para que el test verifique exactamente lo que se despliega.
 */
final class MotorReglasTest extends TestCase
{
    /** @return array<string, array<string, mixed>> */
    private static function reglas(): array
    {
        $sql = file_get_contents(__DIR__ . '/../../database/seeds/001_catalogos.sql');
        preg_match_all(
            "/\\('(R0\\d)',.*?'(RIESGO|AVANCE|REFUERZO|RECONOCIMIENTO)',\\s*'(\\{.*?\\})',\\s*'(\\{.*?\\})'/s",
            $sql,
            $m,
            PREG_SET_ORDER
        );
        $reglas = [];
        foreach ($m as $f) {
            $reglas[$f[1]] = ['id' => 1, 'codigo' => $f[1], 'tipo' => $f[2], 'condicion' => json_decode($f[3], true),
                              'sugerencia' => json_decode($f[4], true), 'version' => 1];
        }

        return $reglas;
    }

    /** @param array<string, mixed> $ctx @return list<string> */
    private static function disparadas(array $ctx): array
    {
        $base = ['puntaje' => null, 'eficiencia' => null, 'mejora' => null, 'persistencia' => null,
                 'puntaje_medio_categoria' => null, 'actividades_categoria' => 0];

        return array_map(
            fn ($d) => $d['regla']['codigo'],
            MotorReglas::evaluar(array_values(self::reglas()), $ctx + $base)
        );
    }

    public function testSeCarganLasOchoReglasYSonValidas(): void
    {
        $reglas = self::reglas();
        $this->assertSame(['R01', 'R02', 'R03', 'R04', 'R05', 'R06', 'R07', 'R08'], array_keys($reglas));
        foreach ($reglas as $codigo => $r) {
            $this->assertSame([], MotorReglas::validarCondicion($r['condicion']), $codigo);
        }
    }

    public function testR01YR07PuntajeBajoEnPrimerIntento(): void
    {
        $this->assertSame(
            ['R01', 'R07'],
            self::sorted(self::disparadas(['puntaje' => 30.0, 'mejora' => 0.0, 'persistencia' => 1]))
        );
    }

    public function testR02ListoParaAvanzar(): void
    {
        $this->assertSame(
            ['R02'],
            self::disparadas(['puntaje' => 90.0, 'eficiencia' => 1.2, 'mejora' => 0.0, 'persistencia' => 1])
        );
    }

    public function testR03DominaConLentitud(): void
    {
        $this->assertSame(
            ['R03'],
            self::disparadas(['puntaje' => 90.0, 'eficiencia' => 0.5, 'mejora' => 0.0, 'persistencia' => 1])
        );
    }

    public function testR04AprendeConLaPractica(): void
    {
        $this->assertSame(
            ['R04'],
            self::disparadas(['puntaje' => 75.0, 'eficiencia' => 0.9, 'mejora' => 25.0, 'persistencia' => 2])
        );
    }

    public function testR05Estancamiento(): void
    {
        $this->assertSame(['R05'], self::disparadas(['puntaje' => 60.0, 'mejora' => 0.0, 'persistencia' => 3]));
    }

    public function testR06PersistenciaConLogro(): void
    {
        $this->assertSame(
            ['R04', 'R06'],
            self::sorted(self::disparadas(['puntaje' => 80.0, 'mejora' => 30.0, 'persistencia' => 4]))
        );
    }

    public function testR08DificultadSostenidaEnLaCategoria(): void
    {
        $d = self::disparadas(['puntaje' => 55.0, 'mejora' => 5.0, 'persistencia' => 2,
                               'puntaje_medio_categoria' => 42.0, 'actividades_categoria' => 2]);
        $this->assertSame(['R08'], $d);
        // Con una sola actividad en la categoría no alcanza.
        $this->assertSame([], self::disparadas(['puntaje' => 55.0, 'mejora' => 5.0, 'persistencia' => 2,
                                                'puntaje_medio_categoria' => 42.0, 'actividades_categoria' => 1]));
    }

    public function testSinDatoNoDisparaYQuedaRegistrado(): void
    {
        $r = MotorReglas::evaluarRegla(self::reglas()['R02']['condicion'], ['puntaje' => 95.0, 'eficiencia' => null]);
        $this->assertFalse($r['cumple']);
        $this->assertSame(['eficiencia'], $r['valores']['sin_dato']);
    }

    public function testValoresUsadosQuedanParaElPorQue(): void
    {
        $r = MotorReglas::evaluarRegla(self::reglas()['R05']['condicion'], ['persistencia' => 4, 'mejora' => -5.0]);
        $this->assertTrue($r['cumple']);
        $this->assertSame(['persistencia' => 4, 'mejora' => -5.0], $r['valores']);
    }

    public function testValidacionDeCondicionesEditadasPorElAdministrador(): void
    {
        $this->assertNotSame(
            [],
            MotorReglas::validarCondicion(['todas' => [['indicador' => 'edad', 'op' => '<', 'valor' => 1]]])
        );
        $this->assertNotSame(
            [],
            MotorReglas::validarCondicion(['todas' => [['indicador' => 'puntaje', 'op' => 'LIKE', 'valor' => 1]]])
        );
        $this->assertNotSame([], MotorReglas::validarCondicion(['todas' => []]));
        $this->assertNotSame([], MotorReglas::validarCondicion('DROP TABLE'));
        $this->assertSame(
            [],
            MotorReglas::validarCondicion(['todas' => [['indicador' => 'puntaje', 'op' => '<', 'valor' => 45]]])
        );
    }

    /** @param list<string> $x @return list<string> */
    private static function sorted(array $x): array
    {
        sort($x);

        return $x;
    }
}
