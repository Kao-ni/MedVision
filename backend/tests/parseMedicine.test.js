import test from "node:test";
import assert from "node:assert/strict";
import { parseRecognizedMedicine } from "../src/parseMedicine.js";

test("extracts medicine fields from mixed OCR text", () => {
  const text = [
    "Paracetamol 500 mg tablets",
    "Take after food",
    "10 tablets"
  ].join("\n");

  const result = parseRecognizedMedicine(text);

  assert.equal(result.name, "Paracetamol");
  assert.equal(result.dosage, "500 mg");
  assert.equal(result.form, "tablet");
  assert.equal(result.confidence, "high");
  assert.deepEqual(result.warnings, []);
});

test("preserves warnings when OCR text is weak", () => {
  const result = parseRecognizedMedicine("blurry packet\nuse as directed");

  assert.equal(result.name, "blurry packet");
  assert.equal(result.dosage, "");
  assert.equal(result.form, "other");
  assert.equal(result.confidence, "low");
  assert.ok(result.warnings.includes("dosage_not_found"));
  assert.ok(result.warnings.includes("form_not_inferred"));
});

test("parses structured JSON medicine output", () => {
  const result = parseRecognizedMedicine(JSON.stringify({
    is_medicine: true,
    name: "Paracetamol",
    dosage: "500 mg",
    form: "tablet",
    notes: "Take after food",
    warnings: ["check label"]
  }));

  assert.equal(result.name, "Paracetamol");
  assert.equal(result.dosage, "500 mg");
  assert.equal(result.form, "tablet");
  assert.equal(result.notes, "Take after food");
  assert.equal(result.confidence, "medium");
  assert.deepEqual(result.warnings, ["check label"]);
});

test("recovers medicine fields from nested structured JSON", () => {
  const result = parseRecognizedMedicine(JSON.stringify({
    is_medicine: true,
    medicine: {
      brand_name: "Tylenol",
      active_ingredient: "Paracetamol"
    },
    dosage_form: "tablet",
    strength: "500 mg",
    warning: "Take after food"
  }));

  assert.equal(result.name, "Tylenol");
  assert.equal(result.dosage, "500 mg");
  assert.equal(result.form, "tablet");
  assert.equal(result.notes, "Take after food");
});

test("does not treat confidence fields as medicine fields", () => {
  const result = parseRecognizedMedicine(JSON.stringify({
    is_medicine: true,
    confidence: {
      name: "low",
      dosage: "low"
    },
    medicine: {
      brand_name: "Amoxicillin"
    },
    dosage_form: "capsule"
  }));

  assert.equal(result.name, "Amoxicillin");
  assert.equal(result.dosage, "");
  assert.equal(result.form, "capsule");
});

test("marks non-medicine results explicitly", () => {
  const result = parseRecognizedMedicine(JSON.stringify({
    is_medicine: false,
    warnings: ["looks like a receipt"]
  }));

  assert.equal(result.name, "");
  assert.equal(result.form, "other");
  assert.deepEqual(result.warnings, ["not_medicine"]);
  assert.equal(result.confidence, "low");
});
