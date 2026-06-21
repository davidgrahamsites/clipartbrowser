// Image search engines, mirroring the macOS ImageSearchEngine enum.
const ALL = [
  { id: "google", name: "谷歌" },
  { id: "baidu", name: "百度" },
  { id: "bing", name: "必应" },
  { id: "yandex", name: "Yandex" },
];

function searchURL(engine, term) {
  const q = encodeURIComponent(`${term} 剪贴画`);
  switch (engine) {
    case "baidu":
      return `https://image.baidu.com/search/index?tn=baiduimage&ie=utf-8&word=${q}`;
    case "bing":
      return `https://www.bing.com/images/search?q=${q}`;
    case "yandex":
      return `https://yandex.com/images/search?text=${q}`;
    case "google":
    default:
      return `https://www.google.com/search?tbm=isch&q=${q}`;
  }
}

module.exports = { ALL, searchURL };
