<?php

declare(strict_types=1);

namespace Atlas\Repositories;

final class AuditoriaRepository extends Repository
{
    /** @param array<string, mixed> $detalle */
    public function insertar(
        ?int $usuarioId,
        string $accion,
        ?string $recurso,
        ?string $recursoId,
        string $resultado,
        array $detalle,
        string $ip
    ): void {
        $this->ejecutar(
            'INSERT INTO auditoria (usuario_id, accion, recurso, recurso_id, resultado, ip, detalle)
             VALUES (?, ?, ?, ?, ?, ?, ?)',
            [$usuarioId, mb_substr($accion, 0, 80), $recurso !== null ? mb_substr($recurso, 0, 60) : null,
             $recursoId, $resultado, $ip !== '' ? $ip : null,
             $detalle === [] ? null : json_encode($detalle, JSON_UNESCAPED_UNICODE)]
        );
    }

    /**
     * @param array{usuario_id?: int, accion?: string, resultado?: string, desde?: string, hasta?: string} $filtros
     * @return list<array<string, mixed>>
     */
    public function listar(array $filtros, int $limite = 200): array
    {
        $donde = ['1 = 1'];
        $params = [];
        foreach (['usuario_id' => 'a.usuario_id = ?', 'resultado' => 'a.resultado = ?'] as $clave => $condicion) {
            if (isset($filtros[$clave])) {
                $donde[] = $condicion;
                $params[] = $filtros[$clave];
            }
        }
        if (isset($filtros['accion'])) {
            $donde[] = 'a.accion LIKE ?';
            $params[] = $filtros['accion'] . '%';
        }
        if (isset($filtros['desde'])) {
            $donde[] = 'a.creado_en >= ?';
            $params[] = $filtros['desde'] . ' 00:00:00';
        }
        if (isset($filtros['hasta'])) {
            $donde[] = 'a.creado_en <= ?';
            $params[] = $filtros['hasta'] . ' 23:59:59.999';
        }
        $limite = max(1, min($limite, 1000));

        return $this->todos(
            'SELECT a.id, a.creado_en, a.usuario_id, u.correo AS usuario_correo, a.accion, a.recurso,
                    a.recurso_id, a.resultado, a.ip, a.detalle
               FROM auditoria a LEFT JOIN usuarios u ON u.id = a.usuario_id
              WHERE ' . implode(' AND ', $donde) . "
              ORDER BY a.id DESC LIMIT {$limite}",
            $params
        );
    }
}
