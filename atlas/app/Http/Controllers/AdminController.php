<?php

declare(strict_types=1);

namespace Atlas\Http\Controllers;

use Atlas\Core\HttpException;
use Atlas\Http\Json;
use Atlas\Http\Requests\CrearGrupoRequest;
use Atlas\Http\Requests\CrearInstitucionRequest;
use Atlas\Http\Requests\CrearUsuarioRequest;
use Atlas\Http\Requests\MiembrosRequest;
use Atlas\Http\Requests\ModificarInstitucionRequest;
use Atlas\Http\Requests\ModificarUsuarioRequest;
use Atlas\Http\Requests\PermisosRolRequest;
use Atlas\Services\Analysis\MotorReglas;
use Atlas\Services\UsuarioService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Gestión administrativa (RF-01, RF-14, RF-15; ANA-05). El administrador de ATLAS
 * es un perfil de coordinación (DEC-00c): no administra servidores desde la web.
 * Donde importa el antes y el después, el controlador deja el detalle para el
 * middleware de auditoría (atributo `auditoria`, acta D-4).
 */
final class AdminController extends Controller
{
    public function usuarios(Request $p): JsonResponse
    {
        $rol = $p->query('rol');

        return Json::ok($this->atlas->usuarios()->listar(
            in_array($rol, ['ADMIN', 'DOCENTE', 'ESTUDIANTE'], true) ? $rol : null
        ));
    }

    public function crearUsuario(CrearUsuarioRequest $p): JsonResponse
    {
        $d = $p->validados();
        if (!$this->atlas->organizacion()->existeInstitucion($d['institucion_id'])) {
            throw HttpException::validacion(['institucion_id' => 'La institución no existe.']);
        }
        $creado = $this->atlas->usuariosService()->crear($d);
        $this->auditar(['recurso_id' => (string) $creado['id'], 'detalle' => [
            'rol_id' => $creado['rol_id'], 'institucion_id' => $creado['institucion_id'], 'activo' => $creado['activo'],
        ]]);

        return Json::creado($creado);
    }

    public function modificarUsuario(ModificarUsuarioRequest $p): JsonResponse
    {
        $d = $p->validados();
        if (isset($d['institucion_id']) && !$this->atlas->organizacion()->existeInstitucion($d['institucion_id'])) {
            throw HttpException::validacion(['institucion_id' => 'La institución no existe.']);
        }

        return Json::ok($this->modificarAuditado($p, $d));
    }

    public function desactivarUsuario(Request $p): JsonResponse
    {
        return Json::ok($this->modificarAuditado($p, ['activo' => false]));
    }

    /** @param array<string, mixed> $datos @return array<string, mixed> */
    private function modificarAuditado(Request $p, array $datos): array
    {
        $id = $this->id($p);
        $antes = $this->atlas->usuarios()->porId($id);
        $despues = $this->atlas->usuariosService()->modificar($id, $datos, $this->usuario($p)['id']);
        $this->auditar(['detalle' => UsuarioService::cambiosAuditables(
            $antes,
            $despues,
            isset($datos['contrasena'])
        )]);

        return $despues;
    }

    public function instituciones(): JsonResponse
    {
        return Json::ok($this->atlas->organizacion()->instituciones());
    }

    public function crearInstitucion(CrearInstitucionRequest $p): JsonResponse
    {
        $d = $p->validados();
        $id = $this->atlas->organizacion()->crearInstitucion($d['nombre'], $d['requiere_aprobacion'] ?? null);

        return Json::creado($this->atlas->organizacion()->institucion($id));
    }

    /** D-2: la coordinación decide si su institución exige aprobar antes de publicar. */
    public function modificarInstitucion(ModificarInstitucionRequest $p): JsonResponse
    {
        $d = $p->validados();
        $id = $this->id($p);
        $actual = $this->atlas->organizacion()->institucion($id)
            ?? throw HttpException::noEncontrado('Institución no encontrada.');
        $requiere = $d['requiere_aprobacion'] ?? $actual['requiere_aprobacion'];
        $this->atlas->organizacion()->actualizarInstitucion($id, $d['nombre'], $d['activa'] ?? true, $requiere);
        $this->auditar(['detalle' => [
            'requiere_aprobacion' => [$actual['requiere_aprobacion'], $requiere],
            'activa' => [$actual['activa'], $d['activa'] ?? true],
        ]]);

        return Json::ok($this->atlas->organizacion()->institucion($id));
    }

    public function grupos(Request $p): JsonResponse
    {
        $u = $this->usuario($p);
        $org = $this->atlas->organizacion();

        return Json::ok($u['rol'] === 'ADMIN' ? $org->grupos() : $org->grupos($u['id']));
    }

    public function crearGrupo(CrearGrupoRequest $p): JsonResponse
    {
        $d = $p->validados();
        if (!$this->atlas->organizacion()->existeInstitucion($d['institucion_id'])) {
            throw HttpException::validacion(['institucion_id' => 'La institución no existe.']);
        }
        $id = $this->atlas->organizacion()->crearGrupo($d['institucion_id'], $d['nombre'], $d['anio_lectivo']);

        return Json::creado($this->atlas->organizacion()->grupo($id));
    }

    public function miembros(Request $p): JsonResponse
    {
        $grupo = $this->id($p);
        $u = $this->usuario($p);
        if ($u['rol'] !== 'ADMIN' && !$this->atlas->organizacion()->perteneceAGrupo($u['id'], $grupo)) {
            throw HttpException::prohibido('Solo puede ver sus propios grupos.');
        }

        return Json::ok($this->atlas->organizacion()->miembros($grupo));
    }

    public function definirMiembros(MiembrosRequest $p): JsonResponse
    {
        $grupo = $this->id($p);
        if ($this->atlas->organizacion()->grupo($grupo) === null) {
            throw HttpException::noEncontrado('Grupo no encontrado.');
        }
        $ids = array_map('intval', $p->validados()['usuarios']);
        foreach ($ids as $id) {
            $u = $this->atlas->usuarios()->porId($id);
            if ($u === null || $u['rol'] === 'ADMIN') {
                throw HttpException::validacion([
                    'usuarios' => "El usuario {$id} no existe o no puede integrar un grupo.",
                ]);
            }
        }
        $this->atlas->organizacion()->definirMiembros($grupo, $ids);

        return Json::ok($this->atlas->organizacion()->miembros($grupo));
    }

    public function roles(): JsonResponse
    {
        return Json::ok([
            'roles' => $this->atlas->organizacion()->roles(),
            'permisos' => $this->atlas->organizacion()->codigosPermisos(),
        ]);
    }

    public function permisosDeRol(PermisosRolRequest $p): JsonResponse
    {
        $rol = $this->id($p);
        $codigos = array_values(array_unique(array_map('strval', $p->validados()['permisos'])));
        if (array_diff($codigos, $this->atlas->organizacion()->codigosPermisos()) !== []) {
            throw HttpException::validacion(['permisos' => 'Hay permisos inexistentes.']);
        }
        $roles = array_column($this->atlas->organizacion()->roles(), 'codigo', 'id');
        if (!isset($roles[$rol])) {
            throw HttpException::noEncontrado('Rol no encontrado.');
        }
        if ($roles[$rol] === 'ADMIN' && !in_array('permisos.gestionar', $codigos, true)) {
            throw HttpException::conflicto('El rol administrador debe conservar la gestión de permisos.');
        }
        $antes = $this->atlas->usuarios()->permisosDeRol($rol);
        $this->atlas->organizacion()->definirPermisosDeRol($rol, $codigos);
        $despues = $this->atlas->usuarios()->permisosDeRol($rol);
        $this->auditar(['detalle' => [
            'agregados' => array_values(array_diff($despues, $antes)),
            'quitados' => array_values(array_diff($antes, $despues)),
        ]]);

        return Json::ok($this->atlas->organizacion()->roles());
    }

    public function reglas(): JsonResponse
    {
        return Json::ok($this->atlas->analisisRepo()->reglas());
    }

    public function modificarRegla(Request $p): JsonResponse
    {
        $codigo = (string) $p->route('codigo');
        $regla = $this->atlas->analisisRepo()->regla($codigo)
            ?? throw HttpException::noEncontrado('Regla no encontrada.');
        $condicion = $p->input('condicion', $regla['condicion']);
        $errores = MotorReglas::validarCondicion($condicion);
        if ($errores !== []) {
            throw HttpException::validacion(['condicion' => implode(' ', $errores)]);
        }
        $activa = $p->has('activa') ? (bool) $p->input('activa') : $regla['activa'];
        // §27.3: toda edición real de una regla sube su versión (antes lo hacía un trigger; D-4).
        $cambio = $condicion != $regla['condicion'] || $activa !== (bool) $regla['activa'];
        $version = $cambio ? (int) $regla['version'] + 1 : (int) $regla['version'];
        $this->atlas->analisisRepo()->actualizarRegla($codigo, $condicion, $activa, $version, $this->usuario($p)['id']);
        $this->auditar(['recurso_id' => $codigo, 'detalle' => [
            'version' => [(int) $regla['version'], $version],
            'condicion_anterior' => $regla['condicion'],
            'condicion_nueva' => $condicion,
            'activa' => [(bool) $regla['activa'], $activa],
        ]]);

        return Json::ok($this->atlas->analisisRepo()->regla($codigo));
    }

    public function auditoria(Request $p): JsonResponse
    {
        $resultado = $p->query('resultado');
        $accion = $p->query('accion');
        $filtros = array_filter([
            'usuario_id' => $this->consultaEntera($p, 'usuario_id'),
            'accion' => is_string($accion) ? substr($accion, 0, 80) : null,
            'resultado' => in_array($resultado, ['OK', 'DENEGADO', 'ERROR'], true) ? $resultado : null,
            'desde' => $this->consultaFecha($p, 'desde'),
            'hasta' => $this->consultaFecha($p, 'hasta'),
        ], fn ($v) => $v !== null);

        return Json::ok($this->atlas->auditoriaRepo()->listar($filtros, $this->consultaEntera($p, 'limite') ?? 200));
    }
}
