<#
.SYNOPSIS
    ATLAS · Fase 7 — Pruebas de la lógica del módulo AtlasComun sin Windows Server.
.DESCRIPTION
    Se reemplazan los cmdlets de AD/GPO por dobles de prueba (funciones globales) y se
    comprueba: contraseñas aleatorias (Tabla 32), conversión a SecureString, fusión y
    orden de las extensiones de GPO (gPCMachineExtensionNames / gPCUserExtensionNames),
    y que parametros.psd1 y usuarios-ejemplo.csv se leen bien.
    Uso (PowerShell 7, también en Linux):  pwsh -File infra/windows/pruebas/probar-modulo.ps1
#>
$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $raiz 'AtlasComun.psm1') -Force
$script:ok = 0; $script:mal = 0
function Assert-Atlas([string]$Descripcion, [bool]$Condicion) {
    if ($Condicion) { $script:ok++; "  PASS  $Descripcion" } else { $script:mal++; "  FAIL  $Descripcion" }
}

'[parámetros]'
$p = Import-AtlasParametro -Ruta (Join-Path $raiz 'parametros.psd1')
Assert-Atlas 'parametros.psd1: IP 172.16.40.20 (Tabla 40)' ($p.IP -eq '172.16.40.20')
Assert-Atlas 'parametros.psd1: 3 ámbitos DHCP (Tabla 34)' ($p.Ambitos.Count -eq 3)
Assert-Atlas 'parametros.psd1: VLAN 30 hasta .250' (($p.Ambitos | Where-Object Red -EQ '172.16.30.0').Fin -eq '172.16.30.250')
Assert-Atlas 'parametros.psd1: sin contraseñas' (-not ((Get-Content (Join-Path $raiz 'parametros.psd1') -Raw) -match '(?i)password\s*=|contrase\S*\s*='))
$csv = Import-Csv (Join-Path $raiz 'usuarios-ejemplo.csv') -Delimiter ';'
Assert-Atlas 'usuarios-ejemplo.csv: 4 cuentas de prueba, una por perfil' (($csv.Perfil | Sort-Object -Unique).Count -eq 4)

'[contraseñas]'
$muestras = 1..500 | ForEach-Object { Get-AtlasContrasenaAleatoria -Largo 16 }
Assert-Atlas '500 contraseñas de 16 caracteres' (-not ($muestras | Where-Object Length -NE 16))
Assert-Atlas 'todas con mayúscula, minúscula, dígito y símbolo (complejidad, Tabla 32)' (-not ($muestras | Where-Object { $_ -cnotmatch '[A-Z]' -or $_ -cnotmatch '[a-z]' -or $_ -notmatch '\d' -or $_ -notmatch '[!#%+\-=?@_]' }))
Assert-Atlas 'todas distintas' (($muestras | Sort-Object -Unique).Count -eq 500)
Assert-Atlas 'sin caracteres ambiguos (0, O, 1, l, I)' (-not ($muestras | Where-Object { $_ -cmatch '[0O1lI]' }))
$ss = ConvertTo-AtlasSecureString -Texto 'Prueba-123'
Assert-Atlas 'ConvertTo-AtlasSecureString devuelve SecureString de solo lectura' ($ss -is [securestring] -and $ss.IsReadOnly() -and $ss.Length -eq 10)

'[extensiones de GPO]'
# Dobles de prueba de los cmdlets de AD y GPO.
$global:atributos = @{}
function global:Get-GPO { param($Name) [pscustomobject]@{ Id = [guid]'11111111-2222-3333-4444-555555555555'; DisplayName = $Name } }
function global:Get-ADDomain { [pscustomobject]@{ DistinguishedName = 'DC=atlas,DC=local' } }
function global:Get-ADObject { param($Identity, $Properties) $o = [pscustomobject]@{}; foreach ($a in $Properties) { $o | Add-Member NoteProperty $a $global:atributos[$a] }; $o }
function global:Set-ADObject { param($Identity, $Replace) foreach ($k in $Replace.Keys) { $global:atributos[$k] = $Replace[$k] } }

$reg = '[{35378EAC-683F-11D2-A89A-00C04FBBCFA2}{D02B1F72-3407-48AE-BA88-E8213C6761F1}]'
$sec = '[{827D319E-6EAC-11D2-A4EA-00C04F79F83A}{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}]'
$aud = '[{F3CCC681-B74C-4060-9F26-CD84525DCA2A}{0F3F3735-573D-9804-99E4-AB2A69BA5FD4}]'
$global:atributos['gPCMachineExtensionNames'] = $reg
Add-AtlasExtensionGpo -NombreGpo X -Ambito Machine -Cse '{827d319e-6eac-11d2-a4ea-00c04f79f83a}' -Herramientas '{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}'
Assert-Atlas 'agrega "Seguridad" sin borrar la extensión del Registro' ($global:atributos['gPCMachineExtensionNames'] -eq "$reg$sec")
Add-AtlasExtensionGpo -NombreGpo X -Ambito Machine -Cse '{F3CCC681-B74C-4060-9F26-CD84525DCA2A}' -Herramientas '{0F3F3735-573D-9804-99E4-AB2A69BA5FD4}'
Assert-Atlas 'agrega "Auditoría avanzada" y mantiene el orden por GUID' ($global:atributos['gPCMachineExtensionNames'] -eq "$reg$sec$aud")
Add-AtlasExtensionGpo -NombreGpo X -Ambito Machine -Cse '{827D319E-6EAC-11D2-A4EA-00C04F79F83A}' -Herramientas '{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}'
Assert-Atlas 'es idempotente (volver a correr no duplica)' ($global:atributos['gPCMachineExtensionNames'] -eq "$reg$sec$aud")
$global:atributos['gPCUserExtensionNames'] = $null
Add-AtlasExtensionGpo -NombreGpo X -Ambito User -Cse '{5794DAFD-BE60-433F-88A2-1A31939AC01F}' -Herramientas '{2EA1A81B-48E5-45E9-8BB7-A6E3AC170006}'
Add-AtlasExtensionGpo -NombreGpo X -Ambito User -Cse '{00000000-0000-0000-0000-000000000000}' -Herramientas '{2EA1A81B-48E5-45E9-8BB7-A6E3AC170006}'
Assert-Atlas 'unidades de red: {00000000…} primero, como lo guarda la consola GPMC' ($global:atributos['gPCUserExtensionNames'] -eq '[{00000000-0000-0000-0000-000000000000}{2EA1A81B-48E5-45E9-8BB7-A6E3AC170006}][{5794DAFD-BE60-433F-88A2-1A31939AC01F}{2EA1A81B-48E5-45E9-8BB7-A6E3AC170006}]')

'[verificador: auditoría en un Windows en español (Hito 2 de Redes, 7.4)]'
$es = @(
    '',
    'Nombre de equipo,Destino de directiva,Subcategoría,GUID de subcategoría,Configuración de inclusión,Configuración de exclusión',
    'ATLAS-DC01,Sistema,Inicio de sesión,{0CCE9215-69AE-11D9-BED3-505054503030},Aciertos y errores,',
    'ATLAS-DC01,Sistema,Cambios de servicio de directorio,{0CCE923C-69AE-11D9-BED3-505054503030},Aciertos,',
    'ATLAS-DC01,Sistema,Recurso compartido de archivos,{0CCE9224-69AE-11D9-BED3-505054503030},Aciertos y errores,',
    'ATLAS-DC01,Sistema,Administración de cuentas de usuario,{0CCE9235-69AE-11D9-BED3-505054503030},Aciertos y errores,',
    'ATLAS-DC01,Sistema,Sistema de archivos,{0CCE921D-69AE-11D9-BED3-505054503030},Sin auditoría,'
)
$en = @(
    'Machine Name,Policy Target,Subcategory,Subcategory GUID,Inclusion Setting,Exclusion Setting',
    'ATLAS-DC01,System,Logon,{0CCE9215-69AE-11D9-BED3-505054503030},Success and Failure,',
    'ATLAS-DC01,System,File System,{0CCE921D-69AE-11D9-BED3-505054503030},No Auditing,'
)
# Lectura anterior (por nombre de columna en inglés): reproduce la falla del laboratorio.
$anterior = $es | ConvertFrom-Csv
Assert-Atlas 'la lectura anterior no encuentra nada en el CSV en español (falla reproducida)' (-not ($anterior | Where-Object { $_.'Subcategory GUID' }))
$t = ConvertFrom-AtlasAuditpol -Lineas $es
Assert-Atlas 'español: Inicio de sesión auditado' ($t['{0CCE9215-69AE-11D9-BED3-505054503030}'] -eq $true)
Assert-Atlas 'español: "Aciertos" solo también cuenta como auditado' ($t['{0CCE923C-69AE-11D9-BED3-505054503030}'] -eq $true)
Assert-Atlas 'español: Recurso compartido y Cuentas de usuario auditados' ($t['{0CCE9224-69AE-11D9-BED3-505054503030}'] -and $t['{0CCE9235-69AE-11D9-BED3-505054503030}'])
Assert-Atlas 'español: "Sin auditoría" da falso' ($t['{0CCE921D-69AE-11D9-BED3-505054503030}'] -eq $false)
$t = ConvertFrom-AtlasAuditpol -Lineas $en
Assert-Atlas 'inglés: Logon auditado y "No Auditing" falso' ($t['{0CCE9215-69AE-11D9-BED3-505054503030}'] -and -not $t['{0CCE921D-69AE-11D9-BED3-505054503030}'])

'[verificador: escritorio remoto solo desde la VLAN 50 (Hito 2 de Redes, 7.4)]'
Assert-Atlas 'acepta la red como la devuelve Windows (172.16.50.0/255.255.255.0)' (Test-AtlasSoloDesdeRed -Direcciones @('172.16.50.0/255.255.255.0') -Red '172.16.50.0/24')
Assert-Atlas 'acepta la red escrita como /24' (Test-AtlasSoloDesdeRed -Direcciones @('172.16.50.0/24') -Red '172.16.50.0/24')
Assert-Atlas 'rechaza una regla abierta a cualquiera (Any)' (-not (Test-AtlasSoloDesdeRed -Direcciones @('Any') -Red '172.16.50.0/24'))
Assert-Atlas 'rechaza la VLAN 50 más otra red' (-not (Test-AtlasSoloDesdeRed -Direcciones @('172.16.50.0/24', '172.16.20.0/24') -Red '172.16.50.0/24'))
Assert-Atlas 'rechaza una regla sin direcciones' (-not (Test-AtlasSoloDesdeRed -Direcciones @() -Red '172.16.50.0/24'))

'[retención de atlas-backups en el DC (Tabla 29: 28 días / 7 días / 10 versiones)]'
$hoy = [datetime]::new(2026, 11, 20, 5, 0, 0, [DateTimeKind]::Utc)
function Get-NombreRespaldo([int]$Dias, [string[]]$Partes) {
    $s = $hoy.AddDays(-$Dias).AddHours(-3).ToString("yyyyMMdd'T'HHmmss'Z'")
    $Partes | ForEach-Object { "atlas-srv01_atlas_$s.$_" }
}
$completo = 'sql.gz', 'archivos.tar.gz', 'permisos.txt.gz'
$incremental = 'binlog.tar.gz', 'archivos.tar.gz'
$nombres = @()
$nombres += Get-NombreRespaldo 2 $completo        # completo reciente: queda
$nombres += Get-NombreRespaldo 27 $completo       # completo de 27 días: queda (≤ 28)
$nombres += Get-NombreRespaldo 35 $completo       # completo de 35 días: vence
$nombres += Get-NombreRespaldo 1 $incremental     # incremental de ayer: queda
$nombres += Get-NombreRespaldo 6 $incremental     # incremental de 6 días: queda (≤ 7)
$nombres += Get-NombreRespaldo 9 $incremental     # incremental de 9 días: vence
$configs = 0..11 | ForEach-Object { 'atlas-srv01_atlas_config_' + $hoy.AddDays(-$_).ToString("yyyyMMdd'T'HHmmss'Z'") + '.tar.gz' }
$nombres += $configs
$nombres += 'leeme.txt', 'atlas-srv01_otra-cosa.zip', 'copia-manual_atlas_20200101T000000Z.sql.gz'
$v = @(Get-AtlasRespaldoVencido -Nombres $nombres -Ahora $hoy)
Assert-Atlas 'el completo de 35 días vence entero (sus 3 archivos)' (@($v | Where-Object Tipo -EQ 'COMPLETO').Count -eq 3 -and -not ($v | Where-Object { $_.Tipo -eq 'COMPLETO' -and $_.Nombre -notin (Get-NombreRespaldo 35 $completo) }))
Assert-Atlas 'el completo de 27 días se guarda' (-not ($v.Nombre | Where-Object { $_ -in (Get-NombreRespaldo 27 $completo) }))
Assert-Atlas 'el incremental de 9 días vence (binlog y archivos)' (@($v | Where-Object Tipo -EQ 'INCREMENTAL').Count -eq 2 -and -not ($v | Where-Object { $_.Tipo -eq 'INCREMENTAL' -and $_.Nombre -notin (Get-NombreRespaldo 9 $incremental) }))
Assert-Atlas 'el archivos.tar.gz de un completo no se confunde con uno incremental' (-not ($v.Nombre | Where-Object { $_ -in (Get-NombreRespaldo 27 $completo) -or $_ -in (Get-NombreRespaldo 6 $incremental) }))
Assert-Atlas 'configuración: de 12 versiones se borran las 2 más viejas' (@($v | Where-Object Tipo -EQ 'CONFIG').Count -eq 2 -and -not (Compare-Object @($v | Where-Object Tipo -EQ 'CONFIG').Nombre $configs[10..11]))
Assert-Atlas 'lo que no es de atlas-srv01 con ese formato no se toca nunca' (-not ($v.Nombre | Where-Object { $_ -in 'leeme.txt', 'atlas-srv01_otra-cosa.zip', 'copia-manual_atlas_20200101T000000Z.sql.gz' }))
Assert-Atlas 'carpeta vacía: no hay nada que borrar' (@(Get-AtlasRespaldoVencido -Nombres @() -Ahora $hoy).Count -eq 0)

'[sintaxis de todos los scripts de atlas-dc01]'
foreach ($f in Get-ChildItem $raiz -Recurse -Include *.ps1, *.psm1) {
    $errores = $null
    [void][Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errores)
    Assert-Atlas "$($f.Name) se puede leer sin errores de sintaxis" (-not $errores)
}
Assert-Atlas 'los .ps1 nuevos tienen BOM (Windows PowerShell 5.1 lee bien los acentos)' (-not (Get-ChildItem $raiz -Filter '1[34]-*.ps1' | Where-Object { $b = [IO.File]::ReadAllBytes($_.FullName); -not ($b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) }))

''; "Resultado: $script:ok PASS · $script:mal FAIL"
if ($script:mal -gt 0) { exit 1 }
