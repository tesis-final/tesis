<?php

declare(strict_types=1);

namespace Atlas\Tests\Api;

use Atlas\Core\App;
use Atlas\Core\ArraySession;
use Atlas\Core\Config;
use Atlas\Core\Kernel;
use Atlas\Core\Request;

/**
 * Navegador simulado: conserva su sesión (cookie) y el token CSRF entre peticiones
 * y atraviesa el kernel real (ruteo + middleware + servicios + MySQL).
 */
final class Cliente
{
    public ArraySession $sesion;
    public ?string $csrf = null;
    public int $ultimoEstado = 0;

    public function __construct(private readonly Config $config, private readonly AnalisisClientFalso $analisis)
    {
        $this->sesion = new ArraySession();
    }

    /** @param array<string, mixed> $cuerpo @param array<string, string> $query @return mixed cuerpo decodificado */
    public function pedir(
        string $metodo,
        string $ruta,
        array $cuerpo = [],
        array $query = [],
        bool $conCsrf = true
    ): mixed {
        $cabeceras = $conCsrf && $this->csrf !== null ? ['x-csrf-token' => $this->csrf] : [];
        $app = new App($this->config, $this->sesion, null, $this->analisis);
        $respuesta = (new Kernel($app))->atender(new Request(
            $metodo,
            '/api/v1' . $ruta,
            $query,
            $cuerpo,
            $cabeceras,
            '172.16.30.101'
        ));
        $this->ultimoEstado = $respuesta->estado;
        $json = $respuesta->cuerpo();

        return $json === '' ? null : json_decode($json, true);
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
