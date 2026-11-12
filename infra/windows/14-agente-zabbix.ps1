<#
.SYNOPSIS
    ATLAS · Fase 12 · Paso 14 — Agente de Zabbix en atlas-dc01 (§30.5, Tablas 46 y 47; DEC-19).
.DESCRIPTION
    Instala el agente 2 de Zabbix 7.0 LTS desde su instalador MSI oficial y lo deja:
      · respondiendo SOLO a atlas-srv01 (172.16.40.10), que es por donde sale zabbix-server
        (el contenedor sale a la VLAN 40 con la IP del servidor);
      · con el firewall de Windows abierto en TCP 10050 únicamente desde esa IP;
      · con el nombre de host atlas-dc01 (el mismo que da de alta configurar-zabbix.py).
    Es la misma VLAN 40: el tráfico no cruza el router y no hace falta ninguna regla nueva en
    la Tabla 44.

    El MSI se descarga una vez desde https://cdn.zabbix.com/zabbix/binaries/stable/7.0/ (con
    Internet en otro equipo si hace falta) y se pasa con -Msi, por ejemplo desde el CD del
    laboratorio (02-iso-repo.sh) o un pendrive. Elegir «zabbix_agent2-7.0.x-windows-amd64-openssl.msi».

    Uso: .\14-agente-zabbix.ps1 -Msi D:\zabbix_agent2-7.0.x-windows-amd64-openssl.msi
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateScript({ Test-Path $_ -PathType Leaf })][string]$Msi,
    [string]$Servidor = '172.16.40.10'
)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\AtlasComun.psm1" -Force
Import-Module NetSecurity
Assert-AtlasAdministrador
$p = Import-AtlasParametro

$firma = Get-AuthenticodeSignature $Msi
Write-AtlasPaso "Instalador: $(Split-Path $Msi -Leaf) · firma: $($firma.Status) ($($firma.SignerCertificate.Subject -replace ',.*'))"
if ($firma.Status -ne 'Valid') { throw 'La firma digital del MSI no es válida: bajarlo de nuevo desde cdn.zabbix.com.' }

Write-AtlasPaso "Instalación silenciosa: Server=$Servidor, Hostname=$($p.NombreEquipo), sin chequeos activos"
$registroMsi = Join-Path $env:TEMP 'atlas-zabbix-agent2.log'
$argumentos = @('/i', "`"$Msi`"", '/qn', '/norestart', "/l*v `"$registroMsi`"",
    "SERVER=$Servidor", "HOSTNAME=$($p.NombreEquipo)", 'LISTENPORT=10050',
    'ENABLEPATH=1', 'SKIP=fw')      # SKIP=fw: la regla del firewall la crea este script, acotada
if ($PSCmdlet.ShouldProcess($Msi, 'msiexec /i')) {
    $proc = Start-Process msiexec.exe -ArgumentList $argumentos -Wait -PassThru
    if ($proc.ExitCode -notin 0, 3010) { throw "msiexec terminó con código $($proc.ExitCode) (ver $registroMsi)." }
}

Write-AtlasPaso 'Configuración: sin comandos remotos, sin chequeos activos (solo pasivos)'
$conf = Join-Path $env:ProgramFiles 'Zabbix Agent 2\zabbix_agent2.conf'
$texto = Get-Content $conf -Raw
$texto = $texto -replace '(?m)^ServerActive=.*$', '# ServerActive: sin chequeos activos (ATLAS, solo pasivos)'
if ($texto -notmatch '(?m)^DenyKey=system\.run\[\*\]') { $texto += "`r`n# ATLAS: no se permiten comandos remotos`r`nDenyKey=system.run[*]`r`n" }
# Sin BOM: el agente leería la marca BOM como parte de la primera línea y no arrancaría.
[IO.File]::WriteAllText($conf, $texto, (New-Object Text.UTF8Encoding($false)))
Restart-Service 'Zabbix Agent 2'
Set-Service 'Zabbix Agent 2' -StartupType Automatic

Write-AtlasPaso "Firewall: TCP 10050 solo desde $Servidor (zabbix-server sale con la IP de atlas-srv01)"
Get-NetFirewallRule -DisplayName 'ATLAS - Zabbix agente' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName 'ATLAS - Zabbix agente' -Direction Inbound -Protocol TCP -LocalPort 10050 `
    -RemoteAddress $Servidor -Action Allow -Profile Domain, Private, Public -Description 'Monitoreo (§30.5, DEC-19)' | Out-Null

Write-AtlasPaso 'Comprobación'
Get-Service 'Zabbix Agent 2' | Format-Table Name, Status, StartType -AutoSize
Get-NetTCPConnection -LocalPort 10050 -State Listen | Format-Table LocalAddress, LocalPort, State -AutoSize
Get-NetFirewallRule -DisplayName 'ATLAS - Zabbix agente' | Get-NetFirewallAddressFilter | Format-Table RemoteAddress -AutoSize
Select-String -Path $conf -Pattern '^(Server|Hostname|DenyKey)=' | ForEach-Object { '    ' + $_.Line }
Write-AtlasPaso "Listo. En atlas-srv01: sudo atlas-ctl monitoreo  (atlas-dc01 tiene que figurar «responde»)"
