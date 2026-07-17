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

test("preserves structured when_to_take for autoscheduling", () => {
  const result = parseRecognizedMedicine(JSON.stringify({
    is_medicine: true,
    name: "Celebrex",
    dosage: "200mg",
    form: "capsule",
    notes: "Take after breakfast",
    when_to_take: {
      raw: "หลังอาหารเช้า",
      times_per_day: 1,
      time_slots: ["morning"],
      with_food: "after",
      as_needed: false
    },
    warnings: []
  }));

  assert.deepEqual(result.when_to_take, {
    raw: "หลังอาหารเช้า",
    times_per_day: 1,
    time_slots: ["morning"],
    with_food: "after",
    as_needed: false
  });
});

test("infers when_to_take from Thai after-breakfast notes when model omits it", () => {
  const result = parseRecognizedMedicine(JSON.stringify({
    is_medicine: true,
    name: "Celebrex",
    dosage: "200mg",
    form: "capsule",
    notes: "รับประทานครั้งละ 1 แคปซูล วันละ 1 ครั้งหลังอาหารเช้า",
    warnings: []
  }));

  assert.equal(result.when_to_take.with_food, "after");
  assert.deepEqual(result.when_to_take.time_slots, ["morning"]);
  assert.equal(result.when_to_take.times_per_day, 1);
  assert.match(result.when_to_take.raw, /หลังอาหารเช้า/);
});
