#!/usr/bin/env bash
# =============================================================================
# ATLAS · Fase 6 — Instalar el certificado firmado por ATLAS-CA (DEC-20)
# Reemplaza el certificado TEMPORAL del paso 7 por el que firmó atlas-dc01
# (Fase 7, 10-certificado-srv01.ps1).
#
# Uso: sudo ./instalar-certificado.sh atlas-srv01.cer ATLAS-CA.cer
#      (los dos archivos en PEM o DER; se copian desde el DC por SMB o USB)
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root
CERT="${1:?Falta el certificado firmado (atlas-srv01.cer)}"
CA="${2:?Falta el certificado de la CA (ATLAS-CA.cer)}"
TLS="$ATLAS_ROOT/config/tls"

pem() { openssl x509 -in "$1" -inform PEM -out "$2" 2>/dev/null || openssl x509 -in "$1" -inform DER -out "$2"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pem "$CERT" "$TMP/srv.pem"; pem "$CA" "$TMP/ca.pem"

paso "Comprobaciones"
[ "$(openssl x509 -in "$TMP/srv.pem" -noout -pubkey | sha256sum)" = "$(openssl pkey -in "$TLS/atlas.key" -pubout | sha256sum)" ] \
  || error "El certificado no corresponde a la clave privada de $TLS/atlas.key (¿se firmó otro CSR?)."
openssl verify -CAfile "$TMP/ca.pem" "$TMP/srv.pem" || error "El certificado no está firmado por esa CA."
openssl x509 -in "$TMP/srv.pem" -noout -ext subjectAltName | grep -q "IP Address:$ATLAS_IP" \
  || error "Falta la IP $ATLAS_IP en el SAN (los docentes por VPN entran por IP, DEC-20)."
openssl x509 -in "$TMP/srv.pem" -noout -subject -issuer -enddate

paso "Instalación (certificado + cadena)"
cat "$TMP/srv.pem" "$TMP/ca.pem" > "$TLS/atlas.crt"
cp "$TMP/ca.pem" "$TLS/ATLAS-CA.crt"
chown atlasadmin:atlas-admin "$TLS/atlas.crt" "$TLS/ATLAS-CA.crt"; chmod 640 "$TLS/atlas.crt"; chmod 644 "$TLS/ATLAS-CA.crt"
# El propio servidor también confía en la CA del dominio.
cp "$TMP/ca.pem" /usr/local/share/ca-certificates/ATLAS-CA.crt && update-ca-certificates >/dev/null
docker restart atlas-web >/dev/null 2>&1 || aviso "No se pudo reiniciar atlas-web (¿la pila está corriendo?)."
sleep 3
curl -s --max-time 5 --cacert "$TLS/ATLAS-CA.crt" "https://$ATLAS_HOSTNAME.$ATLAS_DOMINIO/api/v1/health" --resolve "$ATLAS_HOSTNAME.$ATLAS_DOMINIO:443:$ATLAS_IP" \
  && echo && paso "HTTPS verificado contra ATLAS-CA (sin -k)." || aviso "No se pudo comprobar HTTPS; revisar 'sudo atlas-ctl logs atlas-web'."
