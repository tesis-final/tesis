<?php

declare(strict_types=1);

namespace Atlas\Tests\Api;

/** RF-06, RF-07, RF-08, RF-09 y OBJ-03 (50 resoluciones, 100 % registradas). */
final class ResolucionTest extends ApiTestCase
{
    /** @return array{0: Cliente, 1: array<string, mixed>, 2: int} */
    private function escenario(int $preguntas = 3): array
    {
        [$admin] = $this->entrar('ADMIN');
        [$docente, $idDoc] = $this->entrar('DOCENTE');
        [$est, $idEst] = $this->entrar('ESTUDIANTE');
        $grupo = self::crearGrupo();
        self::asignar($idDoc, $grupo);
        self::asignar($idEst, $grupo);
        $a = $this->crearActividadApi($docente, $preguntas);
        $this->publicarApi($docente, $admin, $a['id'], $grupo);

        return [$est, $a, $idEst];
    }

    public function testResolverGeneraResultadoYSecuenciaReconstruible(): void
    {
        [$est, $a] = $this->escenario(3);
        $r = $this->resolver($est, $a, 2);

        $this->assertSame([2, 3], [$r['correctas'], $r['total_preguntas']]);
        $this->assertEqualsWithDelta(66.67, $r['puntaje'], 0.001);
        $this->assertSame('FINALIZADO', $r['intento']['estado']);

        $eventos = self::pdo()->query("SELECT secuencia, tipo, pregunta_id, opcion_id FROM interacciones
                                        WHERE intento_id = {$r['intento']['id']} ORDER BY secuencia")->fetchAll();
        $tipos = array_column($eventos, 'tipo');
        $this->assertSame('INICIO', $tipos[0]);
        $this->assertSame('FIN', end($tipos));
        $this->assertSame(
            2,
            count(array_keys($tipos, 'CAMBIO_OPCION')),
            'RF-06: los cambios de opción quedan registrados'
        );
        $this->assertSame(
            range(1, count($eventos)),
            array_map('intval', array_column($eventos, 'secuencia')),
            'RF-06: secuencia continua que permite reconstruir el proceso'
        );
    }

    public function testReenviarUnLoteNoDuplicaEventos(): void
    {
        [$est, $a] = $this->escenario(1);
        $inicio = $est->pedir('POST', '/intentos', ['actividad_id' => $a['id']]);
        $id = $inicio['intento']['id'];
        $lote = ['eventos' => [
            ['secuencia' => 2, 'tipo' => 'PAUSA', 'ocurrido_en' => gmdate('c')],
            ['secuencia' => 3, 'tipo' => 'REANUDA', 'ocurrido_en' => gmdate('c'), 'duracion_ms' => 65000],
        ]];
        $primero = $est->pedir('POST', "/intentos/{$id}/eventos", $lote);
        $segundo = $est->pedir('POST', "/intentos/{$id}/eventos", $lote);
        $this->assertSame([2, 0], [$primero['nuevos'], $segundo['nuevos']]);
        $this->assertSame(3, (int) self::valor('SELECT COUNT(*) FROM interacciones WHERE intento_id = ?', [$id]));
        $this->assertSame(
            65000,
            (int) self::valor("SELECT duracion_ms FROM interacciones WHERE intento_id = ? AND tipo = 'REANUDA'", [$id]),
            'RF-06: la pausa queda con su duración'
        );
    }

    public function testTiempoTotalYPorPreguntaEnSegundos(): void
    {
        [$est, $a] = $this->escenario(2);
        $r = $this->resolver($est, $a, 2);
        $this->assertIsInt($r['intento']['duracion_seg']);
        $this->assertSame([12, 12], array_column($r['detalle'], 'tiempo_seg'), 'RF-09: tiempos parciales por pregunta');
    }

    public function testAbandonoSinResultadoYConTiempo(): void
    {
        [$est, $a] = $this->escenario(2);
        $inicio = $est->pedir('POST', '/intentos', ['actividad_id' => $a['id']]);
        $id = $inicio['intento']['id'];
        $r = $est->pedir('POST', "/intentos/{$id}/abandonar");
        $this->assertSame('ABANDONADO', $r['estado']);
        $this->assertIsInt($r['duracion_seg'], 'RF-09: registra el tiempo hasta la interrupción');
        $est->pedir('GET', "/intentos/{$id}/resultado");
        $this->assertSame(409, $est->ultimoEstado, 'RF-07: los abandonados no generan resultado');
    }

    public function testCadaInicioEsDistinguibleYSeReanudaElEnCurso(): void
    {
        [$est, $a, $idEst] = $this->escenario(1);
        $i1 = $est->pedir('POST', '/intentos', ['actividad_id' => $a['id']]);
        $i1b = $est->pedir('POST', '/intentos', ['actividad_id' => $a['id']]);
        $this->assertTrue($i1b['reanudado']);
        $this->assertSame($i1['intento']['id'], $i1b['intento']['id']);
        $est->pedir('POST', "/intentos/{$i1['intento']['id']}/abandonar");
        $i2 = $est->pedir('POST', '/intentos', ['actividad_id' => $a['id']]);
        $this->assertSame(2, $i2['intento']['numero_intento']);
        $estados = self::pdo()
            ->query("SELECT estado FROM intentos WHERE usuario_id = {$idEst} ORDER BY numero_intento")
            ->fetchAll(\PDO::FETCH_COLUMN);
        $this->assertSame(['ABANDONADO', 'EN_CURSO'], $estados, 'RF-08: en curso / finalizado / abandonado');
    }

    public function testNoSeRespondeConOpcionesDeOtraPregunta(): void
    {
        [$est, $a] = $this->escenario(2);
        $inicio = $est->pedir('POST', '/intentos', ['actividad_id' => $a['id']]);
        [$p1, $p2] = $a['preguntas'];
        $est->pedir(
            'PUT',
            "/intentos/{$inicio['intento']['id']}/respuestas/{$p1['id']}",
            ['opcion_id' => $p2['opciones'][0]['id']]
        );
        $this->assertSame(422, $est->ultimoEstado);
    }

    public function testCincuentaResolucionesQuedanCompletamenteRegistradas(): void
    {
        [$admin] = $this->entrar('ADMIN');
        [$docente, $idDoc] = $this->entrar('DOCENTE');
        $grupo = self::crearGrupo();
        self::asignar($idDoc, $grupo);
        $a = $this->crearActividadApi($docente, 3);
        $this->publicarApi($docente, $admin, $a['id'], $grupo);

        $intentos = [];
        for ($i = 0; $i < 50; $i++) {
            [$est, $idEst] = $this->entrar('ESTUDIANTE');
            self::asignar($idEst, $grupo);
            $intentos[] = $this->resolver($est, $a, $i % 4)['intento']['id'];
        }
        $lista = implode(',', $intentos);
        $completos = (int) self::valor(
            "SELECT COUNT(*) FROM intentos i JOIN resultados r ON r.intento_id = i.id
              WHERE i.id IN ({$lista}) AND i.duracion_seg IS NOT NULL
                AND (SELECT COUNT(*) FROM respuestas x WHERE x.intento_id = i.id) = 3
                AND (SELECT COUNT(*) FROM interacciones x WHERE x.intento_id = i.id) >= 5"
        );
        $this->assertSame(50, $completos, 'OBJ-03: el 100 % de 50 resoluciones con respuestas, tiempo e intentos');
    }
}
