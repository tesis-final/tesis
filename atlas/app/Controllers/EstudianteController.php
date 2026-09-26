<?php

declare(strict_types=1);

namespace Atlas\Controllers;

use Atlas\Core\Request;
use Atlas\Core\Response;

/** Resolución de actividades (RF-04, RF-06..RF-09). El estudiante solo ve lo propio. */
final class EstudianteController extends Controller
{
    public function actividades(Request $p): Response
    {
        return Response::json($this->app->actividadesRepo()->publicadasParaEstudiante($this->usuario($p)['id']));
    }

    public function iniciar(Request $p): Response
    {
        return Response::creado($this->app->intentos()->iniciar(
            $this->usuario($p)['id'],
            $p->validados()['actividad_id']
        ));
    }

    public function eventos(Request $p): Response
    {
        return Response::json($this->app->intentos()->registrarEventos(
            $p->parametroEntero('id'),
            $this->usuario($p)['id'],
            $p->validados()['eventos']
        ));
    }

    public function responder(Request $p): Response
    {
        $d = $p->validados();
        $this->app->intentos()->responder(
            $p->parametroEntero('id'),
            $this->usuario($p)['id'],
            $p->parametroEntero('pregunta'),
            $d['opcion_id'],
            $d['tiempo_seg'] ?? 0
        );

        return Response::sinContenido();
    }

    public function finalizar(Request $p): Response
    {
        return Response::json($this->app->intentos()->finalizar($p->parametroEntero('id'), $this->usuario($p)['id']));
    }

    public function abandonar(Request $p): Response
    {
        return Response::json($this->app->intentos()->abandonar($p->parametroEntero('id'), $this->usuario($p)['id']));
    }

    public function resultado(Request $p): Response
    {
        return Response::json($this->app->intentos()->resultado($p->parametroEntero('id'), $this->usuario($p)['id']));
    }
}
