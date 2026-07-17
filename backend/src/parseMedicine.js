import { normalizeMedicineForm } from "./contracts.js";

const DOSAGE_REGEX = /(\b\d+(?:\.\d+)?\s?(?:mg|mcg|g|ml|iu)\b)/i;

const FORM_KEYWORDS = [
  ["capsule", ["capsule", "capsules", "caplet"]],
  ["tablet", ["tablet", "tablets", "pill", "pill(s)"]],
  ["liquid", ["syrup", "suspension", "liquid"]],
  ["injection", ["inject", "injection", "vial"]],
  ["patch", ["patch"]],
  ["inhaler", ["inhaler", "puff"]]
];

const STRUCTURED_CONTAINER_KEYS = ["medicine", "parsed", "result", "data", "payload", "fields"];
const MEAL_SLOTS = new Set(["morning", "midday", "evening", "night"]);
const WITH_FOOD_VALUES = new Set(["before", "with", "after"]);

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
  const normalized = normalizeMedicineForm(text);
  for (const [form, keywords] of FORM_KEYWORDS) {
    if (keywords.some((keyword) => normalized.includes(keyword))) {
      return form;
    }
  }
  return "other";
}

function findWhenToTakeObject(json) {
  if (json?.when_to_take && typeof json.when_to_take === "object" && !Array.isArray(json.when_to_take)) {
    return json.when_to_take;
  }

  for (const containerKey of STRUCTURED_CONTAINER_KEYS) {
    const container = json?.[containerKey];
    if (container && typeof container === "object" && !Array.isArray(container)
      && container.when_to_take && typeof container.when_to_take === "object"
      && !Array.isArray(container.when_to_take)) {
      return container.when_to_take;
    }
  }

  return null;
}

function normalizeWhenToTake(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const raw = stringValue(value.raw);
  let timesPerDay = null;
  if (typeof value.times_per_day === "number" && Number.isFinite(value.times_per_day)) {
    timesPerDay = Math.trunc(value.times_per_day);
  } else if (typeof value.times_per_day === "string" && /^\d+$/.test(value.times_per_day.trim())) {
    timesPerDay = Number.parseInt(value.times_per_day.trim(), 10);
  }

  const timeSlots = Array.isArray(value.time_slots)
    ? value.time_slots
      .map((slot) => stringValue(slot).toLowerCase())
      .filter((slot) => MEAL_SLOTS.has(slot))
    : [];

  const withFoodRaw = stringValue(value.with_food).toLowerCase();
  const withFood = WITH_FOOD_VALUES.has(withFoodRaw) ? withFoodRaw : null;
  const asNeeded = value.as_needed === true;

  if (!raw && timesPerDay == null && timeSlots.length === 0 && !withFood && !asNeeded) {
    return null;
  }

  return {
    raw,
    times_per_day: timesPerDay,
    time_slots: timeSlots,
    with_food: withFood,
    as_needed: asNeeded
  };
}

function inferTimesPerDay(text) {
  const dayMatch = text.match(/วันละ\s*(\d+)\s*ครั้ง/);
  if (dayMatch) return Number.parseInt(dayMatch[1], 10);

  if (/ทุก\s*4\s*ชั่วโมง|every\s*4\s*hours/i.test(text)) return 6;
  if (/ทุก\s*6\s*ชั่วโมง|every\s*6\s*hours/i.test(text)) return 4;
  if (/ทุก\s*8\s*ชั่วโมง|every\s*8\s*hours/i.test(text)) return 3;
  if (/ทุก\s*12\s*ชั่วโมง|every\s*12\s*hours/i.test(text)) return 2;

  if (/\b(twice daily|2x(?:\s*a)?\s*day|bid)\b/i.test(text)) return 2;
  if (/\b(three times(?:\s*a)?\s*day|tid|3x(?:\s*a)?\s*day)\b/i.test(text)) return 3;
  if (/\b(four times(?:\s*a)?\s*day|qid|4x(?:\s*a)?\s*day)\b/i.test(text)) return 4;
  if (/\b(once daily|once a day|qd)\b/i.test(text)) return 1;

  return null;
}

function inferTimeSlots(text) {
  const slots = [];
  if (/อาหารเช้า|ตอนเช้า|\bเช้า\b|morning|breakfast|\bam\b/i.test(text)) slots.push("morning");
  if (/อาหารกลางวัน|ตอนกลางวัน|กลางวัน|midday|noon|lunch/i.test(text)) slots.push("midday");
  if (/อาหารเย็น|ตอนเย็น|\bเย็น\b|evening|dinner|supper/i.test(text)) slots.push("evening");
  if (/ก่อนนอน|bedtime|at night|nighttime/i.test(text)) slots.push("night");

  // Deduplicate while preserving order.
  return [...new Set(slots)];
}

function inferWithFood(text) {
  if (/ก่อนอาหาร|before (?:food|meals?|eating)/i.test(text)) return "before";
  if (/พร้อมอาหาร|with (?:food|meals?)/i.test(text)) return "with";
  if (/หลังอาหาร|after (?:food|meals?|breakfast|lunch|dinner|eating)/i.test(text)) return "after";
  return null;
}

function inferAsNeeded(text) {
  return /เมื่อมีอาการ|เมื่อปวด|เมื่อจำเป็น|as needed|when needed|\bprn\b/i.test(text);
}

function inferWhenToTakeFromText(...parts) {
  const text = parts
    .map((part) => stringValue(part))
    .filter(Boolean)
    .join("\n")
    .trim();
  if (!text) return null;

  const timeSlots = inferTimeSlots(text);
  const withFood = inferWithFood(text);
  const asNeeded = inferAsNeeded(text);
  const timesPerDay = inferTimesPerDay(text);

  if (timeSlots.length === 0 && !withFood && !asNeeded && timesPerDay == null) {
    return null;
  }

  return {
    raw: firstNonEmptyLine(text) || text,
    times_per_day: timesPerDay,
    time_slots: timeSlots,
    with_food: withFood,
    as_needed: asNeeded
  };
}

function resolveWhenToTake(json, notes, rawText) {
  return normalizeWhenToTake(findWhenToTakeObject(json))
    ?? inferWhenToTakeFromText(notes, rawText);
}

function extractName(line, dosage) {
  if (!line) return "";
  let name = dosage ? line.replace(dosage, "") : line;
  name = name.replace(/\b(tablets?|capsules?|caplets?|pill|liquid|syrup|injection|patch|inhaler)\b/gi, " ");
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
  const structuredForm = normalizeMedicineForm(firstStringFromObject(json, ["form", "dosage_form", "route"]));
  const form = structuredForm ? inferForm(structuredForm) : inferForm(rawText);
  const notes = firstStringFromObject(json, ["notes", "warning", "frequency_note", "frequencyNote"]);
  const warnings = Array.isArray(json?.warnings)
    ? json.warnings.map((entry) => String(entry).trim()).filter(Boolean)
    : [];
  const missingFields = [];

  if (!dosage) missingFields.push("dosage_not_found");
  if (form === "other") missingFields.push("form_not_inferred");

  const whenToTake = resolveWhenToTake(json, notes, rawText);
  const result = {
    name,
    dosage,
    form,
    notes,
    confidence: warnings.length === 0 && missingFields.length === 0 ? "high" : warnings.length + missingFields.length === 1 ? "medium" : "low",
    warnings: [...warnings, ...missingFields],
    rawText
  };
  if (whenToTake) {
    result.when_to_take = whenToTake;
  }
  return result;
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
  const whenToTake = inferWhenToTakeFromText(text);

  const result = {
    name,
    dosage,
    form,
    notes: "",
    confidence,
    warnings,
    rawText: text
  };
  if (whenToTake) {
    result.when_to_take = whenToTake;
  }
  return result;
}
