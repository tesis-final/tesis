<?php

declare(strict_types=1);

/*
 * ATLAS — arranque de Laravel (acta D-1). Laravel resuelve ruteo, sesión,
 * validación y manejo de errores; la lógica propia (servicios, motor de análisis,
 * indicadores, asistente) sigue en clases PHP que no dependen del framework.
 *
 * Cadena de cada petición a /api/v1 (PDF §26.3):
 *   [1] atlas.sesion    ¿hay sesión válida? (+ token CSRF)      no → 401 (403 sin CSRF)
 *   [2] atlas.permiso   ¿este rol puede hacer esto?              no → 403 y queda registrado
 *   [3] Form Request    ¿los datos que llegaron sirven?          no → 422
 *   [4] atlas.auditoria se registra la acción con su autor
 */

use Atlas\Core\HttpException;
use Atlas\Http\Json;
use Atlas\Http\Middleware\Auditoria;
use Atlas\Http\Middleware\Autenticacion;
use Atlas\Http\Middleware\Permiso;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Session\Middleware\StartSession;
use Symfony\Component\HttpKernel\Exception\MethodNotAllowedHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

$app = Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        // La interfaz (app.html + js/) es estática y la sirve public/index.php sin Laravel.
        api: __DIR__ . '/../routes/api.php',
        apiPrefix: 'api/v1',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // La API usa sesión del servidor (no tokens): el grupo api arranca la sesión.
        $middleware->api(prepend: [StartSession::class]);
        $middleware->alias([
            'atlas.sesion' => Autenticacion::class,
            'atlas.permiso' => Permiso::class,
            'atlas.auditoria' => Auditoria::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // Los errores de negocio (401, 403, 404, 409, 422) son respuestas esperadas, no fallas:
        // no van al log. Lo inesperado sí (canal stderr → journald, config/logging.php).
        $exceptions->dontReport([HttpException::class]);
        // Mismo formato de error que antes de la migración: {"error": "...", ...}.
        $exceptions->render(fn (HttpException $e) => Json::error($e->getMessage(), $e->estado, $e->detalle));
        $exceptions->render(fn (NotFoundHttpException $e) => Json::error('Ruta no encontrada.', 404));
        $exceptions->render(fn (MethodNotAllowedHttpException $e) => Json::error('Método no permitido.', 405));
        $exceptions->render(function (PDOException $e) {
            // Las violaciones de reglas del modelo (triggers SIGNAL 45000) son errores de negocio.
            if (($e->errorInfo[0] ?? '') === '45000') {
                return Json::error((string) preg_replace('/^.*ATLAS: /', '', $e->getMessage()), 409);
            }

            return Json::error('Error interno de base de datos.', 500);
        });
        $exceptions->render(function (Throwable $e, Request $request) {
            // Sin detalles internos en la respuesta; el detalle queda en el log.
            return $request->is('api/*') ? Json::error('Error interno.', 500) : null;
        });
    })
    ->create();

// El código se monta en solo lectura (§28.3): lo que Laravel escribe (sesiones,
// cachés de arranque) va a una carpeta escribible fuera del código.
$escribible = getenv('ATLAS_STORAGE') ?: $app->basePath('storage');
foreach (['framework/sessions', 'framework/cache', 'framework/views', 'logs', 'bootstrap'] as $carpeta) {
    if (!is_dir("{$escribible}/{$carpeta}")) {
        @mkdir("{$escribible}/{$carpeta}", 0770, true);
    }
}
$app->useStoragePath($escribible);
foreach (['APP_PACKAGES_CACHE' => 'packages.php', 'APP_SERVICES_CACHE' => 'services.php'] as $variable => $archivo) {
    if (getenv($variable) === false) {
        putenv("{$variable}={$escribible}/bootstrap/{$archivo}");
        $_ENV[$variable] = $_SERVER[$variable] = "{$escribible}/bootstrap/{$archivo}";
    }
}

return $app;
