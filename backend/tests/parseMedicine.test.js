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
  assert.equal(result.form, "pill");
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
