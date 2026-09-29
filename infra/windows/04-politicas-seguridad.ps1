<#
.SYNOPSIS
    ATLAS · Fase 7 · Paso 4 — Seguridad del dominio: GPO_Seguridad_Base y GPO_Auditoria.
.DESCRIPTION
    PDF Tabla 32 y Tabla 33:
      · Contraseñas: mínimo 10, complejidad, historial 5, vencen a los 90 días.
      · Bloqueo: 5 intentos fallidos → 15 minutos.
      · Cuentas por defecto: Administrator renombrada, Guest deshabilitada.
      · Auditoría: inicios de sesión, cambios en el directorio y acceso a recursos.
    GPO_Seguridad_Base (todo el dominio, orden 1): contraseñas, bloqueo, cuentas
    por defecto y auditoría de inicios de sesión y de cuentas.
    GPO_Auditoria (todo el dominio): registro detallado (cambios en el directorio,
    recursos compartidos, cambios de directivas, uso de privilegios, sistema) y
    tamaño del registro de seguridad.
    Las dos usan la auditoría AVANZADA (subcategorías) sin repetir ninguna, así se
    combinan sin pisarse.
#>
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\AtlasComun.psm1" -Force
Import-Module ActiveDirectory, GroupPolicy
Assert-AtlasAdministrador
$p = Import-AtlasParametro
$dom = $p.Dominio

Write-AtlasPaso "Cuentas por defecto: Administrator → $($p.NombreAdministrador), Guest deshabilitada"
$admin = Get-ADUser -Identity "$((Get-ADDomain).DomainSID)-500"
if ($admin.SamAccountName -ne $p.NombreAdministrador -and $PSCmdlet.ShouldProcess($admin.SamAccountName, 'Renombrar')) {
    Set-ADUser -Identity $admin -SamAccountName $p.NombreAdministrador -UserPrincipalName "$($p.NombreAdministrador)@$dom" `
        -Description 'Cuenta integrada de administración: SOLO emergencias (Tabla 32)'
    Rename-ADObject -Identity $admin.DistinguishedName -NewName $p.NombreAdministrador
}
Disable-ADAccount -Identity "$((Get-ADDomain).DomainSID)-501"
$svc = (Get-ADUser -Identity 'svc_atlas_backup').SID.Value

Write-AtlasPaso 'GPO_Seguridad_Base (Tabla 33: todo el dominio)'
New-AtlasGpo -Nombre 'GPO_Seguridad_Base' -Comentario 'ATLAS Tabla 32/33: contraseñas, bloqueo, cuentas por defecto, auditoría de inicios de sesión' `
    -Destinos $p.DN -Orden 1 | Out-Null
$plantilla = @"
[Unicode]
Unicode=yes
[System Access]
MinimumPasswordAge = 1
MaximumPasswordAge = 90
MinimumPasswordLength = 10
PasswordComplexity = 1
PasswordHistorySize = 5
ClearTextPassword = 0
LockoutBadCount = 5
ResetLockoutCount = 15
LockoutDuration = 15
NewAdministratorName = "$($p.NombreAdministrador)"
EnableGuestAccount = 0
[Privilege Rights]
SeDenyInteractiveLogonRight = *$svc
SeDenyRemoteInteractiveLogonRight = *$svc
[Registry Values]
MACHINE\System\CurrentControlSet\Control\Lsa\SCENoApplyLegacyAuditPolicy=4,1
[Version]
signature="`$CHICAGO`$"
Revision=1
"@
Set-AtlasPlantillaSeguridad -NombreGpo 'GPO_Seguridad_Base' -Dominio $dom -Contenido $plantilla
Set-AtlasAuditoriaAvanzada -NombreGpo 'GPO_Seguridad_Base' -Dominio $dom -Subcategorias @(
    [pscustomobject]@{ Nombre = 'Credential Validation';              Guid = '{0cce923f-69ae-11d9-bed3-505054503030}'; Valor = 3 }
    [pscustomobject]@{ Nombre = 'Kerberos Authentication Service';    Guid = '{0cce9242-69ae-11d9-bed3-505054503030}'; Valor = 3 }
    [pscustomobject]@{ Nombre = 'Kerberos Service Ticket Operations'; Guid = '{0cce9240-69ae-11d9-bed3-505054503030}'; Valor = 3 }
    [pscustomobject]@{ Nombre = 'Logon';                              Guid = '{0cce9215-69ae-11d9-bed3-505054503030}'; Valor = 3 }
    [pscustomobject]@{ Nombre = 'Logoff';                             Guid = '{0cce9216-69ae-11d9-bed3-505054503030}'; Valor = 1 }
    [pscustomobject]@{ Nombre = 'Account Lockout';                    Guid = '{0cce9217-69ae-11d9-bed3-505054503030}'; Valor = 3 }
    [pscustomobject]@{ Nombre = 'Special Logon';                      Guid = '{0cce921b-69ae-11d9-bed3-505054503030}'; Valor = 1 }
    [pscustomobject]@{ Nombre = 'User Account Management';            Guid = '{0cce9235-69ae-11d9-bed3-505054503030}'; Valor = 3 }
    [pscustomobject]@{ Nombre = 'Computer Account Management';        Guid = '{0cce9236-69ae-11d9-bed3-505054503030}'; Valor = 3 }
    [pscustomobject]@{ Nombre = 'Security Group Management';          Guid = '{0cce9237-69ae-11d9-bed3-505054503030}'; Valor = 3 }
)

Write-AtlasPaso 'GPO_Auditoria (Tabla 33: todo el dominio, registro detallado)'
New-AtlasGpo -Nombre 'GPO_Auditoria' -Comentario 'ATLAS Tabla 33: registro detallado de eventos' -Destinos $p.DN | Out-Null
Set-AtlasPlantillaSeguridad -NombreGpo 'GPO_Auditoria' -Dominio $dom -Contenido @"
[Unicode]
Unicode=yes
[Security Log]
MaximumLogSize = 524288
AuditLogRetentionPeriod = 0
RestrictGuestAccess = 1
[System Log]
MaximumLogSize = 65536
[Version]
signature="`$CHICAGO`$"
Revision=1
"@
Set-AtlasAuditoriaAvanzada -NombreGpo 'GPO_Auditoria' -Dominio $dom -Subcategorias @(
    [pscustomobject]@{ Nombre = 'Directory Service Access';       Guid = '{0cce923b-69ae-11d9-bed3-505054503030}'; Valor = 2 }
    [pscustomobject]@{ Nombre = 'Directory Service Changes';      Guid = '{0cce923c-69ae-11d9-bed3-505054503030}'; Valor = 1 }
    [pscustomobject]@{ Nombre = 'File Share';                     Guid = '{0cce9224-69ae-11d9-bed3-505054503030}'; Valor = 3 }
    [pscustomobject]@{ Nombre = 'Detailed File Share';            Guid = '{0cce9244-69ae-11d9-bed3-505054503030}'; Valor = 2 }
    [pscustomobject]@{ Nombre = 'Other Account Management Events';Guid = '{0cce923a-69ae-11d9-bed3-505054503030}'; Valor = 1 }
    [pscustomobject]@{ Nombre = 'Audit Policy Change';            Guid = '{0cce922f-69ae-11d9-bed3-505054503030}'; Valor = 3 }
    [pscustomobject]@{ Nombre = 'Authentication Policy Change';   Guid = '{0cce9230-69ae-11d9-bed3-505054503030}'; Valor = 1 }
    [pscustomobject]@{ Nombre = 'Sensitive Privilege Use';        Guid = '{0cce9228-69ae-11d9-bed3-505054503030}'; Valor = 3 }
    [pscustomobject]@{ Nombre = 'Security State Change';          Guid = '{0cce9210-69ae-11d9-bed3-505054503030}'; Valor = 1 }
    [pscustomobject]@{ Nombre = 'Security System Extension';      Guid = '{0cce9211-69ae-11d9-bed3-505054503030}'; Valor = 1 }
    [pscustomobject]@{ Nombre = 'System Integrity';               Guid = '{0cce9212-69ae-11d9-bed3-505054503030}'; Valor = 3 }
    [pscustomobject]@{ Nombre = 'Process Creation';               Guid = '{0cce922b-69ae-11d9-bed3-505054503030}'; Valor = 1 }
)

# "Cambios en el directorio" (Tabla 32): además de la subcategoría, AD necesita una
# entrada de auditoría (SACL) en el dominio para registrar los cambios (evento 5136).
Write-AtlasPaso 'SACL del dominio: registrar cambios de objetos (evento 5136)'
$rutaAd = "AD:\$($p.DN)"
$acl = Get-Acl -Path $rutaAd -Audit
$todos = New-Object Security.Principal.SecurityIdentifier('S-1-1-0')   # "Todos", independiente del idioma
$derechos = [DirectoryServices.ActiveDirectoryRights]'WriteProperty, CreateChild, DeleteChild, Delete'
$yaEsta = $acl.GetAuditRules($true, $false, [Security.Principal.SecurityIdentifier]) |
    Where-Object { $_.IdentityReference -eq $todos -and ($_.ActiveDirectoryRights -band $derechos) -eq $derechos }
if (-not $yaEsta -and $PSCmdlet.ShouldProcess($p.DN, 'Agregar SACL')) {
    $regla = New-Object DirectoryServices.ActiveDirectoryAuditRule($todos, $derechos,
        [Security.AccessControl.AuditFlags]::Success, [DirectoryServices.ActiveDirectorySecurityInheritance]::All)
    $acl.AddAuditRule($regla)
    Set-Acl -Path $rutaAd -AclObject $acl
}

Write-AtlasPaso 'Aplicar ahora en este DC'
& gpupdate.exe /force | Out-Null
& auditpol.exe /get /category:* | Select-String -Pattern 'Logon|Inicio de sesi|Directory Service Changes|Cambios de servicio de directorio'
Write-AtlasPaso 'Listo. Siguiente: 05-dns.ps1'
