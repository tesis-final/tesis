// Helpers del informe de Testing en Word, con formato APA 7 (trabajo de estudiante).
// Mismo formato que el informe del Hito 2 de Testing: Times New Roman 12, interlineado doble,
// márgenes de 2,54 cm, tablas y figuras APA, y el encabezado con los logos de ANEP-UTU e ITI-CETP.
const fs = require('fs');
const path = require('path');
const {
  Document, Packer, Paragraph, TextRun, ImageRun, Table, TableRow, TableCell, Header,
  AlignmentType, HeadingLevel, WidthType, BorderStyle, PageNumber, PageBreak, LevelFormat,
  VerticalAlign, TableLayoutType, LineRuleType, TabStopType,
} = require('docx');

const IMG = path.join(__dirname, 'img');
const RAIZ = path.resolve(__dirname, '../../..');
const FUENTE = 'Times New Roman';
const CM = 567;                       // DXA por centímetro
const SANGRIA = Math.round(1.27 * CM); // 720
const ANCHO = 11906 - 2 * 1440;        // A4 menos márgenes de 2,54 cm = 9026 DXA
const DOBLE = { line: 480, lineRule: LineRuleType.AUTO, before: 0, after: 0 };
const SIMPLE = { line: 240, lineRule: LineRuleType.AUTO, before: 0, after: 0 };

// Texto con *cursiva* y **negrita** simples.
function runs(texto, base = {}) {
  const partes = [];
  const re = /(\*\*[^*]+\*\*|\*[^*]+\*)/g;
  let ultimo = 0, m;
  while ((m = re.exec(texto))) {
    if (m.index > ultimo) partes.push(new TextRun({ text: texto.slice(ultimo, m.index), ...base }));
    const t = m[0];
    if (t.startsWith('**')) partes.push(new TextRun({ text: t.slice(2, -2), bold: true, ...base }));
    else partes.push(new TextRun({ text: t.slice(1, -1), italics: true, ...base }));
    ultimo = m.index + t.length;
  }
  if (ultimo < texto.length) partes.push(new TextRun({ text: texto.slice(ultimo), ...base }));
  return partes;
}

const P = (t) => new Paragraph({ children: runs(t), spacing: DOBLE, indent: { firstLine: SANGRIA } });
const PSin = (t, extra = {}) => new Paragraph({ children: runs(t), spacing: DOBLE, ...extra });
const Centro = (t, extra = {}) => new Paragraph({ children: runs(t), alignment: AlignmentType.CENTER, spacing: DOBLE, ...extra });
const Vacio = () => new Paragraph({ children: [], spacing: DOBLE });
const Salto = () => new Paragraph({ children: [new PageBreak()], spacing: SIMPLE });

// Niveles de encabezado APA 7: 1 centrado negrita; 2 izquierda negrita; 3 izquierda negrita cursiva.
const H1 = (t) => new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun(t)], alignment: AlignmentType.CENTER, spacing: DOBLE, keepNext: true });
const H2 = (t) => new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun(t)], spacing: DOBLE, keepNext: true });
const H3 = (t) => new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun(t)], spacing: DOBLE, keepNext: true });

// Lista numerada (seriación APA con números).
let listas = 0;
const configNumeracion = [];
function Numerada(items) {
  const ref = `lista${++listas}`;
  configNumeracion.push({
    reference: ref,
    levels: [{ level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT,
      style: { paragraph: { indent: { left: SANGRIA * 2, hanging: SANGRIA / 2 } } } }],
  });
  return items.map((t) => new Paragraph({ children: runs(t), numbering: { reference: ref, level: 0 }, spacing: DOBLE }));
}

// Tablas APA: número en negrita, título en cursiva, solo líneas horizontales.
let nTabla = 0;
const NADA = { style: BorderStyle.NONE, size: 0, color: 'auto' };
const LINEA = { style: BorderStyle.SINGLE, size: 6, color: '000000' };
function Tabla(titulo, encabezados, filas, proporciones, nota, prefijo = '') {
  nTabla++;
  const etiqueta = prefijo ? `Tabla ${prefijo}${nTabla - (Tabla.base || 0)}` : `Tabla ${nTabla}`;
  const total = proporciones.reduce((a, b) => a + b, 0);
  const anchos = proporciones.map((p) => Math.floor((p / total) * ANCHO));
  anchos[anchos.length - 1] += ANCHO - anchos.reduce((a, b) => a + b, 0);
  const celda = (texto, i, { cabecera = false, ultima = false } = {}) => new TableCell({
    width: { size: anchos[i], type: WidthType.DXA },
    margins: { top: 50, bottom: 50, left: 80, right: 80 },
    verticalAlign: VerticalAlign.TOP,
    borders: {
      top: cabecera ? LINEA : NADA,
      bottom: cabecera || ultima ? LINEA : NADA,
      left: NADA, right: NADA,
    },
    children: String(texto).split('\n').map((linea) => new Paragraph({
      children: runs(linea, { size: 20 }), spacing: SIMPLE,
    })),
  });
  const tabla = new Table({
    width: { size: ANCHO, type: WidthType.DXA },
    columnWidths: anchos,
    layout: TableLayoutType.FIXED,
    borders: { top: NADA, bottom: NADA, left: NADA, right: NADA, insideHorizontal: NADA, insideVertical: NADA },
    rows: [
      new TableRow({ tableHeader: true, cantSplit: true, children: encabezados.map((e, i) => celda(e, i, { cabecera: true })) }),
      ...filas.map((f, k) => new TableRow({ cantSplit: true, children: f.map((c, i) => celda(c, i, { ultima: k === filas.length - 1 })) })),
    ],
  });
  const salida = [
    new Paragraph({ children: [new TextRun({ text: etiqueta, bold: true })], spacing: DOBLE, keepNext: true }),
    new Paragraph({ children: [new TextRun({ text: titulo, italics: true })], spacing: DOBLE, keepNext: true }),
    tabla,
  ];
  if (nota) salida.push(new Paragraph({ children: [new TextRun({ text: 'Nota.', italics: true }), ...runs(' ' + nota)], spacing: DOBLE }));
  else salida.push(Vacio());
  return salida;
}

// Figuras APA: número en negrita, título en cursiva, imagen y nota debajo.
let nFigura = 0;
function Figura(archivo, ancho, alto, titulo, nota, maxAncho = 560, maxAlto = 600) {
  nFigura++;
  const escala = Math.min(maxAncho / ancho, maxAlto / alto, 1);
  return [
    new Paragraph({ children: [new TextRun({ text: `Figura ${nFigura}`, bold: true })], spacing: DOBLE, keepNext: true }),
    new Paragraph({ children: [new TextRun({ text: titulo, italics: true })], spacing: DOBLE, keepNext: true }),
    new Paragraph({
      alignment: AlignmentType.CENTER, spacing: SIMPLE, keepNext: true,
      children: [new ImageRun({
        type: 'png', data: fs.readFileSync(archivo.includes('/') ? path.join(RAIZ, archivo) : path.join(IMG, archivo)),
        transformation: { width: Math.round(ancho * escala), height: Math.round(alto * escala) },
        altText: { title: `Figura ${nFigura}`, description: titulo, name: path.basename(archivo) },
      })],
    }),
    new Paragraph({ children: [new TextRun({ text: 'Nota.', italics: true }), ...runs(' ' + nota)], spacing: DOBLE }),
  ];
}

// Bloque de salida de consola, en letra de ancho fijo y sin sombreado.
const Consola = (lineas) => lineas.map((l) => new Paragraph({
  children: [new TextRun({ text: l || ' ', font: 'Courier New', size: 18 })], spacing: SIMPLE,
}));

// Referencias con sangría francesa.
const Ref = (t) => new Paragraph({ children: runs(t), spacing: DOBLE, indent: { left: SANGRIA, hanging: SANGRIA } });

// Tamaño real de un PNG (ancho y alto en píxeles).
function tamano(archivo) {
  const b = fs.readFileSync(archivo.includes('/') ? path.join(RAIZ, archivo) : path.join(IMG, archivo));
  return { ancho: b.readUInt32BE(16), alto: b.readUInt32BE(20) };
}
const Fig = (archivo, titulo, nota, maxAncho, maxAlto) => {
  const t = tamano(archivo);
  return Figura(archivo, t.ancho, t.alto, titulo, nota, maxAncho, maxAlto);
};

// Encabezado de todas las páginas, como en el Hito 2: número de página arriba a la derecha y
// debajo los logos de ANEP-UTU (izquierda) e ITI-CETP (derecha).
function encabezado() {
  const logo = (archivo, ancho, alto, nombre) => new ImageRun({
    type: 'png', data: fs.readFileSync(path.join(IMG, archivo)), transformation: { width: ancho, height: alto },
    altText: { title: nombre, description: nombre, name: archivo },
  });
  return new Header({ children: [
    new Paragraph({ alignment: AlignmentType.RIGHT, spacing: SIMPLE, children: [new TextRun({ children: [PageNumber.CURRENT] })] }),
    new Paragraph({
      spacing: { ...SIMPLE, after: 120 },
      tabStops: [{ type: TabStopType.RIGHT, position: ANCHO }],
      children: [logo('logo-anep-utu.png', 250, 39, 'ANEP - UTU, Dirección General de Educación Técnico Profesional'),
        new TextRun({ text: '\t' }), logo('logo-iti-cetp.png', 134, 39, 'ITI CETP, Instituto Tecnológico de Informática')],
    }),
  ] });
}

function documento(titulo, contenido) {
  return new Document({
    creator: 'Grupo Error404',
    title: titulo,
    styles: {
      default: { document: { run: { font: FUENTE, size: 24, color: '000000' }, paragraph: { spacing: DOBLE } } },
      paragraphStyles: [
        { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true,
          run: { font: FUENTE, size: 24, bold: true, color: '000000' },
          paragraph: { alignment: AlignmentType.CENTER, spacing: DOBLE, outlineLevel: 0 } },
        { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true,
          run: { font: FUENTE, size: 24, bold: true, color: '000000' },
          paragraph: { spacing: DOBLE, outlineLevel: 1 } },
        { id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal', quickFormat: true,
          run: { font: FUENTE, size: 24, bold: true, italics: true, color: '000000' },
          paragraph: { spacing: DOBLE, outlineLevel: 2 } },
      ],
    },
    numbering: { config: configNumeracion },
    sections: [{
      properties: { page: { size: { width: 11906, height: 16838 }, margin: { top: 1440, bottom: 1440, left: 1440, right: 1440, header: 567 } } },
      headers: { default: encabezado() },
      children: contenido,
    }],
  });
}

module.exports = {
  fs, path, Packer, Paragraph, TextRun, AlignmentType, SANGRIA, DOBLE, SIMPLE,
  runs, P, PSin, Centro, Vacio, Salto, H1, H2, H3, Numerada, Tabla, Figura, Fig, Consola, Ref, documento,
  get nTabla() { return nTabla; },
};
