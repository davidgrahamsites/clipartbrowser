// Renderer-side image processing: white-trim, fit-to-slide pixel size, and
// upscale. Mirrors the macOS ImageTrimmer + ImageUpscaler + fittedImagePixelSize.
const { fittedImageFrame, EMU_PER_PX } = require("./pptx");

let picaInstance = null;
function pica() {
  if (!picaInstance) {
    try {
      picaInstance = require("pica")();
    } catch (e) {
      picaInstance = false;
    }
  }
  return picaInstance;
}

function loadImage(src) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error("image decode failed"));
    img.src = src;
  });
}

function canvasFromImage(img) {
  const c = document.createElement("canvas");
  c.width = img.naturalWidth || img.width;
  c.height = img.naturalHeight || img.height;
  c.getContext("2d").drawImage(img, 0, 0);
  return c;
}

function trimWhite(canvas, tolerance = 245) {
  const w = canvas.width;
  const h = canvas.height;
  if (w === 0 || h === 0) return canvas;
  const ctx = canvas.getContext("2d");
  const data = ctx.getImageData(0, 0, w, h).data;
  let minX = w;
  let minY = h;
  let maxX = -1;
  let maxY = -1;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const o = (y * w + x) * 4;
      const a = data[o + 3];
      const r = data[o];
      const g = data[o + 1];
      const b = data[o + 2];
      const transparent = a <= 8;
      const white = r >= tolerance && g >= tolerance && b >= tolerance;
      if (transparent || white) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < minX || maxY < minY) return canvas; // all white/transparent
  const cw = maxX - minX + 1;
  const ch = maxY - minY + 1;
  const out = document.createElement("canvas");
  out.width = cw;
  out.height = ch;
  out.getContext("2d").drawImage(canvas, minX, minY, cw, ch, 0, 0, cw, ch);
  return out;
}

function fittedPixelSize(width, height, settings) {
  const frame = fittedImageFrame(
    { pixelWidth: width, pixelHeight: height },
    settings.paddingPixels,
    settings.orientation,
    settings.showsTextLabel
  );
  return {
    width: Math.max(1, Math.round(frame.width / EMU_PER_PX)),
    height: Math.max(1, Math.round(frame.height / EMU_PER_PX)),
  };
}

async function upscale(srcCanvas, targetW, targetH, method) {
  // Upscale-only: never shrink below the source.
  if (Math.max(targetW, targetH) <= Math.max(srcCanvas.width, srcCanvas.height)) {
    return srcCanvas;
  }
  const out = document.createElement("canvas");
  out.width = targetW;
  out.height = targetH;

  if (method === "coreImage" && pica()) {
    try {
      await pica().resize(srcCanvas, out, { filter: "lanczos3" });
      return out;
    } catch (e) {
      /* fall through to canvas */
    }
  }
  const ctx = out.getContext("2d");
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = method === "vImage" ? "medium" : "high";
  ctx.drawImage(srcCanvas, 0, 0, targetW, targetH);
  return out;
}

function toBase64(canvas) {
  return canvas.toDataURL("image/png").split(",")[1];
}

// Returns the processed (trimmed + upscaled) image plus the pre-upscale source.
async function processPicked(dataURL, settings, method) {
  const img = await loadImage(dataURL);
  const full = canvasFromImage(img);
  const trimmed = trimWhite(full);
  const target = fittedPixelSize(trimmed.width, trimmed.height, settings);
  const up = await upscale(trimmed, target.width, target.height, method);
  const base64 = toBase64(up);
  return {
    dataURL: "data:image/png;base64," + base64,
    base64,
    ext: "png",
    pixelWidth: up.width,
    pixelHeight: up.height,
    sourceDataURL: "data:image/png;base64," + toBase64(trimmed),
    sourceWidth: trimmed.width,
    sourceHeight: trimmed.height,
  };
}

module.exports = { processPicked, trimWhite, fittedPixelSize };
