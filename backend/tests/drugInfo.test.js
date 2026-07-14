import test from "node:test";
import assert from "node:assert/strict";
import { normalizeDrugInfoResponse, normalizeDrugQuery } from "../src/drugInfo.js";

test("normalizes drug queries for caching and lookup", () => {
  assert.equal(normalizeDrugQuery("  ParaCetamol 500mg "), "paracetamol 500mg");
});

test("maps provider payload into the app contract", () => {
  const normalized = normalizeDrugInfoResponse({
    brand_name: ["Tylenol"],
    generic_name: ["Paracetamol"],
    purpose: ["Pain relief"],
    warnings: ["Do not exceed dosage"],
    indications_and_usage: ["Reduces fever"]
  });

  assert.equal(normalized.title, "Paracetamol");
  assert.equal(normalized.subtitle, "Tylenol");
  assert.equal(normalized.uses[0], "Pain relief");
  assert.equal(normalized.warnings[0], "Do not exceed dosage");
});
