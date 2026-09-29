<?php

declare(strict_types=1);

namespace Atlas\Tests\Database;

/**
 * Análisis grupal: RF-18 (sp_analisis_grupal y vistas del panel), DEC-11.
 */
final class AnalisisGrupalTest extends DatabaseTestCase
{
    public function testAgregadosDelGrupoConDatosConocidos(): void
    {
        $docente = self::crearUsuario('docente');
        $grupo = self::crearGrupo();
        self::asignar($docente, $grupo);
        [$actividad, $mapa] = self::crearActividad($docente, 4);
        self::publicar($actividad, $grupo, $docente);
        $preguntas = array_keys($mapa);

        // Cuatro estudiantes con 1, 2, 3 y 4 correctas → 25, 50, 75, 100.
        foreach ([1, 2, 3, 4] as $correctas) {
            $e = self::crearUsuario('estudiante');
            self::asignar($e, $grupo);
            if ($correctas === 4) {
                // Intento previo con 0 correctas: no debe contar (se toma el último intento).
                $previo = self::iniciarIntento($e, $actividad);
                foreach ($preguntas as $p) {
                    self::responder($previo, $p, $mapa[$p][1]);
                }
                self::finalizar($previo, '2026-09-10 10:00:00');
            }
            $intento = self::iniciarIntento($e, $actividad);
            foreach ($preguntas as $i => $p) {
                self::responder($intento, $p, $i < $correctas ? $mapa[$p][0] : $mapa[$p][1]);
            }
            self::finalizar($intento, '2026-09-15 10:00:00');
        }
        $st = self::pdo()->prepare('CALL sp_analisis_grupal(?, ?, ?, ?)');
        $st->execute([$grupo, $actividad, '2026-09-01', '2026-09-30']);
        $fila = $st->fetch();
        $st->closeCursor();

        $this->assertSame(4, (int) $fila['n_estudiantes']);
        $this->assertSame('62.50', $fila['promedio']);
        $this->assertSame('62.50', $fila['mediana']);
        $this->assertSame('25.00', $fila['minimo']);
        $this->assertSame('100.00', $fila['maximo']);
    }

    public function testElDocenteNoCuentaComoEstudianteEnElGrupo(): void
    {
        $docente = self::crearUsuario('docente');
        $grupo = self::crearGrupo();
        self::asignar($docente, $grupo);
        [$actividad] = self::crearActividad($docente, 1);
        self::publicar($actividad, $grupo, $docente);

        $st = self::pdo('atlas_app')->prepare('CALL sp_analisis_grupal(?, ?, ?, ?)');
        $st->execute([$grupo, $actividad, '2026-09-01', '2026-09-30']);
        $fila = $st->fetch();
        $st->closeCursor();
        $this->assertSame(0, (int) $fila['n_estudiantes']);
        $this->assertNull($fila['promedio']);
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
