<?php

declare(strict_types=1);

namespace Atlas\Tests\Api;

/** RF-10, RF-12, OBJ-05, OBJ-06: perfil, recomendaciones y "¿por qué?". */
final class MotorAnalisisApiTest extends ApiTestCase
{
    public function testPuntajeBajoDisparaR01YR07ConFundamentoRastreable(): void
    {
        [$admin] = $this->entrar('ADMIN');
        [$docente, $idDoc] = $this->entrar('DOCENTE');
        [$est, $idEst] = $this->entrar('ESTUDIANTE');
        $grupo = self::crearGrupo();
        self::asignar($idDoc, $grupo);
        self::asignar($idEst, $grupo);
        $a = $this->crearActividadApi($docente, 4);
        $this->publicarApi($docente, $admin, $a['id'], $grupo);
        // Otra actividad de la misma categoría y nivel para que haya una sugerencia concreta.
        $refuerzo = $this->crearActividadApi($docente, 2);
        $this->publicarApi($docente, $admin, $refuerzo['id'], $grupo);

        $this->resolver($est, $a, 1); // 25 %, primer intento

        $perfil = $docente->pedir('GET', "/docente/estudiantes/{$idEst}/perfil");
        $this->assertSame(200, $docente->ultimoEstado);
        $tipos = array_column(
            array_filter($perfil['indicadores'], fn ($i) => (int) $i['actividad_id'] === $a['id']),
            'valor',
            'tipo'
        );
        $this->assertEqualsWithDelta(25.0, (float) $tipos['PUNTAJE'], 0.001);
        $this->assertEqualsWithDelta(1.0, (float) $tipos['PERSISTENCIA'], 0.001);
        $this->assertEqualsWithDelta(0.0, (float) $tipos['MEJORA'], 0.001);
        $this->assertArrayNotHasKey('EFICIENCIA', $tipos, 'sin 3 intentos en el grupo no se calcula eficiencia');

        // Hay dos sugerencias distintas (misma actividad para R07, otra actividad para R01).
        $todas = array_merge(...array_map(fn ($r) => array_column($r['reglas'], 'codigo'), $perfil['recomendaciones']));
        sort($todas);
        $this->assertSame(['R01', 'R07'], $todas);
        $r01 = array_values(array_filter(
            $perfil['recomendaciones'],
            fn ($r) => array_column($r['reglas'], 'codigo') === ['R01']
        ))[0];
        $this->assertSame(
            $refuerzo['id'],
            (int) $r01['actividad_sugerida_id'],
            'RF-12: recomienda una actividad concreta'
        );

        $f = $docente->pedir('GET', "/recomendaciones/{$r01['id']}/fundamento");
        $this->assertSame(200, $docente->ultimoEstado);
        $this->assertSame('R01', $f['reglas'][0]['codigo']);
        $this->assertSame(1, (int) $f['reglas'][0]['version_regla']);
        $this->assertEqualsWithDelta(
            25.0,
            (float) $f['reglas'][0]['valores_entrada']['valores']['puntaje'],
            0.001,
            'H20: el fundamento muestra con qué datos se generó'
        );
    }

    public function testElSistemaRecomiendaYElDocenteDecide(): void
    {
        // D-6: el docente confirma la sugerencia o la cambia; el estudiante la ve como recomendada.
        [$admin] = $this->entrar('ADMIN');
        [$docente, $idDoc] = $this->entrar('DOCENTE');
        [$ajeno] = $this->entrar('DOCENTE');
        [$est, $idEst] = $this->entrar('ESTUDIANTE');
        $grupo = self::crearGrupo();
        self::asignar($idDoc, $grupo);
        self::asignar($idEst, $grupo);
        $a = $this->crearActividadApi($docente, 4);
        $this->publicarApi($docente, $admin, $a['id'], $grupo);
        $refuerzo = $this->crearActividadApi($docente, 2);
        $this->publicarApi($docente, $admin, $refuerzo['id'], $grupo);
        $noPublicada = $this->crearActividadApi($docente, 1);
        $this->resolver($est, $a, 1); // dispara R01 (sugiere $refuerzo) y R07 (sugiere repetir $a)

        $recs = $docente->pedir('GET', "/docente/estudiantes/{$idEst}/perfil")['recomendaciones'];
        $porRegla = [];
        foreach ($recs as $r) {
            $porRegla[array_column($r['reglas'], 'codigo')[0]] = $r;
        }

        $ajeno->pedir('POST', "/recomendaciones/{$porRegla['R01']['id']}/decision");
        $this->assertSame(403, $ajeno->ultimoEstado, 'solo un docente del estudiante decide');
        $est->pedir('POST', "/recomendaciones/{$porRegla['R01']['id']}/decision");
        $this->assertSame(403, $est->ultimoEstado, 'el estudiante no decide');

        $r = $docente->pedir('POST', "/recomendaciones/{$porRegla['R01']['id']}/decision");
        $this->assertSame(200, $docente->ultimoEstado, json_encode($r));
        $this->assertSame(['CONFIRMADA', $refuerzo['id']], [$r['decision'], (int) $r['actividad_asignada_id']]);
        $docente->pedir('POST', "/recomendaciones/{$porRegla['R01']['id']}/decision");
        $this->assertSame(409, $docente->ultimoEstado, 'una decisión por recomendación');

        $docente->pedir('POST', "/recomendaciones/{$porRegla['R07']['id']}/decision", [
            'actividad_id' => $noPublicada['id'],
        ]);
        $this->assertSame(422, $docente->ultimoEstado, 'solo actividades publicadas para el estudiante');
        $c = $docente->pedir('POST', "/recomendaciones/{$porRegla['R07']['id']}/decision", [
            'actividad_id' => $refuerzo['id'],
        ]);
        $this->assertSame('CAMBIADA', $c['decision']);

        $lista = $est->pedir('GET', '/estudiante/actividades');
        $this->assertSame($refuerzo['id'], (int) $lista[0]['id'], 'la recomendada va primero');
        $this->assertTrue($lista[0]['recomendada']);
        $this->resolver($est, $refuerzo, 2);
        $lista = $est->pedir('GET', '/estudiante/actividades');
        $this->assertSame(
            [],
            array_values(array_filter($lista, fn ($x) => $x['recomendada'])),
            'al resolverla deja de estar marcada'
        );
    }

    public function testMejoraYPersistenciaDisparanR04YR06(): void
    {
        [$admin] = $this->entrar('ADMIN');
        [$docente, $idDoc] = $this->entrar('DOCENTE');
        [$est, $idEst] = $this->entrar('ESTUDIANTE');
        $grupo = self::crearGrupo();
        self::asignar($idDoc, $grupo);
        self::asignar($idEst, $grupo);
        $a = $this->crearActividadApi($docente, 4);
        $this->publicarApi($docente, $admin, $a['id'], $grupo);

        // Puntajes 25, 25, 50, 100 (4 preguntas).
        foreach ([1, 1, 2, 4] as $aciertos) {
            $this->resolver($est, $a, $aciertos);
        }
        $perfil = $docente->pedir('GET', "/docente/estudiantes/{$idEst}/perfil");
        $todas = array_merge(...array_map(fn ($r) => array_column($r['reglas'], 'codigo'), $perfil['recomendaciones']));
        sort($todas);
        // Intento 1: R01 + R07 · intento 2: R01 · intento 3 (50, mejora 25): ninguna ·
        // intento 4 (100, mejora 75, persistencia 4): R04 + R06.
        $this->assertSame(['R01', 'R01', 'R04', 'R06', 'R07'], $todas);
        $this->assertNotContains('R05', $todas, 'con mejora positiva no hay estancamiento');
    }

    public function testDocenteDeOtroGrupoNoVePerfilNiFundamento(): void
    {
        [$admin] = $this->entrar('ADMIN');
        [$docente, $idDoc] = $this->entrar('DOCENTE');
        [$ajeno] = $this->entrar('DOCENTE');
        [$est, $idEst] = $this->entrar('ESTUDIANTE');
        $grupo = self::crearGrupo();
        self::asignar($idDoc, $grupo);
        self::asignar($idEst, $grupo);
        $a = $this->crearActividadApi($docente, 2);
        $this->publicarApi($docente, $admin, $a['id'], $grupo);
        $this->resolver($est, $a, 0);
        $perfil = $docente->pedir('GET', "/docente/estudiantes/{$idEst}/perfil");

        $ajeno->pedir('GET', "/docente/estudiantes/{$idEst}/perfil");
        $this->assertSame(403, $ajeno->ultimoEstado);
        $ajeno->pedir('GET', "/recomendaciones/{$perfil['recomendaciones'][0]['id']}/fundamento");
        $this->assertSame(403, $ajeno->ultimoEstado);
    }

    public function testEditarUnaReglaCambiaElResultadoYVersiona(): void
    {
        [$admin] = $this->entrar('ADMIN');
        $r = $admin->pedir('GET', '/reglas');
        $r01 = array_values(array_filter($r, fn ($x) => $x['codigo'] === 'R01'))[0];
        $nueva = ['todas' => [['indicador' => 'puntaje', 'op' => '<', 'valor' => 40]]];
        $e = $admin->pedir('PATCH', '/reglas/R01', ['condicion' => $nueva]);
        $this->assertSame(200, $admin->ultimoEstado);
        $this->assertSame($r01['version'] + 1, $e['version']);
        $auditado = json_decode((string) self::valor(
            "SELECT detalle FROM auditoria WHERE accion = 'reglas.modificar' AND recurso_id = 'R01'
              ORDER BY id DESC LIMIT 1"
        ), true);
        $this->assertSame([$r01['version'], $r01['version'] + 1], $auditado['version'], '§27.3: versión auditada');
        $this->assertEquals($nueva, $auditado['condicion_nueva'], 'JSON de MySQL: mismo contenido, otro orden');
        $admin->pedir(
            'PATCH',
            '/reglas/R01',
            ['condicion' => ['todas' => [['indicador' => 'edad', 'op' => '<', 'valor' => 1]]]]
        );
        $this->assertSame(422, $admin->ultimoEstado);
        $admin->pedir('PATCH', '/reglas/R01', ['condicion' => $r01['condicion']]); // restaurar lo aprobado
        $this->assertSame(200, $admin->ultimoEstado);
    }
}
