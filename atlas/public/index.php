<?php

declare(strict_types=1);

/*
 * ATLAS — controlador frontal. Es el único punto expuesto junto con los
 * recursos estáticos de public/ (PDF §26.2). Las rutas /api/* van al kernel;
 * el resto recibe la interfaz web (aplicación de una página).
 */

// En el repositorio, public/ está junto a app/; en el servidor (§28.3), junto a app/ va
// la carpeta con todo el código (/srv/atlas/web/app).
$raiz = is_dir(dirname(__DIR__) . '/app/Core') ? dirname(__DIR__) : dirname(__DIR__) . '/app';
require is_file($raiz . '/vendor/autoload.php') ? $raiz . '/vendor/autoload.php' : $raiz . '/app/autoload.php';

use Atlas\Core\App;
use Atlas\Core\Config;
use Atlas\Core\Kernel;
use Atlas\Core\Request;

$ruta = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';

if (str_starts_with($ruta, '/api/')) {
    (new Kernel(new App(Config::desdeEntorno())))->atender(Request::desdeGlobales())->enviar();
    exit;
}

header('Content-Type: text/html; charset=utf-8');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: same-origin');
readfile(__DIR__ . '/app.html');
