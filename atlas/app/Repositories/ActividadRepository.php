<?php

declare(strict_types=1);

namespace Atlas\Repositories;

use PDO;

/**
 * Actividades, preguntas, opciones, transiciones y publicación (RF-05, RF-16, RF-17, RF-04).
 */
final class ActividadRepository extends Repository
{
    private const CAMPOS = 'a.id, a.autor_id, CONCAT(u.nombre, \' \', u.apellido) AS autor, a.titulo, a.descripcion,
                            n.codigo AS nivel, n.nombre AS nivel_nombre, n.orden AS nivel_orden,
                            c.codigo AS categoria, c.nombre AS categoria_nombre,
                            e.codigo AS estado, a.creado_en, a.actualizado_en,
                            (SELECT COUNT(*) FROM preguntas p WHERE p.actividad_id = a.id) AS total_preguntas';
    private const DESDE = 'FROM actividades a
                             JOIN usuarios u ON u.id = a.autor_id
                             JOIN niveles_dificultad n ON n.id = a.nivel_id
                             JOIN categorias c ON c.id = a.categoria_id
                             JOIN estados_actividad e ON e.id = a.estado_id';

    /** @return array<string, mixed>|null */
    public function obtener(int $id): ?array
    {
        return $this->uno('SELECT ' . self::CAMPOS . ' ' . self::DESDE . ' WHERE a.id = ?', [$id]);
    }

    /** @return list<array<string, mixed>> */
    public function listar(?int $autor = null, ?string $estado = null): array
    {
        $donde = [];
        $params = [];
        if ($autor !== null) {
            $donde[] = 'a.autor_id = ?';
            $params[] = $autor;
        }
        if ($estado !== null) {
            $donde[] = 'e.codigo = ?';
            $params[] = $estado;
        }
        $sql = 'SELECT ' . self::CAMPOS . ' ' . self::DESDE
            . ($donde === [] ? '' : ' WHERE ' . implode(' AND ', $donde)) . ' ORDER BY a.actualizado_en DESC';

        return $this->todos($sql, $params);
    }

    /**
     * Preguntas con sus opciones. Con $conCorrectas = false se oculta cuál es la
     * correcta (vista del estudiante mientras resuelve).
     *
     * @return list<array<string, mixed>>
     */
    public function preguntas(int $actividad, bool $conCorrectas): array
    {
        $preguntas = $this->todos(
            'SELECT id, orden, enunciado FROM preguntas WHERE actividad_id = ? ORDER BY orden',
            [$actividad]
        );
        $opciones = $this->todos(
            'SELECT o.id, o.pregunta_id, o.orden, o.texto, o.es_correcta
               FROM opciones o JOIN preguntas p ON p.id = o.pregunta_id
              WHERE p.actividad_id = ? ORDER BY o.pregunta_id, o.orden',
            [$actividad]
        );
        $porPregunta = [];
        foreach ($opciones as $o) {
            $opcion = ['id' => (int) $o['id'], 'orden' => (int) $o['orden'], 'texto' => $o['texto']];
            if ($conCorrectas) {
                $opcion['correcta'] = (bool) $o['es_correcta'];
            }
            $porPregunta[(int) $o['pregunta_id']][] = $opcion;
        }
        $habilidades = [];
        foreach (
            $this->todos(
                'SELECT ph.pregunta_id, h.codigo
                   FROM pregunta_habilidad ph JOIN preguntas p ON p.id = ph.pregunta_id
                   JOIN habilidades h ON h.id = ph.habilidad_id
                  WHERE p.actividad_id = ? ORDER BY h.codigo',
                [$actividad]
            ) as $f
        ) {
            $habilidades[(int) $f['pregunta_id']][] = $f['codigo'];
        }
        foreach ($preguntas as &$p) {
            $p['id'] = (int) $p['id'];
            $p['orden'] = (int) $p['orden'];
            $p['opciones'] = $porPregunta[$p['id']] ?? [];
            $p['habilidades'] = $habilidades[$p['id']] ?? []; // D-3
        }

        return $preguntas;
    }

    /** @return array<string, int> código → id de las habilidades activas (D-3) */
    public function habilidadesActivas(): array
    {
        return array_map('intval', array_column(
            $this->todos('SELECT id, codigo FROM habilidades WHERE activa'),
            'id',
            'codigo'
        ));
    }

    public function crear(int $autor, string $titulo, ?string $descripcion, string $nivel, string $categoria): int
    {
        return $this->ejecutar(
            'INSERT INTO actividades (autor_id, nivel_id, categoria_id, estado_id, titulo, descripcion)
             VALUES (?, ?, ?, ?, ?, ?)',
            [$autor, $this->idCatalogo('niveles_dificultad', $nivel), $this->idCatalogo('categorias', $categoria),
             $this->idCatalogo('estados_actividad', 'BORRADOR'), $titulo, $descripcion]
        );
    }

    public function actualizarDatos(
        int $id,
        string $titulo,
        ?string $descripcion,
        string $nivel,
        string $categoria
    ): void {
        $this->afectadas(
            'UPDATE actividades SET titulo = ?, descripcion = ?, nivel_id = ?, categoria_id = ? WHERE id = ?',
            [$titulo, $descripcion, $this->idCatalogo('niveles_dificultad', $nivel),
             $this->idCatalogo('categorias', $categoria), $id]
        );
    }

    /** Reemplaza todo el contenido de un borrador (CT-13). @param list<array<string, mixed>> $preguntas */
    public function reemplazarContenido(int $actividad, array $preguntas): void
    {
        $this->afectadas(
            'DELETE o FROM opciones o JOIN preguntas p ON p.id = o.pregunta_id WHERE p.actividad_id = ?',
            [$actividad]
        );
        $this->afectadas('DELETE FROM preguntas WHERE actividad_id = ?', [$actividad]);
        foreach (array_values($preguntas) as $i => $p) {
            $preguntaId = $this->ejecutar(
                'INSERT INTO preguntas (actividad_id, orden, enunciado) VALUES (?, ?, ?)',
                [$actividad, $i + 1, $p['enunciado']]
            );
            foreach (array_values($p['opciones']) as $j => $o) {
                $this->ejecutar(
                    'INSERT INTO opciones (pregunta_id, orden, texto, es_correcta) VALUES (?, ?, ?, ?)',
                    [$preguntaId, $j + 1, $o['texto'], (int) $o['correcta']]
                );
            }
            // D-3: qué habilidades mide la pregunta (los vínculos viejos se borran en cascada).
            foreach ($p['habilidades'] ?? [] as $habilidad) {
                $this->ejecutar(
                    'INSERT INTO pregunta_habilidad (pregunta_id, habilidad_id) VALUES (?, ?)',
                    [$preguntaId, $habilidad]
                );
            }
        }
    }

    public function cambiarEstado(
        int $actividad,
        ?string $origen,
        string $destino,
        int $usuario,
        ?string $observaciones
    ): void {
        if ($origen !== null) {
            $this->afectadas(
                'UPDATE actividades SET estado_id = ? WHERE id = ?',
                [$this->idCatalogo('estados_actividad', $destino), $actividad]
            );
        }
        $this->ejecutar(
            'INSERT INTO transiciones_actividad
               (actividad_id, estado_origen_id, estado_destino_id, usuario_id, observaciones)
             VALUES (?, ?, ?, ?, ?)',
            [$actividad, $origen === null ? null : $this->idCatalogo('estados_actividad', $origen),
             $this->idCatalogo('estados_actividad', $destino), $usuario, $observaciones]
        );
    }

    /** @return list<array<string, mixed>> */
    public function transiciones(int $actividad): array
    {
        return $this->todos(
            'SELECT t.id, eo.codigo AS desde, ed.codigo AS hacia, t.usuario_id,
                    CONCAT(u.nombre, \' \', u.apellido) AS autor, t.observaciones, t.creado_en
               FROM transiciones_actividad t
               LEFT JOIN estados_actividad eo ON eo.id = t.estado_origen_id
               JOIN estados_actividad ed ON ed.id = t.estado_destino_id
               JOIN usuarios u ON u.id = t.usuario_id
              WHERE t.actividad_id = ? ORDER BY t.creado_en, t.id',
            [$actividad]
        );
    }

    public function publicarEnGrupo(int $actividad, int $grupo, int $docente): void
    {
        $this->afectadas(
            'INSERT INTO actividad_grupo (actividad_id, grupo_id, publicado_por) VALUES (?, ?, ?)',
            [$actividad, $grupo, $docente]
        );
    }

    /** @return list<array<string, mixed>> grupos donde está publicada */
    public function gruposPublicados(int $actividad): array
    {
        return $this->todos(
            'SELECT g.id, g.nombre FROM actividad_grupo ag JOIN grupos_clase g ON g.id = ag.grupo_id
              WHERE ag.actividad_id = ? ORDER BY g.nombre',
            [$actividad]
        );
    }

    /** Actividades PUBLICADAS en los grupos activos del estudiante (RF-04). @return list<array<string, mixed>> */
    public function publicadasParaEstudiante(int $estudiante): array
    {
        return $this->todos(
            'SELECT DISTINCT ' . self::CAMPOS . ',
                    (SELECT COUNT(*) FROM intentos i WHERE i.actividad_id = a.id AND i.usuario_id = ?) AS intentos,
                    (SELECT r.puntaje FROM intentos i JOIN resultados r ON r.intento_id = i.id
                      WHERE i.actividad_id = a.id AND i.usuario_id = ?
                      ORDER BY i.finalizado_en DESC LIMIT 1) AS ultimo_puntaje
               ' . self::DESDE . '
               JOIN actividad_grupo ag ON ag.actividad_id = a.id
               JOIN usuario_grupo ug ON ug.grupo_id = ag.grupo_id AND ug.usuario_id = ? AND ug.activo
              WHERE e.codigo = \'PUBLICADA\'
              ORDER BY n.orden, a.titulo',
            [$estudiante, $estudiante, $estudiante]
        );
    }

    public function visibleParaEstudiante(int $actividad, int $estudiante, ?PDO $pdo = null): bool
    {
        return (bool) $this->valor(
            'SELECT COUNT(*) FROM actividades a
               JOIN estados_actividad e ON e.id = a.estado_id AND e.codigo = \'PUBLICADA\'
               JOIN actividad_grupo ag ON ag.actividad_id = a.id
               JOIN usuario_grupo ug ON ug.grupo_id = ag.grupo_id AND ug.usuario_id = ? AND ug.activo
              WHERE a.id = ?',
            [$estudiante, $actividad],
            $pdo
        );
    }

    /** @return list<array<string, mixed>> */
    public function catalogo(string $tabla): array
    {
        return match ($tabla) {
            'niveles' => $this->todos('SELECT codigo, nombre, orden FROM niveles_dificultad ORDER BY orden'),
            'categorias' => $this->todos('SELECT codigo, nombre FROM categorias ORDER BY nombre'),
            // D-3: solo las activas se pueden asignar (las desactivadas siguen en preguntas viejas).
            'habilidades' => $this->todos(
                'SELECT codigo, nombre, descripcion FROM habilidades WHERE activa ORDER BY nombre'
            ),
            default => throw new \LogicException('Catálogo desconocido'),
        };
    }
}
