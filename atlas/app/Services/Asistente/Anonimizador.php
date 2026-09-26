<?php

declare(strict_types=1);

namespace Atlas\Services\Asistente;

/**
 * Reemplaza personas y grupos por seudónimos antes de consultar al LLM y los
 * restituye después (PDF §25.4 "Protección de datos"; H28; Ley 18.331).
 * Al modelo nunca llegan nombres, apellidos, correos, cédulas ni identificadores.
 */
final class Anonimizador
{
    /** @var array<string, string> seudónimo → nombre real */
    private array $mapa = [];
    /** @var array<int, string> id estudiante → seudónimo */
    private array $estudiantes = [];
    /** @var array<int, string> */
    private array $grupos = [];
    /** @var list<string> nombres/apellidos conocidos, para sanitizar texto libre */
    private array $conocidos = [];
    /** @var array<string, list<string>> nombre o apellido suelto → seudónimos que lo usan */
    private array $alias = [];

    public function estudiante(int $id, string $nombre, string $apellido): string
    {
        if (!isset($this->estudiantes[$id])) {
            $seudonimo = 'E' . (count($this->estudiantes) + 1);
            $this->estudiantes[$id] = $seudonimo;
            $this->mapa[$seudonimo] = trim($nombre . ' ' . $apellido);
            array_push($this->conocidos, $nombre . ' ' . $apellido, $nombre, $apellido);
            foreach ([$nombre, $apellido] as $parte) {
                $this->alias[mb_strtolower(trim($parte))][] = $seudonimo;
            }
        }

        return $this->estudiantes[$id];
    }

    public function grupo(int $id, string $nombre): string
    {
        if (!isset($this->grupos[$id])) {
            $seudonimo = 'G' . (count($this->grupos) + 1);
            $this->grupos[$id] = $seudonimo;
            $this->mapa[$seudonimo] = $nombre;
            $this->conocidos[] = $nombre;
        }

        return $this->grupos[$id];
    }

    /** Registra nombres que deben eliminarse del texto libre aunque no estén en el contexto. */
    public function conocer(string ...$nombres): void
    {
        array_push($this->conocidos, ...$nombres);
    }

    /** Quita del texto libre nombres conocidos, correos y números tipo cédula. */
    public function sanitizar(string $texto): string
    {
        $t = preg_replace('/[\w.+-]+@[\w-]+(\.[\w-]+)+/u', '[correo]', $texto) ?? '';
        $t = preg_replace('/\b\d[\d.\-]{5,}\d\b/u', '[número]', $t) ?? '';
        $inverso = array_flip($this->mapa);
        $conocidos = array_unique(array_filter($this->conocidos, fn ($n) => mb_strlen(trim($n)) >= 2));
        usort($conocidos, fn ($a, $b) => mb_strlen($b) <=> mb_strlen($a)); // primero los más largos
        foreach ($conocidos as $nombre) {
            // Nombre completo → su seudónimo; nombre o apellido suelto → seudónimo solo si no es ambiguo.
            $alias = array_unique($this->alias[mb_strtolower(trim($nombre))] ?? []);
            $reemplazo = $inverso[trim($nombre)] ?? (count($alias) === 1 ? $alias[0] : '[persona]');
            $t = preg_replace(
                '/(?<![\p{L}\d])' . preg_quote(trim($nombre), '/') . '(?![\p{L}\d])/iu',
                $reemplazo,
                $t
            ) ?? '';
        }

        return $t;
    }

    /** Restituye los nombres reales en la respuesta del modelo (del lado de ATLAS). */
    public function reidentificar(string $texto): string
    {
        $claves = array_keys($this->mapa);
        usort($claves, fn ($a, $b) => strlen($b) <=> strlen($a)); // E10 antes que E1

        return (string) preg_replace_callback(
            '/\b(' . implode('|', array_map('preg_quote', $claves ?: ['__nada__'])) . ')\b/',
            fn ($m) => $this->mapa[$m[1]],
            $texto
        );
    }

    /** @return array<string, string> seudónimo → nombre (solo para mostrar al docente, nunca se envía). */
    public function mapa(): array
    {
        return $this->mapa;
    }

    /** ¿El contenido serializado contiene algún nombre conocido? (verificación antes de enviar). */
    public function contieneIdentificables(string $contenido): bool
    {
        foreach (array_unique($this->conocidos) as $nombre) {
            $n = trim($nombre);
            if (
                mb_strlen($n) >= 3 && preg_match(
                    '/(?<![\p{L}\d])' . preg_quote($n, '/') . '(?![\p{L}\d])/iu',
                    $contenido
                ) === 1
            ) {
                return true;
            }
        }

        return preg_match('/[\w.+-]+@[\w-]+\.[\w.-]+/u', $contenido) === 1;
    }
}
