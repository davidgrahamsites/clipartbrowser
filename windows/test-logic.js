// Quick functional sanity test for the pure-logic ports (no Electron/DOM).
const assert = require("assert");
const vocabulary = require("./src/lib/vocabulary");
const wordlist = require("./src/lib/wordlist");
const pptx = require("./src/lib/pptx");
const engines = require("./src/lib/engines");

(async () => {
  // vocabulary
  const cands = vocabulary.extractCandidates(
    "Lesson\nVocabulary\ntall\nshort\nbridge building\nKey Sentences\nThe end."
  );
  const terms = cands.map((c) => c.term);
  assert.deepStrictEqual(terms, ["tall", "short", "bridge building"], "vocab terms");

  // inline form
  const inline = vocabulary.extractCandidates("Key Words: sun, hot, beach").map((c) => c.term);
  assert.deepStrictEqual(inline, ["sun", "hot", "beach"], "inline vocab");

  // wordlist text
  assert.strictEqual(
    wordlist.text(["tall", "short", "bridge building"]),
    "1 - Tall\n2 - Short\n3 - Bridge Building",
    "wordlist text"
  );

  // wordlist docx is a zip
  const docxB64 = await wordlist.makeDOCX(["tall", "short"]);
  assert.ok(docxB64.length > 100, "docx produced");
  assert.strictEqual(Buffer.from(docxB64, "base64").slice(0, 2).toString(), "PK", "docx is zip");

  // pptx
  const tinyPng =
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";
  const pptxB64 = await pptx.makePPTX(
    [{ word: "tall", imageBase64: tinyPng, imageExt: "png", pixelWidth: 100, pixelHeight: 80 }],
    { paddingPixels: 12, orientation: "portrait", showsTextLabel: true }
  );
  assert.strictEqual(Buffer.from(pptxB64, "base64").slice(0, 2).toString(), "PK", "pptx is zip");

  // fitted frame sanity
  const frame = pptx.fittedImageFrame({ pixelWidth: 100, pixelHeight: 80 }, 12, "portrait", true);
  assert.ok(frame.width > 0 && frame.height > 0, "frame positive");

  // engines
  assert.ok(engines.searchURL("bing", "cat").includes("bing.com"), "bing url");
  assert.ok(engines.searchURL("yandex", "cat").includes("yandex.com"), "yandex url");

  console.log("ALL LOGIC TESTS PASSED");
})().catch((e) => {
  console.error("TEST FAILED:", e.message);
  process.exit(1);
});
