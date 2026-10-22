<?php

declare(strict_types=1);

namespace Atlas\Core;

use Atlas\Repositories\ActividadRepository;
use Atlas\Repositories\AnalisisRepository;
use Atlas\Repositories\AuditoriaRepository;
use Atlas\Repositories\ConversacionRepository;
use Atlas\Repositories\IntentoRepository;
use Atlas\Repositories\OrganizacionRepository;
use Atlas\Repositories\ReporteRepository;
use Atlas\Repositories\UsuarioRepository;
use Atlas\Services\ActividadService;
use Atlas\Services\AnalisisClient;
use Atlas\Services\Analysis\AnalisisService;
use Atlas\Services\Asistente\AsistenteService;
use Atlas\Services\Asistente\IntentParser;
use Atlas\Services\AuditoriaService;
use Atlas\Services\AuthService;
use Atlas\Services\IntentoService;
use Atlas\Services\PanelDocenteService;
use Atlas\Services\UsuarioService;

/**
 * Composición de dependencias de la lógica propia (servicios, motor de análisis,
 * repositorios), independiente de Laravel: Laravel la crea una vez por petición
 * (AtlasServiceProvider) y también la usa la consola (bin/atlas). Cada objeto se crea una sola vez
 * por petición. Los tests pueden reemplazar la sesión, el reloj y el cliente
 * del servicio de análisis.
 */
final class App
{
    /** @var array<string, object> */
    private array $instancias = [];

    public function __construct(
        public readonly Config $config,
        private readonly ?Session $sesionInyectada = null,
        private readonly ?Clock $relojInyectado = null,
        private readonly ?AnalisisClient $clienteInyectado = null
    ) {
    }

    /**
     * @template T of object
     * @param class-string<T> $clase
     * @param callable(): T   $fabrica
     * @return T
     */
    private function una(string $clase, callable $fabrica): object
    {
        return $this->instancias[$clase] ??= $fabrica();
    }

    public function db(): Database
    {
        return $this->una(Database::class, fn () => new Database($this->config));
    }

    public function sesion(): Session
    {
        // En la web la inyecta AtlasServiceProvider (sesión de Laravel); en la consola, en memoria.
        return $this->una(Session::class, fn () => $this->sesionInyectada ?? new ArraySession());
    }

    public function reloj(): Clock
    {
        return $this->una(Clock::class, fn () => $this->relojInyectado ?? new Clock());
    }

    public function clienteAnalisis(): AnalisisClient
    {
        return $this->una(AnalisisClient::class, fn () => $this->clienteInyectado
            ?? new AnalisisClient(
                $this->config->texto('ATLAS_ANALYSIS_URL', 'http://atlas-analysis:8000'),
                (float) $this->config->entero('ATLAS_ANALYSIS_TIMEOUT', 5)
            ));
    }

    public function usuarios(): UsuarioRepository
    {
        return $this->una(UsuarioRepository::class, fn () => new UsuarioRepository($this->db()));
    }

    public function organizacion(): OrganizacionRepository
    {
        return $this->una(OrganizacionRepository::class, fn () => new OrganizacionRepository($this->db()));
    }

    public function actividadesRepo(): ActividadRepository
    {
        return $this->una(ActividadRepository::class, fn () => new ActividadRepository($this->db()));
    }

    public function intentosRepo(): IntentoRepository
    {
        return $this->una(IntentoRepository::class, fn () => new IntentoRepository($this->db()));
    }

    public function analisisRepo(): AnalisisRepository
    {
        return $this->una(AnalisisRepository::class, fn () => new AnalisisRepository($this->db()));
    }

    public function reportesRepo(): ReporteRepository
    {
        return $this->una(ReporteRepository::class, fn () => new ReporteRepository($this->db()));
    }

    public function auditoriaRepo(): AuditoriaRepository
    {
        return $this->una(AuditoriaRepository::class, fn () => new AuditoriaRepository($this->db()));
    }

    public function auditoria(): AuditoriaService
    {
        return $this->una(AuditoriaService::class, fn () => new AuditoriaService(
            $this->auditoriaRepo(),
            $this->reloj(),
            $this->config->texto('ATLAS_AUDIT_LOG', '') ?: null
        ));
    }

    public function auth(): AuthService
    {
        return $this->una(AuthService::class, fn () => new AuthService(
            $this->usuarios(),
            $this->sesion(),
            $this->auditoria(),
            $this->reloj(),
            $this->config->entero('ATLAS_LOGIN_MAX_INTENTOS', 3),
            $this->config->entero('ATLAS_LOGIN_BLOQUEO_MINUTOS', 15)
        ));
    }

    public function usuariosService(): UsuarioService
    {
        return $this->una(UsuarioService::class, fn () => new UsuarioService($this->usuarios()));
    }

    public function actividades(): ActividadService
    {
        return $this->una(ActividadService::class, fn () => new ActividadService(
            $this->actividadesRepo(),
            $this->organizacion(),
            $this->db()
        ));
    }

    public function analisis(): AnalisisService
    {
        return $this->una(AnalisisService::class, fn () => new AnalisisService($this->analisisRepo()));
    }

    public function intentos(): IntentoService
    {
        return $this->una(IntentoService::class, fn () => new IntentoService(
            $this->intentosRepo(),
            $this->actividadesRepo(),
            $this->analisis(),
            $this->db(),
            $this->reloj()
        ));
    }

    public function panel(): PanelDocenteService
    {
        return $this->una(PanelDocenteService::class, fn () => new PanelDocenteService(
            $this->organizacion(),
            $this->analisisRepo(),
            $this->reportesRepo(),
            $this->clienteAnalisis(),
            $this->reloj(),
            $this->actividadesRepo()
        ));
    }

    public function asistente(): AsistenteService
    {
        return $this->una(AsistenteService::class, fn () => new AsistenteService(
            new IntentParser(),
            $this->organizacion(),
            $this->actividadesRepo(),
            $this->analisisRepo(),
            $this->reportesRepo(),
            new ConversacionRepository($this->db()),
            $this->clienteAnalisis(),
            $this->reloj()
        ));
    }
}
