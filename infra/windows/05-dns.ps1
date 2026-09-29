<#
.SYNOPSIS
    ATLAS · Fase 7 · Paso 5 — DNS del dominio (§29.4).
.DESCRIPTION
    · Zona directa atlas.local: la crea la promoción (integrada en AD).
    · Zona inversa para 172.16.0.0/16 (16.172.in-addr.arpa), integrada en AD.
    · Registros A y PTR de atlas-srv01 (172.16.40.10) y PTR de atlas-dc01.
    · Reenviadores: PENDIENTE (J.2). Si no hay, se usan las sugerencias de raíz
      (el DC puede consultar DNS hacia Internet por la regla 7).
    · Transferencias de zona deshabilitadas y actualizaciones dinámicas solo seguras.
#>
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\AtlasComun.psm1" -Force
Import-Module DnsServer
Assert-AtlasAdministrador
$p = Import-AtlasParametro
$zona = $p.Dominio
$inversa = '16.172.in-addr.arpa'

Write-AtlasPaso "Zona inversa $inversa (172.16.0.0/16)"
if (-not (Get-DnsServerZone -Name $inversa -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -NetworkId '172.16.0.0/16' -ReplicationScope Domain -DynamicUpdate Secure
}

Write-AtlasPaso 'Seguridad de las zonas'
Set-DnsServerPrimaryZone -Name $zona -DynamicUpdate Secure -SecureSecondaries NoTransfer
Set-DnsServerPrimaryZone -Name $inversa -DynamicUpdate Secure -SecureSecondaries NoTransfer

function Set-AtlasRegistro {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Nombre, [string]$IP)
    if (-not $PSCmdlet.ShouldProcess("$Nombre.$zona", "A/PTR $IP")) { return }
    $a = Get-DnsServerResourceRecord -ZoneName $zona -Name $Nombre -RRType A -ErrorAction SilentlyContinue
    if ($a -and $a.RecordData.IPv4Address.IPAddressToString -ne $IP) { $a | Remove-DnsServerResourceRecord -ZoneName $zona -Force; $a = $null }
    if (-not $a) { Add-DnsServerResourceRecordA -ZoneName $zona -Name $Nombre -IPv4Address $IP -CreatePtr }
    $o = $IP.Split('.')
    $ptr = "$($o[3]).$($o[2])"
    if (-not (Get-DnsServerResourceRecord -ZoneName $inversa -Name $ptr -RRType Ptr -ErrorAction SilentlyContinue)) {
        Add-DnsServerResourceRecordPtr -ZoneName $inversa -Name $ptr -PtrDomainName "$Nombre.$zona."
    }
    Write-Host "   $Nombre.$zona → $IP (y PTR $ptr.$inversa)"
}
Write-AtlasPaso 'Registros de los servidores (Tabla 40; §29.4: "el servidor Linux se registra acá")'
Set-AtlasRegistro -Nombre $p.ServidorLinux.Nombre -IP $p.ServidorLinux.IP
Set-AtlasRegistro -Nombre $p.NombreEquipo -IP $p.IP

Write-AtlasPaso 'Resolución hacia afuera'
if ($p.Reenviadores.Count -gt 0) {
    Set-DnsServerForwarder -IPAddress $p.Reenviadores -UseRootHint $true
    Write-Host "   Reenviadores: $($p.Reenviadores -join ', ')"
}
else {
    Write-AtlasAviso 'Reenviadores PENDIENTES (J.2): se usan las sugerencias de raíz. Completar Reenviadores en parametros.psd1 y volver a correr este paso.'
}

Write-AtlasPaso 'Comprobación'
Resolve-DnsName "$($p.ServidorLinux.Nombre).$zona" -Server 127.0.0.1 -Type A | Format-Table -AutoSize
Resolve-DnsName $p.ServidorLinux.IP -Server 127.0.0.1 -Type PTR | Format-Table -AutoSize
Resolve-DnsName "_ldap._tcp.$zona" -Server 127.0.0.1 -Type SRV | Select-Object -First 1 | Format-Table -AutoSize
Write-AtlasPaso 'Listo. Siguiente: 06-dhcp.ps1'
