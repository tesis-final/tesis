<#
.SYNOPSIS
    ATLAS · Fase 7 · Paso 6 — DHCP: un ámbito por VLAN de usuarios (Tabla 34).
.DESCRIPTION
    VLAN 10: 172.16.10.100–.200 · VLAN 20: 172.16.20.100–.200 · VLAN 30: 172.16.30.100–.250
    VLAN 40 y 50: IP fijas, sin DHCP.
    Cada ámbito entrega: puerta de enlace (003), DNS del dominio 172.16.40.20 (006)
    y sufijo atlas.local (015). Los pedidos llegan por el reenvío DHCP del router
    (ip helper-address, regla 4); el campo giaddr le dice al servidor qué ámbito usar.
#>
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\AtlasComun.psm1" -Force
Assert-AtlasAdministrador
$p = Import-AtlasParametro
$fqdn = "$($p.NombreEquipo).$($p.Dominio)"

Write-AtlasPaso 'Rol DHCP'
Install-WindowsFeature -Name DHCP -IncludeManagementTools | Out-Null
Import-Module DhcpServer
& netsh.exe dhcp add securitygroups | Out-Null
Restart-Service -Name DHCPServer
if (-not (Get-DhcpServerInDC | Where-Object DnsName -EQ $fqdn)) {
    Add-DhcpServerInDC -DnsName $fqdn -IPAddress $p.IP
}
# Le avisa al Administrador del servidor que la configuración posterior ya se hizo.
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12' -Name ConfigurationState -Value 2

Write-AtlasPaso 'Opciones comunes a todos los ámbitos: DNS (006) y sufijo (015)'
Set-DhcpServerv4OptionValue -DnsServer $p.IP -DnsDomain $p.Dominio -Force

Write-AtlasPaso 'Ámbitos (Tabla 34)'
foreach ($a in $p.Ambitos) {
    if (-not (Get-DhcpServerv4Scope -ScopeId $a.Red -ErrorAction SilentlyContinue)) {
        Add-DhcpServerv4Scope -Name $a.Nombre -StartRange $a.Inicio -EndRange $a.Fin -SubnetMask 255.255.255.0 `
            -LeaseDuration ([timespan]$p.DuracionConcesion) -State Active
    }
    Set-DhcpServerv4OptionValue -ScopeId $a.Red -Router $a.Gateway
    Write-Host "   $($a.Nombre): $($a.Inicio) – $($a.Fin), gateway $($a.Gateway)"
}

# Los equipos del dominio registran su propio nombre en DNS; el DHCP lo hace por los demás.
Set-DhcpServerv4DnsSetting -DynamicUpdates OnClientRequest -DeleteDnsRROnLeaseExpiry $true

Write-AtlasPaso 'Comprobación'
Get-DhcpServerv4Scope | Format-Table ScopeId, Name, StartRange, EndRange, State -AutoSize
Get-DhcpServerv4OptionValue -All | Format-Table OptionId, Name, Value -AutoSize
Write-AtlasPaso 'Listo. Siguiente: 07-gpo.ps1'
