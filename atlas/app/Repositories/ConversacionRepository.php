<?php

declare(strict_types=1);

namespace Atlas\Repositories;

final class ConversacionRepository extends Repository
{
    /** @param array<string, mixed>|null $contexto */
    public function guardar(
        int $docente,
        string $pregunta,
        string $tipo,
        ?array $contexto,
        ?string $respuesta,
        string $estado
    ): int {
        return $this->ejecutar(
            'INSERT INTO conversaciones (docente_id, pregunta, tipo_consulta, contexto_enviado, respuesta, estado)
             VALUES (?, ?, ?, ?, ?, ?)',
            [$docente, mb_substr($pregunta, 0, 1000), $tipo,
             $contexto === null ? null : json_encode($contexto, JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION),
             $respuesta, $estado]
        );
    }

    /** @return list<array<string, mixed>> */
    public function historial(int $docente, int $limite = 30): array
    {
        $limite = max(1, min($limite, 100));
        $filas = $this->todos(
            "SELECT id, pregunta, tipo_consulta, contexto_enviado, respuesta, estado, creado_en
               FROM conversaciones WHERE docente_id = ? ORDER BY id DESC LIMIT {$limite}",
            [$docente]
        );
        foreach ($filas as &$f) {
            $f['contexto_enviado'] = $f['contexto_enviado'] !== null ? json_decode($f['contexto_enviado'], true) : null;
        }

        return $filas;
    }
}
