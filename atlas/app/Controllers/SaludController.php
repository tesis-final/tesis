<?php

declare(strict_types=1);

namespace Atlas\Controllers;

use Atlas\Core\Request;
use Atlas\Core\Response;

/** Verificación de disponibilidad y tiempo de respuesta (RNF-02, RNF-03; web scenario de Zabbix). */
final class SaludController extends Controller
{
    public function salud(Request $p): Response
    {
        $inicio = microtime(true);
        $bd = false;
        try {
            $bd = (int) $this->app->db()->app()->query('SELECT 1')->fetchColumn() === 1;
        } catch (\Throwable) {
            $bd = false;
        }
        $analisis = $this->app->clienteAnalisis()->salud();

        return Response::json([
            'estado' => $bd ? 'ok' : 'degradado',
            'base_de_datos' => $bd,
            'servicio_analisis' => $analisis !== null,
            'ms' => (int) round((microtime(true) - $inicio) * 1000),
        ], $bd ? 200 : 503);
    }
}
