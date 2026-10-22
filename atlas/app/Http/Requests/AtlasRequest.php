<?php

declare(strict_types=1);

namespace Atlas\Http\Requests;

use Atlas\Core\HttpException;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;

/**
 * [3] ¿Los datos que llegaron sirven? Si no → 422 con el detalle por campo, con el
 * mismo formato que antes de Laravel: {"error": "...", "errores": {"campo": "mensaje"}}.
 * Los permisos ya los controló atlas.permiso, por eso authorize() siempre deja pasar.
 * Los mensajes están en lang/es/validation.php.
 */
abstract class AtlasRequest extends FormRequest
{
    /** @return array<string, list<string>> */
    abstract public function rules(): array;

    public function authorize(): bool
    {
        return true;
    }

    protected function failedValidation(Validator $validador): never
    {
        throw HttpException::validacion(array_map(fn (array $m) => $m[0], $validador->errors()->toArray()));
    }

    /**
     * Datos validados con su tipo (los servicios usan strict_types): enteros como int,
     * booleanos como bool, correos en minúscula. Los opcionales vacíos no aparecen.
     *
     * @return array<string, mixed>
     */
    public function validados(): array
    {
        $reglas = $this->rules();
        $salida = [];
        foreach ($this->validated() as $campo => $valor) {
            if ($valor === null) {
                continue;
            }
            $r = $reglas[$campo] ?? [];
            $salida[$campo] = match (true) {
                in_array('integer', $r, true) => (int) $valor,
                in_array('boolean', $r, true) => filter_var($valor, FILTER_VALIDATE_BOOL),
                in_array('email:filter', $r, true) => mb_strtolower((string) $valor),
                default => $valor,
            };
        }

        return $salida;
    }
}
