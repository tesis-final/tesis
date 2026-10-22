<?php

declare(strict_types=1);

namespace Atlas\Tests\Api;

/** RF-18 (análisis grupal "dónde intervenir hoy"), RF-11, RF-13 y RNF-15. */
final class PanelGrupalTest extends ApiTestCase
{
    /** @return array{0: Cliente, 1: int, 2: array<string, mixed>, 3: array<int, int>} */
    private function grupoConResultados(): array
    {
        [$admin] = $this->entrar('ADMIN');
        [$docente, $idDoc] = $this->entrar('DOCENTE');
        $grupo = self::crearGrupo();
        self::asignar($idDoc, $grupo);
        $a = $this->crearActividadApi($docente, 4);
        $this->publicarApi($docente, $admin, $a['id'], $grupo);
        $estudiantes = [];
        foreach ([4, 3, 1, 0] as $aciertos) { // 100, 75, 25, 0
            [$est, $idEst] = $this->entrar('ESTUDIANTE', 'Est' . $aciertos, 'Sintético');
            self::asignar($idEst, $grupo);
            $this->resolver($est, $a, $aciertos);
            $estudiantes[$aciertos] = $idEst;
        }

        return [$docente, $grupo, $a, $estudiantes];
    }

    public function testDondeIntervenirHoy(): void
    {
        [$docente, $grupo, $a, $est] = $this->grupoConResultados();
        $r = $docente->pedir('GET', "/docente/grupos/{$grupo}/analisis");
        $this->assertSame(200, $docente->ultimoEstado);

        // 1) Estudiantes prioritarios: los de 25 y 0 (R01 + R07), con el motivo explicable.
        $prioritarios = array_column($r['prioritarios'], 'estudiante_id');
        sort($prioritarios);
        $esperados = [$est[1], $est[0]];
        sort($esperados);
        $this->assertSame($esperados, $prioritarios);
        $this->assertStringContainsString('R01', $r['prioritarios'][0]['motivo']);
        $this->assertNotEmpty($r['prioritarios'][0]['recomendaciones'], 'cada prioritario enlaza al "¿por qué?"');

        // 2) Preguntas con mayor proporción de error: la 4.ª pregunta la erraron 3 de 4.
        $this->assertSame(4, (int) $r['preguntas_con_mas_error'][0]['orden']);
        $this->assertEqualsWithDelta(0.75, (float) $r['preguntas_con_mas_error'][0]['proporcion_error'], 0.0001);

        // 3) Agregados y distribución (RF-18).
        $this->assertSame(4, $r['agregados']['n_estudiantes']);
        $this->assertEqualsWithDelta(50.0, $r['agregados']['promedio'], 0.001);
        $this->assertEqualsWithDelta(50.0, $r['agregados']['mediana'], 0.001);
        $this->assertSame(
            ['00-19' => 1, '20-39' => 1, '60-79' => 1, '80-100' => 1],
            array_map('intval', array_column($r['distribucion'], 'cantidad', 'rango'))
        );

        // 3b) Acierto por habilidad (D-3). Preguntas 1 y 3 miden LOGICA; 2 y 4, CALCULO y LOGICA.
        //     LOGICA: 8 de 16 = 50 %; CALCULO: 3 de 8 = 37,5 % → la más débil, a reforzar.
        $this->assertSame(['CALCULO', 'LOGICA'], array_column($r['habilidades'], 'codigo'));
        $this->assertSame([3, 8, 37.5, true, 2], [
            $r['habilidades'][0]['correctas'], $r['habilidades'][0]['preguntas'], $r['habilidades'][0]['porcentaje'],
            $r['habilidades'][0]['a_reforzar'], $r['habilidades'][0]['estudiantes_bajo_umbral'],
        ]);
        $this->assertSame([8, 16, 50.0, false], [
            $r['habilidades'][1]['correctas'], $r['habilidades'][1]['preguntas'], $r['habilidades'][1]['porcentaje'],
            $r['habilidades'][1]['a_reforzar'],
        ]);

        // 3c) Por estudiante (perfil): el de 3 aciertos tiene LOGICA 3/4 y CALCULO 1/2.
        $perfil = $docente->pedir('GET', "/docente/estudiantes/{$est[3]}/perfil");
        $this->assertSame(200, $docente->ultimoEstado);
        $this->assertSame(
            ['CALCULO' => 50.0, 'LOGICA' => 75.0],
            array_column($perfil['habilidades'], 'porcentaje', 'codigo')
        );

        // 4) Nivel 2 honesto: el servicio informa que los datos no alcanzan.
        $this->assertTrue($r['aprendizaje_automatico']['servicio_disponible']);
        $this->assertFalse($r['aprendizaje_automatico']['suficiencia']['suficiente']);
    }

    public function testCuentaElUltimoIntentoYGuardaElHistorial(): void
    {
        // RF-18 (D-4): un estudiante que hace 0 y después 100 cuenta con 100; el resumen
        // calculado en PHP queda guardado en analisis_grupal.
        [$admin] = $this->entrar('ADMIN');
        [$docente, $idDoc] = $this->entrar('DOCENTE');
        $grupo = self::crearGrupo();
        self::asignar($idDoc, $grupo);
        $a = $this->crearActividadApi($docente, 2);
        $this->publicarApi($docente, $admin, $a['id'], $grupo);
        [$est, $idEst] = $this->entrar('ESTUDIANTE');
        self::asignar($idEst, $grupo);
        $this->resolver($est, $a, 0);
        $this->resolver($est, $a, 2);

        $r = $docente->pedir('GET', "/docente/grupos/{$grupo}/analisis", [], ['actividad' => (string) $a['id']]);
        $this->assertSame(200, $docente->ultimoEstado);
        $this->assertSame(1, $r['agregados']['n_estudiantes']);
        $this->assertEqualsWithDelta(100.0, $r['agregados']['promedio'], 0.001);
        $this->assertEqualsWithDelta(100.0, $r['agregados']['minimo'], 0.001);

        $guardado = self::pdo()->query(
            "SELECT n_estudiantes, promedio FROM analisis_grupal WHERE grupo_id = {$grupo} ORDER BY id DESC LIMIT 1"
        )->fetch();
        $this->assertSame([1, '100.00'], [(int) $guardado['n_estudiantes'], $guardado['promedio']]);
    }

    public function testLaConsultaGuiadaRespetaElPeriodo(): void
    {
        // D-5: grupo + período + qué ver. Fuera del período no aparece nada de hoy.
        [$docente, $grupo] = $this->grupoConResultados();
        $hoy = gmdate('Y-m-d');
        $r = $docente->pedir('GET', "/docente/grupos/{$grupo}/analisis", [], ['desde' => $hoy, 'hasta' => $hoy]);
        $this->assertNotEmpty($r['preguntas_con_mas_error']);
        $this->assertNotEmpty($r['habilidades']);

        $vacio = $docente->pedir(
            'GET',
            "/docente/grupos/{$grupo}/analisis",
            [],
            ['desde' => '2000-01-01', 'hasta' => '2000-01-31']
        );
        $this->assertSame(200, $docente->ultimoEstado);
        $this->assertSame(
            [[], [], [], 0],
            [$vacio['prioritarios'], $vacio['preguntas_con_mas_error'], $vacio['habilidades'],
             $vacio['agregados']['n_estudiantes']]
        );
    }

    public function testSinServicioDeAnalisisElPanelSigueFuncionando(): void
    {
        [$docente, $grupo] = $this->grupoConResultados();
        self::$analisis->disponible = false;
        $r = $docente->pedir('GET', "/docente/grupos/{$grupo}/analisis");
        $this->assertSame(200, $docente->ultimoEstado, 'RNF-15');
        $this->assertFalse($r['aprendizaje_automatico']['servicio_disponible']);
        $this->assertNotEmpty($r['prioritarios'], 'el Nivel 1 no depende del servicio externo');
    }

    public function testSinServicioDeAnalisisSeSigueResolviendo(): void
    {
        self::$analisis->disponible = false;
        [$docente, $grupo, $a] = $this->grupoConResultados();
        $this->assertSame(
            0,
            count(array_filter(self::$analisis->enviados, fn ($e) => str_contains($e['ruta'], 'llm')))
        );
        $this->assertGreaterThan(0, (int) self::valor(
            'SELECT COUNT(*) FROM resultados r JOIN intentos i ON i.id = r.intento_id WHERE i.actividad_id = ?',
            [$a['id']]
        ));
    }

    public function testDocenteSoloVeSusGrupos(): void
    {
        [, $grupo] = $this->grupoConResultados();
        [$ajeno] = $this->entrar('DOCENTE');
        $ajeno->pedir('GET', "/docente/grupos/{$grupo}/analisis");
        $this->assertSame(403, $ajeno->ultimoEstado);
        $ajeno->pedir('GET', '/reportes', [], ['grupo' => (string) $grupo]);
        $this->assertSame(403, $ajeno->ultimoEstado);
    }

    public function testReportesFiltrablesPorGrupoActividadYPeriodo(): void
    {
        [$docente, $grupo, $a] = $this->grupoConResultados();
        $hoy = gmdate('Y-m-d');
        $r = $docente->pedir(
            'GET',
            '/reportes',
            [],
            ['grupo' => (string) $grupo, 'actividad' => (string) $a['id'], 'desde' => $hoy, 'hasta' => $hoy]
        );
        $this->assertSame(200, $docente->ultimoEstado);
        $this->assertCount(4, $r['filas']);
        $this->assertSame(4, (int) $r['resumen'][0]['estudiantes']);
        $vacio = $docente->pedir(
            'GET',
            '/reportes',
            [],
            ['grupo' => (string) $grupo, 'desde' => '2000-01-01', 'hasta' => '2000-01-31']
        );
        $this->assertSame([], $vacio['filas']);
    }
}
