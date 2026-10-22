<?php

declare(strict_types=1);

namespace Atlas\Tests\Database;

/**
 * Análisis grupal: RF-18 y vistas del panel. Desde 004 (acta D-4) los agregados
 * los calcula PHP (tests/Unit/ResumenGrupalTest, tests/Api/PanelGrupalTest);
 * la base guarda el historial en `analisis_grupal` y protege su integridad.
 */
final class AnalisisGrupalTest extends DatabaseTestCase
{
    public function testLaBaseNoTieneProcedimientosDeCalculo(): void
    {
        $this->assertSame(0, (int) self::valor(
            "SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema = 'atlas_db'"
        ));
    }

    public function testAppAgregaAnalisisGrupalPeroNoLoAltera(): void
    {
        $grupo = self::crearGrupo();
        $id = self::ejecutar(
            "INSERT INTO analisis_grupal (grupo_id, periodo_inicio, periodo_fin, n_estudiantes, promedio, mediana,
                                          minimo, maximo)
             VALUES (?, '2026-09-01', '2026-09-30', 4, 62.5, 62.5, 25, 100)",
            [$grupo],
            'atlas_app'
        );
        $this->assertGreaterThan(0, $id);
        $this->assertFalla(
            'UPDATE analisis_grupal SET promedio = 100 WHERE id = ?',
            [$id],
            usuario: 'atlas_app',
            contiene: 'command denied'
        );
        $this->assertFalla(
            'DELETE FROM analisis_grupal WHERE id = ?',
            [$id],
            usuario: 'atlas_app',
            contiene: 'command denied'
        );
        $this->assertFalla(
            "INSERT INTO analisis_grupal (grupo_id, periodo_inicio, periodo_fin, n_estudiantes, promedio)
             VALUES (?, '2026-09-30', '2026-09-01', 1, 50)",
            [$grupo],
            usuario: 'atlas_app',
            contiene: 'ck_analisis_grupal_periodo'
        );
    }

    public function testPreguntasConMayorProporcionDeError(): void
    {
        $docente = self::crearUsuario('docente');
        $grupo = self::crearGrupo();
        [$actividad, $mapa] = self::crearActividad($docente, 2);
        self::publicar($actividad, $grupo, $docente);
        [$facil, $dificil] = array_keys($mapa);

        foreach (range(1, 3) as $_) {
            $e = self::crearUsuario('estudiante');
            self::asignar($e, $grupo);
            $intento = self::iniciarIntento($e, $actividad);
            self::responder($intento, $facil, $mapa[$facil][0]);
            self::responder($intento, $dificil, $mapa[$dificil][1]);
            self::finalizar($intento);
        }

        $filas = self::pdo('atlas_read')->query(
            "SELECT pregunta_id, proporcion_error FROM v_preguntas_error
              WHERE grupo_id = {$grupo} ORDER BY proporcion_error DESC"
        )->fetchAll();
        $this->assertSame($dificil, (int) $filas[0]['pregunta_id']);
        $this->assertSame('1.0000', $filas[0]['proporcion_error']);
        $this->assertSame('0.0000', $filas[1]['proporcion_error']);
    }
}
