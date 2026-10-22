<?php

declare(strict_types=1);

namespace Atlas\Services;

use Atlas\Core\HttpException;
use Atlas\Repositories\UsuarioRepository;

/**
 * Gestión de usuarios por el administrador (RF-01, RF-14; DEC-00a):
 * crear, modificar y desactivar. No hay borrado: se desactiva.
 */
final class UsuarioService
{
    public const LONGITUD_MINIMA_CONTRASENA = 10;

    public function __construct(private readonly UsuarioRepository $usuarios)
    {
    }

    /** @param array<string, mixed> $datos validados @return array<string, mixed> */
    public function crear(array $datos): array
    {
        if ($this->usuarios->existeCorreo($datos['correo'])) {
            // RF-01: con un correo ya registrado, rechaza el alta e informa el motivo.
            throw HttpException::validacion(['correo' => 'El correo ya está registrado.']);
        }
        $this->validarContrasena($datos['contrasena']);
        $id = $this->usuarios->crear(
            $datos['institucion_id'],
            $datos['rol'],
            $datos['nombre'],
            $datos['apellido'],
            $datos['correo'],
            AuthService::hash($datos['contrasena'])
        );

        return $this->usuarios->porId($id);
    }

    /** @param array<string, mixed> $datos validados @return array<string, mixed> */
    public function modificar(int $id, array $datos, int $actorId): array
    {
        $actual = $this->usuarios->porId($id) ?? throw HttpException::noEncontrado('Usuario no encontrado.');
        $campos = array_intersect_key($datos, array_flip(['nombre', 'apellido', 'correo', 'institucion_id', 'activo']));
        if (isset($campos['correo']) && $this->usuarios->existeCorreo($campos['correo'], $id)) {
            throw HttpException::validacion(['correo' => 'El correo ya está registrado.']);
        }
        if (isset($datos['contrasena'])) {
            $this->validarContrasena($datos['contrasena']);
            $campos['hash_contrasena'] = AuthService::hash($datos['contrasena']);
        }
        if (($campos['activo'] ?? true) === false && $id === $actorId) {
            throw HttpException::conflicto('Un administrador no puede desactivar su propia cuenta.');
        }
        $this->usuarios->actualizar($actual['id'], $campos);

        return $this->usuarios->porId($id);
    }

    /**
     * Detalle de auditoría de un cambio de usuario (RF-14, RF-15): valores anterior
     * y nuevo de lo administrativo; del correo y la contraseña solo si cambiaron
     * (nunca el hash). Antes lo armaba un trigger; desde 004 lo arma la app (D-4).
     *
     * @param array<string, mixed> $antes   usuario antes del cambio (porId)
     * @param array<string, mixed> $despues usuario después del cambio (porId)
     * @return array<string, mixed>
     */
    public static function cambiosAuditables(array $antes, array $despues, bool $contrasenaCambiada): array
    {
        return [
            'rol_id' => [$antes['rol_id'], $despues['rol_id']],
            'institucion_id' => [$antes['institucion_id'], $despues['institucion_id']],
            'activo' => [$antes['activo'], $despues['activo']],
            'correo_cambiado' => $antes['correo'] !== $despues['correo'],
            'contrasena_cambiada' => $contrasenaCambiada,
        ];
    }

    private function validarContrasena(string $contrasena): void
    {
        if (mb_strlen($contrasena) < self::LONGITUD_MINIMA_CONTRASENA) {
            throw HttpException::validacion([
                'contrasena' => 'Debe tener al menos ' . self::LONGITUD_MINIMA_CONTRASENA . ' caracteres.',
            ]);
        }
    }
}
