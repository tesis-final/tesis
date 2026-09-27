<#
.SYNOPSIS
    ATLAS · Fase 7 · Paso 12 — Cuentas del dominio a partir de un CSV.
.DESCRIPTION
    Crea cada cuenta en la OU de su perfil (§29.2) y la agrega a su grupo:
        Administracion → OU=Usuarios,OU=Administracion  + GG_Administracion
        Docentes       → OU=Usuarios,OU=Docentes        + GG_Docentes
        Estudiantes    → OU=Usuarios,OU=Estudiantes     + GG_Estudiantes
        SoporteTI      → cuenta de uso diario en OU=Usuarios,OU=Administracion
                         + cuenta administrativa SEPARADA adm.<usuario> en OU=ServiciosTI
                           con GG_SoporteTI (Tabla 32: "cuentas administrativas separadas")
    Cada cuenta recibe una contraseña inicial aleatoria y debe cambiarla al entrar.
    Las contraseñas iniciales se guardan en un CSV que solo pueden leer los
    administradores: entregarlas y BORRAR ese archivo.
    Ojo: estas son cuentas del DOMINIO (iniciar sesión en Windows, carpetas). Las
    cuentas de la plataforma ATLAS se crean en ATLAS (RF-01) y son independientes (§28.2).
.PARAMETER Csv
    Archivo separado por ';' con columnas Usuario;Nombre;Apellido;Perfil (UTF-8).
.EXAMPLE
    .\12-usuarios.ps1 -Csv .\usuarios-ejemplo.csv
#>
[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][ValidateScript({ Test-Path $_ })][string]$Csv)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\AtlasComun.psm1" -Force
Import-Module ActiveDirectory
Assert-AtlasAdministrador
$p = Import-AtlasParametro
$atlas = "OU=ATLAS,$($p.DN)"
$destino = @{
    Administracion = @{ OU = "OU=Usuarios,OU=Administracion,$atlas"; Grupo = 'GG_Administracion' }
    Docentes       = @{ OU = "OU=Usuarios,OU=Docentes,$atlas"; Grupo = 'GG_Docentes' }
    Estudiantes    = @{ OU = "OU=Usuarios,OU=Estudiantes,$atlas"; Grupo = 'GG_Estudiantes' }
    SoporteTI      = @{ OU = "OU=Usuarios,OU=Administracion,$atlas"; Grupo = 'GG_Administracion' }
}
$credenciales = New-Object System.Collections.Generic.List[object]

function New-AtlasCuenta {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Sam, [string]$Nombre, [string]$Apellido, [string]$OU, [string]$Grupo, [string]$Descripcion)
    if (Get-ADUser -Filter "SamAccountName -eq '$Sam'" -ErrorAction SilentlyContinue) {
        Write-Host "   = $Sam ya existe"; return
    }
    $clave = Get-AtlasContrasenaAleatoria -Largo 16
    if ($PSCmdlet.ShouldProcess($Sam, "Crear en $OU")) {
        New-ADUser -Name "$Nombre $Apellido ($Sam)" -GivenName $Nombre -Surname $Apellido -SamAccountName $Sam `
            -UserPrincipalName "$Sam@$($p.Dominio)" -DisplayName "$Nombre $Apellido" -Path $OU -Description $Descripcion `
            -AccountPassword (ConvertTo-AtlasSecureString -Texto $clave) -Enabled $true -ChangePasswordAtLogon $true
        Add-ADGroupMember -Identity $Grupo -Members $Sam
        $credenciales.Add([pscustomobject]@{ Usuario = $Sam; ContrasenaInicial = $clave; Grupo = $Grupo })
        Write-Host "   + $Sam → $Grupo"
    }
}

Write-AtlasPaso "Cuentas desde $Csv"
foreach ($f in Import-Csv -Path $Csv -Delimiter ';' -Encoding UTF8) {
    if (-not $destino.ContainsKey($f.Perfil)) { Write-AtlasAviso "Perfil desconocido '$($f.Perfil)' para $($f.Usuario): se omite."; continue }
    $d = $destino[$f.Perfil]
    New-AtlasCuenta -Sam $f.Usuario -Nombre $f.Nombre -Apellido $f.Apellido -OU $d.OU -Grupo $d.Grupo -Descripcion "Cuenta de uso diario ($($f.Perfil))"
    if ($f.Perfil -eq 'SoporteTI') {
        New-AtlasCuenta -Sam "adm.$($f.Usuario)" -Nombre $f.Nombre -Apellido $f.Apellido -OU "OU=ServiciosTI,$atlas" `
            -Grupo 'GG_SoporteTI' -Descripcion 'Cuenta ADMINISTRATIVA separada (Tabla 32). No usar para el trabajo diario'
    }
}

if ($credenciales.Count -gt 0) {
    $archivo = Join-Path $p.CarpetaBase ("credenciales-iniciales-{0:yyyyMMdd-HHmm}.csv" -f (Get-Date))
    $credenciales | Export-Csv -Path $archivo -Delimiter ';' -NoTypeInformation -Encoding UTF8
    $acl = New-Object Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true, $false)
    $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')), 'FullControl', 'Allow')))
    Set-Acl -Path $archivo -AclObject $acl
    Write-AtlasAviso "Contraseñas iniciales en $archivo (solo administradores). Entregarlas y BORRAR el archivo."
}
Write-AtlasPaso 'Listo. Verificar con: .\verificar-dc01.ps1'
