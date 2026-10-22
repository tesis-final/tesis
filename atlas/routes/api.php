<?php

declare(strict_types=1);

/*
 * Rutas de la API REST /api/v1 (PDF §25.2, §26.3). Mismo contrato que antes de
 * Laravel: métodos, URLs, códigos (401 sin sesión, 403 sin permiso, 422 datos
 * inválidos) y forma del JSON. Cada ruta declara:
 *   - atlas.sesion           [1] exige sesión (+ CSRF si modifica datos)
 *   - atlas.permiso:codigo   [2] qué permiso de rol_permiso necesita
 *   - un Form Request        [3] qué datos acepta (en el método del controlador)
 *   - atlas.auditoria:accion [4] con qué nombre queda en la auditoría
 */

use Atlas\Http\Controllers\ActividadController as Act;
use Atlas\Http\Controllers\AdminController as Adm;
use Atlas\Http\Controllers\AuthController as Auth;
use Atlas\Http\Controllers\DocenteController as Doc;
use Atlas\Http\Controllers\EstudianteController as Est;
use Atlas\Http\Controllers\SaludController as Salud;
use Illuminate\Support\Facades\Route;

// Permiso y, si modifica datos, nombre con que queda en la auditoría.
$exige = fn (string $permiso, ?string $auditoria = null): array => array_values(array_filter([
    "atlas.permiso:{$permiso}",
    $auditoria !== null ? "atlas.auditoria:{$auditoria}" : null,
]));

// Públicas
Route::get('/health', [Salud::class, 'salud']);
Route::post('/auth/login', [Auth::class, 'login']);

Route::middleware('atlas.sesion')->group(function () use ($exige) {
    // Sesión
    Route::post('/auth/logout', [Auth::class, 'logout']); // la audita AuthService
    Route::get('/auth/me', [Auth::class, 'yo']);

    // Administración (RF-01, RF-14; D-2)
    Route::get('/usuarios', [Adm::class, 'usuarios'])->middleware($exige('usuarios.gestionar'));
    Route::post('/usuarios', [Adm::class, 'crearUsuario'])
        ->middleware($exige('usuarios.gestionar', 'usuarios.crear'));
    Route::patch('/usuarios/{id}', [Adm::class, 'modificarUsuario'])
        ->middleware($exige('usuarios.gestionar', 'usuarios.modificar'));
    Route::post('/usuarios/{id}/desactivar', [Adm::class, 'desactivarUsuario'])
        ->middleware($exige('usuarios.gestionar', 'usuarios.desactivar'));
    Route::get('/instituciones', [Adm::class, 'instituciones'])->middleware($exige('instituciones.gestionar'));
    Route::post('/instituciones', [Adm::class, 'crearInstitucion'])
        ->middleware($exige('instituciones.gestionar', 'instituciones.crear'));
    Route::patch('/instituciones/{id}', [Adm::class, 'modificarInstitucion'])
        ->middleware($exige('instituciones.gestionar', 'instituciones.modificar'));
    Route::get('/roles', [Adm::class, 'roles'])->middleware($exige('permisos.gestionar'));
    Route::put('/roles/{id}/permisos', [Adm::class, 'permisosDeRol'])
        ->middleware($exige('permisos.gestionar', 'permisos.modificar'));
    Route::get('/grupos', [Adm::class, 'grupos']);
    Route::post('/grupos', [Adm::class, 'crearGrupo'])->middleware($exige('grupos.gestionar', 'grupos.crear'));
    Route::get('/grupos/{id}/miembros', [Adm::class, 'miembros']);
    Route::put('/grupos/{id}/miembros', [Adm::class, 'definirMiembros'])
        ->middleware($exige('grupos.gestionar', 'grupos.miembros'));
    Route::get('/reglas', [Adm::class, 'reglas'])->middleware($exige('reglas.gestionar'));
    Route::patch('/reglas/{codigo}', [Adm::class, 'modificarRegla'])
        ->middleware($exige('reglas.gestionar', 'reglas.modificar'));
    Route::get('/auditoria', [Adm::class, 'auditoria'])->middleware($exige('auditoria.ver'));

    // Actividades y ciclo de aprobación (RF-05, RF-16, RF-17; D-2, D-3)
    Route::get('/catalogos', [Act::class, 'catalogos']);
    Route::get('/actividades', [Act::class, 'listar']);
    Route::post('/actividades', [Act::class, 'crear'])->middleware($exige('actividades.crear', 'actividades.crear'));
    Route::get('/actividades/{id}', [Act::class, 'ver']);
    Route::patch('/actividades/{id}', [Act::class, 'editar'])
        ->middleware($exige('actividades.crear', 'actividades.editar'));
    Route::post('/actividades/{id}/enviar', [Act::class, 'enviar'])
        ->middleware($exige('actividades.enviar', 'actividades.enviar'));
    Route::post('/actividades/{id}/aprobar', [Act::class, 'aprobar'])
        ->middleware($exige('actividades.aprobar', 'actividades.aprobar'));
    Route::post('/actividades/{id}/rechazar', [Act::class, 'rechazar'])
        ->middleware($exige('actividades.aprobar', 'actividades.rechazar'));
    Route::post('/actividades/{id}/publicar', [Act::class, 'publicar'])
        ->middleware($exige('actividades.publicar', 'actividades.publicar'));
    Route::get('/actividades/{id}/transiciones', [Act::class, 'transiciones']);

    // Estudiante (RF-04, RF-06..RF-09; D-8)
    Route::get('/estudiante/actividades', [Est::class, 'actividades'])->middleware($exige('actividades.resolver'));
    Route::post('/intentos', [Est::class, 'iniciar'])->middleware($exige('actividades.resolver', 'intentos.iniciar'));
    // Eventos y respuestas no se auditan: quedan en `interacciones` y `respuestas`.
    Route::post('/intentos/{id}/eventos', [Est::class, 'eventos'])->middleware($exige('actividades.resolver'));
    Route::put('/intentos/{id}/respuestas/{pregunta}', [Est::class, 'responder'])
        ->middleware($exige('actividades.resolver'));
    Route::post('/intentos/{id}/finalizar', [Est::class, 'finalizar'])
        ->middleware($exige('actividades.resolver', 'intentos.finalizar'));
    Route::post('/intentos/{id}/abandonar', [Est::class, 'abandonar'])
        ->middleware($exige('actividades.resolver', 'intentos.abandonar'));
    Route::get('/intentos/{id}/resultado', [Est::class, 'resultado'])->middleware($exige('resultados.ver_propios'));

    // Docente (RF-10..RF-13, RF-18, RF-20; D-5, D-6)
    Route::get('/docente/grupos/{id}/analisis', [Doc::class, 'analisisGrupal'])->middleware($exige('panel.docente'));
    Route::get('/docente/estudiantes/{id}/perfil', [Doc::class, 'perfil'])->middleware($exige('perfiles.ver'));
    Route::get('/recomendaciones/{id}/fundamento', [Doc::class, 'fundamento'])
        ->middleware($exige('recomendaciones.ver'));
    Route::post('/recomendaciones/{id}/decision', [Doc::class, 'decidir'])
        ->middleware($exige('recomendaciones.decidir', 'recomendaciones.decidir'));
    Route::get('/reportes', [Doc::class, 'reportes'])->middleware($exige('reportes.ver'));
    Route::post('/asistente/consultas', [Doc::class, 'consultar'])
        ->middleware($exige('asistente.usar', 'asistente.consultar'));
    Route::get('/asistente/consultas', [Doc::class, 'historial'])->middleware($exige('asistente.usar'));
});
