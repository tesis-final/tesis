<?php

declare(strict_types=1);

namespace Atlas\Repositories;

use PDO;

/**
 * Consultas del panel docente sobre las vistas de reporte, con el usuario
 * atlas_read (Tabla 21). El filtro de alcance lo aplica siempre quien llama.
 */
final class ReporteRepository extends Repository
{
    private function lectura(): PDO
    {
        return $this->db->lectura();
    }

    /** @return list<array<string, mixed>> */
    public function distribucion(int $grupo, ?int $actividad): array
    {
        return $this->todos(
            'SELECT rango, SUM(cantidad) AS cantidad FROM v_distribucion_puntajes
              WHERE grupo_id = ? AND (? IS NULL OR actividad_id = ?) GROUP BY rango ORDER BY rango',
            [$grupo, $actividad, $actividad],
            $this->lectura()
        );
    }

    /**
     * Preguntas con mayor proporción de error del grupo en el período (RF-18, H26).
     * Arranca por el grupo en vez de materializar v_preguntas_error entera (E-BD-006:
     * ~41 ms contra ~490 ms) y respeta el período de la consulta guiada (D-5). La base
     * cuenta; la proporción y el orden los calcula PHP (D-4).
     *
     * @return list<array<string, mixed>>
     */
    public function preguntasConMasError(
        int $grupo,
        ?int $actividad,
        string $desde,
        string $hasta,
        int $limite = 5
    ): array {
        $filas = $this->todos(
            "SELECT p.actividad_id, p.id AS pregunta_id, p.orden, p.enunciado,
                    COUNT(*) AS respuestas, SUM(o.es_correcta = FALSE) AS errores
               FROM actividad_grupo ag
               JOIN intentos i       ON i.actividad_id = ag.actividad_id AND i.estado = 'FINALIZADO'
               JOIN usuario_grupo ug ON ug.usuario_id = i.usuario_id AND ug.grupo_id = ag.grupo_id AND ug.activo
               JOIN respuestas res   ON res.intento_id = i.id
               JOIN preguntas p      ON p.id = res.pregunta_id
               JOIN opciones o       ON o.id = res.opcion_id
              WHERE ag.grupo_id = ? AND (? IS NULL OR ag.actividad_id = ?)
                AND DATE(i.finalizado_en) BETWEEN ? AND ?
              GROUP BY p.actividad_id, p.id, p.orden, p.enunciado",
            [$grupo, $actividad, $actividad, $desde, $hasta]
        );
        $salida = [];
        foreach ($filas as $f) {
            if ((int) $f['errores'] === 0) {
                continue;
            }
            $salida[] = [
                'actividad_id' => (int) $f['actividad_id'],
                'pregunta_id' => (int) $f['pregunta_id'],
                'orden' => (int) $f['orden'],
                'enunciado' => $f['enunciado'],
                'respuestas' => (int) $f['respuestas'],
                'errores' => (int) $f['errores'],
                'proporcion_error' => round((int) $f['errores'] / (int) $f['respuestas'], 4),
            ];
        }
        usort(
            $salida,
            fn ($a, $b) => [$b['proporcion_error'], $b['respuestas']] <=> [$a['proporcion_error'], $a['respuestas']]
        );

        return array_slice($salida, 0, max(1, min($limite, 50)));
    }

    /** @param list<int> $estudiantes @return list<array<string, mixed>> */
    public function riesgoEnPeriodo(array $estudiantes, string $desde, string $hasta): array
    {
        if ($estudiantes === []) {
            return [];
        }
        $marcas = implode(',', array_fill(0, count($estudiantes), '?'));

        return $this->todos(
            "SELECT estudiante_id, recomendacion_id, generado_en, regla_codigo, regla_nombre
               FROM v_recomendaciones_riesgo
              WHERE estudiante_id IN ({$marcas}) AND DATE(generado_en) BETWEEN ? AND ?
              ORDER BY generado_en DESC",
            [...$estudiantes, $desde, $hasta],
            $this->lectura()
        );
    }

    /** @return list<array<string, mixed>> */
    public function evolucion(int $estudiante, int $grupo): array
    {
        return $this->todos(
            'SELECT actividad_id, actividad_titulo, categoria, nivel, numero_intento, finalizado_en, puntaje
               FROM v_evolucion_estudiante WHERE estudiante_id = ? AND grupo_id = ? ORDER BY finalizado_en',
            [$estudiante, $grupo],
            $this->lectura()
        );
    }

    /**
     * Reporte filtrable por grupo, actividad y período (RF-13).
     *
     * @param list<int>|null $grupos grupos permitidos (null = todos, solo administrador)
     * @return array{filas: list<array<string, mixed>>, resumen: list<array<string, mixed>>}
     */
    public function resultados(?array $grupos, ?int $grupo, ?int $actividad, ?string $desde, ?string $hasta): array
    {
        $donde = ["estado = 'FINALIZADO'"];
        $params = [];
        if ($grupos !== null) {
            if ($grupos === []) {
                return ['filas' => [], 'resumen' => []];
            }
            $donde[] = 'grupo_id IN (' . implode(',', array_fill(0, count($grupos), '?')) . ')';
            array_push($params, ...$grupos);
        }
        foreach (['grupo_id' => $grupo, 'actividad_id' => $actividad] as $col => $v) {
            if ($v !== null) {
                $donde[] = "{$col} = ?";
                $params[] = $v;
            }
        }
        if ($desde !== null) {
            $donde[] = 'DATE(finalizado_en) >= ?';
            $params[] = $desde;
        }
        if ($hasta !== null) {
            $donde[] = 'DATE(finalizado_en) <= ?';
            $params[] = $hasta;
        }
        $where = implode(' AND ', $donde);
        $filas = $this->todos(
            "SELECT intento_id, estudiante_id, estudiante_nombre, estudiante_apellido, grupo_id, actividad_id,
                    actividad_titulo, nivel, categoria, numero_intento, finalizado_en, duracion_seg,
                    duracion_activa_seg, correctas, total_preguntas, puntaje
               FROM v_resultados_detalle WHERE {$where} ORDER BY finalizado_en DESC LIMIT 2000",
            $params,
            $this->lectura()
        );
        $resumen = $this->todos(
            "SELECT actividad_id, actividad_titulo, nivel, categoria, COUNT(*) AS intentos,
                    COUNT(DISTINCT estudiante_id) AS estudiantes, ROUND(AVG(puntaje), 2) AS promedio,
                    ROUND(AVG(duracion_seg), 0) AS duracion_media_seg,
                    ROUND(AVG(duracion_activa_seg), 0) AS duracion_activa_media_seg
               FROM v_resultados_detalle WHERE {$where}
              GROUP BY actividad_id, actividad_titulo, nivel, categoria ORDER BY actividad_titulo",
            $params,
            $this->lectura()
        );

        return ['filas' => $filas, 'resumen' => $resumen];
    }

    /**
     * Puntaje del último intento finalizado de cada estudiante del grupo en cada
     * actividad del período (p_actividad null = todas). Solo lee: los agregados los
     * calcula ResumenGrupal en PHP (D-4).
     *
     * @return list<array{usuario_id: int, puntaje: float}>
     */
    public function ultimosPuntajes(int $grupo, ?int $actividad, string $desde, string $hasta): array
    {
        $filas = $this->todos(
            "SELECT usuario_id, puntaje FROM (
                SELECT i.usuario_id, r.puntaje,
                       ROW_NUMBER() OVER (PARTITION BY i.usuario_id, i.actividad_id
                                          ORDER BY i.finalizado_en DESC, i.id DESC) AS rn
                  FROM intentos i
                  JOIN resultados r       ON r.intento_id = i.id
                  JOIN usuarios u         ON u.id = i.usuario_id
                  JOIN roles ro           ON ro.id = u.rol_id AND ro.codigo = 'ESTUDIANTE'
                  JOIN usuario_grupo ug   ON ug.usuario_id = i.usuario_id AND ug.grupo_id = ? AND ug.activo
                  JOIN actividad_grupo ag ON ag.actividad_id = i.actividad_id AND ag.grupo_id = ?
                 WHERE i.estado = 'FINALIZADO'
                   AND DATE(i.finalizado_en) BETWEEN ? AND ?
                   AND (? IS NULL OR i.actividad_id = ?)
             ) x WHERE rn = 1",
            [$grupo, $grupo, $desde, $hasta, $actividad, $actividad]
        );

        return array_map(
            fn ($f) => ['usuario_id' => (int) $f['usuario_id'], 'puntaje' => (float) $f['puntaje']],
            $filas
        );
    }

    /**
     * Una fila por (pregunta, habilidad que mide) del último intento finalizado de cada
     * estudiante en cada actividad del período, con si la acertó (sin responder = no).
     * Solo lee: IndicadoresHabilidad calcula los porcentajes (D-3, D-4).
     *
     * @param list<int> $estudiantes
     * @param int|null  $grupo si se indica, solo actividades publicadas en ese grupo
     * @return list<array{usuario_id: int, codigo: string, nombre: string, acerto: bool}>
     */
    public function aciertosPorHabilidad(array $estudiantes, string $desde, string $hasta, ?int $grupo = null): array
    {
        if ($estudiantes === []) {
            return [];
        }
        $marcas = implode(',', array_fill(0, count($estudiantes), '?'));
        $filtroGrupo = $grupo === null
            ? ''
            : 'JOIN actividad_grupo ag ON ag.actividad_id = i.actividad_id AND ag.grupo_id = ?';
        $filas = $this->todos(
            "SELECT u.usuario_id, h.codigo, h.nombre, COALESCE(o.es_correcta, FALSE) AS acerto
               FROM (SELECT i.id, i.usuario_id, i.actividad_id,
                            ROW_NUMBER() OVER (PARTITION BY i.usuario_id, i.actividad_id
                                               ORDER BY i.finalizado_en DESC, i.id DESC) AS rn
                       FROM intentos i {$filtroGrupo}
                      WHERE i.estado = 'FINALIZADO' AND i.usuario_id IN ({$marcas})
                        AND DATE(i.finalizado_en) BETWEEN ? AND ?) u
               JOIN preguntas p           ON p.actividad_id = u.actividad_id
               JOIN pregunta_habilidad ph ON ph.pregunta_id = p.id
               JOIN habilidades h         ON h.id = ph.habilidad_id
               LEFT JOIN respuestas r     ON r.intento_id = u.id AND r.pregunta_id = p.id
               LEFT JOIN opciones o       ON o.id = r.opcion_id
              WHERE u.rn = 1",
            [...($grupo === null ? [] : [$grupo]), ...$estudiantes, $desde, $hasta]
        );

        return array_map(fn ($f) => [
            'usuario_id' => (int) $f['usuario_id'],
            'codigo' => $f['codigo'],
            'nombre' => $f['nombre'],
            'acerto' => (bool) $f['acerto'],
        ], $filas);
    }

    /**
     * Guarda el análisis grupal calculado (historial en `analisis_grupal`).
     *
     * @param array{n_estudiantes: int, promedio: float|null, mediana: float|null,
     *              minimo: float|null, maximo: float|null} $resumen
     */
    public function guardarAnalisisGrupal(
        int $grupo,
        ?int $actividad,
        string $desde,
        string $hasta,
        array $resumen
    ): void {
        $this->ejecutar(
            'INSERT INTO analisis_grupal
               (grupo_id, actividad_id, periodo_inicio, periodo_fin, n_estudiantes, promedio, mediana, minimo, maximo)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [$grupo, $actividad, $desde, $hasta, $resumen['n_estudiantes'], $resumen['promedio'],
             $resumen['mediana'], $resumen['minimo'], $resumen['maximo']]
        );
    }

    /** @return array<string, mixed>|null último agrupamiento del Nivel 2 para el grupo y período */
    public function agrupamiento(int $grupo, string $desde): ?array
    {
        $a = $this->uno(
            'SELECT id, k, silueta, n_muestras, modelo_version, generado_en FROM agrupamientos
              WHERE grupo_id = ? AND periodo_inicio = ? ORDER BY id DESC LIMIT 1',
            [$grupo, $desde]
        );
        if ($a === null) {
            return null;
        }
        $a['miembros'] = $this->todos(
            "SELECT p.usuario_id AS estudiante_id, CAST(i.valor AS UNSIGNED) AS cluster
               FROM indicadores i JOIN perfiles_aprendizaje p ON p.id = i.perfil_id
              WHERE i.agrupamiento_id = ? AND i.tipo = 'CLUSTER'",
            [$a['id']]
        );

        return $a;
    }
}
