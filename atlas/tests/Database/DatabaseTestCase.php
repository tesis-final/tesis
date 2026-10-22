<?php

declare(strict_types=1);

namespace Atlas\Tests\Database;

use Atlas\Services\Analysis\Indicadores;
use PDO;
use PDOException;
use PHPUnit\Framework\TestCase;

/**
 * Base de los tests de la Fase 5: se conectan a un MySQL 8.0 real levantado
 * con el esquema de database/ (ver tests/Database/run.sh).
 *
 * Las credenciales llegan por variables de entorno; son de prueba local.
 */
abstract class DatabaseTestCase extends TestCase
{
    /** @var array<string, PDO> */
    private static array $conexiones = [];

    /**
     * La institución 1 de las pruebas exige aprobación, para recorrer el ciclo completo
     * (BORRADOR → PENDIENTE → APROBADA → PUBLICADA). Desde 004 el valor por defecto es
     * sin aprobación (acta D-2); ese caso se prueba con instituciones nuevas.
     */
    public static function setUpBeforeClass(): void
    {
        self::ejecutar('UPDATE instituciones SET requiere_aprobacion = TRUE WHERE id = 1');
    }

    protected static function pdo(string $usuario = 'root'): PDO
    {
        if (!isset(self::$conexiones[$usuario])) {
            $variable = [
                'root' => 'ATLAS_TEST_ROOT_PASSWORD',
                'atlas_app' => 'ATLAS_DB_APP_PASSWORD',
                'atlas_read' => 'ATLAS_DB_READ_PASSWORD',
                'atlas_analysis' => 'ATLAS_DB_ANALYSIS_PASSWORD',
                'atlas_backup' => 'ATLAS_DB_BACKUP_PASSWORD',
                'atlas_admin' => 'ATLAS_DB_ADMIN_PASSWORD',
            ][$usuario];
            $host = getenv('ATLAS_TEST_DB_HOST') ?: '192.168.250.20';
            $pdo = new PDO(
                "mysql:host={$host};port=3306;dbname=atlas_db;charset=utf8mb4",
                $usuario,
                (string) getenv($variable),
                [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
            );
            $pdo->exec("SET time_zone = '+00:00'");
            self::$conexiones[$usuario] = $pdo;
        }

        return self::$conexiones[$usuario];
    }

    protected static function valor(string $sql, array $params = [], string $usuario = 'root'): mixed
    {
        $st = self::pdo($usuario)->prepare($sql);
        $st->execute($params);

        return $st->fetchColumn();
    }

    protected static function ejecutar(string $sql, array $params = [], string $usuario = 'root'): int
    {
        $st = self::pdo($usuario)->prepare($sql);
        $st->execute($params);

        return (int) self::pdo($usuario)->lastInsertId();
    }

    /** Afirma que la sentencia falla y devuelve el mensaje de error. */
    protected function assertFalla(
        string $sql,
        array $params = [],
        string $usuario = 'root',
        ?string $contiene = null
    ): string {
        try {
            self::ejecutar($sql, $params, $usuario);
        } catch (PDOException $e) {
            if ($contiene !== null) {
                $this->assertStringContainsString($contiene, $e->getMessage());
            }
            $this->addToAssertionCount(1);

            return $e->getMessage();
        }
        $this->fail("Se esperaba un error y la sentencia se ejecutó: {$sql}");
    }

    protected static function id(string $tabla, string $codigo): int
    {
        return (int) self::valor("SELECT id FROM {$tabla} WHERE codigo = ?", [$codigo]);
    }

    protected static function crearUsuario(string $rol): int
    {
        $correo = $rol . '.' . bin2hex(random_bytes(6)) . '@prueba.atlas.local';

        return self::ejecutar(
            'INSERT INTO usuarios (institucion_id, rol_id, nombre, apellido, correo, hash_contrasena)
             VALUES (1, ?, ?, ?, ?, ?)',
            [self::id('roles', strtoupper($rol)), 'Nombre', 'Sintético', $correo, password_hash('x', PASSWORD_ARGON2ID)]
        );
    }

    protected static function crearGrupo(): int
    {
        return self::ejecutar(
            'INSERT INTO grupos_clase (institucion_id, nombre, anio_lectivo) VALUES (1, ?, 2026)',
            ['G-' . bin2hex(random_bytes(4))]
        );
    }

    protected static function asignar(int $usuario, int $grupo): void
    {
        self::ejecutar('INSERT INTO usuario_grupo (usuario_id, grupo_id) VALUES (?, ?)', [$usuario, $grupo]);
    }

    /**
     * Crea una actividad en BORRADOR con $preguntas preguntas de 3 opciones
     * (la primera correcta). Devuelve [actividad_id, [pregunta_id => [correcta, incorrecta]]].
     *
     * @return array{0:int, 1:array<int, array{0:int, 1:int}>}
     */
    protected static function crearActividad(int $autor, int $preguntas = 2): array
    {
        $actividad = self::ejecutar(
            'INSERT INTO actividades (autor_id, nivel_id, categoria_id, estado_id, titulo)
             VALUES (?, ?, ?, ?, ?)',
            [$autor, self::id('niveles_dificultad', 'BASICO'), self::id('categorias', 'RESOLUCION_PROBLEMAS'),
             self::id('estados_actividad', 'BORRADOR'), 'Actividad sintética']
        );
        $mapa = [];
        for ($i = 1; $i <= $preguntas; $i++) {
            $p = self::ejecutar(
                'INSERT INTO preguntas (actividad_id, orden, enunciado) VALUES (?, ?, ?)',
                [$actividad, $i, "Pregunta {$i}"]
            );
            $ok = self::ejecutar(
                'INSERT INTO opciones (pregunta_id, orden, texto, es_correcta) VALUES (?, 1, ?, TRUE)',
                [$p, 'A']
            );
            $mal = self::ejecutar(
                'INSERT INTO opciones (pregunta_id, orden, texto, es_correcta) VALUES (?, 2, ?, FALSE)',
                [$p, 'B']
            );
            self::ejecutar(
                'INSERT INTO opciones (pregunta_id, orden, texto, es_correcta) VALUES (?, 3, ?, FALSE)',
                [$p, 'C']
            );
            $mapa[$p] = [$ok, $mal];
        }

        return [$actividad, $mapa];
    }

    protected static function cambiarEstado(int $actividad, string $estado): void
    {
        self::ejecutar(
            'UPDATE actividades SET estado_id = ? WHERE id = ?',
            [self::id('estados_actividad', $estado), $actividad]
        );
    }

    /** Lleva una actividad nueva hasta PUBLICADA en un grupo. */
    protected static function publicar(int $actividad, int $grupo, int $docente): void
    {
        foreach (['PENDIENTE', 'APROBADA', 'PUBLICADA'] as $estado) {
            self::cambiarEstado($actividad, $estado);
        }
        self::ejecutar(
            'INSERT INTO actividad_grupo (actividad_id, grupo_id, publicado_por) VALUES (?, ?, ?)',
            [$actividad, $grupo, $docente]
        );
    }

    protected static function iniciarIntento(int $estudiante, int $actividad): int
    {
        $n = (int) self::valor(
            'SELECT COALESCE(MAX(numero_intento), 0) + 1 FROM intentos WHERE usuario_id = ? AND actividad_id = ?',
            [$estudiante, $actividad]
        );

        return self::ejecutar(
            'INSERT INTO intentos (usuario_id, actividad_id, numero_intento) VALUES (?, ?, ?)',
            [$estudiante, $actividad, $n]
        );
    }

    protected static function responder(int $intento, int $pregunta, int $opcion): void
    {
        self::ejecutar(
            'INSERT INTO respuestas (intento_id, pregunta_id, opcion_id, tiempo_seg) VALUES (?, ?, ?, 10)',
            [$intento, $pregunta, $opcion]
        );
    }

    /**
     * Cierra el intento y guarda su resultado como lo hace la aplicación
     * (IntentoService::finalizar): desde 004 la base no lo calcula (acta D-4).
     */
    protected static function finalizar(int $intento, ?string $cuando = null): void
    {
        self::ejecutar(
            "UPDATE intentos SET estado = 'FINALIZADO', finalizado_en = COALESCE(?, CURRENT_TIMESTAMP(3)),
                    duracion_seg = 60 WHERE id = ?",
            [$cuando, $intento]
        );
        $total = (int) self::valor(
            'SELECT COUNT(*) FROM preguntas p JOIN intentos i ON i.actividad_id = p.actividad_id WHERE i.id = ?',
            [$intento]
        );
        $correctas = (int) self::valor(
            'SELECT COUNT(*) FROM respuestas r JOIN opciones o ON o.id = r.opcion_id
              WHERE r.intento_id = ? AND o.es_correcta = TRUE',
            [$intento]
        );
        self::ejecutar(
            'INSERT INTO resultados (intento_id, correctas, total_preguntas, puntaje) VALUES (?, ?, ?, ?)',
            [$intento, $correctas, $total, Indicadores::puntaje($correctas, $total)]
        );
    }
}
