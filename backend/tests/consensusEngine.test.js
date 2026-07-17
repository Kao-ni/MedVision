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
  runConsensusPipeline
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

test("resolution: all returned sources agree is consensus", () => {
  const result = resolveConsensus({
    ocrName: "Sara",
    ocrDosage: "500 mg",
    thaiResult: { name: "Sara", score: 0.98 },
    openFdaResult: null,
    judgeResult: { name: "Sara", dosage: "500 mg", verdict: "prefer_thai" }
  });
  assert.equal(result.status, "consensus");
  assert.equal(result.finalName, "Sara");
  assert.equal(result.label, "verified");
});

test("resolution: Thai and openFDA same name is consensus", () => {
  const result = resolveConsensus({
    ocrName: "paracetamol",
    ocrDosage: "500 mg",
    thaiResult: { name: "Paracetamol", score: 0.99 },
    openFdaResult: { name: "Paracetamol", score: 1 },
    judgeResult: { name: "Paracetamol", verdict: "prefer_ocr" }
  });
  assert.equal(result.status, "consensus");
  assert.equal(result.finalName, "Paracetamol");
});

test("resolution: any source disagreement is disagreement — no winner picking", () => {
  const result = resolveConsensus({
    ocrName: "Sara",
    ocrDosage: "500 mg",
    thaiResult: { name: "Sara", score: 0.97 },
    openFdaResult: { name: "Sarafem", score: 1 },
    judgeResult: { name: "Sara", dosage: "500 mg", verdict: "prefer_thai" }
  });
  assert.equal(result.status, "disagreement");
  assert.equal(result.finalName, null);
  assert.ok(result.candidates.some((c) => c.name === "Sara"));
  assert.ok(result.candidates.some((c) => c.name === "Sarafem"));
});

test("resolution: Thai vs judge disagreement is disagreement", () => {
  const result = resolveConsensus({
    ocrName: "Sara",
    ocrDosage: "500 mg",
    thaiResult: { name: "Sara", score: 0.97 },
    openFdaResult: null,
    judgeResult: { name: "Sarafem", verdict: "prefer_ocr" }
  });
  assert.equal(result.status, "disagreement");
  assert.equal(result.finalName, null);
});

test("resolution: judge-only correction cannot overwrite OCR", () => {
  const result = resolveConsensus({
    ocrName: "Dehecta",
    ocrDosage: "3 gm/20 mL",
    thaiResult: null,
    openFdaResult: null,
    judgeResult: {
      name: "Dextropropoxyphene",
      dosage: "30 mg/20 mL",
      verdict: "prefer_ocr"
    }
  });
  assert.equal(result.status, "unverified");
  assert.equal(result.label, "unverified");
  assert.equal(result.finalName, "Dehecta");
  assert.equal(result.finalDosage, "3 gm/20 mL");
});

test("resolution: one lookup cannot replace a different OCR name", () => {
  const result = resolveConsensus({
    ocrName: "Celebrex",
    ocrDosage: "200 mg",
    thaiResult: { name: "Celecoxib", score: 0.91 },
    openFdaResult: null,
    judgeResult: null
  });
  assert.equal(result.status, "unverified");
  assert.equal(result.finalName, "Celebrex");
  assert.equal(result.finalDosage, "200 mg");
});

test("resolution: two independent sources may correct an OCR name", () => {
  const result = resolveConsensus({
    ocrName: "Paracetmol",
    ocrDosage: "500 mg",
    thaiResult: { name: "Paracetamol", score: 0.96 },
    openFdaResult: null,
    judgeResult: { name: "Paracetamol", dosage: "500 mg", verdict: "prefer_thai" }
  });
  assert.equal(result.status, "consensus");
  assert.equal(result.finalName, "Paracetamol");
  assert.equal(result.finalDosage, "500 mg");
});

test("resolution: unsupported judge dosage cannot replace parsed dosage", () => {
  const result = resolveConsensus({
    rawText: "Meiact 200 mg tablet",
    ocrName: "Meiact",
    ocrDosage: "200 mg",
    thaiResult: null,
    openFdaResult: null,
    judgeResult: { name: "Meiact", dosage: "20 mg", verdict: "prefer_ocr" }
  });
  assert.equal(result.status, "consensus");
  assert.equal(result.finalName, "Meiact");
  assert.equal(result.finalDosage, "200 mg");
});

test("resolution: judge dosage printed in OCR text may replace parser dosage", () => {
  const result = resolveConsensus({
    rawText: "Bioflor 250 mg capsule. Take one capsule twice daily.",
    ocrName: "Bioflor",
    ocrDosage: "one capsule twice daily",
    thaiResult: null,
    openFdaResult: null,
    judgeResult: { name: "Bioflor", dosage: "250 mg", verdict: "prefer_ocr" }
  });
  assert.equal(result.status, "consensus");
  assert.equal(result.finalName, "Bioflor");
  assert.equal(result.finalDosage, "250 mg");
});

test("resolution: nothing named returns unverified with OCR name", () => {
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

test("runConsensusPipeline always calls judge when provided", async () => {
  let judgeCalled = false;
  const outcome = await runConsensusPipeline({
    rawText: "Sara 500 mg",
    parsedMedicine: { name: "Sara", dosage: "500 mg" },
    callJudge: async () => {
      judgeCalled = true;
      return { name: "Sara", dosage: "500 mg", verdict: "prefer_thai" };
    },
    fetchImpl: async () => ({ ok: false, status: 500 })
  });

  assert.equal(outcome.judgeSkipped, false);
  assert.equal(judgeCalled, true);
  assert.equal(outcome.resolution.status, "consensus");
  assert.equal(outcome.resolution.finalName, "Sara");
});

test("runConsensusPipeline skips openFDA for Thai-script names", async () => {
  let fetched = false;
  await runConsensusPipeline({
    rawText: "ซาร่า",
    parsedMedicine: { name: "ซาร่า", dosage: "500 mg" },
    callJudge: async () => ({ name: "Sara", verdict: "prefer_thai" }),
    fetchImpl: async () => {
      fetched = true;
      return { ok: false, status: 500 };
    }
  });
  assert.equal(fetched, false);
});

test("runLookups is sequential: Thai then gated openFDA", async () => {
  const order = [];
  await runConsensusPipeline({
    rawText: "Paracetamol",
    parsedMedicine: { name: "Paracetamol", dosage: "500 mg" },
    matchThai: (name) => {
      order.push("thai");
      return { source: "thai", name: "Paracetamol", score: 0.99 };
    },
    fetchImpl: async () => {
      order.push("fda");
      return {
        ok: true,
        status: 200,
        json: async () => ({
          results: [{
            openfda: { brand_name: ["Tylenol"], generic_name: ["Paracetamol"] }
          }]
        })
      };
    },
    callJudge: async () => {
      order.push("judge");
      return { name: "Paracetamol", verdict: "prefer_ocr" };
    }
  });
  assert.deepEqual(order, ["thai", "fda", "judge"]);
});
