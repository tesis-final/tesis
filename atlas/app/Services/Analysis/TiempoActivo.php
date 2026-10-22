<?php

declare(strict_types=1);

namespace Atlas\Services\Analysis;

use DateTimeImmutable;
use DateTimeZone;

/**
 * Tiempo activo de un intento (acta D-8): el total menos las pausas. Una pausa va de
 * un evento PAUSA (inactividad de 60 s o pestaña oculta) al REANUDA siguiente; si no
 * se reanudó, llega hasta el cierre. Se usan las marcas de tiempo ya acotadas por el
 * servidor (IntentoService::instante), no la duración que informa el navegador.
 * Función pura: mismos eventos → mismo resultado.
 */
final class TiempoActivo
{
    /**
     * @param list<array{tipo: string, ocurrido_en: string}> $eventos en orden de secuencia
     * @return array{pausas_seg: int, activo_seg: int}
     */
    public static function calcular(array $eventos, string $inicio, string $fin, int $totalSeg): array
    {
        $desde = self::instante($inicio);
        $hasta = self::instante($fin);
        $pausas = 0.0;
        $pausaDesde = null;
        foreach ($eventos as $e) {
            $t = min(max(self::instante($e['ocurrido_en']), $desde), $hasta);
            if ($e['tipo'] === 'PAUSA' && $pausaDesde === null) {
                $pausaDesde = $t;
            } elseif ($pausaDesde !== null && in_array($e['tipo'], ['REANUDA', 'FIN', 'ABANDONO'], true)) {
                $pausas += max(0.0, $t - $pausaDesde);
                $pausaDesde = null;
            }
        }
        if ($pausaDesde !== null) {
            $pausas += max(0.0, $hasta - $pausaDesde);
        }
        $pausasSeg = (int) min($totalSeg, round($pausas));

        return ['pausas_seg' => $pausasSeg, 'activo_seg' => max(0, $totalSeg - $pausasSeg)];
    }

    private static function instante(string $valor): float
    {
        return (float) (new DateTimeImmutable($valor, new DateTimeZone('UTC')))->format('U.v');
    }
}
