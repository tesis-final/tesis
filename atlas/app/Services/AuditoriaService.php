<?php

declare(strict_types=1);

namespace Atlas\Services;

use Atlas\Core\Clock;
use Atlas\Repositories\AuditoriaRepository;

/**
 * Registro de auditoría en dos lugares (AMB-30):
 * - tabla `auditoria` (consultable, solo INSERT para la app, inmutable por trigger);
 * - archivo `auditoria.log` en /srv/atlas/logs, con atributo append-only (§28.3).
 */
final class AuditoriaService
{
    public function __construct(
        private readonly AuditoriaRepository $repo,
        private readonly Clock $reloj,
        private readonly ?string $archivo = null
    ) {
    }

    /** @param array<string, mixed> $detalle */
    public function registrar(
        ?int $usuarioId,
        string $accion,
        ?string $recurso,
        ?string $recursoId,
        string $resultado,
        array $detalle = [],
        string $ip = ''
    ): void {
        $this->repo->insertar($usuarioId, $accion, $recurso, $recursoId, $resultado, $detalle, $ip);
        if ($this->archivo === null) {
            return;
        }
        $linea = json_encode([
            'ts' => $this->reloj->ahora()->format('Y-m-d\TH:i:s.v\Z'),
            'usuario_id' => $usuarioId,
            'accion' => $accion,
            'recurso' => $recurso,
            'recurso_id' => $recursoId,
            'resultado' => $resultado,
            'ip' => $ip,
        ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) . "\n";
        // FILE_APPEND es compatible con chattr +a: solo agrega, nunca reescribe.
        if (@file_put_contents($this->archivo, $linea, FILE_APPEND | LOCK_EX) === false) {
            error_log('ATLAS: no se pudo escribir el log de auditoría en ' . $this->archivo);
        }
    }
}
