<?php

declare(strict_types=1);

namespace Atlas\Tests\Database;

/**
 * Auditoría: RF-15 (no modificable). El autor, la fecha y el detalle de cada cambio
 * (RF-14) y el versionado de reglas (§27.3) los registra la aplicación (acta D-4).
 */
final class AuditoriaTest extends DatabaseTestCase
{
    public function testAuditoriaNoSeModificaNiBorraNiSiquieraComoRoot(): void
    {
        $id = self::ejecutar(
            "INSERT INTO auditoria (accion, resultado) VALUES ('prueba.inmutable', 'OK')"
        );
        $this->assertFalla(
            'UPDATE auditoria SET accion = ? WHERE id = ?',
            ['alterada', $id],
            contiene: 'no se puede modificar'
        );
        $this->assertFalla('DELETE FROM auditoria WHERE id = ?', [$id], contiene: 'no se puede borrar');
    }

    public function testLaBaseNoCalculaNiEscribeAuditoriaPorSuCuenta(): void
    {
        // Acta D-4 (004): los registros de auditoría con su detalle y la versión de las
        // reglas los escribe la aplicación (ver tests/Api/GestionAdministrativaTest y
        // MotorAnalisisApiTest). La base solo protege la auditoría (test anterior).
        $this->assertSame([], self::pdo()->query(
            "SELECT trigger_name FROM information_schema.triggers
              WHERE trigger_schema = 'atlas_db'
                AND (trigger_name LIKE '%auditoria_ins' OR trigger_name LIKE '%auditoria_upd'
                     OR trigger_name IN ('trg_reglas_version', 'trg_reglas_auditoria'))"
        )->fetchAll(\PDO::FETCH_COLUMN));

        $docente = self::crearUsuario('docente');
        $antes = (int) self::valor('SELECT COUNT(*) FROM auditoria');
        self::ejecutar('UPDATE usuarios SET activo = FALSE WHERE id = ?', [$docente]);
        $this->assertSame($antes, (int) self::valor('SELECT COUNT(*) FROM auditoria'));

        $version = (int) self::valor("SELECT version FROM reglas_analisis WHERE codigo = 'R03'");
        self::ejecutar("UPDATE reglas_analisis SET activa = activa WHERE codigo = 'R03'");
        $this->assertSame($version, (int) self::valor("SELECT version FROM reglas_analisis WHERE codigo = 'R03'"));
    }
}
