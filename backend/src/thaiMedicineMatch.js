import { thaiCommonMedicines } from "./thaiCommonMedicines.js";

export const THAI_HIT_THRESHOLD = 0.85;
export const THAI_STRONG_THRESHOLD = 0.95;

const LATIN_NAME_REGEX = /^[a-zA-Z0-9\s.\-()/]+$/;

/**
 * Normalize a medicine name for comparison / fuzzy match.
 * Lowercase, strip spaces, strip common units and form words.
 */
export function normalizeName(input) {
  return String(input ?? "")
    .toLowerCase()
    .normalize("NFKC")
    .replace(/[()[\],;:|/\\]/g, " ")
    .replace(/\b\d+(?:\.\d+)?\s?(?:mg|mcg|g|ml|iu|%)\b/gi, " ")
    .replace(/\b(?:tablets?|capsules?|pills?|syrup|suspension|liquid|cream|drops?|inhaler|patch|powder)\b/gi, " ")
    .replace(/\s+/g, "")
    .trim();
}

/** True when the name is mostly Latin script (openFDA-eligible). */
export function isLatinScriptName(name) {
  const trimmed = String(name ?? "").trim();
  if (!trimmed) return false;
  return LATIN_NAME_REGEX.test(trimmed);
}

function jaroWinkler(a, b) {
  if (a === b) return 1;
  if (!a.length || !b.length) return 0;

  const matchDistance = Math.max(0, Math.floor(Math.max(a.length, b.length) / 2) - 1);
  const aMatches = new Array(a.length).fill(false);
  const bMatches = new Array(b.length).fill(false);

  let matches = 0;
  let transpositions = 0;

  for (let i = 0; i < a.length; i += 1) {
    const start = Math.max(0, i - matchDistance);
    const end = Math.min(i + matchDistance + 1, b.length);
    for (let j = start; j < end; j += 1) {
      if (bMatches[j] || a[i] !== b[j]) continue;
      aMatches[i] = true;
      bMatches[j] = true;
      matches += 1;
      break;
    }
  }

  if (matches === 0) return 0;

  let k = 0;
  for (let i = 0; i < a.length; i += 1) {
    if (!aMatches[i]) continue;
    while (!bMatches[k]) k += 1;
    if (a[i] !== b[k]) transpositions += 1;
    k += 1;
  }

  const m = matches;
  const jaro = (m / a.length + m / b.length + (m - transpositions / 2) / m) / 3;

  let prefix = 0;
  const maxPrefix = Math.min(4, a.length, b.length);
  while (prefix < maxPrefix && a[prefix] === b[prefix]) prefix += 1;

  return jaro + prefix * 0.1 * (1 - jaro);
}

function scoreAgainstEntry(normalizedQuery, entry) {
  const candidates = [entry.name, ...(entry.aliases ?? []), entry.generic]
    .filter(Boolean)
    .map((value) => normalizeName(value))
    .filter(Boolean);

  let best = 0;
  for (const candidate of candidates) {
    best = Math.max(best, jaroWinkler(normalizedQuery, candidate));
  }
  return best;
}

/**
 * Fuzzy-match OCR name against the local Thai common-medicines list.
 * Returns null when best score is below THAI_HIT_THRESHOLD (0.85).
 */
export function matchThaiMedicine(name, catalog = thaiCommonMedicines) {
  const normalizedQuery = normalizeName(name);
  if (!normalizedQuery) return null;

  let best = null;
  for (const entry of catalog) {
    const score = scoreAgainstEntry(normalizedQuery, entry);
    if (!best || score > best.score) {
      best = { source: "thai", name: entry.name, score, form: entry.form ?? null, generic: entry.generic ?? null };
    }
  }

  if (!best || best.score < THAI_HIT_THRESHOLD) return null;
  return best;
}
