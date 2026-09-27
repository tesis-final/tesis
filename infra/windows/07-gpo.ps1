<#
.SYNOPSIS
    ATLAS · Fase 7 · Paso 7 — GPO por unidad organizativa (Tabla 33).
.DESCRIPTION
    GPO_Estudiantes (OU Estudiantes): no pueden instalar software; unidad de red mapeada
        S: → \\atlas-dc01\estudiantes (DEC-08: la VLAN 30 no tiene SMB hacia srv01).
    GPO_Docentes (OU Docentes): acceso a recursos compartidos: T: → \\atlas-srv01\docentes.
        Impresoras: fuera de alcance, no hay ninguna en el inventario (DEC-08).
    GPO_Servidores (OU Servidores): endurecimiento y actualizaciones controladas.
        Se vincula también a "Domain Controllers": atlas-dc01 no puede moverse a
        OU=Servidores (Microsoft exige que los DC queden en su OU) y es el único
        servidor Windows. Ver hallazgo H7-02.
    GPO_Seguridad_Base y GPO_Auditoria se crean en el paso 4.
    Las GPO usan claves de directiva del Registro (Set-GPRegistryValue).
#>
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\AtlasComun.psm1" -Force
Import-Module GroupPolicy
Assert-AtlasAdministrador
$p = Import-AtlasParametro
$dom = $p.Dominio
$atlas = "OU=ATLAS,$($p.DN)"

function Set-AtlasValorGpo {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Gpo, [string]$Clave, [string]$Nombre, [int]$Valor)
    if ($PSCmdlet.ShouldProcess($Gpo, "$Clave\$Nombre = $Valor")) {
        Set-GPRegistryValue -Name $Gpo -Key $Clave -ValueName $Nombre -Type DWord -Value $Valor | Out-Null
    }
}

# --- GPO_Estudiantes ---------------------------------------------------------
Write-AtlasPaso 'GPO_Estudiantes'
New-AtlasGpo -Nombre 'GPO_Estudiantes' -Comentario 'ATLAS Tabla 33: sin instalación de software; unidad S: (DEC-08)' `
    -Destinos "OU=Estudiantes,$atlas" | Out-Null
# Windows Installer: prohibido para aplicaciones no administradas (las que distribuya TI por GPO sí).
Set-AtlasValorGpo -Gpo 'GPO_Estudiantes' -Clave 'HKLM\Software\Policies\Microsoft\Windows\Installer' -Nombre 'DisableMSI' -Valor 1
Set-AtlasValorGpo -Gpo 'GPO_Estudiantes' -Clave 'HKLM\Software\Policies\Microsoft\Windows\Installer' -Nombre 'DisableUserInstalls' -Valor 1
# Aplicaciones empaquetadas (Microsoft Store / appx) solo por administradores.
Set-AtlasValorGpo -Gpo 'GPO_Estudiantes' -Clave 'HKLM\Software\Policies\Microsoft\Windows\Appx' -Nombre 'BlockNonAdminUserInstall' -Valor 1
Set-AtlasValorGpo -Gpo 'GPO_Estudiantes' -Clave 'HKLM\Software\Policies\Microsoft\WindowsStore' -Nombre 'RemoveWindowsStore' -Valor 1
Set-AtlasUnidadRed -NombreGpo 'GPO_Estudiantes' -Dominio $dom -Letra $p.UnidadEstudiantes `
    -Ruta "\\$($p.NombreEquipo)\estudiantes" -Etiqueta 'Estudiantes'

# --- GPO_Docentes ------------------------------------------------------------
Write-AtlasPaso 'GPO_Docentes'
New-AtlasGpo -Nombre 'GPO_Docentes' -Comentario 'ATLAS Tabla 33: recurso compartido de docentes (T:). Impresoras fuera de alcance (DEC-08)' `
    -Destinos "OU=Docentes,$atlas" | Out-Null
Set-AtlasUnidadRed -NombreGpo 'GPO_Docentes' -Dominio $dom -Letra $p.UnidadDocentes `
    -Ruta "\\$($p.ServidorLinux.Nombre)\docentes" -Etiqueta 'Docentes'

# --- GPO_Servidores ----------------------------------------------------------
Write-AtlasPaso 'GPO_Servidores'
New-AtlasGpo -Nombre 'GPO_Servidores' -Comentario 'ATLAS Tabla 33: endurecimiento y actualizaciones controladas' `
    -Destinos "OU=Servidores,$atlas", "OU=Domain Controllers,$($p.DN)" | Out-Null
$srv = 'GPO_Servidores'
# SMB: sin SMBv1 y con firma obligatoria (servidor y cliente).
Set-AtlasValorGpo -Gpo $srv -Clave 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Nombre 'SMB1' -Valor 0
Set-AtlasValorGpo -Gpo $srv -Clave 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Nombre 'RequireSecuritySignature' -Valor 1
Set-AtlasValorGpo -Gpo $srv -Clave 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Nombre 'EnableSecuritySignature' -Valor 1
Set-AtlasValorGpo -Gpo $srv -Clave 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' -Nombre 'RequireSecuritySignature' -Valor 1
# Autenticación: solo NTLMv2 y sin guardar hashes LM.
Set-AtlasValorGpo -Gpo $srv -Clave 'HKLM\SYSTEM\CurrentControlSet\Control\Lsa' -Nombre 'LmCompatibilityLevel' -Valor 5
Set-AtlasValorGpo -Gpo $srv -Clave 'HKLM\SYSTEM\CurrentControlSet\Control\Lsa' -Nombre 'NoLMHash' -Valor 1
# LDAP firmado (el DC rechaza enlaces LDAP sin firma).
Set-AtlasValorGpo -Gpo $srv -Clave 'HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Parameters' -Nombre 'LDAPServerIntegrity' -Valor 2
# Sin resolución de nombres por multidifusión (LLMNR), un vector común de robo de credenciales.
Set-AtlasValorGpo -Gpo $srv -Clave 'HKLM\Software\Policies\Microsoft\Windows NT\DNSClient' -Nombre 'EnableMulticast' -Valor 0
# Escritorio remoto: solo con autenticación a nivel de red (NLA) y cifrado alto.
Set-AtlasValorGpo -Gpo $srv -Clave 'HKLM\Software\Policies\Microsoft\Windows NT\Terminal Services' -Nombre 'UserAuthentication' -Valor 1
Set-AtlasValorGpo -Gpo $srv -Clave 'HKLM\Software\Policies\Microsoft\Windows NT\Terminal Services' -Nombre 'SecurityLayer' -Valor 2
Set-AtlasValorGpo -Gpo $srv -Clave 'HKLM\Software\Policies\Microsoft\Windows NT\Terminal Services' -Nombre 'MinEncryptionLevel' -Valor 3
# Actualizaciones controladas: se descargan y se avisa; se instalan en ventana de mantenimiento.
Set-AtlasValorGpo -Gpo $srv -Clave 'HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU' -Nombre 'NoAutoUpdate' -Valor 0
Set-AtlasValorGpo -Gpo $srv -Clave 'HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU' -Nombre 'AUOptions' -Valor 3
Set-AtlasValorGpo -Gpo $srv -Clave 'HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU' -Nombre 'NoAutoRebootWithLoggedOnUsers' -Valor 1

Write-AtlasPaso 'Resumen de vínculos'
foreach ($t in @($p.DN, "OU=Estudiantes,$atlas", "OU=Docentes,$atlas", "OU=Servidores,$atlas", "OU=Domain Controllers,$($p.DN)")) {
    $v = (Get-GPInheritance -Target $t).GpoLinks | ForEach-Object DisplayName
    Write-Host "   $t → $($v -join ', ')"
}
& gpupdate.exe /force | Out-Null
Write-AtlasPaso 'Listo. Siguiente: 08-recursos-compartidos.ps1'
