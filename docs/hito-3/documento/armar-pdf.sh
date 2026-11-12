#!/usr/bin/env bash
# =============================================================================
# ATLAS — arma el Documento integrador V3.0 (Hito 3) en Word y en un único PDF.
#
#   1. generar-integrador.js → docs/hito-3/ATLAS_Documento_integrador_V3.0.docx
#   2. LibreOffice convierte el .docx a PDF
#   3. pdfunite agrega al final el informe de Redes del Hito 2 (Anexo E, 109 figuras)
#      → docs/hito-3/ATLAS_Documento_integrador_V3.0.pdf
#
# Requisitos: Node.js con el paquete docx, LibreOffice (soffice) y poppler-utils (pdfunite).
# Uso: docs/hito-3/documento/armar-pdf.sh
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/../../.."
SALIDA=docs/hito-3
TMP=$(mktemp -d); trap 'rm -rf "${TMP:?}"' EXIT
NODE_PATH="${NODE_PATH:-$(npm root -g)}" node docs/hito-3/documento/generar-integrador.js "$SALIDA/ATLAS_Documento_integrador_V3.0.docx"
soffice --headless --convert-to pdf --outdir "$TMP" "$SALIDA/ATLAS_Documento_integrador_V3.0.docx" >/dev/null
pdfunite "$TMP/ATLAS_Documento_integrador_V3.0.pdf" Hito2_Redes_ATLAS_v2.pdf "$SALIDA/ATLAS_Documento_integrador_V3.0.pdf"
echo "Cuerpo: $(pdfinfo "$TMP/ATLAS_Documento_integrador_V3.0.pdf" | awk '/^Pages/ {print $2}') páginas · con el Anexo E: $(pdfinfo "$SALIDA/ATLAS_Documento_integrador_V3.0.pdf" | awk '/^Pages/ {print $2}') páginas"
ls -lh "$SALIDA"/ATLAS_Documento_integrador_V3.0.*
