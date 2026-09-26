<?php

declare(strict_types=1);

namespace Atlas\Tests\Database;

/**
 * Restricciones de integridad: BD-06, RF-01 (correo único), CHECK de rangos.
 */
final class IntegridadTest extends DatabaseTestCase
{
    public function testClaveForaneaRechazaReferenciaInexistente(): void
    {
        $this->assertFalla(
            'INSERT INTO usuario_grupo (usuario_id, grupo_id) VALUES (999999999, 999999999)',
            contiene: 'foreign key constraint fails'
        );
    }

    public function testCorreoDuplicadoRechazadoRf01(): void
    {
        $id = self::crearUsuario('docente');
        $correo = self::valor('SELECT correo FROM usuarios WHERE id = ?', [$id]);
        $this->assertFalla(
            'INSERT INTO usuarios (institucion_id, rol_id, nombre, apellido, correo, hash_contrasena)
             VALUES (1, 2, ?, ?, ?, ?)',
            ['Otro', 'Usuario', $correo, 'x'],
            contiene: 'Duplicate entry'
        );
    }

    public function testCamposObligatoriosVaciosRechazadosRf01(): void
    {
        $this->assertFalla(
            'INSERT INTO usuarios (institucion_id, rol_id, nombre, apellido, correo, hash_contrasena)
             VALUES (1, 2, ?, ?, ?, ?)',
            ['   ', 'Apellido', 'vacio.' . bin2hex(random_bytes(4)) . '@prueba.atlas.local', 'x'],
            contiene: 'ck_usuarios_nombre'
        );
    }

    public function testPuntajeFueraDeRangoRechazado(): void
    {
        $docente = self::crearUsuario('docente');
        $estudiante = self::crearUsuario('estudiante');
        [$actividad] = self::crearActividad($docente);
        $intento = self::iniciarIntento($estudiante, $actividad);

        $this->assertFalla(
            'INSERT INTO resultados (intento_id, correctas, total_preguntas, puntaje) VALUES (?, 1, 1, 101)',
            [$intento],
            contiene: 'ck_resultados_puntaje'
        );
    }

    public function testIntentoCerradoDebeTenerFechaYDuracion(): void
    {
        $docente = self::crearUsuario('docente');
        $estudiante = self::crearUsuario('estudiante');
        [$actividad] = self::crearActividad($docente);
        $intento = self::iniciarIntento($estudiante, $actividad);

        $this->assertFalla(
            "UPDATE intentos SET estado = 'FINALIZADO' WHERE id = ?",
            [$intento],
            contiene: 'ck_intentos_cierre'
        );
    }

    public function testOpcionDebePertenecerALaPreguntaRespondida(): void
    {
        $docente = self::crearUsuario('docente');
        $estudiante = self::crearUsuario('estudiante');
        $grupo = self::crearGrupo();
        self::asignar($estudiante, $grupo);
        [$actividad, $mapa] = self::crearActividad($docente, 2);
        self::publicar($actividad, $grupo, $docente);
        [$p1, $p2] = array_keys($mapa);
        $intento = self::iniciarIntento($estudiante, $actividad);

        // Opción de la pregunta 2 usada para responder la pregunta 1: FK compuesta.
        $this->assertFalla(
            'INSERT INTO respuestas (intento_id, pregunta_id, opcion_id) VALUES (?, ?, ?)',
            [$intento, $p1, $mapa[$p2][0]],
            contiene: 'foreign key constraint fails'
        );
    }

    public function testSecuenciaDeInteraccionesUnicaPorIntento(): void
    {
        $docente = self::crearUsuario('docente');
        $estudiante = self::crearUsuario('estudiante');
        [$actividad] = self::crearActividad($docente);
        $intento = self::iniciarIntento($estudiante, $actividad);

        self::ejecutar(
            "INSERT INTO interacciones (intento_id, secuencia, tipo, ocurrido_en) VALUES (?, 1, 'INICIO', NOW(3))",
            [$intento]
        );
        $this->assertFalla(
            "INSERT INTO interacciones (intento_id, secuencia, tipo, ocurrido_en) VALUES (?, 1, 'PAUSA', NOW(3))",
            [$intento],
            contiene: 'Duplicate entry'
        );
    }

    public function testIndicadorDeNivel1RequiereActividadYRango(): void
    {
        $estudiante = self::crearUsuario('estudiante');
        $perfil = self::ejecutar(
            "INSERT INTO perfiles_aprendizaje (usuario_id, periodo_inicio, periodo_fin) VALUES (?, '2026-09-01', '2026-09-30')",
            [$estudiante]
        );

        $this->assertFalla(
            "INSERT INTO indicadores (perfil_id, tipo, valor, origen) VALUES (?, 'PUNTAJE', 50, 'NIVEL1')",
            [$perfil],
            contiene: 'ck_indicadores_nivel1'
        );
        $this->assertFalla(
            "INSERT INTO indicadores (perfil_id, tipo, valor, origen) VALUES (?, 'RIESGO', 1.5, 'NIVEL2')",
            [$perfil],
            contiene: 'ck_indicadores_riesgo'
        );
    }
}
