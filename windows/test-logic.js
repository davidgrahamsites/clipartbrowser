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

  // title-like heading with a qualifier ("Unit 5 Vocabulary", "Week 3 Spelling Words")
  const titled = vocabulary
    .extractCandidates("Unit 5 Vocabulary\ntall\nshort\nhappy")
    .map((c) => c.term);
  assert.deepStrictEqual(titled, ["tall", "short", "happy"], "title-like vocab heading");
  const spelling = vocabulary
    .extractCandidates("Week 3 Spelling Words\nbecause\nfriend\npeople")
    .map((c) => c.term);
  assert.deepStrictEqual(spelling, ["because", "friend", "people"], "title-like spelling heading");
  // ordinary sentence ending in "vocabulary" must NOT start a section
  const sentence = vocabulary
    .extractCandidates("Students will learn new vocabulary\nThe lesson covers several topics.")
    .map((c) => c.term);
  assert.deepStrictEqual(sentence, [], "sentence ending in vocabulary is not a heading");

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

  // license verify (only when the dev private key is present locally)
  const fs = require("fs");
  const cp = require("child_process");
  const keygen = require("path").join(__dirname, "..", "licensing", "keygen.js");
  if (fs.existsSync(require("path").join(__dirname, "..", "licensing", "private.pem"))) {
    const license = require("./src/license");
    const lic = cp.execSync(`node "${keygen}" issue --mid TEST-1234-5678-9ABC`, { encoding: "utf8" }).trim();
    assert.ok(license.verify(lic, "TEST-1234-5678-9ABC"), "license verifies for its machine");
    assert.strictEqual(license.verify(lic, "WRONG-0000-0000-0000"), null, "rejects wrong machine");
    assert.strictEqual(license.verify("X" + lic.slice(1), "TEST-1234-5678-9ABC"), null, "rejects tampered");
    console.log("license verify: OK");
  } else {
    console.log("license verify: skipped (no private.pem)");
  }

  console.log("ALL LOGIC TESTS PASSED");
})().catch((e) => {
  console.error("TEST FAILED:", e.message);
  process.exit(1);
});
