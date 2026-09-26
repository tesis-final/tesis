<?php

declare(strict_types=1);

namespace Atlas\Services;

use Atlas\Core\Database;
use Atlas\Core\HttpException;
use Atlas\Repositories\ActividadRepository;
use Atlas\Repositories\OrganizacionRepository;

/**
 * Creación de actividades y ciclo de aprobación (RF-16, RF-17; §25.3; DEC-12).
 *
 * Transiciones permitidas:
 *   BORRADOR  → PENDIENTE  (docente autor; ≥1 pregunta, cada una ≥2 opciones y 1 correcta)
 *   PENDIENTE → APROBADA   (administrador)
 *   PENDIENTE → RECHAZADA  (administrador; observaciones obligatorias)
 *   RECHAZADA → BORRADOR   (docente autor, al editar)
 *   APROBADA  → PUBLICADA  (docente autor, eligiendo sus grupos)
 * La base de datos repite el control con un trigger (segunda barrera).
 */
final class ActividadService
{
    public function __construct(
        private readonly ActividadRepository $actividades,
        private readonly OrganizacionRepository $organizacion,
        private readonly Database $db
    ) {
    }

    /** @param array<string, mixed> $datos validados @return array<string, mixed> */
    public function crear(int $docente, array $datos): array
    {
        $preguntas = $this->normalizarPreguntas($datos['preguntas'] ?? []);
        $id = $this->db->transaccion(function () use ($docente, $datos, $preguntas): int {
            $id = $this->actividades->crear(
                $docente,
                $datos['titulo'],
                $datos['descripcion'] ?? null,
                $datos['nivel'],
                $datos['categoria']
            );
            $this->actividades->cambiarEstado($id, null, 'BORRADOR', $docente, null);
            $this->actividades->reemplazarContenido($id, $preguntas);

            return $id;
        });

        return $this->detalle($id, true);
    }

    /** @param array<string, mixed> $datos validados @return array<string, mixed> */
    public function editar(int $id, int $docente, array $datos): array
    {
        $actividad = $this->propia($id, $docente);
        if (!in_array($actividad['estado'], ['BORRADOR', 'RECHAZADA'], true)) {
            throw HttpException::conflicto('Solo se pueden editar actividades en borrador o rechazadas.');
        }
        $preguntas = $this->normalizarPreguntas($datos['preguntas'] ?? []);
        $this->db->transaccion(function () use ($id, $docente, $datos, $preguntas, $actividad): void {
            if ($actividad['estado'] === 'RECHAZADA') {
                // "Rechaza → vuelve al docente con observaciones" (§25.3): al editar vuelve a borrador.
                $this->actividades->cambiarEstado($id, 'RECHAZADA', 'BORRADOR', $docente, null);
            }
            $this->actividades->actualizarDatos(
                $id,
                $datos['titulo'],
                $datos['descripcion'] ?? null,
                $datos['nivel'],
                $datos['categoria']
            );
            $this->actividades->reemplazarContenido($id, $preguntas);
        });

        return $this->detalle($id, true);
    }

    public function enviar(int $id, int $docente): array
    {
        $actividad = $this->propia($id, $docente);
        $this->exigirEstado($actividad, 'BORRADOR');
        $errores = $this->erroresDeContenido($this->actividades->preguntas($id, true));
        if ($errores !== []) {
            throw HttpException::validacion(
                $errores,
                'La actividad no cumple las condiciones para enviarse a aprobación.'
            );
        }
        $this->transicion($id, 'BORRADOR', 'PENDIENTE', $docente, null);

        return $this->detalle($id, true);
    }

    public function aprobar(int $id, int $admin): array
    {
        $this->exigirEstado($this->existente($id), 'PENDIENTE');
        $this->transicion($id, 'PENDIENTE', 'APROBADA', $admin, null);

        return $this->detalle($id, true);
    }

    public function rechazar(int $id, int $admin, string $observaciones): array
    {
        $this->exigirEstado($this->existente($id), 'PENDIENTE');
        $this->transicion($id, 'PENDIENTE', 'RECHAZADA', $admin, $observaciones);

        return $this->detalle($id, true);
    }

    /** @param list<int> $grupos */
    public function publicar(int $id, int $docente, array $grupos): array
    {
        $actividad = $this->propia($id, $docente);
        $this->exigirEstado($actividad, 'APROBADA');
        $grupos = array_values(array_unique(array_map('intval', $grupos)));
        foreach ($grupos as $g) {
            if (!$this->organizacion->perteneceAGrupo($docente, $g)) {
                throw HttpException::prohibido("El grupo {$g} no es uno de sus grupos.");
            }
        }
        $this->db->transaccion(function () use ($id, $docente, $grupos): void {
            foreach ($grupos as $g) {
                $this->actividades->publicarEnGrupo($id, $g, $docente);
            }
            $this->actividades->cambiarEstado($id, 'APROBADA', 'PUBLICADA', $docente, null);
        });

        return $this->detalle($id, true);
    }

    /** @return array<string, mixed> */
    public function detalle(int $id, bool $conCorrectas): array
    {
        $actividad = $this->existente($id);
        $actividad['preguntas'] = $this->actividades->preguntas($id, $conCorrectas);
        $actividad['grupos'] = $this->actividades->gruposPublicados($id);
        $transiciones = $this->actividades->transiciones($id);
        $actividad['transiciones'] = $transiciones;
        $ultimoRechazo = array_values(array_filter($transiciones, fn ($t) => $t['hacia'] === 'RECHAZADA'));
        $actividad['observaciones_rechazo'] = $ultimoRechazo === [] ? null : end($ultimoRechazo)['observaciones'];

        return $actividad;
    }

    /** Detalle visible para un usuario según su rol (admin revisa; docente solo las suyas). */
    public function detalleSegunRol(int $id, array $usuario): array
    {
        $actividad = $this->existente($id);
        if ($usuario['rol'] === 'DOCENTE' && (int) $actividad['autor_id'] !== $usuario['id']) {
            throw HttpException::prohibido('Solo puede ver sus propias actividades.');
        }

        return $this->detalle($id, true);
    }

    /**
     * Reglas de H24 sobre el contenido. @param list<array<string, mixed>> $preguntas
     * @return array<string, string>
     */
    public function erroresDeContenido(array $preguntas): array
    {
        if ($preguntas === []) {
            return ['preguntas' => 'Una actividad sin preguntas no puede enviarse a aprobación.'];
        }
        $errores = [];
        foreach ($preguntas as $i => $p) {
            $opciones = $p['opciones'] ?? [];
            $correctas = count(array_filter($opciones, fn ($o) => !empty($o['correcta'])));
            if (count($opciones) < 2) {
                $errores["preguntas.{$i}"] = 'Cada pregunta necesita al menos 2 opciones.';
            } elseif ($correctas !== 1) {
                $errores["preguntas.{$i}"] = 'Cada pregunta necesita exactamente 1 opción correcta.';
            }
        }

        return $errores;
    }

    private function transicion(int $id, string $origen, string $destino, int $usuario, ?string $obs): void
    {
        $this->db->transaccion(fn () => $this->actividades->cambiarEstado($id, $origen, $destino, $usuario, $obs));
    }

    /** @return array<string, mixed> */
    private function existente(int $id): array
    {
        return $this->actividades->obtener($id) ?? throw HttpException::noEncontrado('Actividad no encontrada.');
    }

    /** @return array<string, mixed> */
    private function propia(int $id, int $docente): array
    {
        $actividad = $this->existente($id);
        if ((int) $actividad['autor_id'] !== $docente) {
            throw HttpException::prohibido('Solo el docente autor puede realizar esta acción.');
        }

        return $actividad;
    }

    /** @param array<string, mixed> $actividad */
    private function exigirEstado(array $actividad, string $estado): void
    {
        if ($actividad['estado'] !== $estado) {
            throw HttpException::conflicto(
                "La actividad está en estado {$actividad['estado']}; se requiere {$estado}."
            );
        }
    }

    /**
     * Valida la forma de las preguntas del borrador (el contenido completo se exige al enviar).
     *
     * @return list<array{enunciado: string, opciones: list<array{texto: string, correcta: bool}>}>
     */
    private function normalizarPreguntas(mixed $preguntas): array
    {
        if (!is_array($preguntas) || !array_is_list($preguntas) || count($preguntas) > 100) {
            throw HttpException::validacion(['preguntas' => 'Debe ser una lista de hasta 100 preguntas.']);
        }
        $salida = [];
        $errores = [];
        foreach ($preguntas as $i => $p) {
            $enunciado = is_array($p) ? trim((string) ($p['enunciado'] ?? '')) : '';
            if ($enunciado === '' || mb_strlen($enunciado) > 2000) {
                $errores["preguntas.{$i}.enunciado"] = 'El enunciado es obligatorio (máximo 2000 caracteres).';
                continue;
            }
            $opciones = [];
            foreach ((array) ($p['opciones'] ?? []) as $j => $o) {
                $texto = is_array($o) ? trim((string) ($o['texto'] ?? '')) : '';
                if ($texto === '' || mb_strlen($texto) > 500) {
                    $errores["preguntas.{$i}.opciones.{$j}"] = 'El texto de la opción es obligatorio (máximo 500).';
                    continue;
                }
                $opciones[] = ['texto' => $texto, 'correcta' => (bool) ($o['correcta'] ?? false)];
            }
            if (count($opciones) > 10) {
                $errores["preguntas.{$i}.opciones"] = 'Máximo 10 opciones por pregunta.';
            }
            $salida[] = ['enunciado' => $enunciado, 'opciones' => $opciones];
        }
        if ($errores !== []) {
            throw HttpException::validacion($errores);
        }

        return $salida;
    }
}
