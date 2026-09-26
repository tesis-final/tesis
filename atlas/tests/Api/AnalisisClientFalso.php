<?php

declare(strict_types=1);

namespace Atlas\Tests\Api;

use Atlas\Services\AnalisisClient;

/**
 * Sustituto del servicio atlas-analysis para los tests: registra lo que se le
 * envía (para verificar la anonimización) y responde lo configurado, o null
 * para simular que el servicio está caído (RNF-15).
 */
final class AnalisisClientFalso extends AnalisisClient
{
    /** @var list<array{metodo: string, ruta: string, cuerpo: array<string, mixed>|null}> */
    public array $enviados = [];
    public bool $disponible = true;

    public function __construct()
    {
        parent::__construct('http://falso');
    }

    protected function solicitar(string $metodo, string $ruta, ?array $cuerpo, ?float $timeout = null): ?array
    {
        $this->enviados[] = ['metodo' => $metodo, 'ruta' => $ruta, 'cuerpo' => $cuerpo];
        if (!$this->disponible) {
            return null;
        }
        if (str_starts_with($ruta, '/v1/llm/redactar')) {
            // Un LLM "de juguete": devuelve un texto que usa los seudónimos recibidos.
            $contexto = json_encode($cuerpo['contexto'], JSON_UNESCAPED_UNICODE);
            preg_match_all('/\b[EG]\d+\b/', (string) $contexto, $m);

            return [
                'texto' => 'Resumen redactado sobre ' . implode(', ', array_unique($m[0])) . '.',
                'modelo' => 'falso'
            ];
        }
        if (str_contains($ruta, '/estado')) {
            return ['suficiencia' => ['suficiente' => false, 'estudiantes_con_datos' => 1, 'requeridos' => 20]];
        }

        return ['estado' => 'ok'];
    }
}
