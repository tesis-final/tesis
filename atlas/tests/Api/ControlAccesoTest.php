<?php

declare(strict_types=1);

namespace Atlas\Tests\Api;

use PHPUnit\Framework\Attributes\DataProvider;

/**
 * RF-03, RNF-01, OBJ-01 (diez casos de prueba documentados) y OBJ-07 (intentos no
 * autorizados rechazados y registrados). Cadena de middleware §26.3 (401/403).
 */
final class ControlAccesoTest extends ApiTestCase
{
    /** @return array<string, array{0: string, 1: string, 2: string, 3: int}> */
    public static function casos(): array
    {
        return [
            'C01 estudiante → panel docente' => ['ESTUDIANTE', 'GET', '/docente/grupos/1/analisis', 403],
            'C02 estudiante → reportes' => ['ESTUDIANTE', 'GET', '/reportes', 403],
            'C03 estudiante → crear actividad' => ['ESTUDIANTE', 'POST', '/actividades', 403],
            'C04 estudiante → asistente' => ['ESTUDIANTE', 'POST', '/asistente/consultas', 403],
            'C05 docente → gestión de usuarios' => ['DOCENTE', 'GET', '/usuarios', 403],
            'C06 docente → aprobar actividad' => ['DOCENTE', 'POST', '/actividades/1/aprobar', 403],
            'C07 docente → auditoría' => ['DOCENTE', 'GET', '/auditoria', 403],
            'C08 docente → editar reglas' => ['DOCENTE', 'PATCH', '/reglas/R01', 403],
            'C09 administrador → resolver actividades' => ['ADMIN', 'POST', '/intentos', 403],
            'C10 administrador → asistente docente' => ['ADMIN', 'POST', '/asistente/consultas', 403],
        ];
    }

    #[DataProvider('casos')]
    public function testAccesoCruzadoEntreRolesDevuelve403YQuedaRegistrado(
        string $rol,
        string $metodo,
        string $ruta,
        int $esperado
    ): void {
        [$c, $id] = $this->entrar($rol);
        $r = $c->pedir(
            $metodo,
            $ruta,
            ['actividad_id' => 1, 'pregunta' => 'x', 'titulo' => 'x', 'nivel' => 'BASICO', 'categoria' => 'MEMORIA']
        );

        $this->assertSame($esperado, $c->ultimoEstado);
        $this->assertArrayHasKey('error', $r);
        $this->assertSame(1, (int) self::valor(
            "SELECT COUNT(*) FROM auditoria
              WHERE usuario_id = ? AND accion = 'acceso.denegado' AND resultado = 'DENEGADO'",
            [$id]
        ), 'RF-03: el intento no autorizado queda registrado');
    }

    public function testSinSesionDevuelve401(): void
    {
        $c = $this->cliente();
        foreach (['/auth/me', '/actividades', '/estudiante/actividades', '/usuarios'] as $ruta) {
            $c->pedir('GET', $ruta);
            $this->assertSame(401, $c->ultimoEstado, $ruta);
        }
    }

    public function testSinTokenCsrfNoSeModificaNada(): void
    {
        [$c, $id] = $this->entrar('DOCENTE');
        $c->pedir(
            'POST',
            '/actividades',
            ['titulo' => 'x', 'nivel' => 'BASICO', 'categoria' => 'MEMORIA'],
            conCsrf: false
        );
        $this->assertSame(403, $c->ultimoEstado);
        $this->assertSame(0, (int) self::valor('SELECT COUNT(*) FROM actividades WHERE autor_id = ?', [$id]));
        $this->assertSame(1, (int) self::valor(
            "SELECT COUNT(*) FROM auditoria WHERE usuario_id = ? AND accion = 'seguridad.csrf'",
            [$id]
        ));
    }

    public function testValidacionDevuelve422ConDetallePorCampo(): void
    {
        [$c] = $this->entrar('DOCENTE');
        $r = $c->pedir('POST', '/actividades', ['titulo' => '', 'nivel' => 'BASICO']);
        $this->assertSame(422, $c->ultimoEstado);
        $this->assertSame(['titulo', 'categoria'], array_keys($r['errores']));
    }

    public function testDocenteNoVeActividadesDeOtroDocente(): void
    {
        [$autor] = $this->entrar('DOCENTE');
        [$otro] = $this->entrar('DOCENTE');
        $a = $this->crearActividadApi($autor);
        $otro->pedir('GET', "/actividades/{$a['id']}");
        $this->assertSame(403, $otro->ultimoEstado);
        $otro->pedir('POST', "/actividades/{$a['id']}/enviar");
        $this->assertSame(403, $otro->ultimoEstado);
    }

    public function testEstudianteNoVeIntentosDeOtroEstudiante(): void
    {
        [$admin] = $this->entrar('ADMIN');
        [$docente, $idDoc] = $this->entrar('DOCENTE');
        [$e1, $idE1] = $this->entrar('ESTUDIANTE');
        [$e2, $idE2] = $this->entrar('ESTUDIANTE');
        $grupo = self::crearGrupo();
        foreach ([$idDoc, $idE1, $idE2] as $u) {
            self::asignar($u, $grupo);
        }
        $a = $this->crearActividadApi($docente, 1);
        $this->publicarApi($docente, $admin, $a['id'], $grupo);
        $r = $this->resolver($e1, $a, 1);

        $e2->pedir('GET', "/intentos/{$r['intento']['id']}/resultado");
        $this->assertSame(404, $e2->ultimoEstado);
    }
}
