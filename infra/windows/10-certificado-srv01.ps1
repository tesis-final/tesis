<#
.SYNOPSIS
    ATLAS · Fase 7 · Paso 10 — Firmar el certificado HTTPS de atlas-srv01 con ATLAS-CA.
.DESCRIPTION
    Recibe el pedido atlas.csr que generó atlas-srv01 (Fase 6, paso 7), lo firma con
    la plantilla "Servidor web" (WebServer) y devuelve atlas-srv01.cer y ATLAS-CA.cer.
    La plantilla WebServer toma el nombre y el SAN del pedido: CN atlas-srv01.atlas.local
    y SAN IP 172.16.40.10 (DEC-20). En srv01 se instala con instalar-certificado.sh.
.PARAMETER Csr
    Ruta del archivo atlas.csr copiado desde atlas-srv01.
.EXAMPLE
    .\10-certificado-srv01.ps1 -Csr C:\ATLAS\atlas.csr
#>
[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][ValidateScript({ Test-Path $_ })][string]$Csr)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot\AtlasComun.psm1" -Force
Assert-AtlasAdministrador
$p = Import-AtlasParametro
$config = "$($p.NombreEquipo).$($p.Dominio)\$($p.NombreCA)"
$salida = Join-Path $p.CarpetaBase 'atlas-srv01.cer'

Write-AtlasPaso 'Contenido del pedido'
$dump = & certutil.exe -dump $Csr
$dump | Select-String -Pattern 'CN=|DNS Name|Nombre DNS|IP Address|Dirección IP'
if (-not ($dump -match '172\.16\.40\.10')) { throw 'El CSR no incluye la IP 172.16.40.10 en el SAN (DEC-20).' }

Write-AtlasPaso "Firma con la plantilla WebServer en $config"
if ($PSCmdlet.ShouldProcess($Csr, 'certreq -submit')) {
    Remove-Item $salida -ErrorAction SilentlyContinue
    & certreq.exe -submit -q -attrib 'CertificateTemplate:WebServer' -config $config $Csr $salida
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $salida)) { throw 'certreq no emitió el certificado (ver el mensaje de arriba).' }
}
& certutil.exe -ca.cert (Join-Path $p.CarpetaBase 'ATLAS-CA.cer') | Out-Null
& certutil.exe -dump $salida | Select-String -Pattern 'Sujeto|Subject|NotAfter|Fecha de expiraci|IP Address|Dirección IP'
Write-Host ''
Write-Host "   Copiar a atlas-srv01: $salida y $(Join-Path $p.CarpetaBase 'ATLAS-CA.cer')"
Write-Host '   En srv01: sudo ./instalar-certificado.sh atlas-srv01.cer ATLAS-CA.cer'
