<?php

declare(strict_types=1);

namespace Atlas\Core;

use PDO;

/**
 * Conexiones PDO con los usuarios de la Tabla 21: atlas_app para operar y
 * atlas_read para las vistas de reportes. La aplicación nunca usa atlas_admin.
 * Todas las consultas usan sentencias preparadas (§27.5).
 */
final class Database
{
    private ?PDO $app = null;
    private ?PDO $lectura = null;

    public function __construct(private readonly Config $config)
    {
    }

    public function app(): PDO
    {
        return $this->app ??= $this->conectar('ATLAS_DB_APP_USER', 'atlas_app', 'ATLAS_DB_APP_PASSWORD');
    }

    public function lectura(): PDO
    {
        return $this->lectura ??= $this->conectar('ATLAS_DB_READ_USER', 'atlas_read', 'ATLAS_DB_READ_PASSWORD');
    }

    /**
     * @template T
     * @param callable(PDO): T $trabajo
     * @return T
     */
    public function transaccion(callable $trabajo): mixed
    {
        $pdo = $this->app();
        $pdo->beginTransaction();
        try {
            $resultado = $trabajo($pdo);
            $pdo->commit();

            return $resultado;
        } catch (\Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }
    }

    private function conectar(string $claveUsuario, string $usuarioDefecto, string $claveContrasena): PDO
    {
        $dsn = sprintf(
            'mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4',
            $this->config->texto('ATLAS_DB_HOST', 'atlas-db'),
            $this->config->entero('ATLAS_DB_PORT', 3306),
            $this->config->texto('ATLAS_DB_NAME', 'atlas_db')
        );
        $pdo = new PDO($dsn, $this->config->texto(
            $claveUsuario,
            $usuarioDefecto
        ), $this->config->texto($claveContrasena), [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
            PDO::ATTR_STRINGIFY_FETCHES => false,
        ]);
        $pdo->exec("SET time_zone = '+00:00'");

        return $pdo;
    }
}
