<?php

declare(strict_types=1);

namespace Atlas\Repositories;

/**
 * Datos del motor de análisis Nivel 1: perfiles, indicadores, reglas y
 * recomendaciones con su trazabilidad (RF-10, RF-12, §27.3).
 */
final class AnalisisRepository extends Repository
{
    /** @return array<string, mixed> */
    public function contextoIntento(int $intento): array
    {
        return $this->uno(
            'SELECT i.id, i.usuario_id, i.actividad_id, i.finalizado_en, a.categoria_id, n.orden AS nivel_orden
               FROM intentos i JOIN actividades a ON a.id = i.actividad_id
               JOIN niveles_dificultad n ON n.id = a.nivel_id WHERE i.id = ?',
            [$intento]
        ) ?? throw new \RuntimeException("Intento {$intento} inexistente");
    }

    /** @return list<array{numero: int, estado: string, puntaje: float|null, duracion_seg: int|null, id: int}> */
    public function intentosDeActividad(int $estudiante, int $actividad): array
    {
        return array_map(fn ($f) => [
            'id' => (int) $f['id'],
            'numero' => (int) $f['numero_intento'],
            'estado' => $f['estado'],
            'puntaje' => $f['puntaje'] !== null ? (float) $f['puntaje'] : null,
            'duracion_seg' => $f['duracion_seg'] !== null ? (int) $f['duracion_seg'] : null,
        ], $this->todos(
            'SELECT i.id, i.numero_intento, i.estado, r.puntaje, i.duracion_seg
               FROM intentos i LEFT JOIN resultados r ON r.intento_id = i.id
              WHERE i.usuario_id = ? AND i.actividad_id = ? ORDER BY i.numero_intento',
            [$estudiante, $actividad]
        ));
    }

    /**
     * Duración media de los intentos finalizados de la actividad dentro de los grupos
     * del estudiante donde está publicada (referencia de la eficiencia).
     *
     * @return array{media: float|null, n: int}
     */
    public function duracionGrupo(int $estudiante, int $actividad): array
    {
        $fila = $this->uno(
            "SELECT AVG(i.duracion_seg) AS media, COUNT(*) AS n
               FROM intentos i
              WHERE i.actividad_id = ? AND i.estado = 'FINALIZADO' AND i.duracion_seg > 0
                AND i.usuario_id IN (
                  SELECT ug2.usuario_id FROM usuario_grupo ug2
                   WHERE ug2.activo AND ug2.grupo_id IN (
                     SELECT ug.grupo_id FROM usuario_grupo ug
                       JOIN actividad_grupo ag ON ag.grupo_id = ug.grupo_id AND ag.actividad_id = ?
                      WHERE ug.usuario_id = ? AND ug.activo))",
            [$actividad, $actividad, $estudiante]
        );

        return ['media' => $fila['media'] !== null ? (float) $fila['media'] : null, 'n' => (int) $fila['n']];
    }

    /**
     * Agregados de la categoría en el período (regla R08): puntaje medio del último
     * intento finalizado de cada actividad de la categoría y cantidad de actividades.
     *
     * @return array{puntaje_medio_categoria: float|null, actividades_categoria: int}
     */
    public function agregadosCategoria(int $estudiante, int $categoria, string $desde, string $hasta): array
    {
        $fila = $this->uno(
            "SELECT AVG(puntaje) AS medio, COUNT(*) AS n FROM (
               SELECT r.puntaje, ROW_NUMBER() OVER (
                   PARTITION BY i.actividad_id ORDER BY i.finalizado_en DESC,
                   i.id DESC
               ) AS rn
                 FROM intentos i JOIN resultados r ON r.intento_id = i.id
                 JOIN actividades a ON a.id = i.actividad_id
                WHERE i.usuario_id = ? AND a.categoria_id = ? AND i.estado = 'FINALIZADO'
                  AND DATE(i.finalizado_en) BETWEEN ? AND ?
             ) x WHERE rn = 1",
            [$estudiante, $categoria, $desde, $hasta]
        );

        return [
            'puntaje_medio_categoria' => $fila['medio'] !== null ? round((float) $fila['medio'], 2) : null,
            'actividades_categoria' => (int) $fila['n'],
        ];
    }

    public function perfil(int $estudiante, string $desde, string $hasta): int
    {
        $this->afectadas(
            'INSERT INTO perfiles_aprendizaje (usuario_id, periodo_inicio, periodo_fin) VALUES (?, ?, ?)
             ON DUPLICATE KEY UPDATE actualizado_en = CURRENT_TIMESTAMP(3)',
            [$estudiante, $desde, $hasta]
        );

        return (int) $this->valor(
            'SELECT id FROM perfiles_aprendizaje WHERE usuario_id = ? AND periodo_inicio = ?',
            [$estudiante, $desde]
        );
    }

    public function guardarIndicador(int $perfil, int $actividad, string $tipo, float $valor): void
    {
        $this->ejecutar(
            "INSERT INTO indicadores (perfil_id, actividad_id, tipo, valor, origen) VALUES (?, ?, ?, ?, 'NIVEL1')",
            [$perfil, $actividad, $tipo, $valor]
        );
    }

    /** @return list<array<string, mixed>> reglas activas con la condición decodificada */
    public function reglasActivas(): array
    {
        return array_map(fn ($r) => $this->decodificarRegla($r), $this->todos(
            'SELECT id, codigo, nombre, descripcion, tipo, condicion, sugerencia, recomendacion_plantilla, prioridad,
                    activa, version FROM reglas_analisis WHERE activa ORDER BY prioridad DESC, codigo'
        ));
    }

    /** @return list<array<string, mixed>> */
    public function reglas(): array
    {
        return array_map(fn ($r) => $this->decodificarRegla($r), $this->todos(
            'SELECT id, codigo, nombre, descripcion, tipo, condicion, sugerencia, recomendacion_plantilla, prioridad,
                    activa, version, actualizado_por, actualizado_en FROM reglas_analisis ORDER BY codigo'
        ));
    }

    /** @return array<string, mixed>|null */
    public function regla(string $codigo): ?array
    {
        $fila = $this->uno(
            'SELECT id, codigo, nombre, descripcion, tipo, condicion, sugerencia, recomendacion_plantilla, prioridad,
                    activa, version, actualizado_por, actualizado_en FROM reglas_analisis WHERE codigo = ?',
            [$codigo]
        );

        return $fila === null ? null : $this->decodificarRegla($fila);
    }

    /** @param array<string, mixed> $condicion */
    public function actualizarRegla(string $codigo, array $condicion, bool $activa, int $usuario): void
    {
        $this->afectadas(
            'UPDATE reglas_analisis SET condicion = ?, activa = ?, actualizado_por = ? WHERE codigo = ?',
            [json_encode($condicion), (int) $activa, $usuario, $codigo]
        );
    }

    /**
     * Actividad PUBLICADA en los grupos del estudiante, de la categoría y el nivel
     * pedidos, que el estudiante todavía no finalizó.
     */
    public function actividadSugerida(int $estudiante, int $categoria, int $nivelOrden, int $excluir): ?int
    {
        $id = $this->valor(
            "SELECT a.id FROM actividades a
               JOIN niveles_dificultad n ON n.id = a.nivel_id AND n.orden = ?
               JOIN estados_actividad e ON e.id = a.estado_id AND e.codigo = 'PUBLICADA'
               JOIN actividad_grupo ag ON ag.actividad_id = a.id
               JOIN usuario_grupo ug ON ug.grupo_id = ag.grupo_id AND ug.usuario_id = ? AND ug.activo
              WHERE a.categoria_id = ? AND a.id <> ?
                AND NOT EXISTS (SELECT 1 FROM intentos i WHERE i.actividad_id = a.id AND i.usuario_id = ?
                                   AND i.estado = 'FINALIZADO')
              ORDER BY a.id LIMIT 1",
            [$nivelOrden, $estudiante, $categoria, $excluir, $estudiante]
        );

        return $id === false ? null : (int) $id;
    }

    public function existeNivel(int $orden): bool
    {
        return (bool) $this->valor('SELECT COUNT(*) FROM niveles_dificultad WHERE orden = ?', [$orden]);
    }

    public function tituloActividad(int $id): string
    {
        return (string) $this->valor('SELECT titulo FROM actividades WHERE id = ?', [$id]);
    }

    public function crearRecomendacion(int $perfil, ?int $actividadSugerida, string $texto): int
    {
        return $this->ejecutar(
            'INSERT INTO recomendaciones (perfil_id, actividad_sugerida_id, texto) VALUES (?, ?, ?)',
            [$perfil, $actividadSugerida, mb_substr($texto, 0, 1000)]
        );
    }

    /** @param array<string, mixed> $valores */
    public function vincularRegla(int $recomendacion, int $regla, int $version, array $valores): void
    {
        $this->ejecutar(
            'INSERT INTO recomendacion_regla (recomendacion_id, regla_id, version_regla, valores_entrada)
             VALUES (?, ?, ?, ?)',
            [
                $recomendacion,
                $regla,
                $version,
                json_encode($valores, JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION)
            ]
        );
    }

    /** @return list<array<string, mixed>> indicadores del perfil (último valor por actividad y tipo) */
    public function indicadoresDelPerfil(int $perfil): array
    {
        return $this->todos(
            "SELECT x.actividad_id, a.titulo AS actividad, c.nombre AS categoria, x.tipo, x.valor, x.calculado_en
               FROM (
                 SELECT i.*, ROW_NUMBER() OVER (PARTITION BY i.actividad_id, i.tipo ORDER BY i.id DESC) AS rn
                   FROM indicadores i WHERE i.perfil_id = ? AND i.origen = 'NIVEL1'
               ) x
               JOIN actividades a ON a.id = x.actividad_id
               JOIN categorias c ON c.id = a.categoria_id
              WHERE x.rn = 1 ORDER BY x.calculado_en DESC, x.actividad_id, x.tipo",
            [$perfil]
        );
    }

    /** @return list<array<string, mixed>> */
    public function indicadoresNivel2(int $perfil): array
    {
        return $this->todos(
            "SELECT tipo, valor, agrupamiento_id, calculado_en FROM indicadores
              WHERE perfil_id = ? AND origen = 'NIVEL2' ORDER BY id DESC LIMIT 2",
            [$perfil]
        );
    }

    /** @return array<string, mixed>|null */
    public function perfilDe(int $estudiante, string $desde): ?array
    {
        return $this->uno(
            'SELECT id, usuario_id, periodo_inicio, periodo_fin, actualizado_en FROM perfiles_aprendizaje
              WHERE usuario_id = ? AND periodo_inicio = ?',
            [$estudiante, $desde]
        );
    }

    /** @return list<array<string, mixed>> */
    public function recomendacionesDelPerfil(int $perfil): array
    {
        $recs = $this->todos(
            'SELECT r.id, r.texto, r.generado_en, r.actividad_sugerida_id, a.titulo AS actividad_sugerida
               FROM recomendaciones r LEFT JOIN actividades a ON a.id = r.actividad_sugerida_id
              WHERE r.perfil_id = ? ORDER BY r.generado_en DESC, r.id DESC LIMIT 20',
            [$perfil]
        );
        foreach ($recs as &$r) {
            $r['reglas'] = $this->todos(
                'SELECT ra.codigo, ra.nombre, ra.tipo FROM recomendacion_regla rr
                   JOIN reglas_analisis ra ON ra.id = rr.regla_id WHERE rr.recomendacion_id = ? ORDER BY ra.codigo',
                [$r['id']]
            );
        }

        return $recs;
    }

    /** @return array<string, mixed>|null recomendación con estudiante (para verificar alcance) */
    public function recomendacion(int $id): ?array
    {
        return $this->uno(
            'SELECT r.id, r.texto, r.generado_en, r.actividad_sugerida_id, a.titulo AS actividad_sugerida,
                    p.usuario_id AS estudiante_id, p.periodo_inicio, p.periodo_fin
               FROM recomendaciones r JOIN perfiles_aprendizaje p ON p.id = r.perfil_id
               LEFT JOIN actividades a ON a.id = r.actividad_sugerida_id WHERE r.id = ?',
            [$id]
        );
    }

    /** @return list<array<string, mixed>> reglas + versión + datos exactos usados */
    public function fundamento(int $recomendacion): array
    {
        return array_map(function ($f) {
            $f['valores_entrada'] = json_decode($f['valores_entrada'], true);
            $f['condicion_actual'] = json_decode($f['condicion_actual'], true);

            return $f;
        }, $this->todos(
            'SELECT ra.codigo, ra.nombre, ra.descripcion, ra.tipo, rr.version_regla, ra.version AS version_actual,
                    ra.condicion AS condicion_actual, rr.valores_entrada
               FROM recomendacion_regla rr JOIN reglas_analisis ra ON ra.id = rr.regla_id
              WHERE rr.recomendacion_id = ? ORDER BY ra.codigo',
            [$recomendacion]
        ));
    }

    /** @param array<string, mixed> $r @return array<string, mixed> */
    private function decodificarRegla(array $r): array
    {
        $r['id'] = (int) $r['id'];
        $r['version'] = (int) $r['version'];
        $r['prioridad'] = (int) $r['prioridad'];
        $r['activa'] = (bool) $r['activa'];
        $r['condicion'] = json_decode($r['condicion'], true);
        $r['sugerencia'] = json_decode($r['sugerencia'], true);

        return $r;
    }
}
