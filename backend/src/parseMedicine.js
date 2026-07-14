const DOSAGE_REGEX = /(\b\d+(?:\.\d+)?\s?(?:mg|mcg|g|ml|iu)\b)/i;

const FORM_KEYWORDS = [
  ["pill", ["tablet", "tablets", "pill", "capsule", "caplet"]],
  ["liquid", ["syrup", "suspension", "liquid"]],
  ["injection", ["inject", "injection", "vial"]],
  ["patch", ["patch"]],
  ["inhaler", ["inhaler", "puff"]]
];

function firstNonEmptyLine(text) {
  return text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .find(Boolean) ?? "";
}

function inferForm(text) {
  const normalized = text.toLowerCase();
  for (const [form, keywords] of FORM_KEYWORDS) {
    if (keywords.some((keyword) => normalized.includes(keyword))) {
      return form;
    }
  }
  return "other";
}

function extractName(line, dosage) {
  if (!line) return "";
  let name = dosage ? line.replace(dosage, "") : line;
  name = name.replace(/\b(tablets?|capsules?|pill|liquid|syrup|injection|patch|inhaler)\b/gi, " ");
  name = name.replace(/\s+/g, " ").trim();
  return name || line.trim();
}

export function parseRecognizedMedicine(rawText) {
  const text = typeof rawText === "string" ? rawText.trim() : "";
  const firstLine = firstNonEmptyLine(text);
  const dosageMatch = text.match(DOSAGE_REGEX);
  const dosage = dosageMatch ? dosageMatch[1] : "";
  const form = inferForm(text);
  const name = extractName(firstLine, dosage);
  const warnings = [];

  if (!dosage) warnings.push("dosage_not_found");
  if (form === "other") warnings.push("form_not_inferred");
  if (!name) warnings.push("name_not_found");

  const confidence = warnings.length === 0 ? "high" : warnings.length === 1 ? "medium" : "low";

  return {
    name,
    dosage,
    form,
    notes: "",
    confidence,
    warnings,
    rawText: text
  };
}
