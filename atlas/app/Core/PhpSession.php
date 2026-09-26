<?php

declare(strict_types=1);

namespace Atlas\Core;

/**
 * Sesión nativa con cookie Secure, HttpOnly y SameSite=Strict, y expiración
 * por inactividad.
 */
final class PhpSession implements Session
{
    public function __construct(private readonly Config $config)
    {
        if (session_status() !== PHP_SESSION_ACTIVE) {
            session_name('ATLASSID');
            session_set_cookie_params([
                'lifetime' => 0,
                'path' => '/',
                'secure' => $config->booleano('ATLAS_COOKIE_SECURE', true),
                'httponly' => true,
                'samesite' => 'Strict',
            ]);
            ini_set('session.use_strict_mode', '1');
            ini_set('session.use_only_cookies', '1');
            session_start();
        }
        $limite = $config->entero('ATLAS_SESSION_IDLE_MINUTES', 30) * 60;
        $ultimo = $_SESSION['_ultimo_uso'] ?? null;
        if ($ultimo !== null && time() - (int) $ultimo > $limite) {
            $_SESSION = [];
            session_regenerate_id(true);
        }
        $_SESSION['_ultimo_uso'] = time();
    }

    public function obtener(string $clave, mixed $defecto = null): mixed
    {
        return $_SESSION[$clave] ?? $defecto;
    }

    public function guardar(string $clave, mixed $valor): void
    {
        $_SESSION[$clave] = $valor;
    }

    public function regenerar(): void
    {
        session_regenerate_id(true);
    }

    public function destruir(): void
    {
        $_SESSION = [];
        session_destroy();
    }
}
