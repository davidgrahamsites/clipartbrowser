const { ipcRenderer } = require("electron");
const path = require("path");
const { pathToFileURL } = require("url");

const engines = require("./lib/engines");
const vocabulary = require("./lib/vocabulary");
const extract = require("./lib/extract");
const imageproc = require("./lib/imageproc");
const pptx = require("./lib/pptx");
const wordlist = require("./lib/wordlist");

const USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

const state = {
  words: [],
  cards: [],
  docName: null,
  padding: 12,
  orientation: "portrait",
  showLabels: true,
  upscaler: "coreImage",
  engine: localStorage.getItem("engine") || "google",
  tabs: [],
  tabIndex: 0,
  browsing: false,
  selectedCardId: null,
  importing: false,
  lastLoadKey: null,
  browserZoom: parseFloat(localStorage.getItem("zoom")) || 0.6,
  previewPanels: [],
};

const METHODS = [
  { id: "coreImage", name: "最清晰" },
  { id: "coreGraphics", name: "平衡" },
  { id: "vImage", name: "最快" },
  { id: "appKit", name: "最平滑" },
];

let nextId = 1;
const $ = (id) => document.getElementById(id);

function setStatus(text) {
  $("statusText").textContent = text;
}

function settingsForProc() {
  return {
    paddingPixels: state.padding,
    orientation: state.orientation,
    showsTextLabel: state.showLabels,
  };
}

// ---------- 词语 ----------
function renderWords() {
  $("docName").textContent = state.docName ? state.docName : "导入文档以查找词汇。";
  const list = $("wordList");
  list.innerHTML = "";
  if (state.words.length === 0) {
    const d = document.createElement("div");
    d.className = "empty";
    d.textContent = "暂无词语。";
    list.appendChild(d);
    return;
  }
  state.words.forEach((w, i) => {
    const row = document.createElement("label");
    row.className = "word";
    const cb = document.createElement("input");
    cb.type = "checkbox";
    cb.checked = w.included;
    cb.addEventListener("change", () => {
      state.words[i].included = cb.checked;
    });
    const meta = document.createElement("div");
    meta.innerHTML = `<div class="term">${escapeHtml(w.term)}</div><div class="ln">${
      w.sourceLine > 0 ? "第 " + w.sourceLine + " 行" : "手动"
    }</div>`;
    row.appendChild(cb);
    row.appendChild(meta);
    list.appendChild(row);
  });
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
}

function selectedWords() {
  return state.words.filter((w) => w.included).map((w) => w.term);
}

// ---------- 导入 ----------
async function importFile(file) {
  if (!file) return;
  if (!extract.isSupported(file.name)) {
    setStatus(`不支持的文件类型：${file.name}`);
    return;
  }
  state.importing = true;
  setStatus(`正在导入 ${file.name}……`);
  try {
    const text = await extract.extractText(file, (p) =>
      setStatus(`正在读取 ${file.name}…… ${Math.round(p * 100)}%`)
    );
    const candidates = vocabulary.extractCandidates(text);
    state.docName = file.name;
    state.words = candidates.map((c) => ({ term: c.term, sourceLine: c.sourceLine, included: true }));
    renderWords();
    updateButtons();
    setStatus(
      candidates.length
        ? `找到 ${candidates.length} 个词汇。请审阅后选择图片。`
        : "未检测到词汇部分，请手动添加。"
    );
  } catch (err) {
    setStatus(`无法导入 ${file.name}：${err.message}`);
  } finally {
    state.importing = false;
  }
}

// ---------- 图片浏览 / 选择 ----------
function currentTab() {
  return state.tabs[state.tabIndex];
}

function renderTabs() {
  const tabs = $("tabs");
  tabs.innerHTML = "";
  state.tabs.forEach((t, i) => {
    const el = document.createElement("div");
    el.className = "tab" + (i === state.tabIndex ? " on" : "");
    el.textContent = t.word;
    el.addEventListener("click", () => {
      state.tabIndex = i;
      renderTabs();
      loadCurrent();
      setStatus(`为 ${t.word} 选择图片。`);
    });
    tabs.appendChild(el);
  });
}

function loadCurrent() {
  const tab = currentTab();
  if (!tab) return;
  const key = `${tab.word}|${state.engine}`;
  if (key === state.lastLoadKey) return;
  state.lastLoadKey = key;
  $("webview").src = engines.searchURL(state.engine, tab.word);
}

function startPicking() {
  const words = selectedWords();
  if (words.length === 0) return;
  state.tabs = words.map((w) => ({ word: w }));
  state.tabIndex = 0;
  state.browsing = true;
  state.lastLoadKey = null;
  $("browser-pane").classList.add("active");
  renderTabs();
  loadCurrent();
  setStatus(`为 ${currentTab().word} 选择图片。`);
}

function closeBrowser() {
  state.browsing = false;
  $("browser-pane").classList.remove("active");
}

function moveTab(delta) {
  const next = Math.min(Math.max(state.tabIndex + delta, 0), state.tabs.length - 1);
  state.tabIndex = next;
  renderTabs();
  loadCurrent();
  setStatus(`为 ${currentTab().word} 选择图片。`);
}

function advanceAfterImport() {
  if (state.tabIndex + 1 < state.tabs.length) {
    state.tabIndex += 1;
    renderTabs();
    loadCurrent();
    setStatus(`为 ${currentTab().word} 选择图片。`);
  } else {
    setStatus(`已选择 ${state.cards.length} 张图片。导出前请审阅卡片。`);
  }
}

async function handlePick(pick) {
  if (state.importing || !state.browsing) return;
  const tab = currentTab();
  if (!tab) return;
  const word = tab.word;
  state.importing = true;
  setStatus(`正在为 ${word} 导入图片……`);
  try {
    const dl = await ipcRenderer.invoke("download-bigger", {
      imageURL: pick.imageURL,
      thumbnailURL: pick.thumbnailURL,
      referer: pick.pageURL,
    });
    if (!dl) {
      setStatus(`无法下载 ${word} 的图片，请尝试其他。`);
      return;
    }
    const proc = await imageproc.processPicked(dl.dataURL, settingsForProc(), state.upscaler);
    upsertCard(word, proc, pick);
    renderCards();
    updateButtons();
    setStatus(`已添加 ${word} —— ${proc.pixelWidth}×${proc.pixelHeight} 像素。`);
    advanceAfterImport();
  } catch (err) {
    setStatus(`无法导入 ${word}：${err.message}`);
  } finally {
    state.importing = false;
  }
}

function upsertCard(word, proc, pick) {
  const card = {
    id: state.cards.find((c) => c.word.toLowerCase() === word.toLowerCase())?.id || nextId++,
    word,
    dataURL: proc.dataURL,
    base64: proc.base64,
    ext: proc.ext,
    pixelWidth: proc.pixelWidth,
    pixelHeight: proc.pixelHeight,
    sourceDataURL: proc.sourceDataURL,
    source: pick,
  };
  const idx = state.cards.findIndex((c) => c.id === card.id);
  if (idx >= 0) state.cards[idx] = card;
  else state.cards.push(card);
}

// ---------- 卡片 ----------
function renderCards() {
  const cards = $("cards");
  $("cardsSub").textContent = `${state.orientation === "landscape" ? "横向" : "纵向"} Letter 导出，边距 ${state.padding} 像素，标签${state.showLabels ? "显示" : "隐藏"}`;
  cards.innerHTML = "";
  if (state.cards.length === 0) {
    const d = document.createElement("div");
    d.className = "empty";
    d.textContent = "审阅词语后选择图片。";
    cards.appendChild(d);
    return;
  }
  state.cards.forEach((c) => {
    const el = document.createElement("div");
    el.className = "card" + (state.orientation === "landscape" ? " land" : "") + (c.id === state.selectedCardId ? " sel" : "");
    el.addEventListener("click", () => {
      state.selectedCardId = c.id;
      renderCards();
    });

    const wrap = document.createElement("div");
    wrap.className = "imgwrap";
    const img = document.createElement("img");
    img.src = c.dataURL;
    wrap.appendChild(img);
    el.appendChild(wrap);

    const remove = document.createElement("button");
    remove.className = "x";
    remove.textContent = "🗑";
    remove.title = "移除";
    remove.addEventListener("click", (e) => {
      e.stopPropagation();
      state.cards = state.cards.filter((x) => x.id !== c.id);
      renderCards();
      updateButtons();
    });
    el.appendChild(remove);

    const retry = document.createElement("button");
    retry.className = "retry";
    retry.textContent = "↻";
    retry.title = "更换图片";
    retry.addEventListener("click", (e) => {
      e.stopPropagation();
      retryWord(c.word);
    });
    el.appendChild(retry);

    const w = document.createElement("div");
    w.className = "w";
    w.textContent = wordlist.titleCase(c.word);
    el.appendChild(w);

    const dims = document.createElement("div");
    dims.className = "dims";
    dims.textContent = `${c.pixelWidth}×${c.pixelHeight} 像素`;
    el.appendChild(dims);

    cards.appendChild(el);
  });
}

function retryWord(word) {
  state.tabs = [{ word }];
  state.tabIndex = 0;
  state.browsing = true;
  state.lastLoadKey = null;
  $("browser-pane").classList.add("active");
  renderTabs();
  loadCurrent();
  setStatus(`为 ${word} 选择替换图片。`);
}

// ---------- 导出 ----------
async function exportPPTX() {
  if (state.cards.length === 0) return;
  try {
    const pick = await ipcRenderer.invoke("pick-save-path", {
      defaultName: `${baseName()}.pptx`,
      filters: [{ name: "PowerPoint", extensions: ["pptx"] }],
    });
    if (pick.canceled) return setStatus("已取消导出。");
    setStatus("正在生成 PPTX……");
    const slides = state.cards.map((c) => ({
      word: c.word,
      imageBase64: c.base64,
      imageExt: c.ext,
      pixelWidth: c.pixelWidth,
      pixelHeight: c.pixelHeight,
    }));
    const base64 = await pptx.makePPTX(slides, {
      paddingPixels: state.padding,
      orientation: state.orientation,
      showsTextLabel: state.showLabels,
    });
    const res = await ipcRenderer.invoke("write-file", { filePath: pick.filePath, base64 });
    setStatus(`已导出 ${res.name}。`);
  } catch (err) {
    setStatus(`无法导出 PPTX：${err.message}`);
  }
}

async function exportList() {
  if (state.cards.length === 0) return;
  const words = state.cards.map((c) => c.word);
  try {
    const pick = await ipcRenderer.invoke("pick-save-path", {
      defaultName: `${baseName()} 词汇清单.txt`,
      filters: [
        { name: "文本", extensions: ["txt"] },
        { name: "Word", extensions: ["docx"] },
      ],
    });
    if (pick.canceled) return setStatus("已取消导出。");
    const base64 =
      pick.ext === "docx"
        ? await wordlist.makeDOCX(words)
        : Buffer.from(wordlist.text(words), "utf8").toString("base64");
    const res = await ipcRenderer.invoke("write-file", { filePath: pick.filePath, base64 });
    setStatus(`已导出 ${res.name}。`);
  } catch (err) {
    setStatus(`无法导出清单：${err.message}`);
  }
}

function baseName() {
  const v = $("fileName").value.trim();
  return v || "词汇卡片";
}

// ---------- 按钮状态 ----------
function updateButtons() {
  $("pickBtn").disabled = selectedWords().length === 0;
  $("pptxBtn").disabled = state.cards.length === 0;
  $("listBtn").disabled = state.cards.length === 0;
  $("compareBtn").disabled = state.cards.length === 0;
}

// ---------- 浏览缩放 ----------
function applyZoom() {
  $("zoomPct").textContent = Math.round(state.browserZoom * 100) + "%";
  try {
    $("webview").setZoomFactor(state.browserZoom);
  } catch (e) {
    /* 尚未就绪 */
  }
}

function nudgeZoom(delta) {
  state.browserZoom = Math.min(1, Math.max(0.3, Math.round((state.browserZoom + delta) * 10) / 10));
  localStorage.setItem("zoom", String(state.browserZoom));
  applyZoom();
}

// ---------- 放大预览（比较方式） ----------
async function openPreview() {
  const card = state.cards.find((c) => c.id === state.selectedCardId) || state.cards[state.cards.length - 1];
  if (!card) return;
  $("previewWord").textContent = `"${card.word}"`;
  $("preview-overlay").style.display = "flex";
  $("previewGrid").innerHTML = '<div class="muted">正在渲染……</div>';
  try {
    const img = await imageproc.loadImage(card.sourceDataURL);
    const src = imageproc.canvasFromImage(img);
    const target = imageproc.fittedPixelSize(src.width, src.height, settingsForProc());
    const panels = [{ name: "原图", canvas: src }];
    for (const m of METHODS) {
      const up = await imageproc.upscale(src, target.width, target.height, m.id);
      panels.push({ name: m.name, canvas: up });
    }
    state.previewPanels = panels;
    renderPreviewPanels();
  } catch (e) {
    $("previewGrid").innerHTML = `<div class="muted">无法渲染：${e.message}</div>`;
  }
}

function renderPreviewPanels() {
  const grid = $("previewGrid");
  const zoom = $("previewZoom").value;
  grid.innerHTML = "";
  state.previewPanels.forEach((p) => {
    const cell = document.createElement("div");
    cell.style.cssText = "border:1px solid #e5e7eb;border-radius:6px;padding:8px";
    const box = document.createElement("div");
    box.style.cssText = "background:#fff;border:1px solid #f3f4f6;border-radius:6px;height:260px;overflow:auto;display:flex;align-items:center;justify-content:center";
    const im = document.createElement("img");
    im.src = p.canvas.toDataURL("image/png");
    if (zoom === "fit") {
      im.style.maxWidth = "100%";
      im.style.maxHeight = "100%";
    } else {
      im.style.width = p.canvas.width * Number(zoom) + "px";
      im.style.imageRendering = "pixelated";
    }
    box.appendChild(im);
    cell.appendChild(box);
    const t = document.createElement("div");
    t.style.cssText = "font-weight:600;margin-top:6px";
    t.textContent = p.name;
    cell.appendChild(t);
    const d = document.createElement("div");
    d.className = "dims";
    d.textContent = `${p.canvas.width}×${p.canvas.height} 像素`;
    cell.appendChild(d);
    grid.appendChild(cell);
  });
}

// ---------- 初始化 ----------
function initEngineSelect() {
  const sel = $("engine");
  engines.ALL.forEach((e) => {
    const o = document.createElement("option");
    o.value = e.id;
    o.textContent = e.name;
    sel.appendChild(o);
  });
  sel.value = state.engine;
  sel.addEventListener("change", () => {
    state.engine = sel.value;
    localStorage.setItem("engine", state.engine);
    state.lastLoadKey = null;
    loadCurrent();
  });
}

function initSegmented(id, onPick) {
  const group = $(id);
  group.querySelectorAll("button").forEach((btn) => {
    btn.addEventListener("click", () => {
      group.querySelectorAll("button").forEach((b) => b.classList.remove("on"));
      btn.classList.add("on");
      onPick(btn.dataset.v);
    });
  });
}

function init() {
  const wv = $("webview");
  wv.setAttribute("preload", pathToFileURL(path.join(__dirname, "webview-preload.js")).href);
  wv.setAttribute("useragent", USER_AGENT);
  wv.addEventListener("ipc-message", (e) => {
    if (e.channel === "clipart-pick") handlePick(e.args[0]);
  });
  wv.addEventListener("dom-ready", applyZoom);

  $("importBtn").addEventListener("click", () => $("fileInput").click());
  $("fileInput").addEventListener("change", (e) => {
    if (e.target.files[0]) importFile(e.target.files[0]);
    e.target.value = "";
  });
  $("pickBtn").addEventListener("click", startPicking);
  $("pptxBtn").addEventListener("click", exportPPTX);
  $("listBtn").addEventListener("click", exportList);
  $("addTermBtn").addEventListener("click", addTerm);
  $("termInput").addEventListener("keydown", (e) => {
    if (e.key === "Enter") addTerm();
  });
  $("prevTab").addEventListener("click", () => moveTab(-1));
  $("nextTab").addEventListener("click", () => moveTab(1));
  $("closeBrowser").addEventListener("click", closeBrowser);
  $("reloadBtn").addEventListener("click", () => {
    if (wv.getURL && wv.getURL()) wv.reload();
  });
  $("zoomOut").addEventListener("click", () => nudgeZoom(-0.1));
  $("zoomIn").addEventListener("click", () => nudgeZoom(0.1));
  $("zoomPct").textContent = Math.round(state.browserZoom * 100) + "%";

  $("compareBtn").addEventListener("click", openPreview);
  $("previewClose").addEventListener("click", () => {
    $("preview-overlay").style.display = "none";
  });
  $("previewZoom").addEventListener("change", renderPreviewPanels);

  const pad = $("padding");
  const padNum = $("paddingNum");
  const syncPad = (v) => {
    state.padding = Math.max(0, Math.min(72, Math.round(v)));
    pad.value = state.padding;
    padNum.value = state.padding;
    renderCards();
  };
  pad.addEventListener("input", () => syncPad(+pad.value));
  padNum.addEventListener("input", () => syncPad(+padNum.value));

  initSegmented("orientation", (v) => {
    state.orientation = v;
    renderCards();
  });
  initSegmented("labels", (v) => {
    state.showLabels = v === "show";
    renderCards();
  });
  $("upscaler").addEventListener("change", (e) => {
    state.upscaler = e.target.value;
  });

  initEngineSelect();

  document.body.addEventListener("dragover", (e) => e.preventDefault());
  document.body.addEventListener("drop", (e) => {
    e.preventDefault();
    if (e.dataTransfer.files[0]) importFile(e.dataTransfer.files[0]);
  });

  renderWords();
  renderCards();
  updateButtons();
}

function addTerm() {
  const input = $("termInput");
  const term = input.value.trim().replace(/\s+/g, " ");
  if (!term) return;
  if (!state.words.some((w) => w.term.toLowerCase() === term.toLowerCase())) {
    state.words.push({ term, sourceLine: 0, included: true });
    renderWords();
    updateButtons();
  }
  input.value = "";
}

init();
