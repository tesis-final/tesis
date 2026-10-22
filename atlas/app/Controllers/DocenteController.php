<?php

declare(strict_types=1);

namespace Atlas\Controllers;

use Atlas\Core\Request;
use Atlas\Core\Response;

/** Panel docente, reportes y asistente (RF-10..RF-13, RF-18, RF-20). */
final class DocenteController extends Controller
{
    public function analisisGrupal(Request $p): Response
    {
        return Response::json($this->app->panel()->analisisGrupal(
            $this->usuario($p),
            $p->parametroEntero('id'),
            $this->consultaEntera($p, 'actividad'),
            $this->consultaFecha($p, 'desde'),
            $this->consultaFecha($p, 'hasta')
        ));
    }

    public function perfil(Request $p): Response
    {
        return Response::json($this->app->panel()->perfilEstudiante(
            $this->usuario($p),
            $p->parametroEntero('id'),
            $this->consultaFecha($p, 'desde')
        ));
    }

    public function fundamento(Request $p): Response
    {
        return Response::json($this->app->panel()->fundamento($this->usuario($p), $p->parametroEntero('id')));
    }

    /** D-6: el docente confirma o cambia la actividad sugerida. */
    public function decidir(Request $p): Response
    {
        return Response::json($this->app->panel()->decidir(
            $this->usuario($p),
            $p->parametroEntero('id'),
            $p->validados()['actividad_id'] ?? null
        ));
    }

    public function reportes(Request $p): Response
    {
        return Response::json($this->app->panel()->reporte(
            $this->usuario($p),
            $this->consultaEntera($p, 'grupo'),
            $this->consultaEntera($p, 'actividad'),
            $this->consultaFecha($p, 'desde'),
            $this->consultaFecha($p, 'hasta')
        ));
    }

    public function consultar(Request $p): Response
    {
        return Response::json($this->app->asistente()->consultar($this->usuario($p), $p->validados()['pregunta']));
    }

    public function historial(Request $p): Response
    {
        $repo = new \Atlas\Repositories\ConversacionRepository($this->app->db());
        return Response::json($repo->historial($this->usuario($p)['id']));
    }
}
