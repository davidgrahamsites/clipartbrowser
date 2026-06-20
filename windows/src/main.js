const { app, BrowserWindow, ipcMain } = require("electron");
const path = require("path");
const sizeOf = require("image-size");

// Desktop Chrome UA so the engines serve their full layouts and full-size
// images (the same reason the macOS app sets a desktop Safari UA).
const USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 860,
    title: "ClipartBrowser",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      webviewTag: true,
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  });
  win.loadFile(path.join(__dirname, "index.html"));
}

async function fetchImage(url, referer) {
  if (!url) return null;
  try {
    const headers = {
      "User-Agent": USER_AGENT,
      Accept: "image/avif,image/webp,image/png,image/jpeg,image/*;q=0.8,*/*;q=0.5",
    };
    if (referer) headers.Referer = referer;
    const res = await fetch(url, { headers, signal: AbortSignal.timeout(15000) });
    if (!res.ok) return null;
    const buf = Buffer.from(await res.arrayBuffer());
    let dim;
    try {
      dim = sizeOf(buf);
    } catch (e) {
      return null;
    }
    if (!dim || !dim.width || !dim.height) return null;
    return { buf, width: dim.width, height: dim.height, type: dim.type };
  } catch (e) {
    return null;
  }
}

function mimeFor(type) {
  switch (type) {
    case "png":
      return "image/png";
    case "jpg":
    case "jpeg":
      return "image/jpeg";
    case "gif":
      return "image/gif";
    case "webp":
      return "image/webp";
    default:
      return "image/png";
  }
}

// Download both candidates (full + thumbnail) and keep whichever decodes to the
// bigger image — the same "bigger of the two" rule as the macOS app.
ipcMain.handle("download-bigger", async (_event, { imageURL, thumbnailURL, referer }) => {
  const [primary, fallback] = await Promise.all([
    fetchImage(imageURL, referer),
    thumbnailURL ? fetchImage(thumbnailURL, referer) : Promise.resolve(null),
  ]);
  const candidates = [primary, fallback].filter(Boolean);
  if (candidates.length === 0) return null;
  const best = candidates.reduce((m, c) =>
    c.width * c.height > m.width * m.height ? c : m
  );
  return {
    dataURL: `data:${mimeFor(best.type)};base64,${best.buf.toString("base64")}`,
    width: best.width,
    height: best.height,
  };
});

app.whenReady().then(() => {
  createWindow();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
