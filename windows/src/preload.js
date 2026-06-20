const { contextBridge, ipcRenderer } = require("electron");
const path = require("path");
const { pathToFileURL } = require("url");
const engines = require("./engines");

const USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

contextBridge.exposeInMainWorld("api", {
  webviewPreload: pathToFileURL(path.join(__dirname, "webview-preload.js")).href,
  userAgent: USER_AGENT,
  engines: engines.ALL,
  searchURL: (engine, term) => engines.searchURL(engine, term),
  downloadBigger: (args) => ipcRenderer.invoke("download-bigger", args),
});
