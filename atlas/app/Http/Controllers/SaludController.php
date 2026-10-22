<?php

declare(strict_types=1);

namespace Atlas\Http\Controllers;

use Atlas\Http\Json;
use Illuminate\Http\JsonResponse;

/** Verificación de disponibilidad y tiempo de respuesta (RNF-02, RNF-03; web scenario de Zabbix). */
final class SaludController extends Controller
{
    public function salud(): JsonResponse
    {
        $inicio = microtime(true);
        try {
            $bd = (int) $this->atlas->db()->app()->query('SELECT 1')->fetchColumn() === 1;
        } catch (\Throwable) {
            $bd = false;
        }
        $analisis = $this->atlas->clienteAnalisis()->salud();

        return Json::ok([
            'estado' => $bd ? 'ok' : 'degradado',
            'base_de_datos' => $bd,
            'servicio_analisis' => $analisis !== null,
            'ms' => (int) round((microtime(true) - $inicio) * 1000),
        ], $bd ? 200 : 503);
    }
}
