import test from "node:test";
import assert from "node:assert/strict";
import {
  extractInviteCode,
  formatMissedDoseMessage,
  generateInviteCode
} from "../src/lineMessaging.js";
import { validateDoseEventSyncPayload } from "../src/validation.js";

test("generateInviteCode is 8 alphanumeric chars", () => {
  const code = generateInviteCode();
  assert.match(code, /^[A-Z0-9]{8}$/);
});

test("extractInviteCode finds code in free text", () => {
  assert.equal(extractInviteCode("please use AB12CD34 thanks"), "AB12CD34");
  assert.equal(extractInviteCode("no code here"), null);
});

test("formatMissedDoseMessage includes medicine and bilingual hint", () => {
  const text = formatMissedDoseMessage({
    patientName: "Grandma",
    medicineName: "Sara",
    dosage: "500 mg",
    scheduledFor: "2026-07-16T08:00:00.000Z"
  });
  assert.match(text, /Grandma/);
  assert.match(text, /Sara/);
  assert.match(text, /500 mg/);
  assert.match(text, /แจ้งเตือน/);
});

test("validateDoseEventSyncPayload accepts client-keyed upsert", () => {
  const payload = validateDoseEventSyncPayload({
    clientKey: "tag|2026-07-16T01:00:00Z",
    medicineName: "Sara",
    dosage: "500 mg",
    form: "Tablet",
    scheduledFor: "2026-07-16T01:00:00.000Z",
    status: "pending"
  });
  assert.equal(payload.form, "tablet");
  assert.equal(payload.medicineName, "Sara");
});

test("validateDoseEventSyncPayload requires takenAt for complete", () => {
  assert.throws(() =>
    validateDoseEventSyncPayload({
      clientKey: "x",
      medicineName: "Sara",
      scheduledFor: "2026-07-16T01:00:00.000Z",
      status: "complete"
    })
  );
});
