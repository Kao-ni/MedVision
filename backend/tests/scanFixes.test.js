import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const addMedicineView = readFileSync(
  path.join(root, "MedVision/Features/Medicines/AddMedicineView.swift"),
  "utf8"
);
const recognitionService = readFileSync(
  path.join(root, "MedVision/Services/RecognitionService.swift"),
  "utf8"
);
const fieldConfidenceModel = readFileSync(
  path.join(root, "MedVision/Models/MedicineFieldConfidence.swift"),
  "utf8"
);

function parseConfidence(value) {
  if (typeof value !== "string") return null;
  const normalized = value.toLowerCase();
  return ["high", "medium", "low"].includes(normalized) ? normalized : null;
}

function parseFieldConfidence(json) {
  const confidence = json.confidence;
  if (!confidence || typeof confidence !== "object") {
    return { name: null, dosage: null, form: null, whenToTake: null };
  }
  return {
    name: parseConfidence(confidence.name),
    dosage: parseConfidence(confidence.dosage),
    form: parseConfidence(confidence.form),
    whenToTake: parseConfidence(confidence.when_to_take)
  };
}

function parseWarnings(json) {
  if (Array.isArray(json.warnings)) {
    return json.warnings
      .map((entry) => String(entry).trim())
      .filter(Boolean);
  }
  if (typeof json.warning === "string" && json.warning.trim()) {
    return [json.warning.trim()];
  }
  return [];
}

function hasUncertainFields(confidence) {
  return Object.values(confidence).some((value) => value === "low" || value === "medium");
}

function suggestSchedule(hint, meals = { breakfast: 8 * 3600, lunch: 12 * 3600, dinner: 18 * 3600 }) {
  if (!hint) return { times: [], frequencyNote: "" };

  const note = (hint.raw ?? "").trim();
  if (hint.asNeeded && hint.timeSlots.length === 0 && !hint.withFood) {
    return { times: [], frequencyNote: note };
  }
  if (hint.timeSlots.length === 0 && !hint.withFood) {
    return { times: [], frequencyNote: note };
  }

  let slots = [...hint.timeSlots];
  if (slots.length === 0 && hint.withFood) {
    slots = ["morning", "midday", "evening"];
  }

  const slotSeconds = {
    morning: meals.breakfast,
    midday: meals.lunch,
    evening: meals.dinner,
    night: meals.dinner + 120 * 60
  };
  const offset = hint.withFood === "before" ? -30 * 60 : 0;
  const order = ["morning", "midday", "evening", "night"];
  const seen = new Set();
  const times = [];

  for (const slot of order) {
    if (!slots.includes(slot)) continue;
    const seconds = ((slotSeconds[slot] + offset) % (24 * 3600) + 24 * 3600) % (24 * 3600);
    const key = `${Math.floor(seconds / 3600)}:${Math.floor((seconds % 3600) / 60)}`;
    if (seen.has(key)) continue;
    seen.add(key);
    times.push(seconds);
  }

  return { times, frequencyNote: note };
}

function simulatePrefilledInit(prefilled) {
  const suggestion = suggestSchedule(prefilled.scheduleHint);
  return {
    scheduledTimes: suggestion.times,
    frequencyNote: suggestion.frequencyNote
  };
}

test("issue 1: AddMedicineView no longer wipes OCR schedule suggestions", () => {
  const prefilledBranch = addMedicineView.slice(
    addMedicineView.indexOf("} else if let p = prefilled {"),
    addMedicineView.indexOf("} else {", addMedicineView.indexOf("} else if let p = prefilled {"))
  );

  assert.match(prefilledBranch, /_scheduledTimes = State\(initialValue: suggestion\.times\)/);
  assert.match(prefilledBranch, /_frequencyNote = State\(initialValue: suggestion\.frequencyNote\)/);
  assert.doesNotMatch(
    prefilledBranch,
    /_scheduledTimes = State\(initialValue: suggestion\.times\)[\s\S]*_scheduledTimes = State\(initialValue: \[\]\)/
  );
  assert.doesNotMatch(
    prefilledBranch,
    /_frequencyNote = State\(initialValue: suggestion\.frequencyNote\)[\s\S]*_frequencyNote = State\(initialValue: ""\)/
  );
});

test("issue 1: meal schedule mapper produces times for after-food label hint", () => {
  const prefilled = {
    scheduleHint: {
      raw: "Take after food, morning and evening",
      timeSlots: ["morning", "evening"],
      withFood: "after",
      asNeeded: false
    }
  };

  const initState = simulatePrefilledInit(prefilled);

  assert.equal(initState.scheduledTimes.length, 2);
  assert.equal(initState.frequencyNote, "Take after food, morning and evening");
  assert.deepEqual(initState.scheduledTimes, [8 * 3600, 18 * 3600]);
});

test("issue 2: RecognizedMedicine carries confidence and warnings through parsing", () => {
  assert.match(recognitionService, /var fieldConfidence: MedicineFieldConfidence/);
  assert.match(recognitionService, /var warnings: \[String\]/);
  assert.match(recognitionService, /fieldConfidence: fieldConfidence/);
  assert.match(recognitionService, /warnings: warnings/);
  assert.match(recognitionService, /private func parseFieldConfidence/);
  assert.match(recognitionService, /private func parseWarnings/);
  assert.match(fieldConfidenceModel, /var hasUncertainFields: Bool/);
});

test("issue 2: confidence and warnings are parsed from structured OCR JSON", () => {
  const payload = {
    is_medicine: true,
    name: "Paracetamol",
    dosage: "500 mg",
    form: "tablet",
    confidence: {
      name: "high",
      dosage: "low",
      form: "medium",
      when_to_take: "low"
    },
    warnings: ["dosage partially obscured", "multiple strengths on label"]
  };

  const confidence = parseFieldConfidence(payload);
  const warnings = parseWarnings(payload);

  assert.equal(confidence.name, "high");
  assert.equal(confidence.dosage, "low");
  assert.equal(confidence.form, "medium");
  assert.equal(confidence.whenToTake, "low");
  assert.ok(hasUncertainFields(confidence));
  assert.deepEqual(warnings, [
    "dosage partially obscured",
    "multiple strengths on label"
  ]);
});

test("issue 2: confirm screen surfaces uncertainty UI", () => {
  assert.match(addMedicineView, /prefilled\?\.fieldConfidence\.hasUncertainFields/);
  assert.match(addMedicineView, /prefilled\?\.warnings/);
  assert.match(addMedicineView, /ocrFieldLabel\("Name", confidence: prefilled\?\.fieldConfidence\.name\)/);
  assert.match(addMedicineView, /ocrFieldLabel\("Dosage", confidence: prefilled\?\.fieldConfidence\.dosage\)/);
  assert.match(addMedicineView, /ocrFieldLabel\("Form", confidence: prefilled\?\.fieldConfidence\.form\)/);
  assert.match(addMedicineView, /Scan Warnings/);
});
