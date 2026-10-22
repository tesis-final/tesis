<?php

declare(strict_types=1);

namespace Atlas\Tests\Api;

use Atlas\Core\Config;
use Atlas\Tests\Database\DatabaseTestCase;

/**
 * Base de los tests de API (Fase 4): usuarios reales en MySQL, credenciales de
 * la app (atlas_app / atlas_read) y un servicio de análisis simulado.
 */
abstract class ApiTestCase extends DatabaseTestCase
{
    protected const CLAVE = 'Clave-de-prueba-10';
    protected static AnalisisClientFalso $analisis;
    protected static string $logAuditoria;

    public static function setUpBeforeClass(): void
    {
        parent::setUpBeforeClass();
        self::$analisis = new AnalisisClientFalso();
        self::$logAuditoria = sys_get_temp_dir() . '/atlas-auditoria-test.log';
    }

    protected function setUp(): void
    {
        self::$analisis->disponible = true;
        self::$analisis->enviados = [];
    }

    protected static function config(): Config
    {
        return new Config([
            'ATLAS_DB_HOST' => getenv('ATLAS_TEST_DB_HOST') ?: '192.168.250.20',
            'ATLAS_DB_APP_USER' => 'atlas_app',
            'ATLAS_DB_APP_PASSWORD' => (string) getenv('ATLAS_DB_APP_PASSWORD'),
            'ATLAS_DB_READ_USER' => 'atlas_read',
            'ATLAS_DB_READ_PASSWORD' => (string) getenv('ATLAS_DB_READ_PASSWORD'),
            'ATLAS_AUDIT_LOG' => self::$logAuditoria,
        ]);
    }

    protected function cliente(): Cliente
    {
        return new Cliente(self::config(), self::$analisis);
    }

    /** Crea un usuario con contraseña conocida y devuelve [id, correo]. @return array{0:int,1:string} */
    protected static function usuario(
        string $rol,
        string $nombre = 'Nombre',
        string $apellido = 'Sintético',
        int $institucion = 1
    ): array {
        $correo = strtolower($rol) . '.' . bin2hex(random_bytes(5)) . '@prueba.atlas.local';
        $id = self::ejecutar(
            'INSERT INTO usuarios (institucion_id, rol_id, nombre, apellido, correo, hash_contrasena)
             VALUES (?, ?, ?, ?, ?, ?)',
            [$institucion, self::id('roles', $rol), $nombre, $apellido, $correo,
             password_hash(self::CLAVE, PASSWORD_ARGON2ID)]
        );

        return [$id, $correo];
    }

    /** Cliente ya autenticado. @return array{0: Cliente, 1: int} */
    protected function entrar(
        string $rol,
        string $nombre = 'Nombre',
        string $apellido = 'Sintético',
        int $institucion = 1
    ): array {
        [$id, $correo] = self::usuario($rol, $nombre, $apellido, $institucion);
        $c = $this->cliente();
        $c->login($correo, self::CLAVE);
        $this->assertSame(200, $c->ultimoEstado);

        return [$c, $id];
    }

    /** Actividad completa en borrador vía API. @return array<string, mixed> */
    protected function crearActividadApi(
        Cliente $docente,
        int $preguntas = 3,
        string $nivel = 'BASICO',
        string $categoria = 'RESOLUCION_PROBLEMAS'
    ): array {
        $lista = [];
        for ($i = 1; $i <= $preguntas; $i++) {
            $lista[] = ['enunciado' => "¿Pregunta {$i}?", 'opciones' => [
                ['texto' => 'Correcta', 'correcta' => true],
                ['texto' => 'Incorrecta A', 'correcta' => false],
                ['texto' => 'Incorrecta B', 'correcta' => false],
            ], 'habilidades' => $i % 2 === 1 ? ['LOGICA'] : ['CALCULO', 'LOGICA']]; // D-3
        }
        $a = $docente->pedir('POST', '/actividades', ['titulo' => 'Actividad ' . bin2hex(random_bytes(3)),
            'nivel' => $nivel, 'categoria' => $categoria, 'preguntas' => $lista]);
        $this->assertSame(201, $docente->ultimoEstado, json_encode($a));

        return $a;
    }

    /** Lleva una actividad de la API hasta PUBLICADA en el grupo. */
    protected function publicarApi(Cliente $docente, Cliente $admin, int $actividad, int $grupo): void
    {
        $docente->pedir('POST', "/actividades/{$actividad}/enviar");
        $this->assertSame(200, $docente->ultimoEstado);
        $admin->pedir('POST', "/actividades/{$actividad}/aprobar");
        $this->assertSame(200, $admin->ultimoEstado);
        $docente->pedir('POST', "/actividades/{$actividad}/publicar", ['grupos' => [$grupo]]);
        $this->assertSame(200, $docente->ultimoEstado);
    }

    /**
     * Resuelve un intento completo con $aciertos respuestas correctas.
     *
     * @param array<string, mixed> $actividad detalle con preguntas (con "correcta")
     * @return array<string, mixed> resultado
     */
    protected function resolver(Cliente $estudiante, array $actividad, int $aciertos): array
    {
        $inicio = $estudiante->pedir('POST', '/intentos', ['actividad_id' => $actividad['id']]);
        $this->assertSame(201, $estudiante->ultimoEstado, json_encode($inicio));
        $intento = $inicio['intento']['id'];
        $seq = $inicio['intento']['proxima_secuencia'];
        $eventos = [];
        foreach ($actividad['preguntas'] as $i => $p) {
            $correcta = array_values(array_filter($p['opciones'], fn ($o) => $o['correcta']))[0]['id'];
            $incorrecta = array_values(array_filter($p['opciones'], fn ($o) => !$o['correcta']))[0]['id'];
            $elegida = $i < $aciertos ? $correcta : $incorrecta;
            $eventos[] = [
                'secuencia' => $seq++,
                'tipo' => 'VER_PREGUNTA',
                'pregunta_id' => $p['id'],
                'ocurrido_en' => gmdate('c')
            ];
            $eventos[] = [
                'secuencia' => $seq++,
                'tipo' => 'SELECCION',
                'pregunta_id' => $p['id'],
                'opcion_id' => $incorrecta,
                'ocurrido_en' => gmdate('c')
            ];
            if ($elegida !== $incorrecta) {
                $eventos[] = [
                    'secuencia' => $seq++,
                    'tipo' => 'CAMBIO_OPCION',
                    'pregunta_id' => $p['id'],
                    'opcion_id' => $elegida,
                    'ocurrido_en' => gmdate('c')
                ];
            }
            $estudiante->pedir(
                'PUT',
                "/intentos/{$intento}/respuestas/{$p['id']}",
                ['opcion_id' => $elegida, 'tiempo_seg' => 12]
            );
            $this->assertSame(204, $estudiante->ultimoEstado);
        }
        $estudiante->pedir('POST', "/intentos/{$intento}/eventos", ['eventos' => $eventos]);
        $this->assertSame(200, $estudiante->ultimoEstado);
        $r = $estudiante->pedir('POST', "/intentos/{$intento}/finalizar");
        $this->assertSame(200, $estudiante->ultimoEstado, json_encode($r));

        return $r;
    }
}
