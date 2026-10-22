<?php

declare(strict_types=1);

namespace Atlas\Core;

use Closure;
use Illuminate\Contracts\Session\Session as SesionDeLaravel;

/**
 * Adaptador: los servicios propios (AuthService) usan la interfaz Session; en la
 * web la respalda la sesión de Laravel (driver file, cookie Secure/HttpOnly/
 * SameSite=Strict y vencimiento por inactividad, config/session.php).
 */
final class SesionLaravel implements Session
{
    /** @param Closure(): SesionDeLaravel $sesion la sesión de la petición, resuelta al usarla */
    public function __construct(private readonly Closure $sesion)
    {
    }

    public function obtener(string $clave, mixed $defecto = null): mixed
    {
        return ($this->sesion)()->get($clave, $defecto);
    }

    public function guardar(string $clave, mixed $valor): void
    {
        ($this->sesion)()->put($clave, $valor);
    }

    public function regenerar(): void
    {
        ($this->sesion)()->regenerate(true);
    }

    public function destruir(): void
    {
        ($this->sesion)()->invalidate();
    }
}
