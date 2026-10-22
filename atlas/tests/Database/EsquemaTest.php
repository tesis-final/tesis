<?php

declare(strict_types=1);

namespace Atlas\Tests\Database;

/**
 * Estructura del modelo: OBJ-04, BD-02, BD-06 (PDF §27, Tabla 19, Tabla 20).
 */
final class EsquemaTest extends DatabaseTestCase
{
    private const TABLAS = [
        'instituciones', 'roles', 'permisos', 'rol_permiso', 'usuarios', 'grupos_clase', 'usuario_grupo',
        'niveles_dificultad', 'categorias', 'estados_actividad', 'actividades', 'preguntas', 'opciones',
        'transiciones_actividad', 'actividad_grupo',
        'intentos', 'respuestas', 'interacciones', 'resultados',
        'perfiles_aprendizaje', 'indicadores', 'reglas_analisis', 'recomendaciones', 'recomendacion_regla',
        'analisis_grupal', 'agrupamientos',
        'auditoria', 'conversaciones', 'registro_respaldos',
        // Hito 2 (migración 003)
        'habilidades', 'pregunta_habilidad',
    ];

    public function testExistenLas31TablasDelModeloYAlMenos15(): void
    {
        $tablas = self::pdo()->query(
            "SELECT table_name FROM information_schema.tables
              WHERE table_schema = 'atlas_db' AND table_type = 'BASE TABLE' ORDER BY table_name"
        )->fetchAll(\PDO::FETCH_COLUMN);

        sort($tablas);
        $esperadas = self::TABLAS;
        sort($esperadas);
        $this->assertSame($esperadas, $tablas);
        $this->assertGreaterThanOrEqual(15, count($tablas), 'Tabla 5, objetivo 4: mínimo 15 tablas');
    }

    public function testTodasLasTablasSonInnoDbParaIntegridadReferencial(): void
    {
        $otras = (int) self::valor(
            "SELECT COUNT(*) FROM information_schema.tables
              WHERE table_schema = 'atlas_db' AND table_type = 'BASE TABLE' AND engine <> 'InnoDB'"
        );
        $this->assertSame(0, $otras);
    }

    public function testCadaColumnaTerminadaEnIdTieneClaveForanea(): void
    {
        // Toda columna *_id (salvo PK) debe estar respaldada por una FK (Tabla 20).
        $sinFk = self::pdo()->query(
            "SELECT CONCAT(c.table_name, '.', c.column_name)
               FROM information_schema.columns c
               JOIN information_schema.tables t
                 ON t.table_schema = c.table_schema AND t.table_name = c.table_name AND t.table_type = 'BASE TABLE'
              WHERE c.table_schema = 'atlas_db'
                AND c.column_name LIKE '%\\_id'
                AND c.column_name <> 'recurso_id' -- auditoria: identificador libre del recurso, no FK
                AND NOT EXISTS (
                  SELECT 1 FROM information_schema.key_column_usage k
                   WHERE k.table_schema = c.table_schema AND k.table_name = c.table_name
                     AND k.column_name = c.column_name AND k.referenced_table_name IS NOT NULL)"
        )->fetchAll(\PDO::FETCH_COLUMN);

        $this->assertSame([], $sinFk);
    }

    public function testIndiceCompuestoUsuarioActividadEnIntentos(): void
    {
        $columnas = self::pdo()->query(
            "SELECT column_name FROM information_schema.statistics
              WHERE table_schema = 'atlas_db' AND table_name = 'intentos'
                AND index_name = 'ix_intentos_usuario_actividad' ORDER BY seq_in_index"
        )->fetchAll(\PDO::FETCH_COLUMN);

        $this->assertSame(['usuario_id', 'actividad_id'], $columnas);
    }

    public function testVistasProcedimientoYTriggersPresentes(): void
    {
        $vistas = self::pdo()->query(
            "SELECT table_name FROM information_schema.views WHERE table_schema = 'atlas_db' ORDER BY table_name"
        )->fetchAll(\PDO::FETCH_COLUMN);
        $this->assertSame([
            'v_distribucion_puntajes', 'v_evolucion_estudiante', 'v_preguntas_error',
            'v_recomendaciones_riesgo', 'v_resultados_detalle',
        ], $vistas);

        // Acta D-4 (004): la base no calcula; no quedan procedimientos almacenados.
        $this->assertSame(0, (int) self::valor(
            "SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'atlas_db'"
        ));
        $this->assertGreaterThanOrEqual(15, (int) self::valor(
            "SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema = 'atlas_db'"
        ));
    }

    public function testCatalogosSemilla(): void
    {
        $this->assertSame(3, (int) self::valor('SELECT COUNT(*) FROM roles'));
        $this->assertSame(5, (int) self::valor('SELECT COUNT(*) FROM estados_actividad'));
        $this->assertSame(
            ['R01', 'R02', 'R03', 'R04', 'R05', 'R06', 'R07', 'R08'],
            self::pdo()->query('SELECT codigo FROM reglas_analisis ORDER BY codigo')->fetchAll(\PDO::FETCH_COLUMN),
            'Tabla 5, objetivo 5: al menos ocho reglas documentadas (DEC-23)'
        );
    }

    public function testNingunaVistaExponeCorreoNiHash(): void
    {
        $sensibles = (int) self::valor(
            "SELECT COUNT(*) FROM information_schema.columns c
               JOIN information_schema.views v ON v.table_schema = c.table_schema AND v.table_name = c.table_name
              WHERE c.table_schema = 'atlas_db' AND (c.column_name LIKE '%correo%' OR c.column_name LIKE '%hash%')"
        );
        $this->assertSame(0, $sensibles, 'RNF-14: las vistas de reporte no exponen datos no necesarios');
    }
}
