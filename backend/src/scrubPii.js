import { thaiCommonMedicines } from "./thaiCommonMedicines.js";

const REDACTED = "[REDACTED]";

/** Build a lowercase set of protected drug tokens so scrubbing does not eat medicine names. */
function buildProtectedTokens() {
  const tokens = new Set([
    "paracetamol",
    "acetaminophen",
    "ibuprofen",
    "amoxicillin",
    "mg",
    "mcg",
    "ml",
    "tablet",
    "tablets",
    "capsule",
    "capsules",
    "syrup",
    "หลังอาหาร",
    "ก่อนอาหาร",
    "พร้อมอาหาร",
    "เม็ด",
    "แคปซูล",
    "ยาน้ำ"
  ]);

  for (const entry of thaiCommonMedicines) {
    for (const value of [entry.name, entry.generic, ...(entry.aliases || [])]) {
      if (!value) continue;
      const lower = String(value).toLowerCase().trim();
      if (lower) tokens.add(lower);
      for (const part of lower.split(/\s+/)) {
        if (part.length >= 3) tokens.add(part);
      }
    }
  }
  return tokens;
}

const PROTECTED_TOKENS = buildProtectedTokens();

function isProtectedSpan(text) {
  const lower = text.toLowerCase().trim();
  if (!lower) return false;
  if (PROTECTED_TOKENS.has(lower)) return true;
  // Dosage-heavy spans are medicine context, not patient identity.
  if (/\d+\s?(?:mg|mcg|g|ml|iu|%)/i.test(lower)) return true;
  if (/(?:หลังอาหาร|ก่อนอาหาร|พร้อมอาหาร|morning|evening|with food)/i.test(lower)) {
    return true;
  }
  return false;
}

/**
 * Rules-first PII scrub for pharmacy-label OCR.
 * Replaces patient name / age / HN-style identity with [REDACTED].
 *
 * @param {string} rawText
 * @returns {{ scrubbedText: string, redactionCount: number, categories: string[] }}
 */
export function scrubPii(rawText = "") {
  if (!rawText || typeof rawText !== "string") {
    return { scrubbedText: "", redactionCount: 0, categories: [] };
  }

  const categories = new Set();
  let redactionCount = 0;
  let text = rawText;

  const apply = (pattern, category, replacer) => {
    text = text.replace(pattern, (...args) => {
      const match = args[0];
      const groups = args.slice(1, -2);
      if (isProtectedSpan(match)) return match;
      const replacement =
        typeof replacer === "function" ? replacer(match, ...groups) : replacer ?? REDACTED;
      if (replacement !== match) {
        redactionCount += 1;
        categories.add(category);
      }
      return replacement;
    });
  };

  // Full lines labeled as patient / name fields.
  apply(
    /^(?:\s*)(?:patient(?:\s*name)?|name|ชื่อ(?:ผู้ป่วย)?|ชื่อ-สกุล)\s*[:：\-]\s*.+$/gim,
    "patient_label",
    REDACTED
  );

  // Hospital / visit / Rx identifiers.
  apply(
    /\b(?:HN|VN|AN|Rx|RX|Prescription(?:\s*No\.?)?)\s*[:#-]?\s*[A-Za-z0-9\-]+/gi,
    "hospital_id",
    REDACTED
  );
  apply(
    /(?:เลขที่(?:ผู้ป่วย)?|หมายเลข(?:ผู้ป่วย)?|ใบสั่ง(?:ยา)?)\s*[:：]?\s*[A-Za-z0-9\-]+/gi,
    "hospital_id",
    REDACTED
  );

  // Age patterns (EN + TH).
  apply(
    /\b(?:age|aged)\s*[:\-]?\s*\d{1,3}(?:\s*(?:years?|yrs?|y\.?o\.?))?\b/gi,
    "age",
    REDACTED
  );
  apply(/อายุ\s*[:：]?\s*\d{1,3}\s*(?:ปี)?/gi, "age", REDACTED);
  apply(/\b\d{1,3}\s*(?:years?\s*old|yrs?\s*old|y\.?o\.?)\b/gi, "age", REDACTED);

  // English honorific + following name tokens (same-line only; \s would cross newlines).
  apply(
    /\b(?:Mr|Mrs|Ms|Miss|Dr)\.?[ \t]+[A-Z][A-Za-z'’\-]+(?:[ \t]+[A-Z][A-Za-z'’\-]+){0,3}\b/g,
    "honorific_en",
    REDACTED
  );

  // Thai honorific + following name tokens (Thai letters; same-line only).
  apply(
    /(?:นางสาว|นาย|นาง|คุณ)[ \t]*[\u0E00-\u0E7F]+(?:[ \t]+[\u0E00-\u0E7F]+){0,3}/g,
    "honorific_th",
    REDACTED
  );

  // Bare "First Last" style when line is mostly a person name (two Capitalized tokens, no digits/mg).
  apply(
    /^(?:\s*)([A-Z][a-zA-Z'’\-]{1,30})\s+([A-Z][a-zA-Z'’\-]{1,30})(?:\s+([A-Z][a-zA-Z'’\-]{1,30}))?(?:\s*)$/gm,
    "person_name",
    (match) => {
      if (isProtectedSpan(match)) return match;
      if (/\d/.test(match)) return match;
      return REDACTED;
    }
  );

  // Collapse duplicate redaction markers on a line.
  text = text.replace(/(?:\[REDACTED\]\s*){2,}/g, `${REDACTED} `);

  return {
    scrubbedText: text.trimEnd(),
    redactionCount,
    categories: [...categories]
  };
}
