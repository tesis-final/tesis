<?php

declare(strict_types=1);

namespace Atlas\Core;

use Atlas\Middleware\Auditoria;
use Atlas\Middleware\Autenticacion;
use Atlas\Middleware\Middleware;
use Atlas\Middleware\Permisos;
use Atlas\Middleware\Validacion;
use PDOException;
use Throwable;

/**
 * Atiende una petición: ruteo → cadena de middleware (§26.3) → controlador.
 * Traduce errores a respuestas JSON sin exponer detalles internos.
 */
final class Kernel
{
    private Router $router;

    public function __construct(private readonly App $app)
    {
        $this->router = new Router();
        foreach (require dirname(__DIR__, 2) . '/config/rutas.php' as $ruta) {
            $this->router->agregar($ruta);
        }
    }

    public function atender(Request $peticion): Response
    {
        try {
            [$ruta, $parametros] = $this->router->resolver($peticion->metodo, $peticion->ruta);
            $peticion->con('parametros', $parametros);
            /** @var list<Middleware> $cadena */
            $cadena = [
                new Autenticacion(
                    $this->app->sesion(),
                    $this->app->usuarios(),
                    $this->app->db(),
                    $this->app->auditoria()
                ),
                new Permisos($this->app->usuarios(), $this->app->auditoria()),
                new Validacion(),
                new Auditoria($this->app->auditoria()),
            ];
            $controlador = function (Request $p) use ($ruta): Response {
                [$clase, $metodo] = $ruta->manejador;

                return (new $clase($this->app))->$metodo($p);
            };
            $siguiente = array_reduce(
                array_reverse($cadena),
                fn (callable $sig, Middleware $m) => fn (Request $p) => $m->procesar($p, $ruta, $sig),
                $controlador
            );

            return $siguiente($peticion);
        } catch (HttpException $e) {
            return Response::json(['error' => $e->getMessage()] + $e->detalle, $e->estado);
        } catch (PDOException $e) {
            // Las violaciones de reglas del modelo (triggers SIGNAL 45000) son errores de negocio.
            if (($e->errorInfo[0] ?? '') === '45000') {
                return Response::json(['error' => preg_replace('/^.*ATLAS: /', '', $e->getMessage())], 409);
            }
            error_log('ATLAS PDO: ' . $e->getMessage());

            return Response::json(['error' => 'Error interno de base de datos.'], 500);
        } catch (Throwable $e) {
            error_log('ATLAS: ' . $e::class . ': ' . $e->getMessage() . "\n" . $e->getTraceAsString());

            return Response::json(['error' => 'Error interno.'], 500);
        }
    }
}
