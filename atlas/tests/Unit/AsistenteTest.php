<?php

declare(strict_types=1);

namespace Atlas\Tests\Unit;

use Atlas\Services\Asistente\Anonimizador;
use Atlas\Services\Asistente\Consulta;
use Atlas\Services\Asistente\IntentParser;
use PHPUnit\Framework\TestCase;

/** Interpretación local de preguntas y anonimización (RF-20, H28, §25.4). */
final class AsistenteTest extends TestCase
{
    private const GRUPOS = [['id' => 7, 'nombre' => '3A'], ['id' => 8, 'nombre' => '3B']];
    private const ESTUDIANTES = [
        ['id' => 11, 'nombre' => 'Juan', 'apellido' => 'Pérez'],
        ['id' => 12, 'nombre' => 'María', 'apellido' => 'Gómez'],
        ['id' => 13, 'nombre' => 'Juan', 'apellido' => 'Silva'],
    ];
    private const CATEGORIAS = [['codigo' => 'RESOLUCION_PROBLEMAS', 'nombre' => 'Resolución de problemas']];

    private function interpretar(string $pregunta): Consulta
    {
        return (new IntentParser())->interpretar($pregunta, self::GRUPOS, self::ESTUDIANTES, self::CATEGORIAS);
    }

    public function testLasTresConsultasDeEjemploDelPdf(): void
    {
        $c = $this->interpretar('¿Cómo viene el grupo 3A en resolución de problemas?');
        $this->assertSame([Consulta::ESTADO_GRUPO, 7, 'RESOLUCION_PROBLEMAS'], [$c->tipo, $c->grupoId, $c->categoria]);

        $c = $this->interpretar('¿Qué estudiantes tuvieron más dificultad esta semana?');
        $this->assertSame([Consulta::DIFICULTAD, 'semana'], [$c->tipo, $c->periodo]);

        $c = $this->interpretar('Explicame por qué ATLAS recomienda esto para María');
        $this->assertSame([Consulta::EXPLICAR_RECOMENDACION, 12], [$c->tipo, $c->estudianteId]);
    }

    public function testNombreAmbiguoRequiereApellido(): void
    {
        // Hay dos "Juan": sin apellido no se adivina.
        $this->assertNotSame(
            Consulta::EXPLICAR_RECOMENDACION,
            $this->interpretar('¿Por qué recomienda eso para Juan?')->tipo
        );
        $c = $this->interpretar('¿Por qué recomienda eso para Juan Silva?');
        $this->assertSame([Consulta::EXPLICAR_RECOMENDACION, 13], [$c->tipo, $c->estudianteId]);
    }

    public function testPreguntaFueraDeAlcanceNoSeReconoce(): void
    {
        $this->assertSame(Consulta::NO_RECONOCIDA, $this->interpretar('¿Qué hora es en Tokio?')->tipo);
    }

    public function testAnonimizacionYReidentificacion(): void
    {
        $a = new Anonimizador();
        $e1 = $a->estudiante(12, 'María', 'Gómez');
        $g1 = $a->grupo(7, '3A');
        $sanitizada = $a->sanitizar(
            '¿Cómo le fue a María Gómez (maria.gomez@iti.edu.uy, CI 4.567.890-1) en el grupo 3A?'
        );

        $this->assertSame(['E1', 'G1'], [$e1, $g1]);
        $this->assertStringNotContainsString('María', $sanitizada);
        $this->assertStringNotContainsString('@', $sanitizada);
        $this->assertStringNotContainsString('4.567.890', $sanitizada);
        $this->assertStringContainsString('E1', $sanitizada);
        $this->assertFalse($a->contieneIdentificables($sanitizada));
        $this->assertTrue($a->contieneIdentificables('{"texto":"María Gómez"}'));

        $this->assertSame('María Gómez mejoró en 3A.', $a->reidentificar('E1 mejoró en G1.'));
    }

    public function testE10NoSeConfundeConE1(): void
    {
        $a = new Anonimizador();
        for ($i = 1; $i <= 10; $i++) {
            $a->estudiante($i, "Nombre{$i}", 'Apellido');
        }
        $this->assertSame('Nombre10 Apellido y Nombre1 Apellido', $a->reidentificar('E10 y E1'));
    }
}
