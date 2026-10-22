<?php

declare(strict_types=1);

namespace Atlas\Tests\Api;

/** RF-01 (H9) y RF-14 (H22): el administrador registra, modifica y desactiva usuarios. */
final class GestionAdministrativaTest extends ApiTestCase
{
    public function testAltaValidaQuedaDisponibleParaIniciarSesion(): void
    {
        [$admin] = $this->entrar('ADMIN');
        $correo = 'nuevo.' . bin2hex(random_bytes(4)) . '@prueba.atlas.local';
        $u = $admin->pedir('POST', '/usuarios', ['nombre' => 'Ana', 'apellido' => 'Sintética', 'correo' => $correo,
            'contrasena' => 'Una-clave-larga', 'rol' => 'DOCENTE', 'institucion_id' => 1]);
        $this->assertSame(201, $admin->ultimoEstado);
        $this->assertSame('DOCENTE', $u['rol']);
        $this->assertSame(1, $u['institucion_id'], 'RF-01: queda con su rol e institución');

        $c = $this->cliente();
        $c->login($correo, 'Una-clave-larga');
        $this->assertSame(200, $c->ultimoEstado);
    }

    public function testCorreoRepetidoSeRechazaInformandoElMotivo(): void
    {
        [$admin] = $this->entrar('ADMIN');
        [, $correo] = self::usuario('ESTUDIANTE');
        $r = $admin->pedir('POST', '/usuarios', ['nombre' => 'X', 'apellido' => 'Y', 'correo' => $correo,
            'contrasena' => 'Una-clave-larga', 'rol' => 'ESTUDIANTE', 'institucion_id' => 1]);
        $this->assertSame(422, $admin->ultimoEstado);
        $this->assertSame('El correo ya está registrado.', $r['errores']['correo']);
    }

    public function testCamposObligatoriosVaciosNoSePersisten(): void
    {
        [$admin] = $this->entrar('ADMIN');
        $antes = (int) self::valor('SELECT COUNT(*) FROM usuarios');
        $admin->pedir('POST', '/usuarios', ['nombre' => '', 'apellido' => 'Y', 'correo' => 'z@prueba.atlas.local',
            'contrasena' => 'Una-clave-larga', 'rol' => 'ESTUDIANTE', 'institucion_id' => 1]);
        $this->assertSame(422, $admin->ultimoEstado);
        $this->assertSame($antes, (int) self::valor('SELECT COUNT(*) FROM usuarios'));
    }

    public function testContrasenaCortaRechazada(): void
    {
        [$admin] = $this->entrar('ADMIN');
        $r = $admin->pedir('POST', '/usuarios', [
            'nombre' => 'A', 'apellido' => 'B', 'correo' => 'c.' . bin2hex(random_bytes(3)) . '@prueba.atlas.local',
            'contrasena' => 'corta', 'rol' => 'ESTUDIANTE', 'institucion_id' => 1,
        ]);
        $this->assertSame(422, $admin->ultimoEstado);
        $this->assertArrayHasKey('contrasena', $r['errores']);
    }

    public function testModificarYDesactivarQuedanRegistradosConAutorYFecha(): void
    {
        [$admin, $idAdmin] = $this->entrar('ADMIN');
        [$idDoc, $correo] = self::usuario('DOCENTE');
        $admin->pedir('PATCH', "/usuarios/{$idDoc}", ['nombre' => 'Renombrado']);
        $this->assertSame(200, $admin->ultimoEstado);
        $admin->pedir('POST', "/usuarios/{$idDoc}/desactivar");
        $this->assertSame(200, $admin->ultimoEstado);

        $filas = self::pdo()->query(
            "SELECT accion, usuario_id, detalle, creado_en FROM auditoria
              WHERE recurso_id = '{$idDoc}' AND accion IN ('usuarios.modificar', 'usuarios.desactivar') ORDER BY id"
        )->fetchAll();
        $this->assertSame(
            ['usuarios.modificar', 'usuarios.desactivar'],
            array_column($filas, 'accion'),
            'un registro por acción (D-4: sin duplicados de triggers)'
        );
        foreach ($filas as $f) {
            $this->assertSame($idAdmin, (int) $f['usuario_id'], 'autor');
            $this->assertNotEmpty($f['creado_en'], 'marca temporal');
        }
        $this->assertSame([true, false], json_decode($filas[1]['detalle'], true)['activo'], 'antes y después');

        $c = $this->cliente();
        $c->login($correo, self::CLAVE);
        $this->assertSame(401, $c->ultimoEstado, 'un usuario desactivado ya no entra');
    }

    public function testAltaYCambioDeContrasenaAuditadosSinCopiarElHash(): void
    {
        [$admin] = $this->entrar('ADMIN');
        $u = $admin->pedir('POST', '/usuarios', [
            'nombre' => 'Alta', 'apellido' => 'Auditada',
            'correo' => 'alta.' . bin2hex(random_bytes(3)) . '@prueba.atlas.local',
            'contrasena' => 'Una-clave-larga', 'rol' => 'DOCENTE', 'institucion_id' => 1,
        ]);
        $this->assertSame(201, $admin->ultimoEstado);
        $alta = json_decode((string) self::valor(
            "SELECT detalle FROM auditoria WHERE accion = 'usuarios.crear' AND recurso_id = ?",
            [(string) $u['id']]
        ), true);
        $this->assertSame([1, true], [$alta['institucion_id'], $alta['activo']]);

        $admin->pedir('PATCH', "/usuarios/{$u['id']}", ['contrasena' => 'Otra-clave-larga']);
        $this->assertSame(200, $admin->ultimoEstado);
        $detalle = (string) self::valor(
            "SELECT detalle FROM auditoria WHERE accion = 'usuarios.modificar' AND recurso_id = ?
              ORDER BY id DESC LIMIT 1",
            [(string) $u['id']]
        );
        $this->assertStringNotContainsString('argon2id', $detalle);
        $this->assertTrue(json_decode($detalle, true)['contrasena_cambiada']);
    }

    public function testAdministradorNoPuedeDesactivarseASiMismo(): void
    {
        [$admin, $id] = $this->entrar('ADMIN');
        $admin->pedir('POST', "/usuarios/{$id}/desactivar");
        $this->assertSame(409, $admin->ultimoEstado);
    }

    public function testInstitucionesGruposYPermisos(): void
    {
        [$admin] = $this->entrar('ADMIN');
        $inst = $admin->pedir('POST', '/instituciones', ['nombre' => 'Sede de prueba ' . bin2hex(random_bytes(3))]);
        $this->assertSame(201, $admin->ultimoEstado);
        $g = $admin->pedir(
            'POST',
            '/grupos',
            ['nombre' => 'G' . bin2hex(random_bytes(2)), 'anio_lectivo' => 2026, 'institucion_id' => $inst['id']]
        );
        $this->assertSame(201, $admin->ultimoEstado);
        [$idE] = self::usuario('ESTUDIANTE');
        $m = $admin->pedir('PUT', "/grupos/{$g['id']}/miembros", ['usuarios' => [$idE]]);
        $this->assertSame([$idE], array_map(fn ($x) => (int) $x['id'], $m));

        $roles = $admin->pedir('GET', '/roles');
        $this->assertSame(['ADMIN', 'DOCENTE', 'ESTUDIANTE'], array_column($roles['roles'], 'codigo'));
        $idAdmin = $roles['roles'][0]['id'];
        $admin->pedir('PUT', "/roles/{$idAdmin}/permisos", ['permisos' => ['usuarios.gestionar']]);
        $this->assertSame(409, $admin->ultimoEstado, 'el administrador no puede quitarse la gestión de permisos');
    }

    public function testAuditoriaConsultablePorElAdministrador(): void
    {
        [$admin] = $this->entrar('ADMIN');
        $filas = $admin->pedir('GET', '/auditoria', [], ['accion' => 'auth.login', 'limite' => '5']);
        $this->assertSame(200, $admin->ultimoEstado);
        $this->assertNotEmpty($filas);
        $this->assertStringStartsWith('auth.login', $filas[0]['accion']);
    }
}
