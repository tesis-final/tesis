<?php

declare(strict_types=1);

namespace Atlas\Tests\Api;

/**
 * Rutas de lectura que el análisis de cobertura del Hito 3 de Testing encontró sin prueba de API:
 * GET /auth/me con sesión, GET /grupos, GET /grupos/{id}/miembros y GET /instituciones.
 * La interfaz las usa en cada pantalla (perfil y token CSRF) y en Coordinación → Grupos.
 */
final class ConsultasOrganizacionTest extends ApiTestCase
{
    public function testPerfilDeSesionDevuelveRolYElMismoTokenCsrf(): void
    {
        [$docente, $id] = $this->entrar('DOCENTE', 'Laura', 'Docente-Prueba');
        $yo = $docente->pedir('GET', '/auth/me');
        $this->assertSame(200, $docente->ultimoEstado);
        $this->assertSame($id, $yo['usuario']['id']);
        $this->assertSame('DOCENTE', $yo['usuario']['rol']);
        $this->assertContains('panel.docente', $yo['permisos'], 'los permisos del rol, para armar el menú');
        $this->assertSame($docente->csrf, $yo['csrf'], 'la interfaz recupera el token CSRF de la sesión al recargar');
        $this->assertArrayNotHasKey('hash_contrasena', $yo['usuario'], 'el perfil no expone el hash de la contraseña');
    }

    public function testCoordinacionVeTodosLosGruposYElDocenteSoloLosSuyos(): void
    {
        $propio = self::crearGrupo();
        $ajeno = self::crearGrupo();
        [$docente, $idDocente] = $this->entrar('DOCENTE');
        self::asignar($idDocente, $propio);
        [$admin] = $this->entrar('ADMIN');

        $todos = array_column($admin->pedir('GET', '/grupos'), 'id');
        $this->assertSame(200, $admin->ultimoEstado);
        $this->assertContains($propio, $todos);
        $this->assertContains($ajeno, $todos);

        $suyos = array_column($docente->pedir('GET', '/grupos'), 'id');
        $this->assertSame(200, $docente->ultimoEstado);
        $this->assertSame([$propio], $suyos, 'el docente no ve grupos de los que no es miembro');
    }

    public function testMiembrosSoloParaCoordinacionOParaQuienPerteneceAlGrupo(): void
    {
        $grupo = self::crearGrupo();
        [$docente, $idDocente] = $this->entrar('DOCENTE');
        [$idEstudiante] = self::usuario('ESTUDIANTE', 'Ana', 'Estudiante-Prueba');
        self::asignar($idDocente, $grupo);
        self::asignar($idEstudiante, $grupo);
        [$admin] = $this->entrar('ADMIN');
        [$intruso] = $this->entrar('ESTUDIANTE');

        $miembros = $admin->pedir('GET', "/grupos/{$grupo}/miembros");
        $this->assertSame(200, $admin->ultimoEstado);
        $this->assertEqualsCanonicalizing([$idDocente, $idEstudiante], array_column($miembros, 'id'));
        $this->assertEqualsCanonicalizing(['DOCENTE', 'ESTUDIANTE'], array_column($miembros, 'rol'));

        $docente->pedir('GET', "/grupos/{$grupo}/miembros");
        $this->assertSame(200, $docente->ultimoEstado, 'el docente del grupo ve a sus integrantes');

        $r = $intruso->pedir('GET', "/grupos/{$grupo}/miembros");
        $this->assertSame(403, $intruso->ultimoEstado, 'un estudiante de otro grupo no ve los integrantes');
        $this->assertSame('Solo puede ver sus propios grupos.', $r['error']);
    }

    public function testInstitucionesSoloParaCoordinacion(): void
    {
        [$admin] = $this->entrar('ADMIN');
        $lista = $admin->pedir('GET', '/instituciones');
        $this->assertSame(200, $admin->ultimoEstado);
        $this->assertContains(1, array_column($lista, 'id'));
        $this->assertArrayHasKey('requiere_aprobacion', $lista[0], 'D-2: se ve si la institución exige aprobación');

        [$docente] = $this->entrar('DOCENTE');
        $docente->pedir('GET', '/instituciones');
        $this->assertSame(403, $docente->ultimoEstado, 'RNF-01: sin el permiso instituciones.gestionar');
    }
}
