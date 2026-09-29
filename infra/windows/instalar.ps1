<#
.SYNOPSIS
    ATLAS · Fase 7 — Orden de ejecución de los scripts de atlas-dc01.
.DESCRIPTION
    Hay dos reinicios obligatorios, así que se corre en tres etapas:
      Etapa 1:  .\instalar.ps1 -Etapa 1   → 01 (IP, nombre) y reinicia
      Etapa 2:  .\instalar.ps1 -Etapa 2   → 02 (dominio) y reinicia
      Etapa 3:  .\instalar.ps1 -Etapa 3   → 03 a 11 y verificación (entrar como ATLAS\<administrador>)
    Después: .\12-usuarios.ps1 -Csv <archivo>  y  .\10-certificado-srv01.ps1 -Csr <atlas.csr>
#>
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet(1, 2, 3)][int]$Etapa)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
switch ($Etapa) {
    1 { .\01-red-y-nombre.ps1 }
    2 { .\02-promover-dc.ps1 }
    3 {
        foreach ($s in '03-estructura-ad', '04-politicas-seguridad', '05-dns', '06-dhcp', '07-gpo',
            '08-recursos-compartidos', '09-ca-atlas', '11-firewall-y-hora') {
            Write-Host "`n████ $s" -ForegroundColor Cyan
            & ".\$s.ps1"
        }
        Write-Host "`n████ Verificación" -ForegroundColor Cyan
        .\verificar-dc01.ps1
    }
}
