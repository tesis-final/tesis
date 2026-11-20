<?php

declare(strict_types=1);

namespace Atlas\Tests\Api;

use Atlas\Core\Config;
use Atlas\Services\AnalisisClient;
use Illuminate\Contracts\Http\Kernel;
use Illuminate\Foundation\Bootstrap\HandleExceptions;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Facade;

/**
 * Navegador simulado: conserva su cookie de sesión (ATLASSID) y el token CSRF
 * entre peticiones y atraviesa la aplicación Laravel real (ruteo + middleware +
 * Form Requests + servicios + MySQL), sin servidor web de por medio.
 */
final class Cliente
{
    public ?string $csrf = null;
    public ?string $cookieSesion = null;
    public int $ultimoEstado = 0;

    public function __construct(private readonly Config $config, private readonly AnalisisClientFalso $analisis)
    {
    }

    /** @param array<string, mixed> $cuerpo @param array<string, string> $query @return mixed cuerpo decodificado */
    public function pedir(
        string $metodo,
        string $ruta,
        array $cuerpo = [],
        array $query = [],
        bool $conCsrf = true
    ): mixed {
        // Las sesiones de las pruebas van a una carpeta temporal, no al repositorio.
        putenv('ATLAS_STORAGE=' . sys_get_temp_dir() . '/atlas-pruebas');
        $laravel = require dirname(__DIR__, 2) . '/bootstrap/app.php';
        $laravel->instance(Config::class, $this->config);
        $laravel->instance(AnalisisClient::class, $this->analisis);
        $kernel = $laravel->make(Kernel::class);

        $servidor = ['REMOTE_ADDR' => '172.16.30.101', 'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json'];
        if ($conCsrf && $this->csrf !== null) {
            $servidor['HTTP_X_CSRF_TOKEN'] = $this->csrf;
        }
        $uri = '/api/v1' . $ruta . ($query === [] ? '' : '?' . http_build_query($query));
        $peticion = Request::create(
            $uri,
            $metodo,
            [],
            $this->cookieSesion !== null ? ['ATLASSID' => $this->cookieSesion] : [],
            [],
            $servidor,
            in_array($metodo, ['GET', 'HEAD'], true) ? null : (string) json_encode($cuerpo)
        );
        $respuesta = $kernel->handle($peticion);
        $kernel->terminate($peticion, $respuesta);
        $this->anotarRuta($laravel, $peticion, $respuesta->getStatusCode());
        // Laravel instala sus manejadores de errores al arrancar; se quitan como en sus propias
        // pruebas. Y se suelta la aplicación entera, para que cierre sus conexiones a MySQL.
        HandleExceptions::flushState();
        $laravel->flush();
        Facade::clearResolvedInstances();
        Facade::setFacadeApplication(null);
        unset($kernel, $laravel);
        gc_collect_cycles();
        foreach ($respuesta->headers->getCookies() as $cookie) {
            if ($cookie->getName() === 'ATLASSID') {
                $this->cookieSesion = $cookie->getValue();
            }
        }
        $this->ultimoEstado = $respuesta->getStatusCode();
        $json = (string) $respuesta->getContent();

        return $json === '' ? null : json_decode($json, true);
    }

    /**
     * Cobertura de rutas (informe de Testing del Hito 3): si ATLAS_RUTAS_CUBIERTAS apunta a un
     * archivo, anota cada ruta que la prueba alcanzó, con su método y el código de respuesta, y
     * deja al lado (.todas) la lista completa de rutas de la API para comparar.
     */
    private function anotarRuta(object $laravel, Request $peticion, int $estado): void
    {
        $archivo = getenv('ATLAS_RUTAS_CUBIERTAS');
        if ($archivo === false || $archivo === '') {
            return;
        }
        $ruta = $peticion->route();
        $patron = $ruta === null ? 'SIN-RUTA ' . $peticion->path() : $peticion->method() . ' ' . $ruta->uri();
        file_put_contents($archivo, "{$patron}\t{$estado}\n", FILE_APPEND | LOCK_EX);
        if (!is_file($archivo . '.todas')) {
            $todas = [];
            foreach ($laravel['router']->getRoutes() as $r) {
                foreach (array_diff($r->methods(), ['HEAD']) as $m) {
                    $todas[] = "{$m} {$r->uri()}";
                }
            }
            sort($todas);
            file_put_contents($archivo . '.todas', implode("\n", $todas) . "\n", LOCK_EX);
        }
    }

    /** @return array<string, mixed> */
    public function login(string $correo, string $contrasena): array
    {
        $r = $this->pedir('POST', '/auth/login', ['correo' => $correo, 'contrasena' => $contrasena]);
        if ($this->ultimoEstado === 200) {
            $this->csrf = $r['csrf'];
        }

        return $r;
    }
}
