<?php

declare(strict_types=1);

namespace Atlas\Tests\Api;

/** RF-16, RF-17, RF-04, RF-05, OBJ-02 a través de la API. */
final class CicloAprobacionApiTest extends ApiTestCase
{
    public function testRecorridoCompletoConRechazoYObservaciones(): void
    {
        [$admin, $idAdmin] = $this->entrar('ADMIN');
        [$docente, $idDoc] = $this->entrar('DOCENTE');
        $grupo = self::crearGrupo();
        self::asignar($idDoc, $grupo);

        // Borrador sin preguntas: se guarda, pero no se puede enviar (H24).
        $a = $docente->pedir(
            'POST',
            '/actividades',
            ['titulo' => 'Fracciones', 'nivel' => 'BASICO', 'categoria' => 'RESOLUCION_PROBLEMAS']
        );
        $this->assertSame([201, 'BORRADOR'], [$docente->ultimoEstado, $a['estado']]);
        $r = $docente->pedir('POST', "/actividades/{$a['id']}/enviar");
        $this->assertSame(422, $docente->ultimoEstado);
        $this->assertStringContainsString('sin preguntas', $r['errores']['preguntas']);

        // Pregunta con dos correctas: tampoco.
        $datos = ['titulo' => 'Fracciones', 'nivel' => 'BASICO', 'categoria' => 'RESOLUCION_PROBLEMAS',
                  'preguntas' => [[
                      'enunciado' => '¿1/2 + 1/2?',
                      'opciones' => [['texto' => '1', 'correcta' => true], ['texto' => 'uno', 'correcta' => true]]
                  ]]];
        $docente->pedir('PATCH', "/actividades/{$a['id']}", $datos);
        $docente->pedir('POST', "/actividades/{$a['id']}/enviar");
        $this->assertSame(422, $docente->ultimoEstado);

        $datos['preguntas'][0]['opciones'][1]['correcta'] = false;
        $docente->pedir('PATCH', "/actividades/{$a['id']}", $datos);
        $docente->pedir('POST', "/actividades/{$a['id']}/enviar");
        $this->assertSame(200, $docente->ultimoEstado);

        // Rechazo: observaciones obligatorias.
        $admin->pedir('POST', "/actividades/{$a['id']}/rechazar", []);
        $this->assertSame(422, $admin->ultimoEstado);
        $r = $admin->pedir(
            'POST',
            "/actividades/{$a['id']}/rechazar",
            ['observaciones' => 'Agregar una pregunta de cierre.']
        );
        $this->assertSame(
            ['RECHAZADA', 'Agregar una pregunta de cierre.'],
            [$r['estado'], $r['observaciones_rechazo']]
        );

        // Vuelve al docente: al editar pasa a borrador.
        $datos['preguntas'][] = [
            'enunciado' => '¿1/4 + 1/4?',
            'opciones' => [['texto' => '1/2', 'correcta' => true], ['texto' => '2/8', 'correcta' => false]]
        ];
        $e = $docente->pedir('PATCH', "/actividades/{$a['id']}", $datos);
        $this->assertSame('BORRADOR', $e['estado']);
        $docente->pedir('POST', "/actividades/{$a['id']}/enviar");
        $admin->pedir('POST', "/actividades/{$a['id']}/aprobar");
        $this->assertSame(200, $admin->ultimoEstado);
        $p = $docente->pedir('POST', "/actividades/{$a['id']}/publicar", ['grupos' => [$grupo]]);
        $this->assertSame('PUBLICADA', $p['estado']);

        // Cada transición con su autor (H25).
        $t = $docente->pedir('GET', "/actividades/{$a['id']}/transiciones");
        $this->assertSame(
            [[null, 'BORRADOR', $idDoc], ['BORRADOR', 'PENDIENTE', $idDoc], ['PENDIENTE', 'RECHAZADA', $idAdmin],
             ['RECHAZADA', 'BORRADOR', $idDoc], ['BORRADOR', 'PENDIENTE', $idDoc], ['PENDIENTE', 'APROBADA', $idAdmin],
             ['APROBADA', 'PUBLICADA', $idDoc]],
            array_map(fn ($x) => [$x['desde'], $x['hacia'], (int) $x['usuario_id']], $t)
        );
        $this->assertCount(5, array_unique(array_column($t, 'hacia')), 'OBJ-02: recorre los cinco estados');
    }

    public function testElAdministradorVePendientesYNoPuedePublicar(): void
    {
        [$admin] = $this->entrar('ADMIN');
        [$docente] = $this->entrar('DOCENTE');
        $a = $this->crearActividadApi($docente);
        $docente->pedir('POST', "/actividades/{$a['id']}/enviar");
        $pendientes = $admin->pedir('GET', '/actividades');
        $this->assertContains($a['id'], array_map('intval', array_column($pendientes, 'id')));
        $admin->pedir('POST', "/actividades/{$a['id']}/publicar", ['grupos' => [1]]);
        $this->assertSame(403, $admin->ultimoEstado);
    }

    public function testNoSePublicaEnUnGrupoAjeno(): void
    {
        [$admin] = $this->entrar('ADMIN');
        [$docente] = $this->entrar('DOCENTE');
        $ajeno = self::crearGrupo();
        $a = $this->crearActividadApi($docente);
        $docente->pedir('POST', "/actividades/{$a['id']}/enviar");
        $admin->pedir('POST', "/actividades/{$a['id']}/aprobar");
        $docente->pedir('POST', "/actividades/{$a['id']}/publicar", ['grupos' => [$ajeno]]);
        $this->assertSame(403, $docente->ultimoEstado);
    }

    public function testSaltearLaAprobacionNoEstaPermitido(): void
    {
        [$docente, $idDoc] = $this->entrar('DOCENTE');
        $grupo = self::crearGrupo();
        self::asignar($idDoc, $grupo);
        $a = $this->crearActividadApi($docente);
        $docente->pedir('POST', "/actividades/{$a['id']}/publicar", ['grupos' => [$grupo]]);
        $this->assertSame(409, $docente->ultimoEstado);
    }

    public function testEstudianteVeSoloPublicadasDeSusGruposConNivel(): void
    {
        [$admin] = $this->entrar('ADMIN');
        [$docente, $idDoc] = $this->entrar('DOCENTE');
        [$est, $idEst] = $this->entrar('ESTUDIANTE');
        [$otroEst] = $this->entrar('ESTUDIANTE');
        $grupo = self::crearGrupo();
        self::asignar($idDoc, $grupo);
        self::asignar($idEst, $grupo);

        $publicada = $this->crearActividadApi($docente, 2, 'INTERMEDIO');
        $this->publicarApi($docente, $admin, $publicada['id'], $grupo);
        $borrador = $this->crearActividadApi($docente);
        $pendiente = $this->crearActividadApi($docente);
        $docente->pedir('POST', "/actividades/{$pendiente['id']}/enviar");

        $visibles = $est->pedir('GET', '/estudiante/actividades');
        $this->assertSame([$publicada['id']], array_map('intval', array_column($visibles, 'id')));
        $this->assertSame(
            'Intermedio',
            $visibles[0]['nivel_nombre'],
            'RF-05: el nivel se ve en la vista del estudiante'
        );
        $this->assertSame([], $otroEst->pedir('GET', '/estudiante/actividades'), 'otro grupo no la ve');

        $est->pedir('POST', '/intentos', ['actividad_id' => $borrador['id']]);
        $this->assertSame(404, $est->ultimoEstado);
    }

    public function testElEstudianteNoRecibeLaRespuestaCorrecta(): void
    {
        [$admin] = $this->entrar('ADMIN');
        [$docente, $idDoc] = $this->entrar('DOCENTE');
        [$est, $idEst] = $this->entrar('ESTUDIANTE');
        $grupo = self::crearGrupo();
        self::asignar($idDoc, $grupo);
        self::asignar($idEst, $grupo);
        $a = $this->crearActividadApi($docente, 2);
        $this->publicarApi($docente, $admin, $a['id'], $grupo);

        $inicio = $est->pedir('POST', '/intentos', ['actividad_id' => $a['id']]);
        foreach ($inicio['actividad']['preguntas'] as $p) {
            foreach ($p['opciones'] as $o) {
                $this->assertArrayNotHasKey('correcta', $o);
            }
        }
    }
}
