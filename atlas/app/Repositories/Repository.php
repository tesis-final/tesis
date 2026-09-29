<?php

declare(strict_types=1);

namespace Atlas\Repositories;

use Atlas\Core\Database;
use PDO;

/**
 * Base de la capa de acceso a datos: todas las consultas pasan por aquí y
 * usan sentencias preparadas (§26.4 "las consultas van todas a los repositorios").
 */
abstract class Repository
{
    public function __construct(protected readonly Database $db)
    {
    }

    protected function pdo(): PDO
    {
        return $this->db->app();
    }

    /** @param array<int|string, mixed> $params @return list<array<string, mixed>> */
    protected function todos(string $sql, array $params = [], ?PDO $pdo = null): array
    {
        $st = ($pdo ?? $this->pdo())->prepare($sql);
        $st->execute($params);

        return $st->fetchAll();
    }

    /** @param array<int|string, mixed> $params @return array<string, mixed>|null */
    protected function uno(string $sql, array $params = [], ?PDO $pdo = null): ?array
    {
        $st = ($pdo ?? $this->pdo())->prepare($sql);
        $st->execute($params);
        $fila = $st->fetch();

        return $fila === false ? null : $fila;
    }

    /** @param array<int|string, mixed> $params */
    protected function valor(string $sql, array $params = [], ?PDO $pdo = null): mixed
    {
        $st = ($pdo ?? $this->pdo())->prepare($sql);
        $st->execute($params);

        return $st->fetchColumn();
    }

    /** @param array<int|string, mixed> $params */
    protected function ejecutar(string $sql, array $params = []): int
    {
        $st = $this->pdo()->prepare($sql);
        $st->execute($params);

        return (int) $this->pdo()->lastInsertId();
    }

    /** @param array<int|string, mixed> $params */
    protected function afectadas(string $sql, array $params = []): int
    {
        $st = $this->pdo()->prepare($sql);
        $st->execute($params);

        return $st->rowCount();
    }

    protected function idCatalogo(string $tabla, string $codigo): int
    {
        $permitidas = ['roles', 'estados_actividad', 'niveles_dificultad', 'categorias'];
        if (!in_array($tabla, $permitidas, true)) {
            throw new \LogicException("Catálogo no permitido: {$tabla}");
        }
        $id = $this->valor("SELECT id FROM {$tabla} WHERE codigo = ?", [$codigo]);
        if ($id === false) {
            throw new \RuntimeException("Código {$codigo} inexistente en {$tabla}");
        }

        return (int) $id;
    }
}
