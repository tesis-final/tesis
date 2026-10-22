<?php

declare(strict_types=1);

namespace Atlas\Providers;

use Atlas\Core\App as Atlas;
use Atlas\Core\Config;
use Atlas\Core\SesionLaravel;
use Atlas\Services\AnalisisClient;
use Illuminate\Support\ServiceProvider;

/**
 * Une Laravel con la lógica propia: una composición de ATLAS (Atlas\Core\App) por
 * petición, con la sesión de Laravel. Los controladores la reciben por inyección.
 * Las pruebas pueden registrar otra Config o un AnalisisClient simulado antes de
 * atender la petición.
 */
final class AtlasServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->scoped(Atlas::class, fn ($laravel) => new Atlas(
            $laravel->bound(Config::class) ? $laravel->make(Config::class) : Config::desdeEntorno(),
            new SesionLaravel(fn () => $laravel->make('request')->session()),
            null,
            $laravel->bound(AnalisisClient::class) ? $laravel->make(AnalisisClient::class) : null
        ));
    }
}
