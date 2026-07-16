import test from "node:test";
import assert from "node:assert/strict";
import {
  isLatinScriptName,
  matchThaiMedicine,
  normalizeName,
  THAI_HIT_THRESHOLD
} from "../src/thaiMedicineMatch.js";
import {
  resolveConsensus,
  runConsensusPipeline,
  shouldSkipJudge
} from "../src/consensusEngine.js";

test("normalizeName strips dosage and form words", () => {
  assert.equal(normalizeName("Paracetamol 500mg tablets"), normalizeName("paracetamol"));
  assert.equal(normalizeName("  Sara  "), "sara");
});

test("Latin script gate allows Latin and rejects Thai", () => {
  assert.equal(isLatinScriptName("Paracetamol"), true);
  assert.equal(isLatinScriptName("Amoxicillin 500 mg"), true);
  assert.equal(isLatinScriptName("ซาร่า"), false);
  assert.equal(isLatinScriptName("Sara ซาร่า"), false);
});

test("Thai fuzzy match hits strong alias and rejects nonsense", () => {
  const hit = matchThaiMedicine("ซาร่า");
  assert.ok(hit);
  assert.equal(hit.source, "thai");
  assert.equal(hit.name, "Sara");
  assert.ok(hit.score >= THAI_HIT_THRESHOLD);

  const latinHit = matchThaiMedicine("Sara 500mg");
  assert.ok(latinHit);
  assert.equal(latinHit.name, "Sara");
  assert.ok(latinHit.score >= 0.95);

  const miss = matchThaiMedicine("blurry packet xyzzy");
  assert.equal(miss, null);
});

test("shouldSkipJudge when Thai is strong and FDA absent or agrees", () => {
  assert.equal(
    shouldSkipJudge({ name: "Sara", score: 0.97 }, null),
    true
  );
  assert.equal(
    shouldSkipJudge({ name: "Paracetamol", score: 0.96 }, { name: "Paracetamol", score: 1 }),
    true
  );
  assert.equal(
    shouldSkipJudge({ name: "Sara", score: 0.97 }, { name: "Sarafem", score: 1 }),
    false
  );
  assert.equal(
    shouldSkipJudge({ name: "Sara", score: 0.9 }, null),
    false
  );
});

test("resolution: Thai-only strong match is consensus", () => {
  const result = resolveConsensus({
    ocrName: "Sara",
    ocrDosage: "500 mg",
    thaiResult: { name: "Sara", score: 0.98 },
    openFdaResult: null,
    judgeResult: null
  });
  assert.equal(result.status, "consensus");
  assert.equal(result.finalName, "Sara");
  assert.equal(result.finalDosage, "500 mg");
});

test("resolution: same Thai and openFDA names is consensus", () => {
  const result = resolveConsensus({
    ocrName: "paracetamol",
    ocrDosage: "500 mg",
    thaiResult: { name: "Paracetamol", score: 0.99 },
    openFdaResult: { name: "Paracetamol", score: 1 },
    judgeResult: null
  });
  assert.equal(result.status, "consensus");
  assert.equal(result.finalName, "Paracetamol");
});

test("resolution: DB disagreement with uncertain judge is disagreement", () => {
  const result = resolveConsensus({
    ocrName: "Sara",
    ocrDosage: "500 mg",
    thaiResult: { name: "Sara", score: 0.97 },
    openFdaResult: { name: "Sarafem", score: 1 },
    judgeResult: { name: null, verdict: "uncertain" }
  });
  assert.equal(result.status, "disagreement");
  assert.equal(result.finalName, null);
  assert.ok(result.candidates.some((c) => c.name === "Sara"));
  assert.ok(result.candidates.some((c) => c.name === "Sarafem"));
});

test("resolution: DB disagreement with prefer_thai is consensus", () => {
  const result = resolveConsensus({
    ocrName: "Sara",
    ocrDosage: "500 mg",
    thaiResult: { name: "Sara", score: 0.97 },
    openFdaResult: { name: "Sarafem", score: 1 },
    judgeResult: { name: "Sara", dosage: "500 mg", verdict: "prefer_thai" }
  });
  assert.equal(result.status, "consensus");
  assert.equal(result.finalName, "Sara");
});

test("resolution: judge-only non-uncertain is ai_corrected consensus", () => {
  const result = resolveConsensus({
    ocrName: "Paracetmol",
    ocrDosage: "5O0 mg",
    thaiResult: null,
    openFdaResult: null,
    judgeResult: { name: "Paracetamol", dosage: "500 mg", verdict: "prefer_ocr" }
  });
  assert.equal(result.status, "consensus");
  assert.equal(result.label, "ai_corrected");
  assert.equal(result.finalName, "Paracetamol");
  assert.equal(result.finalDosage, "500 mg");
});

test("resolution: nothing verified returns unverified with OCR name", () => {
  const result = resolveConsensus({
    ocrName: "Unknown Herb Mix",
    ocrDosage: "10 ml",
    thaiResult: null,
    openFdaResult: null,
    judgeResult: { verdict: "uncertain", name: null }
  });
  assert.equal(result.status, "unverified");
  assert.equal(result.finalName, "Unknown Herb Mix");
  assert.equal(result.finalDosage, "10 ml");
});

test("runConsensusPipeline skips judge on strong Thai hit", async () => {
  let judgeCalled = false;
  const outcome = await runConsensusPipeline({
    rawText: "Sara 500 mg",
    parsedMedicine: { name: "Sara", dosage: "500 mg" },
    callJudge: async () => {
      judgeCalled = true;
      return { name: "Sara", verdict: "prefer_thai" };
    },
    fetchImpl: async () => ({ ok: false, status: 500 })
  });

  assert.equal(outcome.judgeSkipped, true);
  assert.equal(judgeCalled, false);
  assert.equal(outcome.resolution.status, "consensus");
  assert.equal(outcome.resolution.finalName, "Sara");
});

test("runConsensusPipeline skips openFDA for Thai-script names", async () => {
  let fetched = false;
  await runConsensusPipeline({
    rawText: "ซาร่า",
    parsedMedicine: { name: "ซาร่า", dosage: "500 mg" },
    callJudge: null,
    fetchImpl: async () => {
      fetched = true;
      return { ok: false, status: 500 };
    }
  });
  assert.equal(fetched, false);
});
