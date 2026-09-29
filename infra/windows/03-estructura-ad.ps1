<#
.SYNOPSIS
    ATLAS · Fase 7 · Paso 3 — Unidades organizativas, grupos, cuenta de servicio y delegación.
.DESCRIPTION
    PDF §29.2 (literal):
        atlas.local
        ├── OU=ATLAS
        │   ├── OU=Administracion ── Usuarios, Equipos
        │   ├── OU=Docentes ─────── Usuarios, Equipos
        │   ├── OU=Estudiantes ──── Usuarios, Equipos
        │   ├── OU=Servidores
        │   └── OU=ServiciosTI
        └── OU=Grupos  (en la raíz, DEC-R1): GG_Administracion, GG_Docentes, GG_Estudiantes, GG_SoporteTI
    Tabla 32 "Delegación": GG_SoporteTI administra usuarios y equipos DENTRO de OU=ATLAS
    y la membresía de los grupos de OU=Grupos, sin privilegios de dominio.
    CT-09: cuenta de servicio svc_atlas_backup (respaldos de atlas-srv01).
#>
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\AtlasComun.psm1" -Force
Import-Module ActiveDirectory
Assert-AtlasAdministrador
$p = Import-AtlasParametro
$dn = $p.DN

function New-AtlasOU {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Nombre, [string]$Padre, [string]$Descripcion)
    $existe = Get-ADOrganizationalUnit -LDAPFilter "(ou=$Nombre)" -SearchBase $Padre -SearchScope OneLevel -ErrorAction SilentlyContinue
    if (-not $existe -and $PSCmdlet.ShouldProcess("OU=$Nombre,$Padre", 'New-ADOrganizationalUnit')) {
        New-ADOrganizationalUnit -Name $Nombre -Path $Padre -Description $Descripcion -ProtectedFromAccidentalDeletion $true
        Write-Output "   + OU=$Nombre,$Padre"
    }
}

Write-AtlasPaso 'Unidades organizativas (§29.2)'
New-AtlasOU -Nombre 'ATLAS' -Padre $dn -Descripcion 'Estructura de ATLAS: sigue la división de las VLAN (§29.2)'
$atlas = "OU=ATLAS,$dn"
foreach ($area in @(
        @{ N = 'Administracion'; D = 'VLAN 10 - Administración' }
        @{ N = 'Docentes'; D = 'VLAN 20 - Docentes' }
        @{ N = 'Estudiantes'; D = 'VLAN 30 - Estudiantes' })) {
    New-AtlasOU -Nombre $area.N -Padre $atlas -Descripcion $area.D
    New-AtlasOU -Nombre 'Usuarios' -Padre "OU=$($area.N),$atlas" -Descripcion "Cuentas de $($area.N)"
    New-AtlasOU -Nombre 'Equipos' -Padre "OU=$($area.N),$atlas" -Descripcion "Equipos de la $($area.D)"
}
New-AtlasOU -Nombre 'Servidores' -Padre $atlas -Descripcion 'VLAN 40 - Servidores miembros (atlas-srv01)'
New-AtlasOU -Nombre 'ServiciosTI' -Padre $atlas -Descripcion 'Cuentas administrativas separadas y cuentas de servicio (Tabla 32)'
New-AtlasOU -Nombre 'Grupos' -Padre $dn -Descripcion 'Grupos de seguridad de ATLAS (§29.2, DEC-R1)'

Write-AtlasPaso 'Grupos de seguridad globales (§29.2)'
$grupos = "OU=Grupos,$dn"
foreach ($g in @(
        @{ N = 'GG_Administracion'; D = 'Personal de administración (VLAN 10)' }
        @{ N = 'GG_Docentes'; D = 'Docentes (VLAN 20). En Linux: solo web (Tabla 36)' }
        @{ N = 'GG_Estudiantes'; D = 'Estudiantes (VLAN 30). En Linux: solo web (Tabla 36)' }
        @{ N = 'GG_SoporteTI'; D = 'Soporte TI. En atlas-srv01 = atlas-admin (Tabla 36)' })) {
    if (-not (Get-ADGroup -Filter "Name -eq '$($g.N)'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $g.N -SamAccountName $g.N -GroupCategory Security -GroupScope Global -Path $grupos -Description $g.D
        Write-Host "   + $($g.N)"
    }
}

Write-AtlasPaso 'Cuenta de servicio de respaldos svc_atlas_backup (CT-09)'
$servicios = "OU=ServiciosTI,$atlas"
if (-not (Get-ADUser -Filter "SamAccountName -eq 'svc_atlas_backup'" -ErrorAction SilentlyContinue)) {
    $clave = Get-AtlasContrasenaAleatoria -Largo 32
    New-ADUser -Name 'svc_atlas_backup' -SamAccountName 'svc_atlas_backup' -UserPrincipalName "svc_atlas_backup@$($p.Dominio)" `
        -Path $servicios -Description 'Respaldos de atlas-srv01 hacia \\atlas-dc01\atlas-backups (solo crear archivos, CT-05)' `
        -AccountPassword (ConvertTo-AtlasSecureString -Texto $clave) -Enabled $true `
        -PasswordNeverExpires $true -CannotChangePassword $true
    Write-Host ''
    Write-Host '   ┌──────────────────────────────────────────────────────────────────┐'
    Write-Host '   │ svc_atlas_backup — contraseña (se muestra SOLO esta vez):          │'
    Write-Host "   │ $clave"
    Write-Host '   │ Va en atlas-srv01 en el archivo de credenciales de respaldo (Fase 12).│'
    Write-Host '   └──────────────────────────────────────────────────────────────────┘'
    Write-AtlasAviso 'Excepción a la Tabla 32 (vencimiento a 90 días): cuenta de servicio sin inicio de sesión interactivo (se le niega en GPO_Seguridad_Base).'
}

Write-AtlasPaso 'Delegación acotada a GG_SoporteTI (Tabla 32)'
$soporte = "$($p.NetBIOS)\GG_SoporteTI"
function Invoke-AtlasDsacl {
    param([string[]]$Argumentos)
    & dsacls.exe @Argumentos | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "dsacls falló: $Argumentos" }
}
# Crear/borrar usuarios y equipos en OU=ATLAS y sus sub-OU; control sobre esos objetos.
Invoke-AtlasDsacl -Argumentos @($atlas, '/I:T', '/G', "${soporte}:CCDC;user", "${soporte}:CCDC;computer")
Invoke-AtlasDsacl -Argumentos @($atlas, '/I:S', '/G', "${soporte}:GA;;user", "${soporte}:GA;;computer")
# Cambiar miembros de los grupos de OU=Grupos (no crearlos ni borrarlos).
Invoke-AtlasDsacl -Argumentos @($grupos, '/I:S', '/G', "${soporte}:WP;member;group")
Write-Host "   GG_SoporteTI: usuarios y equipos de OU=ATLAS + miembros de OU=Grupos. Sin Domain Admins."

Write-AtlasPaso 'Listo. Siguiente: 04-politicas-seguridad.ps1'
