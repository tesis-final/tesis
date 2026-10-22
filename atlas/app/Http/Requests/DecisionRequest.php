<?php

declare(strict_types=1);

namespace Atlas\Http\Requests;

/** Decisión del docente sobre la actividad sugerida (D-6): sin actividad_id confirma la sugerida. */
final class DecisionRequest extends AtlasRequest
{
    public function rules(): array
    {
        return [
            'actividad_id' => ['nullable', 'integer', 'min:1'],
        ];
    }
}
