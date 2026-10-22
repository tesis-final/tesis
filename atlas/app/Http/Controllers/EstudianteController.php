<?php

declare(strict_types=1);

namespace Atlas\Http\Controllers;

use Atlas\Http\Json;
use Atlas\Http\Requests\EventosRequest;
use Atlas\Http\Requests\IniciarIntentoRequest;
use Atlas\Http\Requests\ResponderRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

/** Resolución de actividades (RF-04, RF-06..RF-09; D-8). El estudiante solo ve lo propio. */
final class EstudianteController extends Controller
{
    public function actividades(Request $p): JsonResponse
    {
        return Json::ok($this->atlas->actividadesRepo()->publicadasParaEstudiante($this->usuario($p)['id']));
    }

    public function iniciar(IniciarIntentoRequest $p): JsonResponse
    {
        return Json::creado($this->atlas->intentos()->iniciar(
            $this->usuario($p)['id'],
            $p->validados()['actividad_id']
        ));
    }

    public function eventos(EventosRequest $p): JsonResponse
    {
        return Json::ok($this->atlas->intentos()->registrarEventos(
            $this->id($p),
            $this->usuario($p)['id'],
            $p->validados()['eventos']
        ));
    }

    public function responder(ResponderRequest $p): Response
    {
        $d = $p->validados();
        $this->atlas->intentos()->responder(
            $this->id($p),
            $this->usuario($p)['id'],
            $this->id($p, 'pregunta'),
            $d['opcion_id'],
            $d['tiempo_seg'] ?? 0
        );

        return Json::sinContenido();
    }

    public function finalizar(Request $p): JsonResponse
    {
        return Json::ok($this->atlas->intentos()->finalizar($this->id($p), $this->usuario($p)['id']));
    }

    public function abandonar(Request $p): JsonResponse
    {
        return Json::ok($this->atlas->intentos()->abandonar($this->id($p), $this->usuario($p)['id']));
    }

    public function resultado(Request $p): JsonResponse
    {
        return Json::ok($this->atlas->intentos()->resultado($this->id($p), $this->usuario($p)['id']));
    }
}
