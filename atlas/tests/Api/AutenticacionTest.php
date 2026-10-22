<?php

declare(strict_types=1);

namespace Atlas\Tests\Api;

/** RF-02 (H10, Tabla 14; DEC-23): login, error genérico, bloqueo a los 3 fallos, auditoría. */
final class AutenticacionTest extends ApiTestCase
{
    public function testCredencialesValidasEntranAlPanelDeSuRol(): void
    {
        [, $correo] = self::usuario('DOCENTE');
        $c = $this->cliente();
        $c->pedir('GET', '/health');
        $antes = $c->cookieSesion;
        $r = $c->login($correo, self::CLAVE);

        $this->assertSame(200, $c->ultimoEstado);
        $this->assertSame('DOCENTE', $r['usuario']['rol']);
        $this->assertContains('panel.docente', $r['permisos']);
        $this->assertSame(64, strlen($r['csrf']));
        $this->assertNotNull($antes);
        $this->assertNotSame($antes, $c->cookieSesion, 'se regenera la sesión al entrar (fijación de sesión)');
        $this->assertArrayNotHasKey('hash_contrasena', $r['usuario']);
    }

    public function testErrorNoRevelaQueDatoEstaMal(): void
    {
        [, $correo] = self::usuario('ESTUDIANTE');
        $c = $this->cliente();
        $malaClave = $c->login($correo, 'otra-clave-cualquiera');
        $estadoMalaClave = $c->ultimoEstado;
        $noExiste = $c->login('nadie.' . bin2hex(random_bytes(4)) . '@prueba.atlas.local', self::CLAVE);

        $this->assertSame([401, 401], [$estadoMalaClave, $c->ultimoEstado]);
        $this->assertSame($malaClave['error'], $noExiste['error']);
        $this->assertSame('Correo o contraseña incorrectos.', $malaClave['error']);
    }

    public function testTresIntentosFallidosBloqueanTemporalmente(): void
    {
        [$id, $correo] = self::usuario('ESTUDIANTE');
        $c = $this->cliente();
        foreach (range(1, 3) as $_) {
            $c->login($correo, 'incorrecta-123');
            $this->assertSame(401, $c->ultimoEstado);
        }
        // Con la contraseña correcta igual queda bloqueado.
        $r = $c->login($correo, self::CLAVE);
        $this->assertSame(423, $c->ultimoEstado);
        $this->assertStringContainsString('bloqueado temporalmente', $r['error']);

        $minutos = (int) self::valor(
            'SELECT TIMESTAMPDIFF(MINUTE, UTC_TIMESTAMP(3), bloqueado_hasta) FROM usuarios WHERE id = ?',
            [$id]
        );
        $this->assertContains($minutos, [14, 15], 'bloqueo de 15 minutos (DEC-23)');

        $acciones = self::pdo()
            ->query("SELECT accion, resultado FROM auditoria WHERE usuario_id = {$id} ORDER BY id")
            ->fetchAll();
        $this->assertSame(
            [
                'auth.login:DENEGADO',
                'auth.login:DENEGADO',
                'auth.login:DENEGADO',
                'auth.bloqueo:OK',
                'auth.login:DENEGADO'
            ],
            array_map(fn ($a) => $a['accion'] . ':' . $a['resultado'], $acciones)
        );
    }

    public function testLoginCorrectoReiniciaElContadorYSeAudita(): void
    {
        [$id, $correo] = self::usuario('DOCENTE');
        $c = $this->cliente();
        $c->login($correo, 'incorrecta-123');
        $c->login($correo, self::CLAVE);
        $this->assertSame(200, $c->ultimoEstado);
        $this->assertSame(0, (int) self::valor('SELECT intentos_fallidos FROM usuarios WHERE id = ?', [$id]));
        $this->assertSame(1, (int) self::valor(
            "SELECT COUNT(*) FROM auditoria WHERE usuario_id = ? AND accion = 'auth.login' AND resultado = 'OK'",
            [$id]
        ));
    }

    public function testCuentaDesactivadaNoEntra(): void
    {
        [$id, $correo] = self::usuario('DOCENTE');
        self::ejecutar('UPDATE usuarios SET activo = FALSE WHERE id = ?', [$id]);
        $c = $this->cliente();
        $c->login($correo, self::CLAVE);
        $this->assertSame(401, $c->ultimoEstado);
    }

    public function testCerrarSesion(): void
    {
        [$c] = $this->entrar('DOCENTE');
        $c->pedir('POST', '/auth/logout');
        $this->assertSame(204, $c->ultimoEstado);
        $c->pedir('GET', '/auth/me');
        $this->assertSame(401, $c->ultimoEstado);
    }

    public function testElLogDeAuditoriaEnArchivoRecibeLineas(): void
    {
        [, $correo] = self::usuario('DOCENTE');
        $antes = is_file(self::$logAuditoria) ? count(file(self::$logAuditoria)) : 0;
        $this->cliente()->login($correo, self::CLAVE);
        $lineas = file(self::$logAuditoria);
        $this->assertGreaterThan($antes, count($lineas));
        $ultima = json_decode(end($lineas), true);
        $this->assertSame('auth.login', $ultima['accion']);
    }
}
