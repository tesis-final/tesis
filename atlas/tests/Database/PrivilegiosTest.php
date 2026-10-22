<?php

declare(strict_types=1);

namespace Atlas\Tests\Database;

/**
 * Privilegios diferenciados: OBJ-04, BD-07, BD-08, RF-15 (PDF Tabla 21, §27.5; DEC-10, CT-13).
 */
final class PrivilegiosTest extends DatabaseTestCase
{
    public function testAppNoPuedeAlterarNiBorrarAuditoria(): void
    {
        $this->assertFalla(
            "UPDATE auditoria SET accion = 'x' WHERE id = 1",
            usuario: 'atlas_app',
            contiene: 'command denied'
        );
        $this->assertFalla('DELETE FROM auditoria WHERE id = 1', usuario: 'atlas_app', contiene: 'command denied');
    }

    public function testAppPuedeInsertarAuditoria(): void
    {
        $id = self::ejecutar(
            "INSERT INTO auditoria (accion, resultado) VALUES ('prueba.app', 'OK')",
            usuario: 'atlas_app'
        );
        $this->assertGreaterThan(0, $id);
    }

    public function testAppNoPuedeCambiarEstructuraNiBorrarUsuarios(): void
    {
        $this->assertFalla('DROP TABLE resultados', usuario: 'atlas_app', contiene: 'command denied');
        $this->assertFalla('ALTER TABLE usuarios ADD COLUMN x INT', usuario: 'atlas_app', contiene: 'command denied');
        $this->assertFalla('DELETE FROM usuarios WHERE id = 1', usuario: 'atlas_app', contiene: 'command denied');
        $this->assertFalla('CREATE USER intruso', usuario: 'atlas_app', contiene: 'denied');
    }

    public function testAppNoPuedeFalsearResultados(): void
    {
        // Desde 004 (D-4) la app agrega el resultado que calcula, pero nunca lo modifica ni lo borra.
        $this->assertFalla('UPDATE resultados SET puntaje = 100', usuario: 'atlas_app', contiene: 'command denied');
        $this->assertFalla('DELETE FROM resultados', usuario: 'atlas_app', contiene: 'command denied');
    }

    public function testAppNoModificaLasDecisionesDelDocente(): void
    {
        // D-6 (004): queda el rastro de qué sugirió el sistema y qué decidió el docente.
        $this->assertFalla(
            'UPDATE decisiones_recomendacion SET decision = \'CAMBIADA\'',
            usuario: 'atlas_app',
            contiene: 'command denied'
        );
        $this->assertFalla('DELETE FROM decisiones_recomendacion', usuario: 'atlas_app', contiene: 'command denied');
    }

    public function testAppNoModificaTransicionesNiConversaciones(): void
    {
        $this->assertFalla(
            'UPDATE transiciones_actividad SET observaciones = NULL',
            usuario: 'atlas_app',
            contiene: 'command denied'
        );
        $this->assertFalla(
            'UPDATE conversaciones SET respuesta = NULL',
            usuario: 'atlas_app',
            contiene: 'command denied'
        );
    }

    public function testReadSoloVeVistas(): void
    {
        $this->assertFalla('SELECT * FROM usuarios LIMIT 1', usuario: 'atlas_read', contiene: 'command denied');
        $this->assertIsInt((int) self::valor('SELECT COUNT(*) FROM v_resultados_detalle', usuario: 'atlas_read'));
        $this->assertFalla(
            'INSERT INTO auditoria (accion, resultado) VALUES (?, ?)',
            ['x', 'OK'],
            'atlas_read',
            'command denied'
        );
    }

    public function testAnalysisNoLeeNombresNiCorreos(): void
    {
        $this->assertFalla(
            'SELECT nombre, correo FROM usuarios LIMIT 1',
            usuario: 'atlas_analysis',
            contiene: 'command denied'
        );
        $this->assertFalla(
            'SELECT * FROM v_resultados_detalle LIMIT 1',
            usuario: 'atlas_analysis',
            contiene: 'command denied'
        );
        $this->assertIsInt((int) self::valor('SELECT COUNT(*) FROM intentos', usuario: 'atlas_analysis'));
        $this->assertIsInt((int) self::valor('SELECT COUNT(grupo_id) FROM usuario_grupo', usuario: 'atlas_analysis'));
    }

    public function testAnalysisSoloInsertaEnAnalisis(): void
    {
        $this->assertFalla(
            'UPDATE intentos SET duracion_seg = 1',
            usuario: 'atlas_analysis',
            contiene: 'command denied'
        );
        $this->assertFalla('DELETE FROM indicadores', usuario: 'atlas_analysis', contiene: 'command denied');

        $grupo = self::crearGrupo();
        $id = self::ejecutar(
            "INSERT INTO agrupamientos (grupo_id, periodo_inicio, periodo_fin, k, silueta, n_muestras, modelo_version)
             VALUES (?, '2026-09-01', '2026-09-30', 3, 0.41, 120, 'kmeans-prueba')",
            [$grupo],
            'atlas_analysis'
        );
        $this->assertGreaterThan(0, $id);
    }

    public function testBackupLeeTodoPeroNoEscribeDatos(): void
    {
        $this->assertIsInt((int) self::valor('SELECT COUNT(*) FROM usuarios', usuario: 'atlas_backup'));
        $this->assertFalla('DELETE FROM intentos', usuario: 'atlas_backup', contiene: 'command denied');
        $this->assertFalla("UPDATE usuarios SET activo = 0", usuario: 'atlas_backup', contiene: 'command denied');

        $grants = implode("\n", self::pdo('atlas_backup')->query('SHOW GRANTS')->fetchAll(\PDO::FETCH_COLUMN));
        $this->assertStringContainsString('TRIGGER', $grants, 'DEC-10');
        $this->assertStringContainsString('SHOW_ROUTINE', $grants, 'DEC-10');
    }

    public function testAdminSoloDesdeDentroDelContenedor(): void
    {
        // atlas_admin existe solo como 'atlas_admin'@'localhost': desde la red se rechaza (BD-08).
        $this->expectException(\PDOException::class);
        $this->expectExceptionMessageMatches('/Access denied/');
        self::pdo('atlas_admin');
    }

    public function testAppPuedeBorrarContenidoSoloEnBorradorCt13(): void
    {
        $docente = self::crearUsuario('docente');
        [$actividad, $mapa] = self::crearActividad($docente, 2);
        $pregunta = array_key_last($mapa);

        self::ejecutar('DELETE FROM opciones WHERE pregunta_id = ?', [$pregunta], 'atlas_app');
        self::ejecutar('DELETE FROM preguntas WHERE id = ?', [$pregunta], 'atlas_app');
        $this->assertSame(1, (int) self::valor('SELECT COUNT(*) FROM preguntas WHERE actividad_id = ?', [$actividad]));
    }
}
