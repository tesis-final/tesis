<?php

declare(strict_types=1);

/*
 * Tabla de rutas de la API REST (PDF §25.2, §26.3; fase-02/02-arquitectura-final §4).
 * Cada ruta declara si requiere sesión, qué permiso exige (paso [2], 403) y qué
 * reglas de validación aplica (paso [3], 422).
 */

use Atlas\Controllers\ActividadController as Act;
use Atlas\Controllers\AdminController as Adm;
use Atlas\Controllers\AuthController as Auth;
use Atlas\Controllers\DocenteController as Doc;
use Atlas\Controllers\EstudianteController as Est;
use Atlas\Controllers\SaludController as Salud;
use Atlas\Core\Route as R;

$api = '/api/v1';

return [
    // Públicas
    new R('GET', $api . '/health', [Salud::class, 'salud'], requiereSesion: false),
    new R(
        'POST',
        $api . '/auth/login',
        [Auth::class, 'login'],
        requiereSesion: false,
        reglas: ['correo' => 'requerido|correo|max:190', 'contrasena' => 'requerido|texto|max:200']
    ),

    // Sesión
    new R('POST', $api . '/auth/logout', [Auth::class, 'logout'], auditar: false), // lo audita AuthService
    new R('GET', $api . '/auth/me', [Auth::class, 'yo']),

    // Administración (RF-01, RF-14)
    new R('GET', $api . '/usuarios', [Adm::class, 'usuarios'], permiso: 'usuarios.gestionar'),
    new R('POST', $api . '/usuarios', [Adm::class, 'crearUsuario'], permiso: 'usuarios.gestionar', reglas: [
        'nombre' => 'requerido|texto|max:80', 'apellido' => 'requerido|texto|max:80',
        'correo' => 'requerido|correo|max:190', 'contrasena' => 'requerido|texto|max:200',
        'rol' => 'requerido|en:ADMIN,DOCENTE,ESTUDIANTE', 'institucion_id' => 'requerido|entero|positivo',
    ], accionAuditoria: 'usuarios.crear'),
    new R('PATCH', $api . '/usuarios/{id}', [Adm::class, 'modificarUsuario'], permiso: 'usuarios.gestionar', reglas: [
        'nombre' => 'opcional|texto|max:80', 'apellido' => 'opcional|texto|max:80',
        'correo' => 'opcional|correo|max:190', 'contrasena' => 'opcional|texto|max:200',
        'institucion_id' => 'opcional|entero|positivo', 'activo' => 'opcional|booleano',
    ], accionAuditoria: 'usuarios.modificar'),
    new R(
        'POST',
        $api . '/usuarios/{id}/desactivar',
        [Adm::class, 'desactivarUsuario'],
        permiso: 'usuarios.gestionar',
        accionAuditoria: 'usuarios.desactivar'
    ),
    new R('GET', $api . '/instituciones', [Adm::class, 'instituciones'], permiso: 'instituciones.gestionar'),
    new R(
        'POST',
        $api . '/instituciones',
        [Adm::class, 'crearInstitucion'],
        permiso: 'instituciones.gestionar',
        reglas: ['nombre' => 'requerido|texto|max:150'],
        accionAuditoria: 'instituciones.crear'
    ),
    new R(
        'PATCH',
        $api . '/instituciones/{id}',
        [Adm::class, 'modificarInstitucion'],
        permiso: 'instituciones.gestionar',
        reglas: ['nombre' => 'requerido|texto|max:150', 'activa' => 'opcional|booleano'],
        accionAuditoria: 'instituciones.modificar'
    ),
    new R('GET', $api . '/roles', [Adm::class, 'roles'], permiso: 'permisos.gestionar'),
    new R(
        'PUT',
        $api . '/roles/{id}/permisos',
        [Adm::class, 'permisosDeRol'],
        permiso: 'permisos.gestionar',
        reglas: ['permisos' => 'requerido|lista|max:100'],
        accionAuditoria: 'permisos.modificar'
    ),
    new R('GET', $api . '/grupos', [Adm::class, 'grupos']),
    new R('POST', $api . '/grupos', [Adm::class, 'crearGrupo'], permiso: 'grupos.gestionar', reglas: [
        'nombre' => 'requerido|texto|max:60', 'anio_lectivo' => 'requerido|entero|min:2000|max:2100',
        'institucion_id' => 'requerido|entero|positivo',
    ], accionAuditoria: 'grupos.crear'),
    new R('GET', $api . '/grupos/{id}/miembros', [Adm::class, 'miembros']),
    new R(
        'PUT',
        $api . '/grupos/{id}/miembros',
        [Adm::class, 'definirMiembros'],
        permiso: 'grupos.gestionar',
        reglas: ['usuarios' => 'requerido|lista|max:500'],
        accionAuditoria: 'grupos.miembros'
    ),
    new R('GET', $api . '/reglas', [Adm::class, 'reglas'], permiso: 'reglas.gestionar'),
    new R(
        'PATCH',
        $api . '/reglas/{codigo}',
        [Adm::class, 'modificarRegla'],
        permiso: 'reglas.gestionar',
        accionAuditoria: 'reglas.modificar'
    ),
    new R('GET', $api . '/auditoria', [Adm::class, 'auditoria'], permiso: 'auditoria.ver'),

    // Actividades y ciclo de aprobación (RF-05, RF-16, RF-17)
    new R('GET', $api . '/catalogos', [Act::class, 'catalogos']),
    new R('GET', $api . '/actividades', [Act::class, 'listar']),
    new R('POST', $api . '/actividades', [Act::class, 'crear'], permiso: 'actividades.crear', reglas: [
        'titulo' => 'requerido|texto|max:150', 'descripcion' => 'opcional|texto|max:5000',
        'nivel' => 'requerido|texto|max:20', 'categoria' => 'requerido|texto|max:40',
    ], accionAuditoria: 'actividades.crear'),
    new R('GET', $api . '/actividades/{id}', [Act::class, 'ver']),
    new R('PATCH', $api . '/actividades/{id}', [Act::class, 'editar'], permiso: 'actividades.crear', reglas: [
        'titulo' => 'requerido|texto|max:150', 'descripcion' => 'opcional|texto|max:5000',
        'nivel' => 'requerido|texto|max:20', 'categoria' => 'requerido|texto|max:40',
    ], accionAuditoria: 'actividades.editar'),
    new R(
        'POST',
        $api . '/actividades/{id}/enviar',
        [Act::class, 'enviar'],
        permiso: 'actividades.enviar',
        accionAuditoria: 'actividades.enviar'
    ),
    new R(
        'POST',
        $api . '/actividades/{id}/aprobar',
        [Act::class, 'aprobar'],
        permiso: 'actividades.aprobar',
        accionAuditoria: 'actividades.aprobar'
    ),
    new R(
        'POST',
        $api . '/actividades/{id}/rechazar',
        [Act::class, 'rechazar'],
        permiso: 'actividades.aprobar',
        reglas: ['observaciones' => 'requerido|texto|max:2000'],
        accionAuditoria: 'actividades.rechazar'
    ),
    new R(
        'POST',
        $api . '/actividades/{id}/publicar',
        [Act::class, 'publicar'],
        permiso: 'actividades.publicar',
        reglas: ['grupos' => 'requerido|lista|min:1|max:50'],
        accionAuditoria: 'actividades.publicar'
    ),
    new R('GET', $api . '/actividades/{id}/transiciones', [Act::class, 'transiciones']),

    // Estudiante (RF-04, RF-06..RF-09)
    new R('GET', $api . '/estudiante/actividades', [Est::class, 'actividades'], permiso: 'actividades.resolver'),
    new R(
        'POST',
        $api . '/intentos',
        [Est::class, 'iniciar'],
        permiso: 'actividades.resolver',
        reglas: ['actividad_id' => 'requerido|entero|positivo'],
        accionAuditoria: 'intentos.iniciar'
    ),
    new R(
        'POST',
        $api . '/intentos/{id}/eventos',
        [Est::class, 'eventos'],
        permiso: 'actividades.resolver',
        reglas: ['eventos' => 'requerido|lista|max:500'],
        auditar: false
    ), // quedan en `interacciones`
    new R(
        'PUT',
        $api . '/intentos/{id}/respuestas/{pregunta}',
        [Est::class, 'responder'],
        permiso: 'actividades.resolver',
        reglas: ['opcion_id' => 'requerido|entero|positivo', 'tiempo_seg' => 'opcional|entero|min:0|max:86400'],
        auditar: false
    ), // quedan en `respuestas`
    new R(
        'POST',
        $api . '/intentos/{id}/finalizar',
        [Est::class, 'finalizar'],
        permiso: 'actividades.resolver',
        accionAuditoria: 'intentos.finalizar'
    ),
    new R(
        'POST',
        $api . '/intentos/{id}/abandonar',
        [Est::class, 'abandonar'],
        permiso: 'actividades.resolver',
        accionAuditoria: 'intentos.abandonar'
    ),
    new R('GET', $api . '/intentos/{id}/resultado', [Est::class, 'resultado'], permiso: 'resultados.ver_propios'),

    // Docente (RF-10..RF-13, RF-18, RF-20)
    new R('GET', $api . '/docente/grupos/{id}/analisis', [Doc::class, 'analisisGrupal'], permiso: 'panel.docente'),
    new R('GET', $api . '/docente/estudiantes/{id}/perfil', [Doc::class, 'perfil'], permiso: 'perfiles.ver'),
    new R('GET', $api . '/recomendaciones/{id}/fundamento', [Doc::class, 'fundamento'], permiso: 'recomendaciones.ver'),
    new R('GET', $api . '/reportes', [Doc::class, 'reportes'], permiso: 'reportes.ver'),
    new R(
        'POST',
        $api . '/asistente/consultas',
        [Doc::class, 'consultar'],
        permiso: 'asistente.usar',
        reglas: ['pregunta' => 'requerido|texto|max:1000'],
        accionAuditoria: 'asistente.consultar'
    ),
    new R('GET', $api . '/asistente/consultas', [Doc::class, 'historial'], permiso: 'asistente.usar'),
];
