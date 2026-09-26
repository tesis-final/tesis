<?php

declare(strict_types=1);

namespace Atlas\Tests\Api;

/** RF-20 (H28; §25.4; DEC-24): consultas en lenguaje natural sin datos identificables. */
final class AsistenteApiTest extends ApiTestCase
{
    /** @return array{0: Cliente, 1: string, 2: int} */
    private function escenario(): array
    {
        [$admin] = $this->entrar('ADMIN');
        [$docente, $idDoc] = $this->entrar('DOCENTE');
        $grupo = self::crearGrupo();
        $nombreGrupo = (string) self::valor('SELECT nombre FROM grupos_clase WHERE id = ?', [$grupo]);
        self::asignar($idDoc, $grupo);
        $a = $this->crearActividadApi($docente, 4);
        $this->publicarApi($docente, $admin, $a['id'], $grupo);
        foreach ([['Valentina', 'Rodríguez', 0], ['Mateo', 'Fernández', 4]] as [$n, $ap, $aciertos]) {
            [$est, $idEst] = $this->entrar('ESTUDIANTE', $n, $ap);
            self::asignar($idEst, $grupo);
            $this->resolver($est, $a, $aciertos);
        }

        return [$docente, $nombreGrupo, $grupo];
    }

    /** Nada identificable en lo que salió hacia el modelo. */
    private function assertSinIdentificables(): void
    {
        $salida = json_encode(array_map(
            fn ($e) => $e['cuerpo'],
            array_filter(self::$analisis->enviados, fn ($e) => str_contains($e['ruta'], 'llm'))
        ), JSON_UNESCAPED_UNICODE);
        $usuarios = self::pdo()
            ->query("SELECT nombre, apellido, correo FROM usuarios WHERE correo LIKE '%@prueba.atlas.local'")
            ->fetchAll();
        foreach ($usuarios as $u) {
            foreach (['Valentina', 'Rodríguez', 'Mateo', 'Fernández', $u['correo']] as $dato) {
                $this->assertStringNotContainsString($dato, (string) $salida, "H28: se envió '{$dato}' al LLM");
            }
        }
        $this->assertStringNotContainsString('@', (string) $salida);
    }

    public function testExplicarRecomendacionParaUnEstudiante(): void
    {
        [$docente] = $this->escenario();
        $r = $docente->pedir(
            'POST',
            '/asistente/consultas',
            ['pregunta' => 'Explicame por qué ATLAS recomienda esto para Valentina']
        );
        $this->assertSame(200, $docente->ultimoEstado);
        $this->assertSame(['EXPLICAR_RECOMENDACION', 'OK'], [$r['tipo'], $r['estado']]);
        $this->assertStringContainsString(
            'Valentina Rodríguez',
            $r['respuesta'],
            'ATLAS re-identifica del lado propio'
        );
        $this->assertSame('E1', $r['contexto_enviado']['datos']['estudiante']);
        $this->assertStringContainsString('E1', $r['contexto_enviado']['pregunta']);
        $this->assertContains('R01', array_column($r['datos']['reglas_que_la_generaron'], 'codigo'));
        $this->assertSinIdentificables();
    }

    public function testDificultadEstaSemana(): void
    {
        [$docente] = $this->escenario();
        $r = $docente->pedir(
            'POST',
            '/asistente/consultas',
            ['pregunta' => '¿Qué estudiantes tuvieron más dificultad esta semana?']
        );
        $this->assertSame('DIFICULTAD', $r['tipo']);
        $this->assertCount(
            1,
            $r['datos']['estudiantes_con_senales_de_riesgo'],
            'solo Valentina disparó reglas de riesgo'
        );
        $this->assertSinIdentificables();
    }

    public function testEstadoDelGrupoEnUnaCategoria(): void
    {
        [$docente, $nombreGrupo] = $this->escenario();
        $r = $docente->pedir(
            'POST',
            '/asistente/consultas',
            ['pregunta' => "¿Cómo viene el grupo {$nombreGrupo} en resolución de problemas?"]
        );
        $this->assertSame('ESTADO_GRUPO', $r['tipo']);
        $this->assertEqualsWithDelta(50.0, $r['datos']['puntaje_promedio'], 0.001);
        $this->assertSame('G1', $r['contexto_enviado']['datos']['grupo']);
        $this->assertStringNotContainsString($nombreGrupo, json_encode($r['contexto_enviado']));
        $this->assertSinIdentificables();
    }

    public function testSinLlmElDocenteRecibeLosDatosVerificados(): void
    {
        [$docente] = $this->escenario();
        self::$analisis->disponible = false;
        $r = $docente->pedir(
            'POST',
            '/asistente/consultas',
            ['pregunta' => 'Explicame por qué ATLAS recomienda esto para Valentina Rodríguez']
        );
        $this->assertSame(200, $docente->ultimoEstado, 'RNF-15');
        $this->assertSame('LLM_NO_DISPONIBLE', $r['estado']);
        $this->assertStringContainsString('Valentina Rodríguez', $r['respuesta']);
        $this->assertStringContainsString('R01', $r['respuesta']);
    }

    public function testConsultaNoReconocidaNoLlamaAlModelo(): void
    {
        [$docente] = $this->escenario();
        $r = $docente->pedir('POST', '/asistente/consultas', ['pregunta' => '¿Cuál es la capital de Francia?']);
        $this->assertSame('NO_RECONOCIDA', $r['estado']);
        $this->assertSame(
            [],
            array_values(array_filter(self::$analisis->enviados, fn ($e) => str_contains($e['ruta'], 'llm')))
        );
    }

    public function testHistorialGuardaPreguntaRespuestaYLoEnviado(): void
    {
        [$docente] = $this->escenario();
        $docente->pedir(
            'POST',
            '/asistente/consultas',
            ['pregunta' => '¿Qué estudiantes tuvieron más dificultad esta semana?']
        );
        $h = $docente->pedir('GET', '/asistente/consultas');
        $this->assertSame('¿Qué estudiantes tuvieron más dificultad esta semana?', $h[0]['pregunta']);
        $this->assertNotNull($h[0]['respuesta']);
        $this->assertSame('DIFICULTAD', $h[0]['contexto_enviado']['tipo'], 'H28: queda la evidencia de lo enviado');
    }
}
