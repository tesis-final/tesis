<?php

declare(strict_types=1);

namespace Atlas\Core;

use DateTimeImmutable;
use DateTimeZone;

/** Reloj inyectable (UTC) para que los cálculos de tiempo sean testeables. */
class Clock
{
    public function ahora(): DateTimeImmutable
    {
        return new DateTimeImmutable('now', new DateTimeZone('UTC'));
    }
}
