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
  words: [], // {term, sourceLine, included}
  cards: [], // {id, word, dataURL, base64, ext, pixelWidth, pixelHeight, sourceDataURL, source}
  docName: null,
  padding: 12,
  orientation: "portrait",
  showLabels: true,
  upscaler: "coreImage",
  engine: localStorage.getItem("engine") || "google",
  // pick session
  tabs: [],
  tabIndex: 0,
  browsing: false,
  selectedCardId: null,
  importing: false,
  lastLoadKey: null,
};

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

// ---------- Words ----------
function renderWords() {
  $("docName").textContent = state.docName
    ? state.docName
    : "Import a document to find vocabulary.";
  const list = $("wordList");
  list.innerHTML = "";
  if (state.words.length === 0) {
    const d = document.createElement("div");
    d.className = "empty";
    d.textContent = "No words yet.";
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
      w.sourceLine > 0 ? "Line " + w.sourceLine : "Manual"
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

// ---------- Import ----------
async function importFile(file) {
  if (!file) return;
  if (!extract.isSupported(file.name)) {
    setStatus(`Unsupported file type: ${file.name}`);
    return;
  }
  state.importing = true;
  setStatus(`Importing ${file.name}...`);
  try {
    const text = await extract.extractText(file, (p) =>
      setStatus(`Reading ${file.name}... ${Math.round(p * 100)}%`)
    );
    const candidates = vocabulary.extractCandidates(text);
    state.docName = file.name;
    state.words = candidates.map((c) => ({ term: c.term, sourceLine: c.sourceLine, included: true }));
    renderWords();
    updateButtons();
    setStatus(
      candidates.length
        ? `Found ${candidates.length} vocabulary words. Review, then Pick Images.`
        : "No vocabulary section detected. Add terms manually."
    );
  } catch (err) {
    setStatus(`Could not import ${file.name}: ${err.message}`);
  } finally {
    state.importing = false;
  }
}

// ---------- Image browser / picking ----------
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
      setStatus(`Choose an image for ${t.word}.`);
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
  setStatus(`Choose an image for ${currentTab().word}.`);
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
  setStatus(`Choose an image for ${currentTab().word}.`);
}

function advanceAfterImport() {
  if (state.tabIndex + 1 < state.tabs.length) {
    state.tabIndex += 1;
    renderTabs();
    loadCurrent();
    setStatus(`Choose an image for ${currentTab().word}.`);
  } else {
    setStatus(`Picked ${state.cards.length} images. Review cards before exporting.`);
  }
}

async function handlePick(pick) {
  if (state.importing || !state.browsing) return;
  const tab = currentTab();
  if (!tab) return;
  const word = tab.word;
  state.importing = true;
  setStatus(`Importing image for ${word}...`);
  try {
    const dl = await ipcRenderer.invoke("download-bigger", {
      imageURL: pick.imageURL,
      thumbnailURL: pick.thumbnailURL,
      referer: pick.pageURL,
    });
    if (!dl) {
      setStatus(`Could not download image for ${word} — try another.`);
      return;
    }
    const proc = await imageproc.processPicked(dl.dataURL, settingsForProc(), state.upscaler);
    upsertCard(word, proc, pick);
    renderCards();
    updateButtons();
    setStatus(`Added ${word} — ${proc.pixelWidth}×${proc.pixelHeight}px.`);
    advanceAfterImport();
  } catch (err) {
    setStatus(`Could not import ${word}: ${err.message}`);
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

// ---------- Flashcards ----------
function renderCards() {
  const cards = $("cards");
  $("cardsSub").textContent = `${state.orientation === "landscape" ? "Landscape" : "Portrait"} letter export, ${state.padding} px padding, labels ${state.showLabels ? "on" : "off"}`;
  cards.innerHTML = "";
  if (state.cards.length === 0) {
    const d = document.createElement("div");
    d.className = "empty";
    d.textContent = "Pick images after reviewing words.";
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
    remove.title = "Remove";
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
    retry.title = "Find a different image";
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
    dims.textContent = `${c.pixelWidth}×${c.pixelHeight}px`;
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
  setStatus(`Choose a replacement image for ${word}.`);
}

// ---------- Export ----------
async function exportPPTX() {
  if (state.cards.length === 0) return;
  try {
    const pick = await ipcRenderer.invoke("pick-save-path", {
      defaultName: `${baseName()}.pptx`,
      filters: [{ name: "PowerPoint", extensions: ["pptx"] }],
    });
    if (pick.canceled) return setStatus("Export cancelled.");
    setStatus("Building PPTX...");
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
    setStatus(`Exported ${res.name}.`);
  } catch (err) {
    setStatus(`Could not export PPTX: ${err.message}`);
  }
}

async function exportList() {
  if (state.cards.length === 0) return;
  const words = state.cards.map((c) => c.word);
  try {
    const pick = await ipcRenderer.invoke("pick-save-path", {
      defaultName: `${baseName()} Word List.txt`,
      filters: [
        { name: "Text", extensions: ["txt"] },
        { name: "Word", extensions: ["docx"] },
      ],
    });
    if (pick.canceled) return setStatus("Export cancelled.");
    const base64 =
      pick.ext === "docx"
        ? await wordlist.makeDOCX(words)
        : Buffer.from(wordlist.text(words), "utf8").toString("base64");
    const res = await ipcRenderer.invoke("write-file", { filePath: pick.filePath, base64 });
    setStatus(`Exported ${res.name}.`);
  } catch (err) {
    setStatus(`Could not export list: ${err.message}`);
  }
}

function baseName() {
  const v = $("fileName").value.trim();
  return v || "Vocabulary Flashcards";
}

// ---------- Buttons enable/disable ----------
function updateButtons() {
  $("pickBtn").disabled = selectedWords().length === 0;
  $("pptxBtn").disabled = state.cards.length === 0;
  $("listBtn").disabled = state.cards.length === 0;
}

// ---------- Wiring ----------
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

  // Drag and drop import
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
