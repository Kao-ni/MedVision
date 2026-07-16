const DOSAGE_REGEX = /(\b\d+(?:\.\d+)?\s?(?:mg|mcg|g|ml|iu)\b)/i;

const FORM_KEYWORDS = [
  ["pill", ["tablet", "tablets", "pill", "capsule", "caplet"]],
  ["liquid", ["syrup", "suspension", "liquid"]],
  ["injection", ["inject", "injection", "vial"]],
  ["patch", ["patch"]],
  ["inhaler", ["inhaler", "puff"]]
];

const STRUCTURED_CONTAINER_KEYS = ["medicine", "parsed", "result", "data", "payload", "fields"];

function firstNonEmptyLine(text) {
  return text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .find(Boolean) ?? "";
}

function stripCodeFences(text) {
  return text
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
}

function stringValue(value) {
  if (typeof value === "string") {
    return value.trim();
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return String(value);
  }
  return "";
}

function firstStringFromObject(object, keys) {
  for (const key of keys) {
    const value = object?.[key];
    const direct = stringValue(value);
    if (direct) {
      return direct;
    }
  }

  for (const containerKey of STRUCTURED_CONTAINER_KEYS) {
    const value = object?.[containerKey];

    if (Array.isArray(value)) {
      for (const entry of value) {
        if (entry && typeof entry === "object") {
          const nestedValue = firstStringFromObject(entry, keys);
          if (nestedValue) {
            return nestedValue;
          }
        }
      }
      continue;
    }

    if (value && typeof value === "object") {
      const nestedValue = firstStringFromObject(value, keys);
      if (nestedValue) {
        return nestedValue;
      }
    }
  }

  return "";
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

function parseStructuredMedicine(json, rawText) {
  const isMedicine = json?.is_medicine;
  if (isMedicine === false) {
    return {
      name: "",
      dosage: "",
      form: "other",
      notes: "",
      confidence: "low",
      warnings: ["not_medicine"],
      rawText
    };
  }

  const name = firstStringFromObject(json, ["name", "medicine_name", "brand_name", "product_name"]);
  if (!name) {
    return null;
  }

  const dosage = firstStringFromObject(json, ["dosage", "strength", "dose", "dose_strength"]);
  const form = inferForm(firstStringFromObject(json, ["form", "dosage_form", "route"]) || rawText);
  const notes = firstStringFromObject(json, ["notes", "warning", "frequency_note", "frequencyNote"]);
  const warnings = Array.isArray(json?.warnings)
    ? json.warnings.map((entry) => String(entry).trim()).filter(Boolean)
    : [];
  const missingFields = [];

  if (!dosage) missingFields.push("dosage_not_found");
  if (form === "other") missingFields.push("form_not_inferred");

  return {
    name,
    dosage,
    form,
    notes,
    confidence: warnings.length === 0 && missingFields.length === 0 ? "high" : warnings.length + missingFields.length === 1 ? "medium" : "low",
    warnings: [...warnings, ...missingFields],
    rawText
  };
}

export function parseRecognizedMedicine(rawText) {
  const text = typeof rawText === "string" ? rawText.trim() : "";
  const jsonText = stripCodeFences(text);

  if (jsonText) {
    try {
      const parsed = JSON.parse(jsonText);
      const structured = parseStructuredMedicine(parsed, text);
      return structured ?? {
        name: "",
        dosage: "",
        form: "other",
        notes: "",
        confidence: "low",
        warnings: ["parsing_failed"],
        rawText: text
      };
    } catch {
      // Fall through to raw text parsing.
    }
  }

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
