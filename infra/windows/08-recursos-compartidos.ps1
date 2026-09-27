<#
.SYNOPSIS
    ATLAS · Fase 7 · Paso 8 — Carpetas compartidas en atlas-dc01.
.DESCRIPTION
    \\atlas-dc01\estudiantes (DEC-08): unidad S: de GPO_Estudiantes. Cada estudiante
        crea su carpeta y solo el dueño la modifica; enumeración por acceso.
    \\atlas-dc01\atlas-backups (DEC-R2, CT-05, CT-09): destino de los respaldos de
        atlas-srv01 (criterio 3-2-1, §28.5). svc_atlas_backup puede CREAR archivos,
        pero NO borrarlos ni cambiar sus permisos: si alguien toma el servidor Linux,
        no puede eliminar las copias externas. La retención (borrar lo viejo) la hace
        una tarea programada del DC (Fase 12).
    Los permisos se asignan por SID o por nombre de grupo del dominio, sin depender
    del idioma de Windows.
#>
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\AtlasComun.psm1" -Force
Import-Module ActiveDirectory, SmbShare
Assert-AtlasAdministrador
$p = Import-AtlasParametro
$nb = $p.NetBIOS

function ConvertTo-AtlasSid([string]$Sid) { New-Object Security.Principal.SecurityIdentifier($Sid) }
$sidAdmins = ConvertTo-AtlasSid 'S-1-5-32-544'      # BUILTIN\Administradores
$sidSystem = ConvertTo-AtlasSid 'S-1-5-18'          # SYSTEM
$sidCreador = ConvertTo-AtlasSid 'S-1-3-0'          # CREATOR OWNER
$sidPropietario = ConvertTo-AtlasSid 'S-1-3-4'      # OWNER RIGHTS
function Get-AtlasSid([string]$Nombre) { ConvertTo-AtlasSid (Get-ADObject -Filter "SamAccountName -eq '$Nombre'" -Properties objectSid).objectSid.Value }

function Get-AtlasReglaAcceso {
    param($Sid, [Security.AccessControl.FileSystemRights]$Derechos, [string]$Aplica)
    $herencia, $propagacion = switch ($Aplica) {
        'CarpetaSubcarpetasArchivos' { 'ContainerInherit, ObjectInherit', 'None' }
        'SoloCarpeta'                { 'None', 'None' }
        'CarpetaYSubcarpetas'        { 'ContainerInherit', 'None' }
        'SoloSubcarpetasYArchivos'   { 'ContainerInherit, ObjectInherit', 'InheritOnly' }
        'SoloArchivos'               { 'ObjectInherit', 'InheritOnly' }
    }
    New-Object Security.AccessControl.FileSystemAccessRule($Sid, $Derechos, $herencia, $propagacion, 'Allow')
}

function Set-AtlasPermisoCarpeta {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Ruta, [object[]]$Reglas)
    if (-not $PSCmdlet.ShouldProcess($Ruta, 'Set-Acl')) { return }
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)       # sin herencia de C:\
    $acl.SetOwner($sidAdmins)
    foreach ($r in $Reglas) { $acl.AddAccessRule($r) }
    Set-Acl -Path $Ruta -AclObject $acl
}

New-Item -ItemType Directory -Path $p.CarpetaBase -Force | Out-Null

# --- estudiantes ---------------------------------------------------------------
Write-AtlasPaso "\\$($p.NombreEquipo)\estudiantes (DEC-08)"
$rEst = Join-Path $p.CarpetaBase 'estudiantes'
New-Item -ItemType Directory -Path $rEst -Force | Out-Null
Set-AtlasPermisoCarpeta -Ruta $rEst -Reglas @(
    (Get-AtlasReglaAcceso -Sid $sidAdmins -Derechos 'FullControl' -Aplica 'CarpetaSubcarpetasArchivos')
    (Get-AtlasReglaAcceso -Sid $sidSystem -Derechos 'FullControl' -Aplica 'CarpetaSubcarpetasArchivos')
    (Get-AtlasReglaAcceso -Sid (Get-AtlasSid 'GG_SoporteTI') -Derechos 'Modify' -Aplica 'CarpetaSubcarpetasArchivos')
    # Cada estudiante ve la raíz y puede crear SU carpeta…
    (Get-AtlasReglaAcceso -Sid (Get-AtlasSid 'GG_Estudiantes') -Derechos 'ReadAndExecute, CreateDirectories' -Aplica 'SoloCarpeta')
    # …y dentro de lo que crea tiene control de modificación (no sobre lo de otros).
    (Get-AtlasReglaAcceso -Sid $sidCreador -Derechos 'Modify' -Aplica 'SoloSubcarpetasYArchivos')
)
if (-not (Get-SmbShare -Name 'estudiantes' -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name 'estudiantes' -Path $rEst -FolderEnumerationMode AccessBased `
        -FullAccess "$nb\GG_SoporteTI" -ChangeAccess "$nb\GG_Estudiantes" `
        -Description 'Unidad S: de estudiantes (GPO_Estudiantes)' | Out-Null
}

# --- atlas-backups -------------------------------------------------------------
Write-AtlasPaso "\\$($p.NombreEquipo)\atlas-backups (CT-05: crear sí, borrar no)"
$rBkp = Join-Path $p.CarpetaBase 'atlas-backups'
New-Item -ItemType Directory -Path $rBkp -Force | Out-Null
foreach ($sub in 'completo', 'incremental', 'configuracion') { New-Item -ItemType Directory -Path (Join-Path $rBkp $sub) -Force | Out-Null }
$svc = Get-AtlasSid 'svc_atlas_backup'
Set-AtlasPermisoCarpeta -Ruta $rBkp -Reglas @(
    (Get-AtlasReglaAcceso -Sid $sidAdmins -Derechos 'FullControl' -Aplica 'CarpetaSubcarpetasArchivos')
    (Get-AtlasReglaAcceso -Sid $sidSystem -Derechos 'FullControl' -Aplica 'CarpetaSubcarpetasArchivos')
    # En las carpetas: listar, crear archivos y subcarpetas. Sin "Eliminar subcarpetas y archivos".
    (Get-AtlasReglaAcceso -Sid $svc -Derechos 'ListDirectory, CreateFiles, CreateDirectories, ReadAttributes, ReadExtendedAttributes, Traverse, ReadPermissions' -Aplica 'CarpetaYSubcarpetas')
    # En los archivos que crea: escribir su contenido. Sin "Eliminar", sin cambiar permisos ni dueño.
    (Get-AtlasReglaAcceso -Sid $sidCreador -Derechos 'ReadData, WriteData, AppendData, ReadAttributes, WriteAttributes, ReadExtendedAttributes, WriteExtendedAttributes, ReadPermissions' -Aplica 'SoloArchivos')
    # OWNER RIGHTS quita al dueño el permiso implícito de cambiar la ACL de sus archivos.
    (Get-AtlasReglaAcceso -Sid $sidPropietario -Derechos 'ReadPermissions' -Aplica 'CarpetaSubcarpetasArchivos')
)
if (-not (Get-SmbShare -Name 'atlas-backups' -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name 'atlas-backups' -Path $rBkp -FolderEnumerationMode AccessBased -EncryptData $true `
        -FullAccess $sidAdmins.Translate([Security.Principal.NTAccount]).Value -ChangeAccess "$nb\svc_atlas_backup" `
        -Description 'Copia externa de respaldos de atlas-srv01 (§28.5, 3-2-1)' | Out-Null
}

Write-AtlasPaso 'Comprobación'
Get-SmbShare -Name estudiantes, atlas-backups | Format-Table Name, Path, FolderEnumerationMode, EncryptData -AutoSize
(Get-Acl $rBkp).Access | Format-Table IdentityReference, FileSystemRights, InheritanceFlags, PropagationFlags -AutoSize
Write-AtlasPaso 'Listo. Siguiente: 09-ca-atlas.ps1'
