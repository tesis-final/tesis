<#
.SYNOPSIS
    ATLAS · Fase 7 · Paso 2 — Crear el dominio atlas.local (bosque nuevo).
.DESCRIPTION
    PDF §29.1: atlas-dc01 es el controlador de dominio de atlas.local, con DNS
    integrado en Active Directory (§29.4). Pide la contraseña del Modo de
    Restauración de Servicios de Directorio (DSRM): no queda escrita en ningún lado.
    Al terminar el equipo se reinicia solo.
#>
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\AtlasComun.psm1" -Force
Assert-AtlasAdministrador
$p = Import-AtlasParametro

if ((Get-CimInstance Win32_ComputerSystem).PartOfDomain) {
    Write-AtlasPaso "Este equipo ya pertenece a un dominio: $((Get-CimInstance Win32_ComputerSystem).Domain). Nada que hacer."
    return
}

Write-AtlasPaso 'Roles: Servicios de dominio de Active Directory y DNS'
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools | Out-Null

Write-AtlasPaso "Bosque y dominio $($p.Dominio) (NetBIOS $($p.NetBIOS))"
$dsrm = Read-Host -AsSecureString 'Contraseña DSRM (mínimo 10 caracteres, con complejidad; guardarla en el gestor del equipo)'
if ($PSCmdlet.ShouldProcess($p.Dominio, 'Install-ADDSForest')) {
    Install-ADDSForest -DomainName $p.Dominio -DomainNetbiosName $p.NetBIOS `
        -ForestMode WinThreshold -DomainMode WinThreshold `
        -InstallDns -CreateDnsDelegation:$false `
        -SafeModeAdministratorPassword $dsrm -Force
}
