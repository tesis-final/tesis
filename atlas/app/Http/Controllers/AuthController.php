<?php

declare(strict_types=1);

namespace Atlas\Http\Controllers;

use Atlas\Http\Json;
use Atlas\Http\Requests\LoginRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

/** Autenticación con sesión del servidor (RF-02): bloqueo por intentos, Argon2id, CSRF. */
final class AuthController extends Controller
{
    public function login(LoginRequest $p): JsonResponse
    {
        $d = $p->validados();

        return Json::ok($this->atlas->auth()->iniciarSesion($d['correo'], $d['contrasena'], (string) $p->ip()));
    }

    public function logout(Request $p): Response
    {
        $this->atlas->auth()->cerrarSesion($this->usuario($p)['id'], (string) $p->ip());

        return Json::sinContenido();
    }

    public function yo(Request $p): JsonResponse
    {
        return Json::ok($this->atlas->auth()->perfilSesion($this->usuario($p))
            + ['csrf' => $this->atlas->sesion()->obtener('csrf')]);
    }
}
