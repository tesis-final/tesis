<?php

declare(strict_types=1);

namespace Atlas\Http\Controllers;

use Atlas\Http\Json;
use Atlas\Http\Requests\ConsultaAsistenteRequest;
use Atlas\Http\Requests\DecisionRequest;
use Atlas\Repositories\ConversacionRepository;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Panel docente, consultas, reportes y asistente (RF-10..RF-13, RF-18, RF-20; D-5, D-6). */
final class DocenteController extends Controller
{
    /** También responde las consultas guiadas: grupo + período (desde/hasta) + actividad (D-5). */
    public function analisisGrupal(Request $p): JsonResponse
    {
        return Json::ok($this->atlas->panel()->analisisGrupal(
            $this->usuario($p),
            $this->id($p),
            $this->consultaEntera($p, 'actividad'),
            $this->consultaFecha($p, 'desde'),
            $this->consultaFecha($p, 'hasta')
        ));
    }

    public function perfil(Request $p): JsonResponse
    {
        return Json::ok($this->atlas->panel()->perfilEstudiante(
            $this->usuario($p),
            $this->id($p),
            $this->consultaFecha($p, 'desde')
        ));
    }

    public function fundamento(Request $p): JsonResponse
    {
        return Json::ok($this->atlas->panel()->fundamento($this->usuario($p), $this->id($p)));
    }

    /** D-6: el docente confirma o cambia la actividad sugerida. */
    public function decidir(DecisionRequest $p): JsonResponse
    {
        return Json::ok($this->atlas->panel()->decidir(
            $this->usuario($p),
            $this->id($p),
            $p->validados()['actividad_id'] ?? null
        ));
    }

    public function reportes(Request $p): JsonResponse
    {
        return Json::ok($this->atlas->panel()->reporte(
            $this->usuario($p),
            $this->consultaEntera($p, 'grupo'),
            $this->consultaEntera($p, 'actividad'),
            $this->consultaFecha($p, 'desde'),
            $this->consultaFecha($p, 'hasta')
        ));
    }

    public function consultar(ConsultaAsistenteRequest $p): JsonResponse
    {
        return Json::ok($this->atlas->asistente()->consultar($this->usuario($p), $p->validados()['pregunta']));
    }

    public function historial(Request $p): JsonResponse
    {
        return Json::ok((new ConversacionRepository($this->atlas->db()))->historial($this->usuario($p)['id']));
    }
}
