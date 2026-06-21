// Activation screen logic. External file (not inline) so the page CSP can stay
// strict — inline <script> is blocked by `default-src 'self'`.
const { ipcRenderer, clipboard } = require("electron");

const fpEl = document.getElementById("fp");

ipcRenderer.invoke("license:fingerprint").then((fp) => {
  fpEl.textContent = fp || "(unavailable)";
});

document.getElementById("copy").addEventListener("click", () => {
  clipboard.writeText(fpEl.textContent);
});

document.getElementById("activate").addEventListener("click", async () => {
  const key = document.getElementById("key").value.trim();
  if (!key) return;
  const ok = await ipcRenderer.invoke("license:activate", key);
  if (ok) {
    ipcRenderer.invoke("license:reload");
  } else {
    document.getElementById("err").textContent =
      document.body.getAttribute("data-invalid") || "That key isn't valid for this computer.";
  }
});
