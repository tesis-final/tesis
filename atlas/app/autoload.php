<?php

declare(strict_types=1);

/*
 * ATLAS — cargador de clases propio (PSR-4: Atlas\ → app/).
 * La aplicación no tiene dependencias de terceros en producción, así que no
 * hace falta Composer para ejecutarla. Si existe vendor/autoload.php (entorno
 * de desarrollo con PHPUnit y PHP_CodeSniffer), se usa ese en su lugar.
 */

spl_autoload_register(static function (string $clase): void {
    if (!str_starts_with($clase, 'Atlas\\')) {
        return;
    }
    $archivo = __DIR__ . '/' . str_replace('\\', '/', substr($clase, strlen('Atlas\\'))) . '.php';
    if (is_file($archivo)) {
        require $archivo;
    }
});
