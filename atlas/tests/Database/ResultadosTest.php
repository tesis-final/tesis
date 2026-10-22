<?php

declare(strict_types=1);

namespace Atlas\Tests\Database;

/**
 * Intentos y resultados: RF-07, RF-08, RF-09. Desde 004 (acta D-4) el puntaje lo
 * calcula la aplicación (ver tests/Unit/IndicadoresTest y tests/Api/ResolucionTest);
 * la base guarda el resultado y protege su integridad.
 */
final class ResultadosTest extends DatabaseTestCase
{
    /** @return array{0:int,1:int,2:array<int, array{0:int,1:int}>} */
    private function escenario(int $preguntas = 4): array
    {
        $docente = self::crearUsuario('docente');
        $estudiante = self::crearUsuario('estudiante');
        $grupo = self::crearGrupo();
        self::asignar($estudiante, $grupo);
        [$actividad, $mapa] = self::crearActividad($docente, $preguntas);
        self::publicar($actividad, $grupo, $docente);

        return [$estudiante, $actividad, $mapa];
    }

    public function testLaBaseNoCalculaElResultado(): void
    {
        // D-4: cerrar el intento en la base ya no genera el resultado (no hay trigger que calcule).
        [$estudiante, $actividad, $mapa] = $this->escenario(2);
        $intento = self::iniciarIntento($estudiante, $actividad);
        $pregunta = array_key_first($mapa);
        self::responder($intento, $pregunta, $mapa[$pregunta][0]);
        self::ejecutar(
            "UPDATE intentos SET estado = 'FINALIZADO', finalizado_en = NOW(3), duracion_seg = 30 WHERE id = ?",
            [$intento]
        );

        $this->assertSame(0, (int) self::valor('SELECT COUNT(*) FROM resultados WHERE intento_id = ?', [$intento]));
        $this->assertSame(0, (int) self::valor(
            "SELECT COUNT(*) FROM information_schema.triggers
              WHERE trigger_schema = 'atlas_db' AND trigger_name = 'trg_intentos_finalizar'"
        ));
    }

    public function testUnSoloResultadoPorIntentoYCoherente(): void
    {
        [$estudiante, $actividad, $mapa] = $this->escenario(4);
        $intento = self::iniciarIntento($estudiante, $actividad);
        $i = 0;
        foreach ($mapa as $pregunta => [$ok, $mal]) {
            self::responder($intento, $pregunta, $i++ < 3 ? $ok : $mal); // 3 de 4 correctas
        }
        self::finalizar($intento);
        $this->assertSame('75.00', self::valor('SELECT puntaje FROM resultados WHERE intento_id = ?', [$intento]));

        // Integridad que sigue en la base: un resultado por intento y correctas ≤ total.
        $this->assertFalla(
            'INSERT INTO resultados (intento_id, correctas, total_preguntas, puntaje) VALUES (?, 4, 4, 100)',
            [$intento],
            contiene: 'uq_resultados_intento'
        );
        [, $otraActividad] = $this->escenario(1);
        $otro = self::iniciarIntento($estudiante, $otraActividad);
        $this->assertFalla(
            'INSERT INTO resultados (intento_id, correctas, total_preguntas, puntaje) VALUES (?, 5, 4, 100)',
            [$otro],
            contiene: 'ck_resultados_correctas'
        );
    }

    public function testIntentoAbandonadoNoGeneraResultado(): void
    {
        [$estudiante, $actividad] = $this->escenario();
        $intento = self::iniciarIntento($estudiante, $actividad);
        self::ejecutar(
            "UPDATE intentos SET estado = 'ABANDONADO', finalizado_en = NOW(3), duracion_seg = 42 WHERE id = ?",
            [$intento]
        );

        $this->assertSame(0, (int) self::valor('SELECT COUNT(*) FROM resultados WHERE intento_id = ?', [$intento]));
        $this->assertSame(
            42,
            (int) self::valor('SELECT duracion_seg FROM intentos WHERE id = ?', [$intento]),
            'RF-09: el intento interrumpido registra el tiempo hasta la interrupción'
        );
    }

    public function testTiempoActivoNoSuperaAlTotal(): void
    {
        // D-8 (004): el tiempo activo lo calcula la app; la base garantiza que sea coherente.
        [$estudiante, $actividad] = $this->escenario();
        $intento = self::iniciarIntento($estudiante, $actividad);
        $this->assertFalla(
            "UPDATE intentos SET estado = 'ABANDONADO', finalizado_en = NOW(3), duracion_seg = 60,
                    duracion_activa_seg = 61 WHERE id = ?",
            [$intento],
            contiene: 'ck_intentos_duracion_activa'
        );
    }

    public function testCadaInicioEsUnIntentoDistinguible(): void
    {
        [$estudiante, $actividad] = $this->escenario();
        $a = self::iniciarIntento($estudiante, $actividad);
        self::finalizar($a);
        $b = self::iniciarIntento($estudiante, $actividad);

        $filas = self::pdo()->query(
            "SELECT numero_intento, estado FROM intentos WHERE usuario_id = {$estudiante} ORDER BY numero_intento"
        )->fetchAll();
        $this->assertSame([[1, 'FINALIZADO'], [2, 'EN_CURSO']], array_map(
            fn ($f) => [(int) $f['numero_intento'], $f['estado']],
            $filas
        ));
        $this->assertNotSame($a, $b);
    }

    public function testIntentoCerradoNoSeReabre(): void
    {
        [$estudiante, $actividad] = $this->escenario();
        $intento = self::iniciarIntento($estudiante, $actividad);
        self::finalizar($intento);

        $this->assertFalla(
            "UPDATE intentos SET estado = 'EN_CURSO', finalizado_en = NULL, duracion_seg = NULL WHERE id = ?",
            [$intento],
            contiene: 'intento cerrado'
        );
    }

    public function testNoSeRespondeUnIntentoCerradoNiOtraActividad(): void
    {
        [$estudiante, $actividad, $mapa] = $this->escenario(1);
        [, $actividad2, $mapa2] = $this->escenario(1);
        $intento = self::iniciarIntento($estudiante, $actividad);
        $p2 = array_key_first($mapa2);

        $this->assertFalla(
            'INSERT INTO respuestas (intento_id, pregunta_id, opcion_id) VALUES (?, ?, ?)',
            [$intento, $p2, $mapa2[$p2][0]],
            contiene: 'fuera del intento'
        );

        self::finalizar($intento);
        $p = array_key_first($mapa);
        $this->assertFalla(
            'INSERT INTO respuestas (intento_id, pregunta_id, opcion_id) VALUES (?, ?, ?)',
            [$intento, $p, $mapa[$p][0]],
            contiene: 'fuera del intento'
        );
    }
}
