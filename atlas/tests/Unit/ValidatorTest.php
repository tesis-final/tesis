<?php

declare(strict_types=1);

namespace Atlas\Tests\Unit;

use Atlas\Core\Validator;
use PHPUnit\Framework\TestCase;

/** Paso [3] de la cadena de middleware (§26.3): 422 con detalle por campo. */
final class ValidatorTest extends TestCase
{
    public function testCamposObligatoriosYTipos(): void
    {
        [$ok, $err] = Validator::validar(
            ['correo' => ' Ana@Ejemplo.UY ', 'edad' => '12', 'rol' => 'DOCENTE'],
            [
                'correo' => 'requerido|correo',
                'edad' => 'requerido|entero|positivo',
                'rol' => 'en:ADMIN,DOCENTE',
                'nombre' => 'requerido|texto'
            ]
        );
        $this->assertSame(['nombre' => 'Es obligatorio.'], $err);
        $this->assertSame('ana@ejemplo.uy', $ok['correo']);
        $this->assertSame(12, $ok['edad']);
    }

    public function testRechazaValoresInvalidos(): void
    {
        [, $err] = Validator::validar(
            [
                'correo' => 'no-es-correo',
                'n' => 'x',
                'rol' => 'ROOT',
                'lista' => ['a' => 1],
                'fecha' => '2026-02-30',
                'texto' => '   '
            ],
            [
                'correo' => 'correo',
                'n' => 'entero',
                'rol' => 'en:ADMIN',
                'lista' => 'lista',
                'fecha' => 'fecha',
                'texto' => 'requerido|texto'
            ]
        );
        $this->assertSame(
            ['correo', 'n', 'rol', 'lista', 'fecha', 'texto'],
            array_keys($err),
            'un texto de solo espacios no es válido'
        );
    }

    public function testMaximoYMinimo(): void
    {
        [, $err] = Validator::validar(
            ['t' => str_repeat('a', 11), 'l' => []],
            ['t' => 'texto|max:10', 'l' => 'requerido|lista|min:1']
        );
        $this->assertArrayHasKey('t', $err);
    }
}
