<?php

declare(strict_types=1);

namespace Atlas\Repositories;

/**
 * Instituciones, grupos y pertenencia de usuarios a grupos (RF-14, RF-04, RF-11).
 */
final class OrganizacionRepository extends Repository
{
    /** @return list<array<string, mixed>> */
    public function instituciones(): array
    {
        return $this->todos('SELECT id, nombre, activa, creado_en FROM instituciones ORDER BY nombre');
    }

    public function crearInstitucion(string $nombre): int
    {
        return $this->ejecutar('INSERT INTO instituciones (nombre) VALUES (?)', [$nombre]);
    }

    public function actualizarInstitucion(int $id, string $nombre, bool $activa): int
    {
        return $this->afectadas(
            'UPDATE instituciones SET nombre = ?, activa = ? WHERE id = ?',
            [$nombre, (int) $activa, $id]
        );
    }

    public function existeInstitucion(int $id): bool
    {
        return (bool) $this->valor('SELECT COUNT(*) FROM instituciones WHERE id = ?', [$id]);
    }

    /** @return list<array<string, mixed>> */
    public function grupos(?int $usuarioId = null): array
    {
        if ($usuarioId === null) {
            return $this->todos(
                'SELECT g.id, g.institucion_id, g.nombre, g.anio_lectivo,
                        (SELECT COUNT(*) FROM usuario_grupo ug JOIN usuarios u ON u.id = ug.usuario_id
                           JOIN roles r ON r.id = u.rol_id
                          WHERE ug.grupo_id = g.id AND ug.activo AND r.codigo = \'ESTUDIANTE\') AS estudiantes
                   FROM grupos_clase g ORDER BY g.anio_lectivo DESC, g.nombre'
            );
        }

        return $this->todos(
            'SELECT g.id, g.institucion_id, g.nombre, g.anio_lectivo,
                    (SELECT COUNT(*) FROM usuario_grupo ug2 JOIN usuarios u ON u.id = ug2.usuario_id
                       JOIN roles r ON r.id = u.rol_id
                      WHERE ug2.grupo_id = g.id AND ug2.activo AND r.codigo = \'ESTUDIANTE\') AS estudiantes
               FROM grupos_clase g JOIN usuario_grupo ug ON ug.grupo_id = g.id AND ug.activo
              WHERE ug.usuario_id = ? ORDER BY g.anio_lectivo DESC, g.nombre',
            [$usuarioId]
        );
    }

    /** @return array<string, mixed>|null */
    public function grupo(int $id): ?array
    {
        return $this->uno('SELECT id, institucion_id, nombre, anio_lectivo FROM grupos_clase WHERE id = ?', [$id]);
    }

    public function crearGrupo(int $institucion, string $nombre, int $anio): int
    {
        return $this->ejecutar(
            'INSERT INTO grupos_clase (institucion_id, nombre, anio_lectivo) VALUES (?, ?, ?)',
            [$institucion, $nombre, $anio]
        );
    }

    /** Deja como miembros activos exactamente los usuarios indicados (sin DELETE). @param list<int> $usuarios */
    public function definirMiembros(int $grupo, array $usuarios): void
    {
        $this->db->transaccion(function () use ($grupo, $usuarios): void {
            $this->afectadas('UPDATE usuario_grupo SET activo = FALSE WHERE grupo_id = ?', [$grupo]);
            foreach (array_unique($usuarios) as $u) {
                $this->afectadas(
                    'INSERT INTO usuario_grupo (usuario_id, grupo_id, activo) VALUES (?, ?, TRUE)
                     ON DUPLICATE KEY UPDATE activo = TRUE',
                    [$u, $grupo]
                );
            }
        });
    }

    /** @return list<array<string, mixed>> */
    public function miembros(int $grupo, ?string $rol = null): array
    {
        $sql = 'SELECT u.id, u.nombre, u.apellido, r.codigo AS rol
                  FROM usuario_grupo ug JOIN usuarios u ON u.id = ug.usuario_id JOIN roles r ON r.id = u.rol_id
                 WHERE ug.grupo_id = ? AND ug.activo AND u.activo';
        $params = [$grupo];
        if ($rol !== null) {
            $sql .= ' AND r.codigo = ?';
            $params[] = $rol;
        }

        return $this->todos($sql . ' ORDER BY u.apellido, u.nombre', $params);
    }

    public function perteneceAGrupo(int $usuario, int $grupo): bool
    {
        return (bool) $this->valor(
            'SELECT COUNT(*) FROM usuario_grupo WHERE usuario_id = ? AND grupo_id = ? AND activo',
            [$usuario, $grupo]
        );
    }

    /** ¿El docente comparte algún grupo activo con el estudiante? (RF-11: solo sus grupos) */
    public function docenteTieneAlEstudiante(int $docente, int $estudiante): bool
    {
        return (bool) $this->valor(
            'SELECT COUNT(*) FROM usuario_grupo d JOIN usuario_grupo e ON e.grupo_id = d.grupo_id AND e.activo
              WHERE d.usuario_id = ? AND d.activo AND e.usuario_id = ?',
            [$docente, $estudiante]
        );
    }

    /** @return list<int> */
    public function gruposDelUsuario(int $usuario): array
    {
        return array_map('intval', array_column(
            $this->todos('SELECT grupo_id FROM usuario_grupo WHERE usuario_id = ? AND activo', [$usuario]),
            'grupo_id'
        ));
    }

    /** Asigna permisos activos a un rol (sin DELETE: los demás quedan inactivos). @param list<string> $codigos */
    public function definirPermisosDeRol(int $rol, array $codigos): void
    {
        $this->db->transaccion(function () use ($rol, $codigos): void {
            $this->afectadas(
                'UPDATE rol_permiso rp JOIN permisos p ON p.id = rp.permiso_id
                    SET rp.activo = (p.codigo IN (
                        ' . ($codigos === [] ? "''" : implode(',
                        ', array_fill(0, count($codigos), '?'))) . '
                    ))
                  WHERE rp.rol_id = ?',
                [...$codigos, $rol]
            );
            foreach ($codigos as $codigo) {
                $this->afectadas(
                    'INSERT INTO rol_permiso (rol_id, permiso_id, activo)
                     SELECT ?, id, TRUE FROM permisos WHERE codigo = ?
                     ON DUPLICATE KEY UPDATE activo = TRUE',
                    [$rol, $codigo]
                );
            }
        });
    }

    /** @return list<array<string, mixed>> */
    public function roles(): array
    {
        $roles = $this->todos('SELECT id, codigo, nombre FROM roles ORDER BY id');
        foreach ($roles as &$r) {
            $r['permisos'] = array_column($this->todos(
                'SELECT p.codigo FROM rol_permiso rp JOIN permisos p ON p.id = rp.permiso_id
                  WHERE rp.rol_id = ? AND rp.activo ORDER BY p.codigo',
                [$r['id']]
            ), 'codigo');
        }

        return $roles;
    }

    /** @return list<string> */
    public function codigosPermisos(): array
    {
        return array_column($this->todos('SELECT codigo FROM permisos ORDER BY codigo'), 'codigo');
    }
}
