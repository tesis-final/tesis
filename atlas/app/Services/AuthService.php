<?php

declare(strict_types=1);

namespace Atlas\Services;

use Atlas\Core\Clock;
use Atlas\Core\HttpException;
use Atlas\Core\Session;
use Atlas\Repositories\UsuarioRepository;

/**
 * Autenticación (RF-02; Tabla 14; DEC-23):
 * - con credenciales válidas entra al panel de su rol;
 * - con inválidas ve un error que no revela qué dato falló;
 * - a los 3 intentos fallidos la cuenta se bloquea 15 minutos;
 * - contraseñas con hash Argon2id; todo queda en auditoría.
 */
final class AuthService
{
    private const MENSAJE_GENERICO = 'Correo o contraseña incorrectos.';

    public function __construct(
        private readonly UsuarioRepository $usuarios,
        private readonly Session $sesion,
        private readonly AuditoriaService $auditoria,
        private readonly Clock $reloj,
        private readonly int $maxIntentos = 3,
        private readonly int $minutosBloqueo = 15
    ) {
    }

    /** @return array<string, mixed> usuario, permisos y token CSRF */
    public function iniciarSesion(string $correo, string $contrasena, string $ip): array
    {
        $usuario = $this->usuarios->paraLogin(mb_strtolower(trim($correo)));

        if ($usuario === null || !$usuario['activo']) {
            // Mismo costo de verificación que un usuario real (no revela si existe).
            password_verify($contrasena, self::hashFicticio());
            $this->auditoria->registrar(
                $usuario['id'] ?? null,
                'auth.login',
                'usuarios',
                null,
                'DENEGADO',
                ['motivo' => $usuario === null ? 'correo_inexistente' : 'cuenta_inactiva'],
                $ip
            );
            throw new HttpException(401, self::MENSAJE_GENERICO);
        }

        if (
            $usuario['bloqueado_hasta'] !== null
            && new \DateTimeImmutable($usuario['bloqueado_hasta'], new \DateTimeZone('UTC')) > $this->reloj->ahora()
        ) {
            $this->auditoria->registrar(
                $usuario['id'],
                'auth.login',
                'usuarios',
                (string) $usuario['id'],
                'DENEGADO',
                ['motivo' => 'cuenta_bloqueada'],
                $ip
            );
            throw new HttpException(
                423,
                'El acceso está bloqueado temporalmente por intentos fallidos. Intente más tarde.'
            );
        }

        if (!password_verify($contrasena, $usuario['hash_contrasena'])) {
            $fallos = $this->usuarios->registrarFallo($usuario['id'], $this->maxIntentos, $this->minutosBloqueo);
            $this->auditoria->registrar(
                $usuario['id'],
                'auth.login',
                'usuarios',
                (string) $usuario['id'],
                'DENEGADO',
                ['motivo' => 'contrasena', 'intentos_fallidos' => $fallos],
                $ip
            );
            if ($fallos >= $this->maxIntentos) {
                $this->auditoria->registrar(
                    $usuario['id'],
                    'auth.bloqueo',
                    'usuarios',
                    (string) $usuario['id'],
                    'OK',
                    ['minutos' => $this->minutosBloqueo],
                    $ip
                );
            }
            throw new HttpException(401, self::MENSAJE_GENERICO);
        }

        $this->usuarios->reiniciarFallos($usuario['id']);
        if (password_needs_rehash($usuario['hash_contrasena'], PASSWORD_ARGON2ID)) {
            $this->usuarios->actualizar($usuario['id'], ['hash_contrasena' => self::hash($contrasena)]);
        }
        $this->sesion->regenerar();
        $csrf = bin2hex(random_bytes(32));
        $this->sesion->guardar('usuario_id', $usuario['id']);
        $this->sesion->guardar('csrf', $csrf);
        $this->auditoria->registrar($usuario['id'], 'auth.login', 'usuarios', (string) $usuario['id'], 'OK', [], $ip);

        return $this->perfilSesion($usuario) + ['csrf' => $csrf];
    }

    public function cerrarSesion(int $usuarioId, string $ip): void
    {
        $this->auditoria->registrar($usuarioId, 'auth.logout', 'usuarios', (string) $usuarioId, 'OK', [], $ip);
        $this->sesion->destruir();
    }

    /** @param array<string, mixed> $usuario @return array<string, mixed> */
    public function perfilSesion(array $usuario): array
    {
        return [
            'usuario' => [
                'id' => $usuario['id'],
                'nombre' => $usuario['nombre'],
                'apellido' => $usuario['apellido'],
                'correo' => $usuario['correo'],
                'rol' => $usuario['rol'],
                'institucion_id' => $usuario['institucion_id'],
            ],
            'permisos' => $this->usuarios->permisosDeRol($usuario['rol_id']),
        ];
    }

    /** Hash real calculado una vez por proceso, para igualar el costo de verificación. */
    private static function hashFicticio(): string
    {
        static $hash = null;

        return $hash ??= password_hash(bin2hex(random_bytes(16)), PASSWORD_ARGON2ID);
    }

    public static function hash(string $contrasena): string
    {
        return password_hash($contrasena, PASSWORD_ARGON2ID);
    }
}
