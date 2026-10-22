<?php

declare(strict_types=1);

namespace Atlas\Tests\Unit;

use Illuminate\Contracts\Http\Kernel;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Bootstrap\HandleExceptions;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Facade;
use PHPUnit\Framework\TestCase;

/**
 * Contrato de la API en Laravel (§26.3): cada ruta declara sesión [1], permiso [2]
 * y auditoría [4]; lo que no existe responde 404/405 con el formato de siempre.
 */
final class RutasTest extends TestCase
{
    private Application $laravel;

    protected function setUp(): void
    {
        putenv('ATLAS_STORAGE=' . sys_get_temp_dir() . '/atlas-pruebas');
        $this->laravel = require dirname(__DIR__, 2) . '/bootstrap/app.php';
        $this->laravel->make(Kernel::class)->bootstrap();
    }

    protected function tearDown(): void
    {
        HandleExceptions::flushState();
        $this->laravel->flush();
        Facade::clearResolvedInstances();
        Facade::setFacadeApplication(null);
    }

    /** @return array<string, list<string>> "MÉTODO /ruta" => middleware */
    private function rutas(): array
    {
        $rutas = [];
        foreach ($this->laravel['router']->getRoutes() as $r) {
            $metodo = $r->methods()[0];
            $rutas["{$metodo} /{$r->uri()}"] = $r->gatherMiddleware();
        }

        return $rutas;
    }

    public function testLas44RutasDeLaApiV1(): void
    {
        $rutas = array_filter(array_keys($this->rutas()), fn ($r) => str_contains($r, ' /api/v1/'));
        $this->assertCount(44, $rutas, '43 del contrato original + la decisión del docente (D-6)');
    }

    public function testTodasExigenSesionMenosSaludYLogin(): void
    {
        foreach ($this->rutas() as $ruta => $middleware) {
            if (!str_contains($ruta, ' /api/v1/')) {
                continue;
            }
            $publica = in_array($ruta, ['GET /api/v1/health', 'POST /api/v1/auth/login'], true);
            $this->assertSame(!$publica, in_array('atlas.sesion', $middleware, true), $ruta);
        }
    }

    public function testPermisosYAuditoriaPorRuta(): void
    {
        $r = $this->rutas();
        $this->assertContains('atlas.permiso:usuarios.gestionar', $r['POST /api/v1/usuarios']);
        $this->assertContains('atlas.auditoria:usuarios.crear', $r['POST /api/v1/usuarios']);
        $this->assertContains('atlas.permiso:actividades.aprobar', $r['POST /api/v1/actividades/{id}/aprobar']);
        $this->assertContains('atlas.permiso:panel.docente', $r['GET /api/v1/docente/grupos/{id}/analisis']);
        $this->assertContains(
            'atlas.permiso:recomendaciones.decidir',
            $r['POST /api/v1/recomendaciones/{id}/decision']
        );
        // Toda operación que modifica datos queda auditada, salvo las que se registran en otra tabla.
        $sinAuditoria = ['POST /api/v1/auth/login', 'POST /api/v1/auth/logout',
            'POST /api/v1/intentos/{id}/eventos', 'PUT /api/v1/intentos/{id}/respuestas/{pregunta}'];
        foreach ($r as $ruta => $middleware) {
            $ignorada = str_starts_with($ruta, 'GET') || !str_contains($ruta, '/api/');
            if ($ignorada || in_array($ruta, $sinAuditoria, true)) {
                continue;
            }
            $auditada = array_filter($middleware, fn ($m) => str_starts_with($m, 'atlas.auditoria:'));
            $this->assertNotEmpty($auditada, "{$ruta} tiene que quedar en la auditoría");
        }
    }

    public function testRutaInexistente404YMetodoIncorrecto405(): void
    {
        $kernel = $this->laravel->make(Kernel::class);
        $r = $kernel->handle(Request::create('/api/v1/no-existe', 'GET'));
        $this->assertSame(404, $r->getStatusCode());
        $this->assertSame(['error' => 'Ruta no encontrada.'], json_decode($r->getContent(), true));
        $r = $kernel->handle(Request::create('/api/v1/usuarios', 'DELETE'));
        $this->assertSame(405, $r->getStatusCode());
    }

    public function testSinSesion401(): void
    {
        $r = $this->laravel->make(Kernel::class)->handle(Request::create('/api/v1/auth/me', 'GET'));
        $this->assertSame(401, $r->getStatusCode());
        $this->assertSame('Se requiere iniciar sesión.', json_decode($r->getContent(), true)['error']);
    }
}
