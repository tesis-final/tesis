<?php

declare(strict_types=1);

namespace Atlas\Services\Analysis;

use DateTimeImmutable;

/** Período de análisis: mes calendario (DEC-23). */
final class Periodo
{
    public function __construct(public readonly string $desde, public readonly string $hasta)
    {
    }

    public static function mesDe(DateTimeImmutable $fecha): self
    {
        return new self($fecha->format('Y-m-01'), $fecha->format('Y-m-t'));
    }

    public static function desdeTexto(?string $desde, ?string $hasta, DateTimeImmutable $ahora): self
    {
        if ($desde !== null && $hasta !== null) {
            return new self($desde, $hasta);
        }

        return self::mesDe($ahora);
    }
}
