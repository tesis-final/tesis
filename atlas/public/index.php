<?php

declare(strict_types=1);

/*
 * ATLAS — controlador frontal. Es el único punto expuesto junto con los recursos
 * estáticos de public/ (PDF §26.2). Las rutas /api/* las atiende Laravel; el resto
 * recibe la interfaz web (aplicación de una página).
 */

$ruta = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';

if (!str_starts_with($ruta, '/api/')) {
    header('Content-Type: text/html; charset=utf-8');
    header('X-Content-Type-Options: nosniff');
    header('Referrer-Policy: same-origin');
    readfile(__DIR__ . '/app.html');
    exit;
}

// En el repositorio, public/ está junto al código; en el servidor (§28.3), junto a
// public/ va la carpeta app/ con todo el código (/srv/atlas/web/app).
$raiz = is_file(dirname(__DIR__) . '/bootstrap/app.php') ? dirname(__DIR__) : dirname(__DIR__) . '/app';
require $raiz . '/vendor/autoload.php';

/** @var Illuminate\Foundation\Application $app */
$app = require $raiz . '/bootstrap/app.php';
$app->usePublicPath(__DIR__);
$app->handleRequest(Illuminate\Http\Request::capture());
