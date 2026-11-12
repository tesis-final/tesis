<#
.SYNOPSIS
    ATLAS · Fase 12 · Paso 13 — Retención de las copias externas en \\atlas-dc01\atlas-backups.
.DESCRIPTION
    atlas-srv01 sube sus respaldos con svc_atlas_backup, que puede crear archivos pero NO
    borrarlos (CT-05): así, si alguien toma el servidor Linux, no puede eliminar las copias
    externas. Por eso borrar lo vencido lo hace el DC, con una tarea programada que corre
    como SYSTEM todos los días a las 05:00 (después de los respaldos de las 02:00 y de la
    verificación de las 03:30). Plazos de la Tabla 29 (§28.5):
      completo       28 días (4 semanas)
      incremental     7 días
      configuración  últimas 10 versiones
    Qué está vencido lo decide Get-AtlasRespaldoVencido (AtlasComun.psm1, probado en
    pruebas/probar-modulo.ps1). Cada borrado queda en C:\ATLAS\registros\retencion.log y en
    el visor de eventos (Aplicación, origen ATLAS-Respaldos).

    Uso:
      .\13-retencion-respaldos.ps1                 instala (o actualiza) la tarea programada
      .\13-retencion-respaldos.ps1 -Ejecutar -WhatIf   muestra qué borraría hoy, sin borrar
      .\13-retencion-respaldos.ps1 -Ejecutar       aplica la retención ahora (lo que hace la tarea)
#>
[CmdletBinding(SupportsShouldProcess)]
param([switch]$Ejecutar)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\AtlasComun.psm1" -Force
$p = Import-AtlasParametro -Ruta "$PSScriptRoot\parametros.psd1"
$carpeta = Join-Path $p.CarpetaBase 'atlas-backups'
$registro = Join-Path $p.CarpetaBase 'registros\retencion.log'
$origenEvento = 'ATLAS-Respaldos'

if ($Ejecutar) {
    New-Item -ItemType Directory -Path (Split-Path $registro) -Force | Out-Null
    if (-not [Diagnostics.EventLog]::SourceExists($origenEvento)) { New-EventLog -LogName Application -Source $origenEvento }
    $archivos = @(Get-ChildItem -Path $carpeta -File -ErrorAction Stop)
    $vencidos = @(Get-AtlasRespaldoVencido -Nombres @($archivos.Name))
    $borrados = 0
    foreach ($v in $vencidos) {
        if ($PSCmdlet.ShouldProcess((Join-Path $carpeta $v.Nombre), "Borrar ($($v.Tipo) del $($v.Fecha.ToString('yyyy-MM-dd HH:mm')) UTC)")) {
            Remove-Item -LiteralPath (Join-Path $carpeta $v.Nombre) -Force
            Add-Content -Path $registro -Value ("{0:yyyy-MM-dd HH:mm:ss}  BORRADO  {1,-11}  {2}" -f (Get-Date), $v.Tipo, $v.Nombre)
            $borrados++
        }
    }
    $mensaje = "Retención de atlas-backups: $($archivos.Count) archivos, $($vencidos.Count) vencidos, $borrados borrados."
    Add-Content -Path $registro -Value ("{0:yyyy-MM-dd HH:mm:ss}  RESUMEN  {1}" -f (Get-Date), $mensaje)
    Write-EventLog -LogName Application -Source $origenEvento -EventId 1300 -EntryType Information -Message $mensaje
    Write-AtlasPaso $mensaje
    return
}

Assert-AtlasAdministrador
Write-AtlasPaso 'Script de retención en C:\ATLAS\scripts (solo Administradores y SYSTEM lo pueden cambiar)'
$destino = Join-Path $p.CarpetaBase 'scripts'
New-Item -ItemType Directory -Path $destino -Force | Out-Null
Copy-Item "$PSScriptRoot\13-retencion-respaldos.ps1", "$PSScriptRoot\AtlasComun.psm1", "$PSScriptRoot\parametros.psd1" -Destination $destino -Force
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true, $false)
foreach ($sid in 'S-1-5-32-544', 'S-1-5-18') {
    $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier($sid)),
                'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow')))
}
Set-Acl -Path $destino -AclObject $acl

Write-AtlasPaso 'Tarea programada «ATLAS - Retencion de respaldos»: todos los días 05:00, como SYSTEM'
$accion = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$destino\13-retencion-respaldos.ps1`" -Ejecutar"
$disparo = New-ScheduledTaskTrigger -Daily -At '05:00'
$cuenta = New-ScheduledTaskPrincipal -UserId 'S-1-5-18' -LogonType ServiceAccount -RunLevel Highest
$ajustes = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
Register-ScheduledTask -TaskName 'ATLAS - Retencion de respaldos' -TaskPath '\ATLAS\' -Action $accion -Trigger $disparo `
    -Principal $cuenta -Settings $ajustes -Description 'Borra las copias vencidas de atlas-backups (Tabla 29: 28 d / 7 d / 10 versiones).' -Force | Out-Null

Write-AtlasPaso 'Qué se borraría hoy (sin borrar nada):'
& "$destino\13-retencion-respaldos.ps1" -Ejecutar -WhatIf
Get-ScheduledTask -TaskPath '\ATLAS\' | Format-Table TaskName, State -AutoSize
Write-AtlasPaso 'Listo. Siguiente: 14-agente-zabbix.ps1'
