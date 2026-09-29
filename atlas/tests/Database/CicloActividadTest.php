<?php

declare(strict_types=1);

namespace Atlas\Tests\Database;

/**
 * Ciclo de aprobación: RF-16, RF-17, OBJ-02 (H24, H25, DEC-12).
 */
final class CicloActividadTest extends DatabaseTestCase
{
    public function testRecorridoCompletoPorLosCincoEstados(): void
    {
        $docente = self::crearUsuario('docente');
        [$actividad] = self::crearActividad($docente);

        foreach (['PENDIENTE', 'RECHAZADA', 'BORRADOR', 'PENDIENTE', 'APROBADA', 'PUBLICADA'] as $estado) {
            self::cambiarEstado($actividad, $estado);
            $this->assertSame($estado, self::valor(
                'SELECT e.codigo FROM actividades a JOIN estados_actividad e ON e.id = a.estado_id WHERE a.id = ?',
                [$actividad]
            ));
        }
    }

    public function testTransicionNoPermitidaRechazada(): void
    {
        $docente = self::crearUsuario('docente');
        [$actividad] = self::crearActividad($docente);

        // BORRADOR → PUBLICADA saltea la aprobación del administrador.
        $this->assertFalla(
            'UPDATE actividades SET estado_id = ? WHERE id = ?',
            [self::id('estados_actividad', 'PUBLICADA'), $actividad],
            contiene: 'transición de estado no permitida'
        );
    }

    public function testActividadSinPreguntasNoSeEnviaAAprobacion(): void
    {
        $docente = self::crearUsuario('docente');
        [$actividad] = self::crearActividad($docente, 0);

        $this->assertFalla(
            'UPDATE actividades SET estado_id = ? WHERE id = ?',
            [self::id('estados_actividad', 'PENDIENTE'), $actividad],
            contiene: 'sin preguntas'
        );
    }

    public function testPreguntaConDosCorrectasNoSeEnvia(): void
    {
        $docente = self::crearUsuario('docente');
        [$actividad, $mapa] = self::crearActividad($docente, 1);
        $pregunta = array_key_first($mapa);
        self::ejecutar('UPDATE opciones SET es_correcta = TRUE WHERE pregunta_id = ?', [$pregunta]);

        $this->assertFalla(
            'UPDATE actividades SET estado_id = ? WHERE id = ?',
            [self::id('estados_actividad', 'PENDIENTE'), $actividad],
            contiene: 'exactamente 1 correcta'
        );
    }

    public function testContenidoInmutableFueraDeBorrador(): void
    {
        $docente = self::crearUsuario('docente');
        [$actividad, $mapa] = self::crearActividad($docente, 1);
        self::cambiarEstado($actividad, 'PENDIENTE');
        $pregunta = array_key_first($mapa);

        $this->assertFalla('DELETE FROM opciones WHERE pregunta_id = ?', [$pregunta], contiene: 'borrador');
        $this->assertFalla(
            'UPDATE preguntas SET enunciado = ? WHERE id = ?',
            ['cambio', $pregunta],
            contiene: 'borrador'
        );
    }

    public function testTransicionesRegistranAutorYObservaciones(): void
    {
        $docente = self::crearUsuario('docente');
        $admin = self::crearUsuario('admin');
        [$actividad] = self::crearActividad($docente);
        self::cambiarEstado($actividad, 'PENDIENTE');
        self::cambiarEstado($actividad, 'RECHAZADA');
        self::ejecutar(
            'INSERT INTO transiciones_actividad
               (actividad_id, estado_origen_id, estado_destino_id, usuario_id, observaciones)
             VALUES (?, ?, ?, ?, ?)',
            [$actividad, self::id('estados_actividad', 'PENDIENTE'), self::id('estados_actividad', 'RECHAZADA'),
             $admin, 'Falta una pregunta de cierre']
        );

        $fila = self::pdo()->query(
            "SELECT usuario_id, observaciones FROM transiciones_actividad WHERE actividad_id = {$actividad}"
        )->fetch();
        $this->assertSame($admin, (int) $fila['usuario_id']);
        $this->assertSame('Falta una pregunta de cierre', $fila['observaciones']);
    }
}
