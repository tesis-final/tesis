<?php

declare(strict_types=1);

/*
 * Datos de DEMOSTRACIÓN (sintéticos). Crea un docente, un grupo "3A", estudiantes
 * con nombres ficticios, actividades publicadas y resoluciones simuladas a través
 * de los servicios reales (mismo camino que la API). Sirve para mostrar la interfaz;
 * NO es evidencia de desempeño real (R-10, R-22).
 *
 * Requiere: ATLAS_DEMO_CONTRASENA (clave de las cuentas de demostración).
 * @var Atlas\Core\App $app
 */

use Atlas\Services\AuthService;

$clave = $app->config->texto('ATLAS_DEMO_CONTRASENA');
$pdo = $app->db()->app();
$usuarios = $app->usuarios();
$org = $app->organizacion();
$crear = function (string $rol, string $nombre, string $apellido, string $correo) use ($usuarios, $clave): int {
    if ($usuarios->existeCorreo($correo)) {
        return (int) $usuarios->paraLogin($correo)['id'];
    }

    return $usuarios->crear(1, $rol, $nombre, $apellido, $correo, AuthService::hash($clave));
};

$admin = $crear('ADMIN', 'Coordinación', 'Demo', 'coordinacion.demo@atlas.local');
$docente = $crear('DOCENTE', 'Laura', 'Docente-Demo', 'docente.demo@atlas.local');
$nombres = [
    'Ana',
    'Bruno',
    'Camila',
    'Diego',
    'Elena',
    'Facundo',
    'Gabriela',
    'Hernán',
    'Inés',
    'Joaquín',
    'Lucía',
    'Martín'
];
$estudiantes = [];
foreach ($nombres as $i => $n) {
    $estudiantes[] = $crear(
        'ESTUDIANTE',
        $n,
        'Demo',
        strtolower(iconv('UTF-8', 'ASCII//TRANSLIT', $n)) . '.demo@atlas.local'
    );
}

$grupo = (int) ($pdo->query("SELECT id FROM grupos_clase WHERE nombre = '3A' AND anio_lectivo = 2026")
    ->fetchColumn() ?: 0);
if ($grupo === 0) {
    $grupo = $org->crearGrupo(1, '3A', 2026);
}
$org->definirMiembros($grupo, [$docente, ...$estudiantes]);

$actividades = [];
foreach (
    [
    ['Problemas con fracciones', 'BASICO'],
    ['Problemas de proporcionalidad', 'BASICO'],
    ['Problemas con porcentajes', 'INTERMEDIO']
    ] as [$titulo, $nivel]
) {
    $preguntas = [];
    for ($p = 1; $p <= 4; $p++) {
        $preguntas[] = ['enunciado' => "{$titulo}: pregunta {$p}", 'opciones' => [
            [
                'texto' => 'Opción correcta',
                'correcta' => true
            ], ['texto' => 'Distractor A', 'correcta' => false], ['texto' => 'Distractor B', 'correcta' => false],
        ], 'habilidades' => $p % 2 === 1 ? ['CALCULO'] : ['COMPRENSION', 'LOGICA']]; // D-3
    }
    $a = $app->actividades()->crear(
        $docente,
        ['titulo' => $titulo, 'nivel' => $nivel, 'categoria' => 'RESOLUCION_PROBLEMAS', 'preguntas' => $preguntas]
    );
    if ($app->organizacion()->requiereAprobacion($docente)) { // D-2: por defecto se publica directo
        $app->actividades()->enviar($a['id'], $docente);
        $app->actividades()->aprobar($a['id'], $admin);
    }
    $app->actividades()->publicar($a['id'], $docente, [$grupo]);
    $actividades[] = $app->actividades()->detalle($a['id'], true);
}

mt_srand(2026); // reproducible
foreach ($estudiantes as $idx => $e) {
    $habilidad = ($idx % 4) + 1; // 1..4 aciertos típicos
    foreach ($actividades as $a) {
        foreach (range(1, mt_rand(1, 3)) as $n) {
            $inicio = $app->intentos()->iniciar($e, $a['id']);
            $intento = $inicio['intento']['id'];
            $aciertos = min(4, max(0, $habilidad + mt_rand(-1, 1) + ($n - 1)));
            foreach ($a['preguntas'] as $i => $p) {
                $correcta = array_values(array_filter($p['opciones'], fn ($o) => $o['correcta']))[0]['id'];
                $otra = array_values(array_filter($p['opciones'], fn ($o) => !$o['correcta']))[0]['id'];
                $app->intentos()->responder($intento, $e, $p['id'], $i < $aciertos ? $correcta : $otra, mt_rand(5, 40));
            }
            $app->intentos()->finalizar($intento, $e);
        }
    }
}
fwrite(STDOUT, "Datos de demostración cargados (SINTÉTICOS): grupo 3A, " . count($estudiantes) . " estudiantes, "
    . count($actividades) . " actividades. Cuentas: coordinacion.demo@atlas.local, docente.demo@atlas.local.\n");
