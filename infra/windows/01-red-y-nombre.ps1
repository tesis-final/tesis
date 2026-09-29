<#
.SYNOPSIS
    ATLAS · Fase 7 · Paso 1 — IP fija, zona horaria y nombre de atlas-dc01.
.DESCRIPTION
    PDF Tabla 31 y Tabla 40: Windows Server 2022, atlas-dc01, 172.16.40.20/24, VLAN 40.
    Al terminar REINICIA el equipo (el cambio de nombre lo necesita).
    DNS: se apunta a sí mismo (127.0.0.1), porque este equipo va a ser el DNS del dominio.
#>
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\AtlasComun.psm1" -Force
Assert-AtlasAdministrador
$p = Import-AtlasParametro

if ($p.Interfaz) { $nic = Get-NetAdapter -Name $p.Interfaz }
else { $nic = Get-NetAdapter -Physical | Where-Object Status -EQ 'Up' | Select-Object -First 1 }
if (-not $nic) { throw 'No hay ninguna interfaz de red conectada. Definir Interfaz en parametros.psd1.' }

Write-AtlasPaso "IP fija $($p.IP)/$($p.Prefijo) en '$($nic.Name)' (gateway $($p.Gateway))"
if ($PSCmdlet.ShouldProcess($nic.Name, 'Configurar IPv4 fija')) {
    Set-NetIPInterface -InterfaceIndex $nic.ifIndex -Dhcp Disabled
    Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object IPAddress -NE $p.IP | Remove-NetIPAddress -Confirm:$false
    Get-NetRoute -InterfaceIndex $nic.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Remove-NetRoute -Confirm:$false
    if (-not (Get-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress $p.IP -ErrorAction SilentlyContinue)) {
        New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress $p.IP -PrefixLength $p.Prefijo -DefaultGateway $p.Gateway | Out-Null
    }
    else { New-NetRoute -InterfaceIndex $nic.ifIndex -DestinationPrefix '0.0.0.0/0' -NextHop $p.Gateway | Out-Null }
    Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses '127.0.0.1'
}

Write-AtlasPaso "Zona horaria: $($p.ZonaHoraria)"
Set-TimeZone -Id $p.ZonaHoraria

if ($env:COMPUTERNAME -ne $p.NombreEquipo.ToUpper()) {
    Write-AtlasPaso "Nombre del equipo: $($p.NombreEquipo). El equipo se reinicia."
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Renombrar a $($p.NombreEquipo)")) {
        Rename-Computer -NewName $p.NombreEquipo -Restart -Force
    }
}
else { Write-AtlasPaso 'El nombre ya es el correcto. Siguiente: 02-promover-dc.ps1' }
