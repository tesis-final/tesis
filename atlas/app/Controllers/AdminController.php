<?php

declare(strict_types=1);

namespace Atlas\Controllers;

use Atlas\Core\HttpException;
use Atlas\Core\Request;
use Atlas\Core\Response;
use Atlas\Services\Analysis\MotorReglas;
use Atlas\Services\UsuarioService;

/**
 * Gestión administrativa (RF-01, RF-14, RF-15; ANA-05). El administrador de ATLAS
 * es un perfil de coordinación (DEC-00c): no administra servidores desde la web.
 */
final class AdminController extends Controller
{
    public function usuarios(Request $p): Response
    {
        $rol = $p->query['rol'] ?? null;

        return Response::json($this->app->usuarios()->listar(in_array(
            $rol,
            ['ADMIN', 'DOCENTE', 'ESTUDIANTE'],
            true
        ) ? $rol : null));
    }

    public function crearUsuario(Request $p): Response
    {
        $d = $p->validados();
        if (!$this->app->organizacion()->existeInstitucion($d['institucion_id'])) {
            throw HttpException::validacion(['institucion_id' => 'La institución no existe.']);
        }

        $creado = $this->app->usuariosService()->crear($d);
        $p->con('auditoria', ['recurso_id' => (string) $creado['id'], 'detalle' => [
            'rol_id' => $creado['rol_id'], 'institucion_id' => $creado['institucion_id'], 'activo' => $creado['activo'],
        ]]);

        return Response::creado($creado);
    }

    public function modificarUsuario(Request $p): Response
    {
        $d = $p->validados();
        if (isset($d['institucion_id']) && !$this->app->organizacion()->existeInstitucion($d['institucion_id'])) {
            throw HttpException::validacion(['institucion_id' => 'La institución no existe.']);
        }

        return Response::json($this->modificarAuditado($p, $d));
    }

    public function desactivarUsuario(Request $p): Response
    {
        return Response::json($this->modificarAuditado($p, ['activo' => false]));
    }

    /** @param array<string, mixed> $datos @return array<string, mixed> */
    private function modificarAuditado(Request $p, array $datos): array
    {
        $id = $p->parametroEntero('id');
        $antes = $this->app->usuarios()->porId($id);
        $despues = $this->app->usuariosService()->modificar($id, $datos, $this->usuario($p)['id']);
        $p->con('auditoria', ['detalle' => UsuarioService::cambiosAuditables(
            $antes,
            $despues,
            isset($datos['contrasena'])
        )]);

        return $despues;
    }

    public function instituciones(Request $p): Response
    {
        return Response::json($this->app->organizacion()->instituciones());
    }

    public function crearInstitucion(Request $p): Response
    {
        $d = $p->validados();
        $id = $this->app->organizacion()->crearInstitucion($d['nombre'], $d['requiere_aprobacion'] ?? null);

        return Response::creado($this->app->organizacion()->institucion($id));
    }

    /** D-2: la coordinación decide si su institución exige aprobar antes de publicar. */
    public function modificarInstitucion(Request $p): Response
    {
        $d = $p->validados();
        $id = $p->parametroEntero('id');
        $actual = $this->app->organizacion()->institucion($id)
            ?? throw HttpException::noEncontrado('Institución no encontrada.');
        $requiere = $d['requiere_aprobacion'] ?? $actual['requiere_aprobacion'];
        $this->app->organizacion()->actualizarInstitucion($id, $d['nombre'], $d['activa'] ?? true, $requiere);
        $p->con('auditoria', ['detalle' => [
            'requiere_aprobacion' => [$actual['requiere_aprobacion'], $requiere],
            'activa' => [$actual['activa'], $d['activa'] ?? true],
        ]]);

        return Response::json($this->app->organizacion()->institucion($id));
    }

    public function grupos(Request $p): Response
    {
        $u = $this->usuario($p);
        $org = $this->app->organizacion();
        $grupos = $u['rol'] === 'ADMIN' ? $org->grupos() : $org->grupos($u['id']);

        return Response::json($grupos);
    }

    public function crearGrupo(Request $p): Response
    {
        $d = $p->validados();
        if (!$this->app->organizacion()->existeInstitucion($d['institucion_id'])) {
            throw HttpException::validacion(['institucion_id' => 'La institución no existe.']);
        }
        $id = $this->app->organizacion()->crearGrupo($d['institucion_id'], $d['nombre'], $d['anio_lectivo']);

        return Response::creado($this->app->organizacion()->grupo($id));
    }

    public function miembros(Request $p): Response
    {
        $grupo = $p->parametroEntero('id');
        $u = $this->usuario($p);
        if ($u['rol'] !== 'ADMIN' && !$this->app->organizacion()->perteneceAGrupo($u['id'], $grupo)) {
            throw HttpException::prohibido('Solo puede ver sus propios grupos.');
        }

        return Response::json($this->app->organizacion()->miembros($grupo));
    }

    public function definirMiembros(Request $p): Response
    {
        $grupo = $p->parametroEntero('id');
        if ($this->app->organizacion()->grupo($grupo) === null) {
            throw HttpException::noEncontrado('Grupo no encontrado.');
        }
        $ids = array_map('intval', $p->validados()['usuarios']);
        foreach ($ids as $id) {
            $u = $this->app->usuarios()->porId($id);
            if ($u === null || $u['rol'] === 'ADMIN') {
                throw HttpException::validacion([
                    'usuarios' => "El usuario {$id} no existe o no puede integrar un grupo.",
                ]);
            }
        }
        $this->app->organizacion()->definirMiembros($grupo, $ids);

        return Response::json($this->app->organizacion()->miembros($grupo));
    }

    public function roles(Request $p): Response
    {
        return Response::json([
            'roles' => $this->app->organizacion()->roles(),
            'permisos' => $this->app->organizacion()->codigosPermisos(),
        ]);
    }

    public function permisosDeRol(Request $p): Response
    {
        $rol = $p->parametroEntero('id');
        $codigos = array_values(array_unique(array_map('strval', $p->validados()['permisos'])));
        $validos = $this->app->organizacion()->codigosPermisos();
        if (array_diff($codigos, $validos) !== []) {
            throw HttpException::validacion(['permisos' => 'Hay permisos inexistentes.']);
        }
        $roles = array_column($this->app->organizacion()->roles(), 'codigo', 'id');
        if (!isset($roles[$rol])) {
            throw HttpException::noEncontrado('Rol no encontrado.');
        }
        if ($roles[$rol] === 'ADMIN' && !in_array('permisos.gestionar', $codigos, true)) {
            throw HttpException::conflicto('El rol administrador debe conservar la gestión de permisos.');
        }
        $antes = $this->app->usuarios()->permisosDeRol($rol);
        $this->app->organizacion()->definirPermisosDeRol($rol, $codigos);
        $despues = $this->app->usuarios()->permisosDeRol($rol);
        $p->con('auditoria', ['detalle' => [
            'agregados' => array_values(array_diff($despues, $antes)),
            'quitados' => array_values(array_diff($antes, $despues)),
        ]]);

        return Response::json($this->app->organizacion()->roles());
    }

    public function reglas(Request $p): Response
    {
        return Response::json($this->app->analisisRepo()->reglas());
    }

    public function modificarRegla(Request $p): Response
    {
        $codigo = $p->parametro('codigo');
        $regla = $this->app->analisisRepo()->regla($codigo)
            ?? throw HttpException::noEncontrado('Regla no encontrada.');
        $d = $p->cuerpo;
        $condicion = $d['condicion'] ?? $regla['condicion'];
        $errores = MotorReglas::validarCondicion($condicion);
        if ($errores !== []) {
            throw HttpException::validacion(['condicion' => implode(' ', $errores)]);
        }
        $activa = array_key_exists('activa', $d) ? (bool) $d['activa'] : $regla['activa'];
        // §27.3: toda edición real de una regla sube su versión (antes lo hacía un trigger; D-4).
        $cambio = $condicion != $regla['condicion'] || $activa !== (bool) $regla['activa'];
        $version = $cambio ? (int) $regla['version'] + 1 : (int) $regla['version'];
        $this->app->analisisRepo()->actualizarRegla($codigo, $condicion, $activa, $version, $this->usuario($p)['id']);
        $p->con('auditoria', ['recurso_id' => $codigo, 'detalle' => [
            'version' => [(int) $regla['version'], $version],
            'condicion_anterior' => $regla['condicion'],
            'condicion_nueva' => $condicion,
            'activa' => [(bool) $regla['activa'], $activa],
        ]]);

        return Response::json($this->app->analisisRepo()->regla($codigo));
    }

    public function auditoria(Request $p): Response
    {
        $filtros = array_filter([
            'usuario_id' => $this->consultaEntera($p, 'usuario_id'),
            'accion' => isset($p->query['accion']) ? substr($p->query['accion'], 0, 80) : null,
            'resultado' => in_array(
                $p->query['resultado'] ?? '',
                ['OK', 'DENEGADO', 'ERROR'],
                true
            ) ? $p->query['resultado'] : null,
            'desde' => $this->consultaFecha($p, 'desde'),
            'hasta' => $this->consultaFecha($p, 'hasta'),
        ], fn ($v) => $v !== null);

        return Response::json($this->app->auditoriaRepo()->listar(
            $filtros,
            $this->consultaEntera($p, 'limite') ?? 200
        ));
    }
}
