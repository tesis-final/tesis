<#
.SYNOPSIS
    ATLAS · Fase 7 — Verificación de atlas-dc01 (PASS / FAIL por ítem).
.DESCRIPTION
    Comprueba §29 (Tabla 31–36) y las decisiones DEC-08, DEC-17, DEC-20, DEC-R8, CT-05, CT-09.
    La salida es evidencia (E-WIN-nnn):  .\verificar-dc01.ps1 | Tee-Object C:\ATLAS\E-WIN-001.txt
#>
[CmdletBinding()]
param()
Import-Module "$PSScriptRoot\AtlasComun.psm1" -Force
Import-Module ActiveDirectory, GroupPolicy, DnsServer, DhcpServer, SmbShare -ErrorAction SilentlyContinue
$p = Import-AtlasParametro
$script:pass = 0; $script:fail = 0
function Test-Item([string]$Descripcion, [scriptblock]$Prueba) {
    try { $ok = [bool](& $Prueba) } catch { $ok = $false }
    if ($ok) { $script:pass++; "  PASS  $Descripcion" } else { $script:fail++; "  FAIL  $Descripcion" }
}
function Write-Seccion([string]$T) { ''; "[$T]" }
$atlas = "OU=ATLAS,$($p.DN)"

"ATLAS — verificación de $env:COMPUTERNAME · $(Get-Date -Format s)"

Write-Seccion 'Servidor (Tabla 31, Tabla 40)'
Test-Item "Nombre $($p.NombreEquipo)" { $env:COMPUTERNAME -eq $p.NombreEquipo.ToUpper() }
Test-Item "IP $($p.IP)/$($p.Prefijo)" { Get-NetIPAddress -IPAddress $p.IP -PrefixLength $p.Prefijo -ErrorAction Stop }
Test-Item "Gateway $($p.Gateway)" { (Get-NetRoute -DestinationPrefix '0.0.0.0/0').NextHop -contains $p.Gateway }
Test-Item 'Windows Server 2022' { (Get-CimInstance Win32_OperatingSystem).Caption -match '2022' }

Write-Seccion 'Dominio y estructura (§29.1, §29.2)'
Test-Item "Dominio $($p.Dominio)" { (Get-ADDomain).DNSRoot -eq $p.Dominio }
Test-Item 'Este equipo es controlador de dominio' { (Get-ADDomainController -Identity $env:COMPUTERNAME).Name }
foreach ($ou in @("OU=ATLAS,$($p.DN)", "OU=Grupos,$($p.DN)", "OU=Servidores,$atlas", "OU=ServiciosTI,$atlas") +
    (@('Administracion', 'Docentes', 'Estudiantes') | ForEach-Object { "OU=Usuarios,OU=$_,$atlas"; "OU=Equipos,OU=$_,$atlas" })) {
    Test-Item "$ou" { Get-ADOrganizationalUnit -Identity $ou }
}
foreach ($g in 'GG_Administracion', 'GG_Docentes', 'GG_Estudiantes', 'GG_SoporteTI') {
    Test-Item "Grupo $g en OU=Grupos (global, seguridad)" {
        $x = Get-ADGroup $g; $x.DistinguishedName -like "*,OU=Grupos,$($p.DN)" -and $x.GroupScope -eq 'Global' -and $x.GroupCategory -eq 'Security'
    }
}
Test-Item 'GG_SoporteTI NO es Domain Admins (delegación acotada, Tabla 32)' {
    -not (Get-ADGroupMember -Identity "$((Get-ADDomain).DomainSID)-512" -Recursive | Where-Object SamAccountName -EQ 'GG_SoporteTI')
}
Test-Item 'Delegación de GG_SoporteTI sobre OU=ATLAS' { (& dsacls.exe $atlas) -match 'GG_SoporteTI' }

Write-Seccion 'Seguridad (Tabla 32)'
$pol = Get-ADDefaultDomainPasswordPolicy
Test-Item 'Contraseña mínima 10' { $pol.MinPasswordLength -eq 10 }
Test-Item 'Complejidad activada' { $pol.ComplexityEnabled }
Test-Item 'Historial 5' { $pol.PasswordHistoryCount -eq 5 }
Test-Item 'Vencen a los 90 días' { $pol.MaxPasswordAge.Days -eq 90 }
Test-Item 'Bloqueo a los 5 intentos' { $pol.LockoutThreshold -eq 5 }
Test-Item 'Bloqueo de 15 minutos' { $pol.LockoutDuration.TotalMinutes -eq 15 }
Test-Item "Administrator renombrada a $($p.NombreAdministrador)" { (Get-ADUser "$((Get-ADDomain).DomainSID)-500").SamAccountName -eq $p.NombreAdministrador }
Test-Item 'Guest deshabilitada' { -not (Get-ADUser "$((Get-ADDomain).DomainSID)-501").Enabled }
$auditoria = & auditpol.exe /get /category:* /r | ConvertFrom-Csv
function Test-Auditoria([string]$Guid) { ($auditoria | Where-Object { $_.'Subcategory GUID' -eq $Guid }).'Inclusion Setting' -match 'Success|Failure|Correcto|Error' }
Test-Item 'Auditoría de inicios de sesión (Logon)' { Test-Auditoria '{0CCE9215-69AE-11D9-BED3-505054503030}' }
Test-Item 'Auditoría de cambios en el directorio (DS Changes)' { Test-Auditoria '{0CCE923C-69AE-11D9-BED3-505054503030}' }
Test-Item 'Auditoría de acceso a recursos (File Share)' { Test-Auditoria '{0CCE9224-69AE-11D9-BED3-505054503030}' }
Test-Item 'Auditoría de administración de cuentas' { Test-Auditoria '{0CCE9235-69AE-11D9-BED3-505054503030}' }

Write-Seccion 'GPO (Tabla 33)'
function Test-Vinculo([string]$Gpo, [string]$Destino) { (Get-GPInheritance -Target $Destino).GpoLinks | Where-Object { $_.DisplayName -eq $Gpo -and $_.Enabled } }
Test-Item 'GPO_Seguridad_Base vinculada al dominio' { Test-Vinculo 'GPO_Seguridad_Base' $p.DN }
Test-Item 'GPO_Auditoria vinculada al dominio' { Test-Vinculo 'GPO_Auditoria' $p.DN }
Test-Item 'GPO_Estudiantes vinculada a OU Estudiantes' { Test-Vinculo 'GPO_Estudiantes' "OU=Estudiantes,$atlas" }
Test-Item 'GPO_Docentes vinculada a OU Docentes' { Test-Vinculo 'GPO_Docentes' "OU=Docentes,$atlas" }
Test-Item 'GPO_Servidores vinculada a OU Servidores' { Test-Vinculo 'GPO_Servidores' "OU=Servidores,$atlas" }
Test-Item 'GPO_Servidores también en Domain Controllers (H7-02)' { Test-Vinculo 'GPO_Servidores' "OU=Domain Controllers,$($p.DN)" }
Test-Item 'GPO_Estudiantes: Windows Installer bloqueado' { (Get-GPRegistryValue -Name GPO_Estudiantes -Key 'HKLM\Software\Policies\Microsoft\Windows\Installer' -ValueName DisableMSI).Value -eq 1 }
Test-Item "GPO_Estudiantes: unidad $($p.UnidadEstudiantes): mapeada" { Test-Path (Join-Path (Get-AtlasRutaGpo 'GPO_Estudiantes' $p.Dominio) 'User\Preferences\Drives\Drives.xml') }
Test-Item "GPO_Docentes: unidad $($p.UnidadDocentes): mapeada" { Test-Path (Join-Path (Get-AtlasRutaGpo 'GPO_Docentes' $p.Dominio) 'User\Preferences\Drives\Drives.xml') }
Test-Item 'GPO_Servidores: SMBv1 deshabilitado' { (Get-GPRegistryValue -Name GPO_Servidores -Key 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -ValueName SMB1).Value -eq 0 }

Write-Seccion 'DNS (§29.4)'
Test-Item "Zona $($p.Dominio) integrada en AD" { (Get-DnsServerZone $p.Dominio).IsDsIntegrated }
Test-Item 'Zona inversa 16.172.in-addr.arpa' { Get-DnsServerZone '16.172.in-addr.arpa' }
Test-Item "atlas-srv01.$($p.Dominio) → $($p.ServidorLinux.IP)" { (Resolve-DnsName "$($p.ServidorLinux.Nombre).$($p.Dominio)" -Server 127.0.0.1 -Type A).IPAddress -eq $p.ServidorLinux.IP }
Test-Item "PTR $($p.ServidorLinux.IP) → atlas-srv01" { (Resolve-DnsName $p.ServidorLinux.IP -Server 127.0.0.1 -Type PTR).NameHost -like "$($p.ServidorLinux.Nombre)*" }
Test-Item 'Sin transferencias de zona' { (Get-DnsServerZone $p.Dominio).SecureSecondaries -eq 'NoTransfer' }
Test-Item 'Reenviadores configurados (J.2)' { (Get-DnsServerForwarder).IPAddress.Count -gt 0 }

Write-Seccion 'DHCP (Tabla 34)'
Test-Item 'Servidor DHCP autorizado en AD' { Get-DhcpServerInDC | Where-Object IPAddress -EQ $p.IP }
foreach ($a in $p.Ambitos) {
    Test-Item "$($a.Nombre): $($a.Inicio)–$($a.Fin) activo" { $s = Get-DhcpServerv4Scope -ScopeId $a.Red; $s.StartRange -eq $a.Inicio -and $s.EndRange -eq $a.Fin -and $s.State -eq 'Active' }
    Test-Item "$($a.Nombre): gateway $($a.Gateway)" { (Get-DhcpServerv4OptionValue -ScopeId $a.Red -OptionId 3).Value -contains $a.Gateway }
}
Test-Item "Opción 006 DNS = $($p.IP)" { (Get-DhcpServerv4OptionValue -OptionId 6).Value -contains $p.IP }
Test-Item "Opción 015 sufijo = $($p.Dominio)" { (Get-DhcpServerv4OptionValue -OptionId 15).Value -contains $p.Dominio }
Test-Item 'Sin ámbitos para VLAN 40 y 50 (IP fijas)' { -not (Get-DhcpServerv4Scope | Where-Object { $_.ScopeId -in '172.16.40.0', '172.16.50.0' }) }

Write-Seccion 'Recursos compartidos (DEC-08, CT-05, CT-09)'
Test-Item '\\atlas-dc01\estudiantes' { Get-SmbShare estudiantes }
Test-Item '\\atlas-dc01\atlas-backups (cifrado SMB)' { (Get-SmbShare atlas-backups).EncryptData }
Test-Item 'svc_atlas_backup sin derecho a borrar en atlas-backups' {
    $r = (Get-Acl (Join-Path $p.CarpetaBase 'atlas-backups')).Access | Where-Object IdentityReference -Match 'svc_atlas_backup|CREATOR OWNER|PROPIETARIO CREADOR'
    $r -and -not ($r | Where-Object { $_.FileSystemRights -match 'Delete|FullControl|Modify|ChangePermissions|TakeOwnership' })
}

Write-Seccion 'Hora, RPC, firewall, CA (DEC-R8, DEC-17, DEC-20)'
Test-Item 'El DC se anuncia como fuente de hora confiable' { (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config').AnnounceFlags -eq 5 }
Test-Item "Rango RPC TCP $($p.RpcInicio) (+$($p.RpcCantidad))" { (& netsh.exe int ipv4 show dynamicport tcp) -match "$($p.RpcInicio)" -and (& netsh.exe int ipv4 show dynamicport tcp) -match "$($p.RpcCantidad)" }
Test-Item 'Firewall activo en los tres perfiles, entrante bloqueado' { -not (Get-NetFirewallProfile | Where-Object { -not $_.Enabled -or $_.DefaultInboundAction -ne 'Block' }) }
Test-Item 'Escritorio remoto solo desde VLAN 50' {
    $r = Get-NetFirewallRule -Direction Inbound -Enabled True | Where-Object { @(($_ | Get-NetFirewallPortFilter).LocalPort) -contains '3389' }
    $r -and -not ($r | Where-Object { @(($_ | Get-NetFirewallAddressFilter).RemoteAddress) -notcontains $p.RedGestion })
}
Test-Item "CA $($p.NombreCA) instalada" { (& certutil.exe -cainfo name) -match $p.NombreCA }

''; "Resultado: $script:pass PASS · $script:fail FAIL"
