// Port of the macOS VocabularyExtractor. Extracts vocabulary terms from text.

const HEADING_WORDS = [
  "key terms",
  "key vocabulary",
  "key words",
  "keywords",
  "spelling list",
  "spelling words",
  "terms to know",
  "vocab",
  "vocabulary",
  "vocabulary list",
  "vocabulary terms",
  "vocabulary words",
  "word bank",
  "words to know",
];

const STOP_HEADINGS = new Set([
  "activity",
  "answer key",
  "comprehension",
  "discussion",
  "exercise",
  "homework",
  "key sentences",
  "lesson",
  "learning objectives",
  "practice",
  "questions",
  "reading",
  "review",
  "weekly activity suggestions",
  "worksheet",
  "writing",
]);

const HEADING_SET = new Set(HEADING_WORDS);

function normalizedHeading(line) {
  return line
    .toLowerCase()
    .trim()
    .replace(/^:+|:+$/g, "")
    .replace(/\s+/g, " ");
}

function isVocabularyHeading(line) {
  const normalized = normalizedHeading(line);
  if (HEADING_SET.has(normalized)) return true;
  // Also accept short, title-like lines that END WITH a known heading phrase,
  // e.g. "Unit 5 Vocabulary" or "Week 3 Spelling Words". The part before the
  // phrase must be a light qualifier (≤2 words, or containing a number) so we
  // don't match ordinary sentences that merely end in "vocabulary".
  return [...HEADING_WORDS]
    .sort((a, b) => b.length - a.length)
    .some((heading) => {
      if (!normalized.endsWith(" " + heading)) return false;
      const prefix = normalized.slice(0, normalized.length - heading.length).trim();
      const prefixWords = prefix.split(/\s+/).filter(Boolean);
      return prefixWords.length <= 2 || /\d/.test(prefix);
    });
}

function isLikelySectionHeading(line) {
  const n = normalizedHeading(line);
  return STOP_HEADINGS.has(n) || HEADING_SET.has(n);
}

function removeLeadingListMarker(value) {
  return value.replace(/^\s*(?:\d+[.)]|[A-Za-z][.)]|[-*•])\s+/, "");
}

function cleanTerm(raw) {
  let value = raw.trim();
  value = removeLeadingListMarker(value);
  for (const sep of [" - ", " -- ", ":", "\t"]) {
    const idx = value.indexOf(sep);
    if (idx !== -1) value = value.slice(0, idx);
  }
  value = value.trim().replace(/^[.:;-]+|[.:;-]+$/g, "");
  value = value.replace(/\s+/g, " ");
  return value;
}

function isPlausibleTerm(term) {
  const wordCount = term.split(/\s+/).filter(Boolean).length;
  if (wordCount < 1 || wordCount > 5) return false;
  const lower = term.toLowerCase();
  const prefixes = ["read ", "write ", "use ", "answer ", "define ", "draw "];
  if (prefixes.some((p) => lower.startsWith(p))) return false;
  return !term.includes(".") && !term.includes("?") && !term.includes("!");
}

function splitTermList(text) {
  return text
    .split(/[,;]/)
    .map((t) => cleanTerm(t))
    .filter((t) => t && isPlausibleTerm(t));
}

function inlineTerms(line) {
  const colon = line.indexOf(":");
  if (colon === -1) return null;
  const prefix = line.slice(0, colon);
  if (!isVocabularyHeading(prefix)) return null;
  const terms = splitTermList(line.slice(colon + 1));
  return terms.length ? terms : null;
}

function headingPrefixedTerms(line) {
  const normalized = normalizedHeading(line);
  for (const heading of [...HEADING_WORDS].sort((a, b) => b.length - a.length)) {
    if (!normalized.startsWith(heading + " ")) continue;
    const suffix = line.slice(Math.min(heading.length, line.length));
    const terms = splitTermList(suffix);
    return terms.length ? terms : null;
  }
  return null;
}

function termsFromVocabularyLine(line) {
  if (line.includes(",") || line.includes(";")) return splitTermList(line);
  const term = cleanTerm(line);
  if (!term || !isPlausibleTerm(term)) return [];
  return [term];
}

function extractCandidates(text) {
  const lines = text.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
  const candidates = [];
  const seen = new Set();
  let inVocab = false;

  const append = (terms, sourceLine) => {
    for (const term of terms) {
      const key = term.toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      candidates.push({ term, sourceLine });
    }
  };

  lines.forEach((rawLine, offset) => {
    const line = rawLine.trim();
    if (!line) return;

    let terms = inlineTerms(line);
    if (terms) {
      append(terms, offset + 1);
      inVocab = false;
      return;
    }
    terms = headingPrefixedTerms(line);
    if (terms) {
      append(terms, offset + 1);
      inVocab = false;
      return;
    }
    if (isVocabularyHeading(line)) {
      inVocab = true;
      return;
    }
    if (!inVocab) return;
    if (isLikelySectionHeading(line)) {
      inVocab = false;
      return;
    }
    append(termsFromVocabularyLine(line), offset + 1);
  });

  return candidates;
}

module.exports = { extractCandidates };
