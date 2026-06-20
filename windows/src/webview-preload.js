// Runs inside the <webview> showing Google/Baidu/Bing/Yandex. On click it
// extracts the full-size image (and a thumbnail fallback) and sends it to the
// host renderer. Ported from the macOS app's universal selection script.
const { ipcRenderer } = require("electron");

(function () {
  if (window.__clipartPickerInstalled) return;
  window.__clipartPickerInstalled = true;

  function firstImageFrom(node) {
    if (!node) return null;
    if (node.tagName === "IMG") return node;
    if (node.closest) {
      const img = node.closest("img");
      if (img) return img;
      const link = node.closest("a");
      if (link && link.querySelector) return link.querySelector("img");
    }
    if (node.querySelector) return node.querySelector("img");
    return null;
  }

  function httpOnly(value) {
    if (!value) return null;
    if (value.indexOf("data:") === 0 || value.indexOf("blob:") === 0) return null;
    if (value.indexOf("http") !== 0) return null;
    return value;
  }

  // Google: <a href="/imgres?...imgurl=FULL&imgrefurl=PAGE...">
  function fromGoogle(node) {
    if (!node || !node.closest) return null;
    let anchor = node.closest('a[href*="imgurl="]');
    if (!anchor) {
      const container = node.closest("[data-ved]") || node.parentElement;
      if (container && container.querySelector) {
        anchor = container.querySelector('a[href*="imgurl="]');
      }
    }
    if (!anchor || !anchor.href) return null;
    try {
      const url = new URL(anchor.href, window.location.href);
      const imgurl = url.searchParams.get("imgurl");
      const imgrefurl = url.searchParams.get("imgrefurl");
      return {
        imageURL: httpOnly(imgurl ? decodeURIComponent(imgurl) : null),
        pageURL: imgrefurl ? decodeURIComponent(imgrefurl) : null,
      };
    } catch (e) {
      return null;
    }
  }

  // Baidu: grid item carries data-objurl (full) and data-thumburl (thumb).
  function fromBaidu(node) {
    if (!node || !node.closest) return null;
    const item = node.closest("[data-objurl]") || node.closest("[data-thumburl]");
    if (!item) return null;
    return {
      imageURL: httpOnly(item.getAttribute("data-objurl")),
      thumbnailURL: httpOnly(item.getAttribute("data-thumburl")),
      pageURL: item.getAttribute("data-fromurl") || null,
    };
  }

  // Bing: <a class="iusc" m='{"murl":FULL,"turl":THUMB,"purl":PAGE}'>
  function fromBing(node) {
    if (!node || !node.closest) return null;
    const a = node.closest("a.iusc") || node.closest("a[m]");
    if (!a) return null;
    const m = a.getAttribute("m");
    if (!m) return null;
    try {
      const data = JSON.parse(m);
      return {
        imageURL: httpOnly(data.murl),
        thumbnailURL: httpOnly(data.turl),
        pageURL: data.purl || null,
      };
    } catch (e) {
      return null;
    }
  }

  // Yandex: .serp-item carries data-bem JSON with serp-item.img_href / preview.
  function fromYandex(node) {
    if (!node || !node.closest) return null;
    const item = node.closest(".serp-item[data-bem]") || node.closest("[data-bem]");
    if (!item) return null;
    const bem = item.getAttribute("data-bem");
    if (!bem) return null;
    try {
      const si = (JSON.parse(bem) || {})["serp-item"];
      if (!si) return null;
      const thumb = si.preview && si.preview.length ? si.preview[0].url : null;
      const full = si.img_href || (si.dups && si.dups.length ? si.dups[0].url : null);
      return {
        imageURL: httpOnly(full),
        thumbnailURL: httpOnly(thumb),
        pageURL: (si.snippet && si.snippet.url) || null,
      };
    } catch (e) {
      return null;
    }
  }

  function pickImageFrom(event) {
    const image = firstImageFrom(event.target);
    if (!image) return;

    const source =
      fromGoogle(image) || fromBaidu(image) || fromBing(image) || fromYandex(image);

    const thumb =
      httpOnly(
        image.currentSrc ||
          image.src ||
          image.getAttribute("data-src") ||
          image.getAttribute("data-iurl") ||
          image.getAttribute("data-ou")
      ) ||
      (source && source.thumbnailURL) ||
      null;

    const imageURL = (source && source.imageURL) || thumb;
    if (!imageURL) return;

    event.preventDefault();
    event.stopPropagation();

    const link = image.closest ? image.closest("a") : null;
    const pageURL =
      (source && source.pageURL) ||
      (link && link.href ? link.href : window.location.href);

    ipcRenderer.sendToHost("clipart-pick", {
      imageURL,
      thumbnailURL: thumb && thumb !== imageURL ? thumb : null,
      pageURL,
      title: image.alt || image.title || document.title || "",
    });
  }

  document.addEventListener("click", pickImageFrom, true);
})();
