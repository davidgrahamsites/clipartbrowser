// Renderer-side document text extraction, mirroring the macOS
// DocumentTextExtractor: docx, txt, rtf, pdf, and image OCR.
const JSZip = require("jszip");

const IMAGE_EXTS = new Set([
  "bmp", "gif", "heic", "heif", "jpeg", "jpg", "png", "tif", "tiff", "webp",
]);

const SUPPORTED_EXTS = new Set([
  "docx", "pdf", "rtf", "txt", ...IMAGE_EXTS,
]);

function extOf(name) {
  return name.toLowerCase().split(".").pop();
}

function isSupported(name) {
  return SUPPORTED_EXTS.has(extOf(name));
}

async function extractDocx(arrayBuffer) {
  const zip = await JSZip.loadAsync(arrayBuffer);
  const entry = zip.file("word/document.xml");
  if (!entry) throw new Error("DOCX missing word/document.xml");
  const xml = await entry.async("string");
  const doc = new DOMParser().parseFromString(xml, "application/xml");
  let out = "";
  const appendBreak = () => {
    if (!out.endsWith("\n")) out += "\n";
  };
  const walk = (node) => {
    for (const child of node.childNodes) {
      if (child.nodeType !== 1) continue;
      const ln = child.localName;
      if (ln === "t") {
        out += child.textContent;
      } else if (ln === "tab") {
        out += "\t";
      } else if (ln === "br" || ln === "cr") {
        appendBreak();
      } else {
        walk(child);
        if (ln === "p") appendBreak();
      }
    }
  };
  walk(doc.documentElement);
  return out.trim();
}

function extractRtf(text) {
  return text
    .replace(/\{\\\*[^{}]*\}/g, "")
    .replace(/\\par[d]?\b/g, "\n")
    .replace(/\\line\b/g, "\n")
    .replace(/\\tab\b/g, "\t")
    .replace(/\\[a-zA-Z]+-?\d* ?/g, "")
    .replace(/[{}]/g, "")
    .replace(/\r/g, "")
    .trim();
}

async function extractPdf(arrayBuffer) {
  // Best-effort; pdf is a secondary input format.
  const pdfjs = require("pdfjs-dist/legacy/build/pdf.js");
  try {
    const { pathToFileURL } = require("url");
    pdfjs.GlobalWorkerOptions.workerSrc = pathToFileURL(
      require.resolve("pdfjs-dist/legacy/build/pdf.worker.js")
    ).href;
  } catch (e) {
    /* worker optional */
  }
  const pdf = await pdfjs.getDocument({
    data: new Uint8Array(arrayBuffer),
    isEvalSupported: false,
  }).promise;
  const pages = [];
  for (let p = 1; p <= pdf.numPages; p++) {
    const page = await pdf.getPage(p);
    const content = await page.getTextContent();
    pages.push(content.items.map((i) => i.str).join(" "));
  }
  return pages.join("\n").trim();
}

async function extractImageOCR(file, onProgress) {
  const { createWorker } = require("tesseract.js");
  const worker = await createWorker("eng", 1, {
    logger: (m) => {
      if (onProgress && m.status === "recognizing text") onProgress(m.progress);
    },
  });
  try {
    const { data } = await worker.recognize(file);
    return (data.text || "").trim();
  } finally {
    await worker.terminate();
  }
}

// file: a File (from <input> or drag-drop). onProgress(0..1) for OCR.
async function extractText(file, onProgress) {
  const ext = extOf(file.name);
  if (ext === "docx") return extractDocx(await file.arrayBuffer());
  if (ext === "pdf") return extractPdf(await file.arrayBuffer());
  if (ext === "rtf") return extractRtf(await file.text());
  if (IMAGE_EXTS.has(ext)) return extractImageOCR(file, onProgress);
  return file.text();
}

module.exports = { extractText, isSupported, IMAGE_EXTS, SUPPORTED_EXTS };
