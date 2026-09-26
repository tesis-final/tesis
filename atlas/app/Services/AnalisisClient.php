<?php

declare(strict_types=1);

namespace Atlas\Services;

/**
 * Cliente de la API REST interna de atlas-analysis (PDF §25.2; RNF-15).
 * Si el servicio no responde dentro del tiempo límite devuelve null y la
 * plataforma sigue funcionando: solo se posterga el análisis.
 */
class AnalisisClient
{
    public function __construct(
        private readonly string $urlBase,
        private readonly float $timeoutSegundos = 5.0
    ) {
    }

    /** @return array<string, mixed>|null */
    public function salud(): ?array
    {
        return $this->solicitar('GET', '/health', null, 2.0);
    }

    /** Estado del Nivel 2 para un grupo: agrupamientos o "datos insuficientes". @return array<string, mixed>|null */
    public function estadoGrupo(int $grupo, string $desde, string $hasta): ?array
    {
        return $this->solicitar(
            'GET',
            '/v1/grupos/' . $grupo . '/estado?' . http_build_query(['desde' => $desde, 'hasta' => $hasta]),
            null
        );
    }

    /** @return array<string, mixed>|null */
    public function recalcular(int $grupo, string $desde, string $hasta): ?array
    {
        return $this->solicitar(
            'POST',
            '/v1/grupos/' . $grupo . '/recalcular',
            ['desde' => $desde, 'hasta' => $hasta],
            30.0
        );
    }

    /**
     * Pide al servicio que redacte un texto sobre un contexto ya anonimizado (Nivel 3).
     *
     * @param array<string, mixed> $contexto
     * @return array<string, mixed>|null
     */
    public function redactar(string $tipo, string $preguntaSanitizada, array $contexto): ?array
    {
        return $this->solicitar('POST', '/v1/llm/redactar', [
            'tipo' => $tipo,
            'pregunta' => $preguntaSanitizada,
            'contexto' => $contexto,
        ], 30.0);
    }

    /** @param array<string, mixed>|null $cuerpo @return array<string, mixed>|null */
    protected function solicitar(string $metodo, string $ruta, ?array $cuerpo, ?float $timeout = null): ?array
    {
        $opciones = [
            'http' => [
                'method' => $metodo,
                'header' => "Content-Type: application/json\r\nAccept: application/json\r\n",
                'timeout' => $timeout ?? $this->timeoutSegundos,
                'ignore_errors' => true,
            ],
        ];
        if ($cuerpo !== null) {
            $opciones['http']['content'] = json_encode($cuerpo, JSON_UNESCAPED_UNICODE);
        }
        $respuesta = @file_get_contents(rtrim($this->urlBase, '/') . $ruta, false, stream_context_create($opciones));
        if ($respuesta === false) {
            return null;
        }
        $estado = 0;
        foreach ($http_response_header ?? [] as $linea) {
            if (preg_match('#^HTTP/\S+\s+(\d{3})#', $linea, $m)) {
                $estado = (int) $m[1];
            }
        }
        $datos = json_decode($respuesta, true);
        if ($estado < 200 || $estado >= 300 || !is_array($datos)) {
            return null;
        }

        return $datos;
    }
}
