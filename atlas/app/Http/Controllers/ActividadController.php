<?php

declare(strict_types=1);

namespace Atlas\Http\Controllers;

use Atlas\Http\Json;
use Atlas\Http\Requests\ActividadRequest;
use Atlas\Http\Requests\PublicarRequest;
use Atlas\Http\Requests\RechazarRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Actividades y ciclo de aprobación (RF-05, RF-16, RF-17; D-2, D-3). */
final class ActividadController extends Controller
{
    public function listar(Request $p): JsonResponse
    {
        $u = $this->usuario($p);
        $estado = $p->query('estado');
        $estado = in_array($estado, ['BORRADOR', 'PENDIENTE', 'APROBADA', 'RECHAZADA', 'PUBLICADA'], true)
            ? $estado : null;

        // El docente ve las suyas; el administrador revisa todas (por defecto, las pendientes).
        return Json::ok($u['rol'] === 'ADMIN'
            ? $this->atlas->actividadesRepo()->listar(null, $estado ?? 'PENDIENTE')
            : $this->atlas->actividadesRepo()->listar($u['id'], $estado));
    }

    public function catalogos(): JsonResponse
    {
        return Json::ok([
            'niveles' => $this->atlas->actividadesRepo()->catalogo('niveles'),
            'categorias' => $this->atlas->actividadesRepo()->catalogo('categorias'),
            'habilidades' => $this->atlas->actividadesRepo()->catalogo('habilidades'),
        ]);
    }

    public function ver(Request $p): JsonResponse
    {
        return Json::ok($this->atlas->actividades()->detalleSegunRol($this->id($p), $this->usuario($p)));
    }

    public function crear(ActividadRequest $p): JsonResponse
    {
        return Json::creado($this->atlas->actividades()->crear(
            $this->usuario($p)['id'],
            $p->validados() + ['preguntas' => $p->input('preguntas', [])]
        ));
    }

    public function editar(ActividadRequest $p): JsonResponse
    {
        return Json::ok($this->atlas->actividades()->editar(
            $this->id($p),
            $this->usuario($p)['id'],
            $p->validados() + ['preguntas' => $p->input('preguntas', [])]
        ));
    }

    public function enviar(Request $p): JsonResponse
    {
        return Json::ok($this->atlas->actividades()->enviar($this->id($p), $this->usuario($p)['id']));
    }

    public function aprobar(Request $p): JsonResponse
    {
        return Json::ok($this->atlas->actividades()->aprobar($this->id($p), $this->usuario($p)['id']));
    }

    public function rechazar(RechazarRequest $p): JsonResponse
    {
        return Json::ok($this->atlas->actividades()->rechazar(
            $this->id($p),
            $this->usuario($p)['id'],
            $p->validados()['observaciones']
        ));
    }

    public function publicar(PublicarRequest $p): JsonResponse
    {
        return Json::ok($this->atlas->actividades()->publicar(
            $this->id($p),
            $this->usuario($p)['id'],
            $p->validados()['grupos']
        ));
    }

    public function transiciones(Request $p): JsonResponse
    {
        $detalle = $this->atlas->actividades()->detalleSegunRol($this->id($p), $this->usuario($p));

        return Json::ok($detalle['transiciones']);
    }
}
