const { app, BrowserWindow, ipcMain, dialog } = require("electron");
const path = require("path");
const fs = require("fs");
const sizeOf = require("image-size");
const license = require("./license");

// Desktop Chrome UA so the engines serve their full layouts and full-size
// images (the same reason the macOS app sets a desktop Safari UA).
const USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 860,
    title: "剪贴画浏览器",
    webPreferences: {
      webviewTag: true,
      nodeIntegration: true,
      contextIsolation: false,
      sandbox: false,
    },
  });
  // Hard-block behind the one-per-computer license.
  const page = license.isLicensed(app) ? "index.html" : "activation.html";
  win.loadFile(path.join(__dirname, page));
}

// Licensing IPC (used by activation.html).
ipcMain.handle("license:fingerprint", () => license.machineFingerprint());
ipcMain.handle("license:activate", (_event, key) => {
  if (license.verify(key, license.machineFingerprint())) {
    license.saveKey(app, key);
    return true;
  }
  return false;
});
ipcMain.handle("license:reload", () => {
  const win = BrowserWindow.getFocusedWindow() || BrowserWindow.getAllWindows()[0];
  if (win) win.loadFile(path.join(__dirname, "index.html"));
});

// Ask the user where to save; returns the chosen path + extension so the
// renderer can build the right format (e.g. .txt vs .docx).
ipcMain.handle("pick-save-path", async (_event, { defaultName, filters }) => {
  const win = BrowserWindow.getFocusedWindow();
  const { canceled, filePath } = await dialog.showSaveDialog(win, {
    defaultPath: defaultName,
    filters,
  });
  if (canceled || !filePath) return { canceled: true };
  return {
    canceled: false,
    filePath,
    name: path.basename(filePath),
    ext: path.extname(filePath).replace(".", "").toLowerCase(),
  };
});

ipcMain.handle("write-file", async (_event, { filePath, base64 }) => {
  await fs.promises.writeFile(filePath, Buffer.from(base64, "base64"));
  return { name: path.basename(filePath) };
});

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
