<#
.SYNOPSIS
    ATLAS · Fase 7 · Paso 11 — Firewall de Windows, hora del dominio y rango RPC.
.DESCRIPTION
    Firewall (fase-02/05 §6; AMB-19; sin reglas de red nuevas, DEC-R8):
      · perfiles activos, entrante bloqueado por defecto;
      · servicios de dominio (DEC-17) solo desde VLAN 10, 20, 30 y 40;
      · DHCP (UDP 67) solo desde las IP del router (reenvío, regla 4);
      · Escritorio remoto (3389) y WinRM solo desde VLAN 50 (regla 6).
      Se restringe el ÁMBITO de las reglas que Windows ya trae, identificándolas por
      puerto (no por nombre, que cambia con el idioma).
    Hora (DEC-R8, DISC-20): el DC es la fuente confiable del dominio con su reloj.
    RPC (DEC-17): rango dinámico TCP 49152–65535, fijado y documentado.
#>
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\AtlasComun.psm1" -Force
Import-Module NetSecurity
Assert-AtlasAdministrador
$p = Import-AtlasParametro

Write-AtlasPaso "Rango RPC dinámico: TCP $($p.RpcInicio)–$($p.RpcInicio + $p.RpcCantidad - 1) (DEC-17)"
& netsh.exe int ipv4 set dynamicport tcp start=$($p.RpcInicio) num=$($p.RpcCantidad) | Out-Null
& netsh.exe int ipv4 show dynamicport tcp

Write-AtlasPaso 'Hora: el DC es la fuente confiable del dominio (DEC-R8)'
& w32tm.exe /config /syncfromflags:NO /reliable:YES /update | Out-Null
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config' -Name AnnounceFlags -Value 5
Restart-Service W32Time
& w32tm.exe /query /status | Select-String -Pattern 'Stratum|Estrato|Source|Origen'

Write-AtlasPaso 'Perfiles del firewall: activos, entrante bloqueado, registro de descartes'
Set-NetFirewallProfile -Profile Domain, Private, Public -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow `
    -LogBlocked True -LogMaxSizeKilobytes 16384

Write-AtlasPaso 'Escritorio remoto habilitado (regla 6: VLAN 50 administra por SSH/RDP)'
Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
Get-NetFirewallRule -Direction Inbound -PolicyStore PersistentStore |
    Where-Object { @(($_ | Get-NetFirewallPortFilter).LocalPort) -contains '3389' } | Enable-NetFirewallRule

$dominio = @($p.RedesUsuarios) + $p.RedServidores
$puertosDominio = @('53', '88', '464', '389', '636', '3268', '3269', '445', '123', '135', 'RPC', 'RPCEPMap', '49152-65535')
$puertosGestion = @('3389', '5985', '5986')
$resumen = @()
foreach ($regla in Get-NetFirewallRule -Direction Inbound -Action Allow -Enabled True -PolicyStore PersistentStore) {
    $pf = $regla | Get-NetFirewallPortFilter
    $locales = @($pf.LocalPort)
    $ambito = $null
    if ($locales | Where-Object { $_ -in $puertosGestion }) { $ambito = @($p.RedGestion); $tipo = 'gestión' }
    elseif ($pf.Protocol -eq 'UDP' -and $locales -contains '67') { $ambito = @($p.IPsRouter); $tipo = 'DHCP' }
    elseif ($locales | Where-Object { $_ -in $puertosDominio }) { $ambito = $dominio; $tipo = 'dominio' }
    if ($ambito -and $PSCmdlet.ShouldProcess($regla.DisplayName, "RemoteAddress = $($ambito -join ',')")) {
        $regla | Set-NetFirewallRule -RemoteAddress $ambito
        $resumen += [pscustomobject]@{ Tipo = $tipo; Regla = $regla.DisplayName; Puertos = ($locales -join ','); Origen = ($ambito -join ', ') }
    }
}
$resumen | Sort-Object Tipo, Regla | Format-Table -AutoSize
Write-AtlasPaso 'Listo. Siguiente: 12-usuarios.ps1'
