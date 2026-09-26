<?php

declare(strict_types=1);

namespace Atlas\Controllers;

use Atlas\Core\Request;
use Atlas\Core\Response;

final class AuthController extends Controller
{
    public function login(Request $p): Response
    {
        $d = $p->validados();

        return Response::json($this->app->auth()->iniciarSesion($d['correo'], $d['contrasena'], $p->ip));
    }

    public function logout(Request $p): Response
    {
        $this->app->auth()->cerrarSesion($this->usuario($p)['id'], $p->ip);

        return Response::sinContenido();
    }

    public function yo(Request $p): Response
    {
        return Response::json($this->app->auth()->perfilSesion($this->usuario($p))
            + ['csrf' => $this->app->sesion()->obtener('csrf')]);
    }
}
