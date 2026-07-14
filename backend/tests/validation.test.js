import test from "node:test";
import assert from "node:assert/strict";
import {
  ValidationError,
  validateDoseEventPayload,
  validateMedicinePayload,
  validateRecognitionUpload,
  validateSchedulePayload
} from "../src/validation.js";

test("accepts a valid medicine payload", () => {
  const payload = validateMedicinePayload({
    name: "Paracetamol",
    dosage: "500 mg",
    form: "pill",
    notes: "After meals",
    frequencyNote: "Twice daily"
  });

  assert.equal(payload.name, "Paracetamol");
  assert.equal(payload.form, "pill");
});

test("rejects an invalid medicine form", () => {
  assert.throws(
    () => validateMedicinePayload({ name: "Paracetamol", form: "capsule" }),
    ValidationError
  );
});

test("accepts a supported image upload", () => {
  const upload = validateRecognitionUpload({
    contentType: "image/jpeg",
    size: 1024
  });

  assert.equal(upload.contentType, "image/jpeg");
  assert.equal(upload.size, 1024);
});

test("rejects oversized recognition uploads", () => {
  assert.throws(
    () => validateRecognitionUpload({ contentType: "image/jpeg", size: 12 * 1024 * 1024 }),
    ValidationError
  );
});

test("accepts a valid schedule payload", () => {
  const schedule = validateSchedulePayload({
    medicineId: "medicine-1",
    frequencyType: "specific_times",
    times: ["08:00", "20:00"],
    withFood: true,
    instructions: "With breakfast and dinner"
  });

  assert.equal(schedule.medicineId, "medicine-1");
  assert.equal(schedule.times.length, 2);
  assert.equal(schedule.withFood, true);
});

test("rejects a schedule without times", () => {
  assert.throws(
    () => validateSchedulePayload({ medicineId: "medicine-1", frequencyType: "specific_times", times: [] }),
    ValidationError
  );
});

test("accepts a valid dose event payload", () => {
  const event = validateDoseEventPayload({
    medicineId: "medicine-1",
    scheduledFor: "2026-07-13T08:00:00Z",
    status: "complete",
    takenAt: "2026-07-13T08:05:00Z"
  });

  assert.equal(event.status, "complete");
  assert.equal(event.takenAt, "2026-07-13T08:05:00Z");
});

test("rejects an unsupported dose event status", () => {
  assert.throws(
    () => validateDoseEventPayload({ medicineId: "medicine-1", scheduledFor: "2026-07-13T08:00:00Z", status: "skipped" }),
    ValidationError
  );
});
