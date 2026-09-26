<?php

declare(strict_types=1);

namespace Atlas\Controllers;

use Atlas\Core\Request;
use Atlas\Core\Response;

/** Actividades y ciclo de aprobación (RF-05, RF-16, RF-17). */
final class ActividadController extends Controller
{
    public function listar(Request $p): Response
    {
        $u = $this->usuario($p);
        $estado = $p->query['estado'] ?? null;
        $estado = in_array(
            $estado,
            ['BORRADOR', 'PENDIENTE', 'APROBADA', 'RECHAZADA', 'PUBLICADA'],
            true
        ) ? $estado : null;

        // El docente ve las suyas; el administrador revisa todas (por defecto, las pendientes).
        return Response::json($u['rol'] === 'ADMIN'
            ? $this->app->actividadesRepo()->listar(null, $estado ?? 'PENDIENTE')
            : $this->app->actividadesRepo()->listar($u['id'], $estado));
    }

    public function catalogos(Request $p): Response
    {
        return Response::json([
            'niveles' => $this->app->actividadesRepo()->catalogo('niveles'),
            'categorias' => $this->app->actividadesRepo()->catalogo('categorias'),
        ]);
    }

    public function ver(Request $p): Response
    {
        return Response::json($this->app->actividades()->detalleSegunRol(
            $p->parametroEntero('id'),
            $this->usuario($p)
        ));
    }

    public function crear(Request $p): Response
    {
        return Response::creado($this->app->actividades()->crear(
            $this->usuario($p)['id'],
            $p->validados() + ['preguntas' => $p->cuerpo['preguntas'] ?? []]
        ));
    }

    public function editar(Request $p): Response
    {
        return Response::json($this->app->actividades()->editar(
            $p->parametroEntero('id'),
            $this->usuario($p)['id'],
            $p->validados() + ['preguntas' => $p->cuerpo['preguntas'] ?? []]
        ));
    }

    public function enviar(Request $p): Response
    {
        return Response::json($this->app->actividades()->enviar($p->parametroEntero('id'), $this->usuario($p)['id']));
    }

    public function aprobar(Request $p): Response
    {
        return Response::json($this->app->actividades()->aprobar($p->parametroEntero('id'), $this->usuario($p)['id']));
    }

    public function rechazar(Request $p): Response
    {
        return Response::json($this->app->actividades()->rechazar(
            $p->parametroEntero('id'),
            $this->usuario($p)['id'],
            $p->validados()['observaciones']
        ));
    }

    public function publicar(Request $p): Response
    {
        return Response::json($this->app->actividades()->publicar(
            $p->parametroEntero('id'),
            $this->usuario($p)['id'],
            $p->validados()['grupos']
        ));
    }

    public function transiciones(Request $p): Response
    {
        $detalle = $this->app->actividades()->detalleSegunRol($p->parametroEntero('id'), $this->usuario($p));

        return Response::json($detalle['transiciones']);
    }
}
