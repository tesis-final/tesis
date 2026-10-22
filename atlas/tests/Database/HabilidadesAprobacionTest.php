<?php

declare(strict_types=1);

namespace Atlas\Tests\Database;

/**
 * Hito 2 (migración 003): habilidades por pregunta (devolución de Programación 4.a)
 * y aprobación configurable por institución (4.c). Prueba las claves, las
 * restricciones, los triggers y los privilegios de las tablas nuevas.
 */
final class HabilidadesAprobacionTest extends DatabaseTestCase
{
    private const VINCULAR = 'INSERT INTO pregunta_habilidad (pregunta_id, habilidad_id) VALUES (?, ?)';
    private const CAMBIAR_ESTADO = 'UPDATE actividades SET estado_id = ? WHERE id = ?';

    private static function habilidad(string $codigo): int
    {
        return self::id('habilidades', $codigo);
    }

    /** Usuario docente en una institución nueva con la aprobación pedida. */
    private static function docenteEnInstitucion(bool $requiereAprobacion): int
    {
        $institucion = self::ejecutar(
            'INSERT INTO instituciones (nombre, requiere_aprobacion) VALUES (?, ?)',
            ['Inst-' . bin2hex(random_bytes(4)), $requiereAprobacion ? 1 : 0]
        );
        $correo = 'docente.' . bin2hex(random_bytes(6)) . '@prueba.atlas.local';

        return self::ejecutar(
            'INSERT INTO usuarios (institucion_id, rol_id, nombre, apellido, correo, hash_contrasena)
             VALUES (?, ?, ?, ?, ?, ?)',
            [$institucion, self::id('roles', 'DOCENTE'), 'Nombre', 'Sintético', $correo, 'hash-de-prueba']
        );
    }

    private static function estado(int $actividad): string
    {
        return (string) self::valor(
            'SELECT e.codigo FROM actividades a JOIN estados_actividad e ON e.id = a.estado_id WHERE a.id = ?',
            [$actividad]
        );
    }

    // ---------------------------------------------------------------- catálogo

    public function testCatalogoInicialConLasCuatroHabilidadesDeLaDevolucion(): void
    {
        $codigos = self::pdo()->query('SELECT codigo FROM habilidades ORDER BY codigo')->fetchAll(\PDO::FETCH_COLUMN);
        foreach (['CALCULO', 'COMPRENSION', 'LOGICA', 'RAZONAMIENTO_ESP'] as $c) {
            $this->assertContains($c, $codigos);
        }
    }

    public function testCodigoYNombreUnicosYConFormato(): void
    {
        $this->assertFalla("INSERT INTO habilidades (codigo, nombre) VALUES ('LOGICA', 'Otra')", contiene: 'Duplicate');
        $this->assertFalla("INSERT INTO habilidades (codigo, nombre) VALUES ('OTRA', 'Lógica')", contiene: 'Duplicate');
        $this->assertFalla(
            "INSERT INTO habilidades (codigo, nombre) VALUES ('minusculas', 'X1')",
            contiene: 'ck_habilidades_codigo'
        );
        $this->assertFalla(
            "INSERT INTO habilidades (codigo, nombre) VALUES ('VACIA', '   ')",
            contiene: 'ck_habilidades_nombre'
        );
        $this->assertFalla(
            "INSERT INTO habilidades (codigo, nombre) VALUES (NULL, 'Sin codigo')",
            contiene: 'cannot be null'
        );
    }

    // ------------------------------------------------------ pregunta_habilidad

    public function testUnaPreguntaPuedeMedirVariasHabilidadesSinRepetir(): void
    {
        [$actividad, $mapa] = self::crearActividad(self::crearUsuario('docente'), 1);
        $pregunta = array_key_first($mapa);

        self::ejecutar(self::VINCULAR, [$pregunta, self::habilidad('LOGICA')]);
        self::ejecutar(self::VINCULAR, [$pregunta, self::habilidad('CALCULO')]);
        $this->assertSame(
            2,
            (int) self::valor('SELECT COUNT(*) FROM pregunta_habilidad WHERE pregunta_id = ?', [$pregunta])
        );

        $this->assertFalla(
            self::VINCULAR,
            [$pregunta, self::habilidad('LOGICA')],
            contiene: 'Duplicate'
        );
        $this->assertSame('BORRADOR', self::estado($actividad));
    }

    public function testClavesForaneasRechazanPreguntaOHabilidadInexistente(): void
    {
        [, $mapa] = self::crearActividad(self::crearUsuario('docente'), 1);
        $pregunta = array_key_first($mapa);

        $this->assertFalla(
            'INSERT INTO pregunta_habilidad (pregunta_id, habilidad_id) VALUES (?, 9999)',
            [$pregunta],
            contiene: 'foreign key'
        );
        $this->assertFalla(
            'INSERT INTO pregunta_habilidad (pregunta_id, habilidad_id) VALUES (999999999, ?)',
            [self::habilidad('LOGICA')]
        );
    }

    public function testHabilidadDesactivadaNoSeAsignaYHabilidadEnUsoNoSeBorra(): void
    {
        [, $mapa] = self::crearActividad(self::crearUsuario('docente'), 2);
        [$p1, $p2] = array_keys($mapa);
        $h = self::ejecutar(
            "INSERT INTO habilidades (codigo, nombre) VALUES (?, ?)",
            ['H' . strtoupper(bin2hex(random_bytes(3))), 'Habilidad ' . bin2hex(random_bytes(3))]
        );

        self::ejecutar(self::VINCULAR, [$p1, $h]);
        $this->assertFalla('DELETE FROM habilidades WHERE id = ?', [$h], contiene: 'foreign key');

        self::ejecutar('UPDATE habilidades SET activa = FALSE WHERE id = ?', [$h]);
        $this->assertFalla(self::VINCULAR, [$p2, $h], contiene: 'desactivada');
    }

    public function testVinculosSoloSeEditanEnBorrador(): void
    {
        [$actividad, $mapa] = self::crearActividad(self::crearUsuario('docente'), 1);
        $pregunta = array_key_first($mapa);
        self::ejecutar(self::VINCULAR, [$pregunta, self::habilidad('LOGICA')]);

        self::cambiarEstado($actividad, 'PENDIENTE');

        $this->assertFalla(self::VINCULAR, [$pregunta, self::habilidad('CALCULO')], contiene: 'borrador');
        $this->assertFalla('DELETE FROM pregunta_habilidad WHERE pregunta_id = ?', [$pregunta], contiene: 'borrador');
        $this->assertFalla(
            'UPDATE pregunta_habilidad SET habilidad_id = ? WHERE pregunta_id = ?',
            [self::habilidad('CALCULO'), $pregunta],
            contiene: 'no se modifica'
        );
    }

    public function testBorrarPreguntaEnBorradorBorraSusVinculos(): void
    {
        [, $mapa] = self::crearActividad(self::crearUsuario('docente'), 1);
        $pregunta = array_key_first($mapa);
        self::ejecutar(self::VINCULAR, [$pregunta, self::habilidad('LOGICA')]);

        self::ejecutar('DELETE FROM opciones WHERE pregunta_id = ?', [$pregunta]);
        self::ejecutar('DELETE FROM preguntas WHERE id = ?', [$pregunta]);

        $this->assertSame(
            0,
            (int) self::valor('SELECT COUNT(*) FROM pregunta_habilidad WHERE pregunta_id = ?', [$pregunta])
        );
    }

    // ---------------------------------------------------- aprobación flexible

    public function testPorDefectoLaInstitucionNoExigeAprobacion(): void
    {
        // Acta D-2 (migración 004): por defecto el docente publica directo.
        $id = self::ejecutar('INSERT INTO instituciones (nombre) VALUES (?)', ['Inst-' . bin2hex(random_bytes(4))]);
        $this->assertSame(0, (int) self::valor('SELECT requiere_aprobacion FROM instituciones WHERE id = ?', [$id]));
    }

    public function testConAprobacionNoSePublicaDirecto(): void
    {
        [$actividad] = self::crearActividad(self::docenteEnInstitucion(true));

        $this->assertFalla(
            self::CAMBIAR_ESTADO,
            [self::id('estados_actividad', 'PUBLICADA'), $actividad],
            contiene: 'transición de estado no permitida'
        );
        self::cambiarEstado($actividad, 'PENDIENTE');
        $this->assertSame('PENDIENTE', self::estado($actividad));
    }

    public function testSinAprobacionElDocentePublicaDirecto(): void
    {
        [$actividad] = self::crearActividad(self::docenteEnInstitucion(false));

        self::cambiarEstado($actividad, 'PUBLICADA');
        $this->assertSame('PUBLICADA', self::estado($actividad));
    }

    public function testSinAprobacionNoSeEnviaAPendiente(): void
    {
        [$actividad] = self::crearActividad(self::docenteEnInstitucion(false));

        $this->assertFalla(
            self::CAMBIAR_ESTADO,
            [self::id('estados_actividad', 'PENDIENTE'), $actividad],
            contiene: 'transición de estado no permitida'
        );
    }

    public function testPublicarDirectoTambienValidaElContenido(): void
    {
        [$sinPreguntas] = self::crearActividad(self::docenteEnInstitucion(false), 0);
        $this->assertFalla(
            self::CAMBIAR_ESTADO,
            [self::id('estados_actividad', 'PUBLICADA'), $sinPreguntas],
            contiene: 'sin preguntas'
        );

        [$actividad, $mapa] = self::crearActividad(self::docenteEnInstitucion(false), 1);
        self::ejecutar('UPDATE opciones SET es_correcta = TRUE WHERE pregunta_id = ?', [array_key_first($mapa)]);
        $this->assertFalla(
            self::CAMBIAR_ESTADO,
            [self::id('estados_actividad', 'PUBLICADA'), $actividad],
            contiene: 'exactamente 1 correcta'
        );
    }

    // ------------------------------------------------------------ privilegios

    public function testPrivilegiosDeLasTablasNuevas(): void
    {
        [, $mapa] = self::crearActividad(self::crearUsuario('docente'), 1);
        $pregunta = array_key_first($mapa);
        $logica = self::habilidad('LOGICA');

        // atlas_app: asigna y quita vínculos; no los modifica ni borra habilidades.
        self::ejecutar(self::VINCULAR, [$pregunta, $logica], 'atlas_app');
        self::ejecutar(
            'DELETE FROM pregunta_habilidad WHERE pregunta_id = ? AND habilidad_id = ?',
            [$pregunta, $logica],
            'atlas_app'
        );
        $this->assertFalla('DELETE FROM habilidades WHERE id = ?', [$logica], 'atlas_app', 'command denied');

        // Los demás usuarios no ven estas tablas (mínimo privilegio).
        $this->assertFalla('SELECT * FROM habilidades', [], 'atlas_read', 'command denied');
        $this->assertFalla('SELECT * FROM pregunta_habilidad', [], 'atlas_analysis', 'command denied');
        $this->assertFalla(
            'INSERT INTO habilidades (codigo, nombre) VALUES (?, ?)',
            ['XBKP', 'Respaldo'],
            'atlas_backup',
            'command denied'
        );
        $this->assertSame(
            4,
            (int) self::valor(
                "SELECT COUNT(*) FROM habilidades"
                . " WHERE codigo IN ('LOGICA', 'CALCULO', 'COMPRENSION', 'RAZONAMIENTO_ESP')",
                [],
                'atlas_backup'
            )
        );
    }
}
