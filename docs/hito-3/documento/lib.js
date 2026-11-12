// Formato APA 7 para el documento integrador de ATLAS (docx). Times New Roman 12, interlineado
// doble, márgenes de 2,54 cm, número de página arriba a la derecha, encabezados de cinco
// niveles, tablas y figuras numeradas con título en cursiva y nota debajo.
// El contenido se arma como una lista de bloques; al final se numeran tablas y figuras en orden
// de aparición y se resuelven las referencias {T:clave} y {F:clave} del texto.
const fs = require('fs');
const path = require('path');
const {
  Paragraph, TextRun, ImageRun, Table, TableRow, TableCell, AlignmentType, HeadingLevel,
  WidthType, BorderStyle, PageBreak, LevelFormat, VerticalAlign, TableLayoutType, LineRuleType,
  ExternalHyperlink,
} = require('docx');

const RAIZ = path.resolve(__dirname, '../../..');
const FUENTE = 'Times New Roman';
const CM = 567;
const SANGRIA = Math.round(1.27 * CM);
const ANCHO = 11906 - 2 * 1440;
const DOBLE = { line: 480, lineRule: LineRuleType.AUTO, before: 0, after: 0 };
const SIMPLE = { line: 240, lineRule: LineRuleType.AUTO, before: 0, after: 0 };

const bloques = [];
const add = (...b) => bloques.push(...b);

// --- bloques -------------------------------------------------------------------------------
const P = (t) => ({ k: 'p', t });
const PSin = (t) => ({ k: 'psin', t });
const Centro = (t, o = {}) => ({ k: 'centro', t, ...o });
const H1 = (t) => ({ k: 'h1', t });
const H2 = (t) => ({ k: 'h2', t });
const H3 = (t) => ({ k: 'h3', t });
const Vineta = (items) => ({ k: 'vineta', items });
const Lista = (items) => ({ k: 'lista', items });
const Salto = () => ({ k: 'salto' });
const Vacio = () => ({ k: 'vacio' });
const Consola = (lineas) => ({ k: 'consola', lineas });
const Ref = (t, url) => ({ k: 'ref', t, url });
// Tabla: clave (para referencias), título, encabezados, filas, proporciones, nota, etiqueta fija (anexos)
const Tabla = (clave, titulo, enc, filas, prop, nota, etiqueta) => ({ k: 'tabla', clave, titulo, enc, filas, prop, nota, etiqueta });
// Figura: archivo relativo a la raíz del repositorio
const Figura = (clave, archivo, titulo, nota, o = {}) => ({ k: 'figura', clave, archivo, titulo, nota, ...o });
const Logo = (archivo, ancho) => ({ k: 'logo', archivo, ancho });

// --- numeración y referencias ----------------------------------------------------------------
function numerar() {
  const mapa = {};
  let nt = 0, nf = 0;
  for (const b of bloques) {
    if (b.k === 'tabla') { b.n = b.etiqueta || `Tabla ${++nt}`; if (b.clave) mapa[`T:${b.clave}`] = b.n; }
    if (b.k === 'figura') { b.n = b.etiqueta || `Figura ${++nf}`; if (b.clave) mapa[`F:${b.clave}`] = b.n; }
  }
  const resolver = (s) => typeof s !== 'string' ? s : s.replace(/\{([TF]:[\w-]+)\}/g, (m, c) => {
    if (!mapa[c]) throw new Error(`Referencia sin destino: ${c}`);
    return mapa[c];
  });
  for (const b of bloques) {
    for (const campo of ['t', 'titulo', 'nota']) if (b[campo]) b[campo] = resolver(b[campo]);
    if (b.items) b.items = b.items.map(resolver);
    if (b.filas) b.filas = b.filas.map((f) => f.map(resolver));
  }
  return { tablas: nt, figuras: nf };
}

// --- render ---------------------------------------------------------------------------------
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

function tamanoPng(archivo) {
  const b = fs.readFileSync(archivo);
  if (b.toString('ascii', 1, 4) !== 'PNG') throw new Error(`No es PNG: ${archivo}`);
  return { ancho: b.readUInt32BE(16), alto: b.readUInt32BE(20), datos: b };
}

const NADA = { style: BorderStyle.NONE, size: 0, color: 'auto' };
const LINEA = { style: BorderStyle.SINGLE, size: 6, color: '000000' };
const numeraciones = [];
let nLista = 0;

function render() {
  const out = [];
  for (const b of bloques) {
    switch (b.k) {
      case 'p': out.push(new Paragraph({ children: runs(b.t), spacing: DOBLE, indent: { firstLine: SANGRIA } })); break;
      case 'psin': out.push(new Paragraph({ children: runs(b.t), spacing: DOBLE })); break;
      case 'centro': out.push(new Paragraph({ children: runs(b.t, b.tam ? { size: b.tam } : {}), alignment: AlignmentType.CENTER, spacing: b.simple ? SIMPLE : DOBLE, keepNext: !!b.junto })); break;
      case 'h1': out.push(new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun(b.t)], alignment: AlignmentType.CENTER, spacing: DOBLE, keepNext: true })); break;
      case 'h2': out.push(new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun(b.t)], spacing: DOBLE, keepNext: true })); break;
      case 'h3': out.push(new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun(b.t)], spacing: DOBLE, keepNext: true })); break;
      case 'salto': out.push(new Paragraph({ children: [new PageBreak()], spacing: SIMPLE })); break;
      case 'vacio': out.push(new Paragraph({ children: [], spacing: DOBLE })); break;
      case 'vineta':
        for (const it of b.items) out.push(new Paragraph({ children: runs(it), bullet: { level: 0 }, spacing: DOBLE }));
        break;
      case 'lista': {
        const ref = `lista${++nLista}`;
        numeraciones.push({ reference: ref, levels: [{ level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: SANGRIA * 2, hanging: SANGRIA / 2 } } } }] });
        for (const it of b.items) out.push(new Paragraph({ children: runs(it), numbering: { reference: ref, level: 0 }, spacing: DOBLE }));
        break;
      }
      case 'consola':
        for (const l of b.lineas) out.push(new Paragraph({ children: [new TextRun({ text: l || ' ', font: 'Courier New', size: 15 })], spacing: SIMPLE, keepLines: true }));
        out.push(new Paragraph({ children: [], spacing: SIMPLE }));
        break;
      case 'ref': {
        const hijos = runs(b.t);
        if (b.url) hijos.push(new ExternalHyperlink({ link: b.url, children: [new TextRun({ text: b.url })] }));
        out.push(new Paragraph({ children: hijos, spacing: DOBLE, indent: { left: SANGRIA, hanging: SANGRIA } }));
        break;
      }
      case 'logo': {
        const { ancho, alto, datos } = tamanoPng(path.join(RAIZ, b.archivo));
        const w = b.ancho; const h = Math.round((alto / ancho) * w);
        out.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: SIMPLE, children: [new ImageRun({ type: 'png', data: datos, transformation: { width: w, height: h }, altText: { title: 'Logotipo de ATLAS', description: 'Logotipo de ATLAS', name: 'logotipo' } })] }));
        break;
      }
      case 'tabla': out.push(...tabla(b)); break;
      case 'figura': out.push(...figura(b)); break;
      default: throw new Error(`Bloque desconocido: ${b.k}`);
    }
  }
  return out;
}

function tabla(b) {
  const total = b.prop.reduce((a, c) => a + c, 0);
  const anchos = b.prop.map((p) => Math.floor((p / total) * ANCHO));
  anchos[anchos.length - 1] += ANCHO - anchos.reduce((a, c) => a + c, 0);
  if (b.enc.length !== b.prop.length) throw new Error(`Tabla «${b.titulo}»: columnas y proporciones no coinciden`);
  b.filas.forEach((f, i) => { if (f.length !== b.enc.length) throw new Error(`Tabla «${b.titulo}», fila ${i + 1}: ${f.length} celdas en lugar de ${b.enc.length}`); });
  const celda = (texto, i, { cab = false, ultima = false } = {}) => new TableCell({
    width: { size: anchos[i], type: WidthType.DXA },
    margins: { top: 40, bottom: 40, left: 70, right: 70 },
    verticalAlign: VerticalAlign.TOP,
    borders: { top: cab ? LINEA : NADA, bottom: cab || ultima ? LINEA : NADA, left: NADA, right: NADA },
    children: String(texto).split('\n').map((linea) => new Paragraph({ children: runs(linea, { size: 20, bold: cab || undefined }), spacing: SIMPLE })),
  });
  return [
    new Paragraph({ children: [new TextRun({ text: b.n, bold: true })], spacing: DOBLE, keepNext: true }),
    new Paragraph({ children: [new TextRun({ text: b.titulo, italics: true })], spacing: DOBLE, keepNext: true }),
    new Table({
      width: { size: ANCHO, type: WidthType.DXA }, columnWidths: anchos, layout: TableLayoutType.FIXED,
      borders: { top: NADA, bottom: NADA, left: NADA, right: NADA, insideHorizontal: NADA, insideVertical: NADA },
      rows: [
        new TableRow({ tableHeader: true, cantSplit: true, children: b.enc.map((e, i) => celda(e, i, { cab: true })) }),
        ...b.filas.map((f, k) => new TableRow({ cantSplit: true, children: f.map((c, i) => celda(c, i, { ultima: k === b.filas.length - 1 })) })),
      ],
    }),
    b.nota
      ? new Paragraph({ children: [new TextRun({ text: 'Nota.', italics: true }), ...runs(' ' + b.nota)], spacing: DOBLE })
      : new Paragraph({ children: [], spacing: DOBLE }),
  ];
}

function figura(b) {
  const { ancho, alto, datos } = tamanoPng(path.join(RAIZ, b.archivo));
  const maxA = b.maxAncho || 600, maxH = b.maxAlto || 640;
  const k = Math.min(maxA / ancho, maxH / alto, 1);
  return [
    new Paragraph({ children: [new TextRun({ text: b.n, bold: true })], spacing: DOBLE, keepNext: true }),
    new Paragraph({ children: [new TextRun({ text: b.titulo, italics: true })], spacing: DOBLE, keepNext: true }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: SIMPLE, keepNext: true, children: [new ImageRun({
      type: 'png', data: datos, transformation: { width: Math.round(ancho * k), height: Math.round(alto * k) },
      altText: { title: b.n, description: b.titulo, name: path.basename(b.archivo) } })] }),
    new Paragraph({ children: [new TextRun({ text: 'Nota.', italics: true }), ...runs(' ' + b.nota)], spacing: DOBLE }),
  ];
}

module.exports = {
  RAIZ, FUENTE, DOBLE, SIMPLE, add, bloques, numerar, render, numeraciones,
  P, PSin, Centro, H1, H2, H3, Vineta, Lista, Salto, Vacio, Consola, Ref, Tabla, Figura, Logo,
};
