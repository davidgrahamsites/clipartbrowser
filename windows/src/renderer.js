const webview = document.getElementById("browser");
const engineSelect = document.getElementById("engine");
const termInput = document.getElementById("term");
const statusEl = document.getElementById("status");
const pickedList = document.getElementById("pickedList");

// Configure the webview before its first navigation.
webview.setAttribute("preload", window.api.webviewPreload);
webview.setAttribute("useragent", window.api.userAgent);

window.api.engines.forEach((engine) => {
  const option = document.createElement("option");
  option.value = engine.id;
  option.textContent = engine.name;
  engineSelect.appendChild(option);
});

function setStatus(text) {
  statusEl.textContent = text;
}

function doSearch() {
  const term = termInput.value.trim();
  if (!term) return;
  webview.src = window.api.searchURL(engineSelect.value, term);
  setStatus(`Searching ${engineSelect.options[engineSelect.selectedIndex].text} for "${term}"...`);
}

document.getElementById("searchBtn").addEventListener("click", doSearch);
document.getElementById("reloadBtn").addEventListener("click", () => {
  if (webview.getURL()) webview.reload();
});
termInput.addEventListener("keydown", (event) => {
  if (event.key === "Enter") doSearch();
});
engineSelect.addEventListener("change", () => {
  if (termInput.value.trim()) doSearch();
});

function addPicked(result, pick) {
  const card = document.createElement("div");
  card.className = "card";

  const img = document.createElement("img");
  img.src = result.dataURL;
  card.appendChild(img);

  const meta = document.createElement("div");
  meta.className = "meta";
  meta.textContent = `${result.width}×${result.height}px`;
  card.appendChild(meta);

  pickedList.prepend(card);
}

webview.addEventListener("ipc-message", async (event) => {
  if (event.channel !== "clipart-pick") return;
  const pick = event.args[0];
  setStatus(`Downloading "${pick.title || "image"}"...`);
  try {
    const result = await window.api.downloadBigger({
      imageURL: pick.imageURL,
      thumbnailURL: pick.thumbnailURL,
      referer: pick.pageURL,
    });
    if (!result) {
      setStatus("Could not download that image — try another.");
      return;
    }
    addPicked(result, pick);
    setStatus(`Picked ${result.width}×${result.height}px.`);
  } catch (error) {
    setStatus(`Download error: ${error.message}`);
  }
});
