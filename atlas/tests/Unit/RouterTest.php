<?php

declare(strict_types=1);

namespace Atlas\Tests\Unit;

use Atlas\Core\HttpException;
use Atlas\Core\Route;
use Atlas\Core\Router;
use PHPUnit\Framework\TestCase;

final class RouterTest extends TestCase
{
    private function router(): Router
    {
        $r = new Router();
        $r->agregar(new Route('GET', '/api/v1/actividades/{id}', ['X', 'ver']));
        $r->agregar(new Route('POST', '/api/v1/actividades/{id}/enviar', ['X', 'enviar']));

        return $r;
    }

    public function testResuelveParametros(): void
    {
        [$ruta, $params] = $this->router()->resolver('GET', '/api/v1/actividades/42');
        $this->assertSame('ver', $ruta->manejador[1]);
        $this->assertSame(['id' => '42'], $params);
    }

    public function testMetodoIncorrecto405YRutaInexistente404(): void
    {
        try {
            $this->router()->resolver('DELETE', '/api/v1/actividades/42');
            $this->fail();
        } catch (HttpException $e) {
            $this->assertSame(405, $e->estado);
        }
        $this->expectExceptionCode(404);
        $this->router()->resolver('GET', '/api/v1/nada');
    }

    public function testTodasLasRutasDeclaradasSonValidas(): void
    {
        $rutas = require __DIR__ . '/../../config/rutas.php';
        $firmas = [];
        foreach ($rutas as $r) {
            $this->assertInstanceOf(Route::class, $r);
            $this->assertTrue(
                method_exists($r->manejador[0], $r->manejador[1]),
                "{$r->manejador[0]}::{$r->manejador[1]}"
            );
            $firma = $r->metodo . ' ' . $r->ruta;
            $this->assertNotContains($firma, $firmas, "Ruta duplicada: {$firma}");
            $firmas[] = $firma;
            if ($r->requiereSesion === false) {
                $this->assertContains(
                    $r->ruta,
                    ['/api/v1/health', '/api/v1/auth/login'],
                    'Solo login y salud son públicas'
                );
            }
        }
    }
}
