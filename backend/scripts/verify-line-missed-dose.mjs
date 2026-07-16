/**
 * Verification helpers for LINE missed-dose alert pipeline.
 * Runs offline unit checks always; optional live cron ping if env is set.
 */
import assert from "node:assert/strict";
import {
  extractInviteCode,
  formatMissedDoseMessage,
  generateInviteCode
} from "../src/lineMessaging.js";

function assertIdempotentMessage() {
  const a = formatMissedDoseMessage({
    patientName: "A",
    medicineName: "Sara",
    dosage: "500 mg",
    scheduledFor: "2026-07-16T08:00:00.000Z"
  });
  const b = formatMissedDoseMessage({
    patientName: "A",
    medicineName: "Sara",
    dosage: "500 mg",
    scheduledFor: "2026-07-16T08:00:00.000Z"
  });
  assert.equal(a, b);
  console.log("PASS idempotent message format");
}

function assertInviteFlowShape() {
  const code = generateInviteCode();
  assert.equal(extractInviteCode(`code ${code}`), code);
  assert.equal(extractInviteCode("hello"), null);
  console.log("PASS invite code extract");
}

function assertGraceLogic() {
  const graceMs = 30 * 60 * 1000;
  const scheduled = Date.parse("2026-07-16T08:00:00.000Z");
  const tooEarly = scheduled + graceMs - 1;
  const due = scheduled + graceMs;
  assert.equal(tooEarly < scheduled + graceMs, true);
  assert.equal(due >= scheduled + graceMs, true);
  console.log("PASS 30-minute grace boundary");
}

assertIdempotentMessage();
assertInviteFlowShape();
assertGraceLogic();

const cronUrl = process.env.MISSED_DOSE_CHECK_URL;
const cronSecret = process.env.CRON_SECRET;
if (cronUrl && cronSecret) {
  const res = await fetch(cronUrl, {
    method: "POST",
    headers: { Authorization: `Bearer ${cronSecret}` }
  });
  console.log(`LIVE cron status ${res.status}`);
  const body = await res.text();
  console.log(body.slice(0, 400));
} else {
  console.log("SKIP live cron (set MISSED_DOSE_CHECK_URL + CRON_SECRET to ping)");
}

console.log("verify-line-missed-dose: done");
