<#
.SYNOPSIS
    ATLAS · Fase 7 · Paso 9 — Autoridad certificadora interna ATLAS-CA (DEC-20).
.DESCRIPTION
    CA raíz de empresa integrada con AD. Su certificado se publica en el directorio
    y la directiva de grupo lo instala sola en el almacén "Entidades de certificación
    raíz de confianza" de TODOS los equipos del dominio: así el navegador de un equipo
    del dominio confía en https://atlas-srv01.atlas.local sin advertencias (P-01, P-13).
    Los docentes que entran por VPN desde un equipo propio importan ATLAS-CA.cer a mano
    (manual de la Fase 10).
    Nota: en producción la CA iría en un servidor aparte; en el laboratorio hay un solo
    servidor Windows (Tabla 31).
#>
[CmdletBinding(SupportsShouldProcess)]
param()
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\AtlasComun.psm1" -Force
Assert-AtlasAdministrador
$p = Import-AtlasParametro

Write-AtlasPaso 'Rol Servicios de certificados de Active Directory'
Install-WindowsFeature -Name ADCS-Cert-Authority -IncludeManagementTools | Out-Null

if (-not (Get-Service -Name CertSvc -ErrorAction SilentlyContinue) -or -not (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration')) {
    Write-AtlasPaso "CA raíz de empresa '$($p.NombreCA)' (RSA 4096, SHA-256, $($p.AniosCA) años)"
    if ($PSCmdlet.ShouldProcess($p.NombreCA, 'Install-AdcsCertificationAuthority')) {
        Install-AdcsCertificationAuthority -CAType EnterpriseRootCA -CACommonName $p.NombreCA `
            -CADistinguishedNameSuffix $p.DN -CryptoProviderName 'RSA#Microsoft Software Key Storage Provider' `
            -KeyLength 4096 -HashAlgorithmName SHA256 -ValidityPeriod Years -ValidityPeriodUnits $p.AniosCA -Force | Out-Null
    }
}
else { Write-AtlasPaso 'La CA ya estaba instalada.' }

Write-AtlasPaso 'Certificado público de la CA para distribuir'
$salida = Join-Path $p.CarpetaBase 'ATLAS-CA.cer'
New-Item -ItemType Directory -Path $p.CarpetaBase -Force | Out-Null
& certutil.exe -ca.cert $salida | Out-Null
& certutil.exe -dump $salida | Select-String -Pattern 'Emisor|Issuer|NotAfter|Fecha de expiraci'
Write-Host "   $salida  (copiarlo a atlas-srv01 y a los equipos que no son del dominio)"
Write-AtlasPaso 'Listo. Siguiente: 10-certificado-srv01.ps1 (cuando llegue el CSR de atlas-srv01)'
