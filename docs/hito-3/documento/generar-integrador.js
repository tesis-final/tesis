// Genera el Documento integrador de ATLAS (V3.0, Hito 3) en Word con formato APA 7.
// Uso: NODE_PATH=$(npm root -g) node docs/hito-3/documento/generar-integrador.js [salida.docx]
const fs = require('fs');
const path = require('path');
const { Document, Packer, Paragraph, TextRun, Header, AlignmentType, PageNumber } = require('docx');
const L = require('./lib');
require('./contenido-1');
require('./contenido-2');
require('./contenido-3');
require('./contenido-4');
require('./anexos');

const cuenta = L.numerar();
const hijos = L.render();
const encabezado = new Header({ children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun({ children: [PageNumber.CURRENT] })] })] });
const estilo = (id, nombre, extra) => ({ id, name: nombre, basedOn: 'Normal', next: 'Normal', quickFormat: true,
  run: { font: L.FUENTE, size: 24, bold: true, color: '000000', ...extra.run }, paragraph: { spacing: L.DOBLE, ...extra.paragraph } });
const doc = new Document({
  creator: 'Grupo Error404',
  title: 'ATLAS - Documento integrador V3.0 (Hito 3)',
  description: 'Proyecto final de egreso, Tecnicatura en Redes y Software, ITI-CETP/UTU',
  styles: {
    default: { document: { run: { font: L.FUENTE, size: 24, color: '000000' }, paragraph: { spacing: L.DOBLE } } },
    paragraphStyles: [
      estilo('Heading1', 'Heading 1', { paragraph: { alignment: AlignmentType.CENTER, outlineLevel: 0 } }),
      estilo('Heading2', 'Heading 2', { paragraph: { outlineLevel: 1 } }),
      estilo('Heading3', 'Heading 3', { run: { italics: true }, paragraph: { outlineLevel: 2 } }),
    ],
  },
  numbering: { config: [...L.numeraciones, { reference: 'vinetas', levels: [{ level: 0, format: 'bullet', text: '•', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 1080, hanging: 360 } } } }] }] },
  sections: [{
    properties: { page: { size: { width: 11906, height: 16838 }, margin: { top: 1440, bottom: 1440, left: 1440, right: 1440, header: 720 } } },
    headers: { default: encabezado },
    children: hijos,
  }],
});
const salida = process.argv[2] || path.join(L.RAIZ, 'docs/hito-3/ATLAS_Documento_integrador_V3.0.docx');
Packer.toBuffer(doc).then((b) => { fs.writeFileSync(salida, b); console.log(`ok ${salida} · ${cuenta.tablas} tablas y ${cuenta.figuras} figuras numeradas en el cuerpo`); });
