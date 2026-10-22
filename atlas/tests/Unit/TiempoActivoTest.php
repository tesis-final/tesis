<?php

declare(strict_types=1);

namespace Atlas\Tests\Unit;

use Atlas\Services\Analysis\TiempoActivo;
use PHPUnit\Framework\TestCase;

/** Tiempo activo = total menos pausas (acta D-8), calculado en PHP (D-4). */
final class TiempoActivoTest extends TestCase
{
    private const INICIO = '2026-10-20 10:00:00.000';
    private const FIN = '2026-10-20 10:10:00.000';

    private static function e(string $tipo, string $hora): array
    {
        return ['tipo' => $tipo, 'ocurrido_en' => "2026-10-20 {$hora}"];
    }

    public function testDescuentaLasPausasReanudadas(): void
    {
        $r = TiempoActivo::calcular([
            self::e('INICIO', '10:00:00.000'), self::e('PAUSA', '10:01:00.000'), self::e('REANUDA', '10:06:00.000'),
            self::e('PAUSA', '10:07:00.000'), self::e('REANUDA', '10:08:30.000'), self::e('FIN', '10:10:00.000'),
        ], self::INICIO, self::FIN, 600);

        $this->assertSame(['pausas_seg' => 390, 'activo_seg' => 210], $r);
    }

    public function testPausaSinReanudarLlegaHastaElCierre(): void
    {
        $r = TiempoActivo::calcular(
            [self::e('PAUSA', '10:08:20.000'), self::e('ABANDONO', '10:10:00.000')],
            self::INICIO,
            self::FIN,
            600
        );
        $this->assertSame(['pausas_seg' => 100, 'activo_seg' => 500], $r);
    }

    public function testSinPausasElActivoEsElTotal(): void
    {
        $this->assertSame(
            ['pausas_seg' => 0, 'activo_seg' => 600],
            TiempoActivo::calcular([self::e('SELECCION', '10:02:00.000')], self::INICIO, self::FIN, 600)
        );
    }

    public function testMarcasFueraDelIntentoSeAcotan(): void
    {
        // Una pausa "anterior al inicio" no puede descontar más que el intento entero.
        $r = TiempoActivo::calcular(
            [['tipo' => 'PAUSA', 'ocurrido_en' => '2026-10-19 09:00:00.000']],
            self::INICIO,
            self::FIN,
            600
        );
        $this->assertSame(['pausas_seg' => 600, 'activo_seg' => 0], $r);
    }
}
