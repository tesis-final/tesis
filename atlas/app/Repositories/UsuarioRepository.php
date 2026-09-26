<?php

declare(strict_types=1);

namespace Atlas\Repositories;

final class UsuarioRepository extends Repository
{
    private const CAMPOS = 'u.id, u.institucion_id, u.rol_id, r.codigo AS rol, u.nombre, u.apellido, u.correo,
                            u.activo, u.intentos_fallidos, u.bloqueado_hasta, u.creado_en';

    /** @return array<string, mixed>|null */
    public function porId(int $id): ?array
    {
        return $this->normalizar($this->uno(
            'SELECT ' . self::CAMPOS . ' FROM usuarios u JOIN roles r ON r.id = u.rol_id WHERE u.id = ?',
            [$id]
        ));
    }

    /** @return array<string, mixed>|null incluye hash_contrasena (solo para el login) */
    public function paraLogin(string $correo): ?array
    {
        return $this->normalizar($this->uno(
            'SELECT ' . self::CAMPOS . ', u.hash_contrasena FROM usuarios u JOIN roles r ON r.id = u.rol_id
              WHERE u.correo = ?',
            [$correo]
        ));
    }

    public function existeCorreo(string $correo, ?int $excepto = null): bool
    {
        return (bool) $this->valor(
            'SELECT COUNT(*) FROM usuarios WHERE correo = ? AND id <> ?',
            [$correo, $excepto ?? 0]
        );
    }

    /** @return list<array<string, mixed>> */
    public function listar(?string $rol = null): array
    {
        $filas = $rol === null
            ? $this->todos(
                'SELECT ' . self::CAMPOS . ' FROM usuarios u JOIN roles r ON r.id = u.rol_id'
                . ' ORDER BY u.apellido, u.nombre'
            )
            : $this->todos(
                'SELECT ' . self::CAMPOS . ' FROM usuarios u JOIN roles r ON r.id = u.rol_id WHERE r.codigo = ?
                  ORDER BY u.apellido, u.nombre',
                [$rol]
            );

        return array_map(fn ($f) => $this->normalizar($f), $filas);
    }

    public function crear(
        int $institucion,
        string $rol,
        string $nombre,
        string $apellido,
        string $correo,
        string $hash
    ): int {
        return $this->ejecutar(
            'INSERT INTO usuarios (institucion_id, rol_id, nombre, apellido, correo, hash_contrasena)
             VALUES (?, ?, ?, ?, ?, ?)',
            [$institucion, $this->idCatalogo('roles', $rol), $nombre, $apellido, $correo, $hash]
        );
    }

    /** @param array<string, mixed> $campos columnas permitidas de usuarios */
    public function actualizar(int $id, array $campos): void
    {
        $permitidos = ['nombre', 'apellido', 'correo', 'institucion_id', 'activo', 'hash_contrasena', 'rol_id'];
        $sets = [];
        $params = [];
        foreach ($campos as $campo => $valor) {
            if (!in_array($campo, $permitidos, true)) {
                throw new \LogicException("Campo no actualizable: {$campo}");
            }
            $sets[] = "{$campo} = ?";
            $params[] = is_bool($valor) ? (int) $valor : $valor;
        }
        if ($sets === []) {
            return;
        }
        $params[] = $id;
        $this->afectadas('UPDATE usuarios SET ' . implode(', ', $sets) . ' WHERE id = ?', $params);
    }

    public function registrarFallo(int $id, int $maximo, int $minutosBloqueo): int
    {
        $this->afectadas(
            'UPDATE usuarios
                SET intentos_fallidos = LEAST(intentos_fallidos + 1, 255),
                    bloqueado_hasta = IF(intentos_fallidos >= ?, UTC_TIMESTAMP(3) + INTERVAL ? MINUTE, bloqueado_hasta)
              WHERE id = ?',
            [$maximo, $minutosBloqueo, $id]
        );

        return (int) $this->valor('SELECT intentos_fallidos FROM usuarios WHERE id = ?', [$id]);
    }

    public function reiniciarFallos(int $id): void
    {
        $this->afectadas('UPDATE usuarios SET intentos_fallidos = 0, bloqueado_hasta = NULL WHERE id = ?', [$id]);
    }

    public function rolTienePermiso(int $rolId, string $permiso): bool
    {
        return (bool) $this->valor(
            'SELECT COUNT(*) FROM rol_permiso rp JOIN permisos p ON p.id = rp.permiso_id
              WHERE rp.rol_id = ? AND p.codigo = ? AND rp.activo',
            [$rolId, $permiso]
        );
    }

    /** @return list<string> */
    public function permisosDeRol(int $rolId): array
    {
        return array_column($this->todos(
            'SELECT p.codigo FROM rol_permiso rp JOIN permisos p ON p.id = rp.permiso_id
              WHERE rp.rol_id = ? AND rp.activo ORDER BY p.codigo',
            [$rolId]
        ), 'codigo');
    }

    /** @param array<string, mixed>|null $fila @return array<string, mixed>|null */
    private function normalizar(?array $fila): ?array
    {
        if ($fila === null) {
            return null;
        }
        $fila['id'] = (int) $fila['id'];
        $fila['rol_id'] = (int) $fila['rol_id'];
        $fila['institucion_id'] = (int) $fila['institucion_id'];
        $fila['activo'] = (bool) $fila['activo'];
        $fila['intentos_fallidos'] = (int) $fila['intentos_fallidos'];

        return $fila;
    }
}
