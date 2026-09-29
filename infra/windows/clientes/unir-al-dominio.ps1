<#
.SYNOPSIS
    ATLAS — Unir un equipo Windows de las VLAN 10, 20 o 30 al dominio atlas.local.
.DESCRIPTION
    §29.2: "Las máquinas de las VLAN 10, 20 y 30 se unen al dominio atlas.local y quedan
    registradas en el contenedor de Equipos de su OU correspondiente". El script mira la
    IP que le dio el DHCP y elige la OU:
        172.16.10.x → OU=Equipos,OU=Administracion
        172.16.20.x → OU=Equipos,OU=Docentes
        172.16.30.x → OU=Equipos,OU=Estudiantes
    Pide una cuenta de Soporte TI (adm.<usuario>) con permiso delegado para unir equipos.
#>
[CmdletBinding(SupportsShouldProcess)]
param([string]$NuevoNombre)
$ErrorActionPreference = 'Stop'
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object IPAddress -Like '172.16.*' | Select-Object -First 1).IPAddress
if (-not $ip) { throw 'Este equipo no tiene una IP 172.16.x.x: revisar el cable/VLAN y el DHCP (ipconfig /all).' }
$ou = switch -Wildcard ($ip) {
    '172.16.10.*' { 'OU=Equipos,OU=Administracion,OU=ATLAS,DC=atlas,DC=local' }
    '172.16.20.*' { 'OU=Equipos,OU=Docentes,OU=ATLAS,DC=atlas,DC=local' }
    '172.16.30.*' { 'OU=Equipos,OU=Estudiantes,OU=ATLAS,DC=atlas,DC=local' }
    default { throw "La IP $ip no es de VLAN 10, 20 ni 30: los servidores y la gestión no se unen con este script." }
}
Write-Host "IP $ip → $ou"
Resolve-DnsName '_ldap._tcp.atlas.local' -Type SRV -ErrorAction Stop | Out-Null
$cred = Get-Credential -Message 'Cuenta de Soporte TI (ATLAS\adm.usuario)'
if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Unir a atlas.local en $ou")) {
    $parametros = @{ DomainName = 'atlas.local'; OUPath = $ou; Credential = $cred; Restart = $true; Force = $true }
    if ($NuevoNombre) { $parametros.NewName = $NuevoNombre }
    Add-Computer @parametros
}
