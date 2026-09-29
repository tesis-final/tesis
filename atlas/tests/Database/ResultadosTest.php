<?php

declare(strict_types=1);

namespace Atlas\Tests\Database;

/**
 * Intentos y resultados: RF-07, RF-08, RF-09, §27.3 (trigger de resultados).
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

    public function testFinalizarGeneraResultadoConPuntajeCorrecto(): void
    {
        [$estudiante, $actividad, $mapa] = $this->escenario(4);
        $intento = self::iniciarIntento($estudiante, $actividad);
        $i = 0;
        foreach ($mapa as $pregunta => [$ok, $mal]) {
            self::responder($intento, $pregunta, $i++ < 3 ? $ok : $mal); // 3 de 4 correctas
        }
        self::finalizar($intento);

        $r = self::pdo()
            ->query("SELECT correctas, total_preguntas, puntaje FROM resultados WHERE intento_id = {$intento}")
            ->fetch();
        $this->assertSame(['correctas' => 3, 'total_preguntas' => 4, 'puntaje' => '75.00'], [
            'correctas' => (int) $r['correctas'],
            'total_preguntas' => (int) $r['total_preguntas'],
            'puntaje' => $r['puntaje'],
        ]);
    }

    public function testPreguntaSinResponderCuentaComoIncorrecta(): void
    {
        [$estudiante, $actividad, $mapa] = $this->escenario(4);
        $intento = self::iniciarIntento($estudiante, $actividad);
        $pregunta = array_key_first($mapa);
        self::responder($intento, $pregunta, $mapa[$pregunta][0]);
        self::finalizar($intento);

        $this->assertSame('25.00', self::valor('SELECT puntaje FROM resultados WHERE intento_id = ?', [$intento]));
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
