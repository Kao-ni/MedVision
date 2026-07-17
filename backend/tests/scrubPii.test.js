import test from "node:test";
import assert from "node:assert/strict";
import { scrubPii } from "../src/scrubPii.js";

test("redacts English honorific names", () => {
  const input = "Mr. Kee\nParacetamol 500 mg\nTake after meals";
  const result = scrubPii(input);
  assert.match(result.scrubbedText, /\[REDACTED\]/);
  assert.doesNotMatch(result.scrubbedText, /Mr\.?\s*Kee/i);
  assert.match(result.scrubbedText, /Paracetamol 500 mg/);
  assert.ok(result.redactionCount >= 1);
  assert.ok(result.categories.includes("honorific_en"));
});

test("redacts bare First Last person lines like Virota Lee", () => {
  const input = "Virota Lee\nSara 500 mg\nหลังอาหาร";
  const result = scrubPii(input);
  assert.doesNotMatch(result.scrubbedText, /Virota\s+Lee/);
  assert.match(result.scrubbedText, /Sara 500 mg/);
  assert.match(result.scrubbedText, /หลังอาหาร/);
});

test("redacts Thai age and honorific", () => {
  const input = "นาย วิโรจน์ สุขใจ\nอายุ 72 ปี\nพาราเซตามอล 500 mg";
  const result = scrubPii(input);
  assert.doesNotMatch(result.scrubbedText, /วิโรจน์/);
  assert.doesNotMatch(result.scrubbedText, /อายุ\s*72/);
  assert.match(result.scrubbedText, /พาราเซตามอล 500 mg/);
  assert.ok(result.categories.includes("age") || result.categories.includes("honorific_th"));
});

test("redacts HN and patient label lines", () => {
  const input = "Patient: John Smith\nHN 123456\nIbuprofen 200 mg";
  const result = scrubPii(input);
  assert.doesNotMatch(result.scrubbedText, /John\s+Smith/);
  assert.doesNotMatch(result.scrubbedText, /HN\s*123456/i);
  assert.match(result.scrubbedText, /Ibuprofen 200 mg/);
});

test("preserves medicine lines without inventing redactionsactions noise", () => {
  const input = "Paracetamol 500 mg\nหลังอาหาร\nTiffy";
  const result = scrubPii(input);
  assert.equal(result.redactionCount, 0);
  assert.match(result.scrubbedText, /Paracetamol 500 mg/);
  assert.match(result.scrubbedText, /หลังอาหาร/);
  assert.match(result.scrubbedText, /Tiffy/);
});

test("scrubbing twice is idempotent for medicine text", () => {
  const input = "Mr. Kee\nParacetamol 500 mg\nAge 65\nHN 998877";
  const once = scrubPii(input);
  const twice = scrubPii(once.scrubbedText);
  assert.match(twice.scrubbedText, /Paracetamol 500 mg/);
  assert.doesNotMatch(twice.scrubbedText, /Kee/);
  assert.doesNotMatch(twice.scrubbedText, /998877/);
});

test("unwraps Typhoon natural_text before redacting patient names", () => {
  const input = JSON.stringify({
    natural_text: "Boy NANOND NIMITKUL\nMeiact 200 mg tablet"
  });

  const result = scrubPii(input);

  assert.equal(result.scrubbedText, "[REDACTED]\nMeiact 200 mg tablet");
  assert.doesNotMatch(result.scrubbedText, /natural_text/);
  assert.ok(result.categories.includes("person_name"));
});

test("unwraps fenced Typhoon natural_text output", () => {
  const input = [
    "```json",
    JSON.stringify({ natural_text: "Mr. Kee\nOndansetron 8 mg tablet" }),
    "```"
  ].join("\n");

  const result = scrubPii(input);

  assert.equal(result.scrubbedText, "[REDACTED]\nOndansetron 8 mg tablet");
});
