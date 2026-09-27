# =============================================================================
# ATLAS — funciones comunes de los scripts de atlas-dc01 (Fase 7).
# Se importa desde cada script:  Import-Module "$PSScriptRoot\AtlasComun.psm1" -Force
# =============================================================================
Set-StrictMode -Version Latest

function Write-AtlasPaso {
    # Write-Host a propósito: son mensajes para quien ejecuta el script, no datos.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    param([Parameter(Mandatory)][string]$Mensaje)
    Write-Host "==> $Mensaje" -ForegroundColor Green
}

function Write-AtlasAviso {
    param([Parameter(Mandatory)][string]$Mensaje)
    Write-Warning $Mensaje
}

function Import-AtlasParametro {
    <#
    .SYNOPSIS Lee parametros.psd1 (valores del PDF, sin contraseñas).
    #>
    [OutputType([hashtable])]
    param([string]$Ruta = (Join-Path $PSScriptRoot 'parametros.psd1'))
    Import-PowerShellDataFile -Path $Ruta
}

function Assert-AtlasAdministrador {
    $identidad = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identidad)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Abrir PowerShell como administrador.'
    }
}

function ConvertTo-AtlasSecureString {
    <#
    .SYNOPSIS Pasa un texto generado en memoria a SecureString (sin ConvertTo-SecureString -AsPlainText).
    #>
    [OutputType([securestring])]
    param([Parameter(Mandatory)][string]$Texto)
    $seguro = New-Object Security.SecureString
    foreach ($c in $Texto.ToCharArray()) { $seguro.AppendChar($c) }
    $seguro.MakeReadOnly()
    $seguro
}

function Get-AtlasContrasenaAleatoria {
    <#
    .SYNOPSIS Contraseña aleatoria que cumple la complejidad de la Tabla 32.
    #>
    [OutputType([string])]
    param([int]$Largo = 20)
    $grupos = @('ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnopqrstuvwxyz', '23456789', '!#%+-=?@_')
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] ($Largo)
    $rng.GetBytes($bytes)
    $todos = -join $grupos
    $chars = for ($i = 0; $i -lt $Largo; $i++) { $todos[$bytes[$i] % $todos.Length] }
    # Garantiza al menos un carácter de cada grupo.
    for ($g = 0; $g -lt $grupos.Count; $g++) { $chars[$g] = $grupos[$g][$bytes[$g] % $grupos[$g].Length] }
    -join ($chars | Sort-Object { Get-Random })
}

function Get-AtlasRutaGpo {
    <#
    .SYNOPSIS Carpeta de la GPO en SYSVOL.
    #>
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$NombreGpo, [Parameter(Mandatory)][string]$Dominio)
    $gpo = Get-GPO -Name $NombreGpo -ErrorAction Stop
    "\\$Dominio\SYSVOL\$Dominio\Policies\{$($gpo.Id)}"
}

function Add-AtlasExtensionGpo {
    <#
    .SYNOPSIS Registra en la GPO las extensiones del lado cliente (CSE) que procesan
              los archivos que escribimos a mano en SYSVOL (GptTmpl.inf, audit.csv, Drives.xml).
    .DESCRIPTION El atributo gPC(Machine|User)ExtensionNames es una lista de
              [{CSE}{herramienta}...] ordenada por GUID. Se agrega sin borrar lo que ya
              hubiera (por ejemplo, la extensión del Registro que agrega Set-GPRegistryValue).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$NombreGpo,
        [Parameter(Mandatory)][ValidateSet('Machine', 'User')][string]$Ambito,
        [Parameter(Mandatory)][string]$Cse,
        [Parameter(Mandatory)][string[]]$Herramientas
    )
    $gpo = Get-GPO -Name $NombreGpo -ErrorAction Stop
    $dn = "CN={$($gpo.Id)},CN=Policies,CN=System,$((Get-ADDomain).DistinguishedName)"
    $atributo = "gPC${Ambito}ExtensionNames"
    $actual = (Get-ADObject -Identity $dn -Properties $atributo).$atributo

    $mapa = [ordered]@{}
    if ($actual) {
        foreach ($bloque in [regex]::Matches($actual, '\[([^\]]+)\]')) {
            $guids = @([regex]::Matches($bloque.Groups[1].Value, '\{[0-9A-Fa-f-]+\}') | ForEach-Object { $_.Value.ToUpper() })
            $mapa[$guids[0]] = [System.Collections.Generic.List[string]]@($guids | Select-Object -Skip 1)
        }
    }
    $cseU = $Cse.ToUpper()
    if (-not $mapa.Contains($cseU)) { $mapa[$cseU] = [System.Collections.Generic.List[string]]::new() }
    foreach ($h in $Herramientas) { if (-not $mapa[$cseU].Contains($h.ToUpper())) { $mapa[$cseU].Add($h.ToUpper()) } }

    $nuevo = -join ($mapa.Keys | Sort-Object | ForEach-Object {
            '[' + $_ + (-join ($mapa[$_] | Sort-Object)) + ']'
        })
    if ($PSCmdlet.ShouldProcess($NombreGpo, "$atributo = $nuevo")) {
        Set-ADObject -Identity $dn -Replace @{ $atributo = $nuevo }
    }
}

function Step-AtlasVersionGpo {
    <#
    .SYNOPSIS Sube la versión de la GPO (AD y GPT.INI) para que los equipos
              vuelvan a aplicarla. Máquina = 16 bits bajos; Usuario = 16 bits altos.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$NombreGpo,
        [Parameter(Mandatory)][string]$Dominio,
        [Parameter(Mandatory)][ValidateSet('Machine', 'User')][string]$Ambito
    )
    $gpo = Get-GPO -Name $NombreGpo -ErrorAction Stop
    $dn = "CN={$($gpo.Id)},CN=Policies,CN=System,$((Get-ADDomain).DistinguishedName)"
    $version = [int](Get-ADObject -Identity $dn -Properties versionNumber).versionNumber
    $version += $(if ($Ambito -eq 'Machine') { 1 } else { 65536 })
    if ($PSCmdlet.ShouldProcess($NombreGpo, "versionNumber = $version")) {
        Set-ADObject -Identity $dn -Replace @{ versionNumber = $version }
        $ini = Join-Path (Get-AtlasRutaGpo -NombreGpo $NombreGpo -Dominio $Dominio) 'GPT.INI'
        Set-Content -Path $ini -Value "[General]`r`nVersion=$version" -Encoding Ascii
    }
}

function Set-AtlasPlantillaSeguridad {
    <#
    .SYNOPSIS Escribe la plantilla de seguridad (GptTmpl.inf) de una GPO:
              contraseñas, bloqueo, derechos de usuario, registro de eventos.
    .DESCRIPTION Es lo mismo que se configura en la consola GPMC en
              "Configuración del equipo > Directivas > Configuración de Windows >
              Configuración de seguridad", escrito como archivo para que sea
              reproducible. El archivo va en UTF-16 (Unicode), como lo guarda Windows.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$NombreGpo,
        [Parameter(Mandatory)][string]$Dominio,
        [Parameter(Mandatory)][string]$Contenido
    )
    $carpeta = Join-Path (Get-AtlasRutaGpo -NombreGpo $NombreGpo -Dominio $Dominio) 'Machine\Microsoft\Windows NT\SecEdit'
    if ($PSCmdlet.ShouldProcess($NombreGpo, 'GptTmpl.inf')) {
        New-Item -ItemType Directory -Path $carpeta -Force | Out-Null
        Set-Content -Path (Join-Path $carpeta 'GptTmpl.inf') -Value $Contenido -Encoding Unicode
        # Extensión "Configuración de seguridad".
        Add-AtlasExtensionGpo -NombreGpo $NombreGpo -Ambito Machine `
            -Cse '{827D319E-6EAC-11D2-A4EA-00C04F79F83A}' -Herramientas '{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}'
        Step-AtlasVersionGpo -NombreGpo $NombreGpo -Dominio $Dominio -Ambito Machine
    }
}

function Set-AtlasAuditoriaAvanzada {
    <#
    .SYNOPSIS Escribe la directiva de auditoría avanzada (audit.csv) de una GPO.
    .PARAMETER Subcategorias Tabla con Nombre, Guid y Valor (1 = correcto, 2 = error, 3 = ambos).
    .DESCRIPTION Antes de escribir, comprueba con auditpol que cada GUID exista en
              este Windows (así no depende del idioma del sistema).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$NombreGpo,
        [Parameter(Mandatory)][string]$Dominio,
        [Parameter(Mandatory)][object[]]$Subcategorias
    )
    $texto = @{ 1 = 'Success'; 2 = 'Failure'; 3 = 'Success and Failure' }
    $lineas = @('Machine Name,Policy Target,Subcategory,Subcategory GUID,Inclusion Setting,Exclusion Setting,Setting Value')
    foreach ($s in $Subcategorias) {
        & auditpol.exe /get "/subcategory:$($s.Guid)" *> $null
        if ($LASTEXITCODE -ne 0) { throw "auditpol no reconoce la subcategoría $($s.Nombre) $($s.Guid)" }
        $lineas += ",System,Audit $($s.Nombre),$($s.Guid),$($texto[[int]$s.Valor]),,$($s.Valor)"
    }
    $carpeta = Join-Path (Get-AtlasRutaGpo -NombreGpo $NombreGpo -Dominio $Dominio) 'Machine\Microsoft\Windows NT\Audit'
    if ($PSCmdlet.ShouldProcess($NombreGpo, 'audit.csv')) {
        New-Item -ItemType Directory -Path $carpeta -Force | Out-Null
        Set-Content -Path (Join-Path $carpeta 'audit.csv') -Value $lineas -Encoding Ascii
        # Extensión "Configuración de directiva de auditoría avanzada".
        Add-AtlasExtensionGpo -NombreGpo $NombreGpo -Ambito Machine `
            -Cse '{F3CCC681-B74C-4060-9F26-CD84525DCA2A}' -Herramientas '{0F3F3735-573D-9804-99E4-AB2A69BA5FD4}'
        Step-AtlasVersionGpo -NombreGpo $NombreGpo -Dominio $Dominio -Ambito Machine
    }
}

function Set-AtlasUnidadRed {
    <#
    .SYNOPSIS Unidad de red mapeada por Preferencias de directiva de grupo
              (Configuración de usuario > Preferencias > Asignaciones de unidades).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$NombreGpo,
        [Parameter(Mandatory)][string]$Dominio,
        [Parameter(Mandatory)][ValidatePattern('^[D-Z]$')][string]$Letra,
        [Parameter(Mandatory)][string]$Ruta,
        [Parameter(Mandatory)][string]$Etiqueta
    )
    $uid = [guid]::NewGuid().ToString('B').ToUpper()
    $fecha = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $ruta = [Security.SecurityElement]::Escape($Ruta)
    $etiqueta = [Security.SecurityElement]::Escape($Etiqueta)
    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<Drives clsid="{8FDDCC1A-0C3C-43cd-A6B4-71A6DF20DA8C}"><Drive clsid="{935D1B74-9CB8-4e3c-9914-7DD559B7A417}" name="${Letra}:" status="${Letra}:" image="2" changed="$fecha" uid="$uid" bypassErrors="1"><Properties action="U" thisDrive="NOCHANGE" allDrives="NOCHANGE" userName="" path="$ruta" label="$etiqueta" persistent="1" useLetter="1" letter="$Letra"/></Drive></Drives>
"@
    $carpeta = Join-Path (Get-AtlasRutaGpo -NombreGpo $NombreGpo -Dominio $Dominio) 'User\Preferences\Drives'
    if ($PSCmdlet.ShouldProcess($NombreGpo, "Unidad ${Letra}: -> $Ruta")) {
        New-Item -ItemType Directory -Path $carpeta -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $carpeta 'Drives.xml'), $xml, (New-Object Text.UTF8Encoding($false)))
        # Extensión "Asignaciones de unidades" (+ la entrada de herramientas de preferencias).
        Add-AtlasExtensionGpo -NombreGpo $NombreGpo -Ambito User `
            -Cse '{00000000-0000-0000-0000-000000000000}' -Herramientas '{2EA1A81B-48E5-45E9-8BB7-A6E3AC170006}'
        Add-AtlasExtensionGpo -NombreGpo $NombreGpo -Ambito User `
            -Cse '{5794DAFD-BE60-433F-88A2-1A31939AC01F}' -Herramientas '{2EA1A81B-48E5-45E9-8BB7-A6E3AC170006}'
        Step-AtlasVersionGpo -NombreGpo $NombreGpo -Dominio $Dominio -Ambito User
    }
}

function New-AtlasGpo {
    <#
    .SYNOPSIS Crea la GPO si no existe y la vincula a los destinos indicados.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Nombre,
        [Parameter(Mandatory)][string]$Comentario,
        [Parameter(Mandatory)][string[]]$Destinos,
        [int]$Orden = 0
    )
    $gpo = Get-GPO -Name $Nombre -ErrorAction SilentlyContinue
    if (-not $gpo -and $PSCmdlet.ShouldProcess($Nombre, 'New-GPO')) {
        $gpo = New-GPO -Name $Nombre -Comment $Comentario
    }
    foreach ($d in $Destinos) {
        $vinculos = (Get-GPInheritance -Target $d).GpoLinks | Where-Object DisplayName -EQ $Nombre
        if (-not $vinculos -and $PSCmdlet.ShouldProcess($d, "Vincular $Nombre")) {
            if ($Orden -gt 0) { New-GPLink -Name $Nombre -Target $d -LinkEnabled Yes -Order $Orden | Out-Null }
            else { New-GPLink -Name $Nombre -Target $d -LinkEnabled Yes | Out-Null }
        }
    }
    $gpo
}

Export-ModuleMember -Function *-Atlas*
