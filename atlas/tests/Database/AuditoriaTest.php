<?php

declare(strict_types=1);

namespace Atlas\Tests\Database;

/**
 * Auditoría: RF-15 (no modificable), RF-14 (autor y fecha), §27.3 (reglas versionadas).
 */
final class AuditoriaTest extends DatabaseTestCase
{
    public function testAuditoriaNoSeModificaNiBorraNiSiquieraComoRoot(): void
    {
        $id = self::ejecutar(
            "INSERT INTO auditoria (accion, resultado) VALUES ('prueba.inmutable', 'OK')"
        );
        $this->assertFalla('UPDATE auditoria SET accion = ? WHERE id = ?', ['alterada', $id], contiene: 'no se puede modificar');
        $this->assertFalla('DELETE FROM auditoria WHERE id = ?', [$id], contiene: 'no se puede borrar');
    }

    public function testCambioDeUsuarioQuedaAuditadoConAutor(): void
    {
        $admin = self::crearUsuario('admin');
        $docente = self::crearUsuario('docente');
        self::pdo()->exec("SET @atlas_usuario_id = {$admin}");
        self::ejecutar('UPDATE usuarios SET activo = FALSE WHERE id = ?', [$docente]);
        self::pdo()->exec('SET @atlas_usuario_id = NULL');

        $fila = self::pdo()->query(
            "SELECT usuario_id, accion, detalle, creado_en FROM auditoria
              WHERE recurso = 'usuarios' AND recurso_id = '{$docente}' AND accion = 'usuarios.modificar'"
        )->fetch();
        $this->assertSame($admin, (int) $fila['usuario_id']);
        $this->assertSame([1, 0], json_decode($fila['detalle'], true)['activo']);
        $this->assertNotEmpty($fila['creado_en']);
    }

    public function testContrasenaNoSeCopiaALaAuditoria(): void
    {
        $docente = self::crearUsuario('docente');
        self::ejecutar('UPDATE usuarios SET hash_contrasena = ? WHERE id = ?', ['$argon2id$nuevo', $docente]);
        $detalle = (string) self::valor(
            "SELECT detalle FROM auditoria WHERE recurso = 'usuarios' AND recurso_id = ? AND accion = 'usuarios.modificar'
              ORDER BY id DESC LIMIT 1",
            [(string) $docente]
        );
        $this->assertStringNotContainsString('argon2id', $detalle);
        $this->assertTrue(json_decode($detalle, true)['contrasena_cambiada']);
    }

    public function testEditarUnaReglaIncrementaVersionYSeAudita(): void
    {
        $antes = (int) self::valor("SELECT version FROM reglas_analisis WHERE codigo = 'R03'");
        self::ejecutar(
            "UPDATE reglas_analisis
                SET condicion = JSON_SET(condicion, '$.todas[1].valor', 0.65)
              WHERE codigo = 'R03'"
        );
        $this->assertSame($antes + 1, (int) self::valor("SELECT version FROM reglas_analisis WHERE codigo = 'R03'"));
        $this->assertSame(1, (int) self::valor(
            "SELECT COUNT(*) FROM auditoria WHERE accion = 'reglas.modificar' AND recurso_id = 'R03'
               AND CAST(JSON_EXTRACT(detalle, '$.version[1]') AS UNSIGNED) = ?",
            [$antes + 1]
        ));
        // Restablecer el valor aprobado (DEC-23).
        self::ejecutar(
            "UPDATE reglas_analisis SET condicion = JSON_SET(condicion, '$.todas[1].valor', 0.7) WHERE codigo = 'R03'"
        );
    }
}
