<?php

declare(strict_types=1);

namespace Atlas\Services\Asistente;

/** Normalización de texto en español para comparar sin mayúsculas ni tildes. */
final class Texto
{
    public static function normalizar(string $texto): string
    {
        $t = mb_strtolower($texto, 'UTF-8');
        $t = strtr($t, ['á' => 'a', 'é' => 'e', 'í' => 'i', 'ó' => 'o', 'ú' => 'u', 'ü' => 'u', 'ñ' => 'n']);
        $t = preg_replace('/[^a-z0-9]+/u', ' ', $t) ?? '';

        return trim(preg_replace('/\s+/', ' ', $t) ?? '');
    }

    /** ¿Aparece $frase como palabra(s) completa(s) dentro de $texto normalizado? */
    public static function contiene(string $textoNormalizado, string $frase): bool
    {
        $f = self::normalizar($frase);

        return $f !== '' && preg_match('/(^| )' . preg_quote($f, '/') . '( |$)/', $textoNormalizado) === 1;
    }
}
