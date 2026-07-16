import { runConsensusPipeline } from "../src/consensusEngine.js";

const cases = [
  { name: "Sara", dosage: "500 mg", expect: "consensus" },
  { name: "Paracetmol", dosage: "500 mg", expect: "consensus" },
  { name: "blurry unknown herb", dosage: "10 ml", expect: "unverified" }
];

let passed = 0;
for (const testCase of cases) {
  const result = await runConsensusPipeline({
    rawText: `${testCase.name} ${testCase.dosage}`,
    parsedMedicine: { name: testCase.name, dosage: testCase.dosage },
    callJudge: null,
    fetchImpl: async () => ({ ok: false, status: 404 })
  });

  const ok = result.resolution.status === testCase.expect;
  console.log(
    ok ? "PASS" : "FAIL",
    testCase.name,
    "->",
    result.resolution.status,
    `(expected ${testCase.expect}, judgeSkipped=${result.judgeSkipped})`
  );
  if (ok) passed += 1;
}

console.log(`\n${passed}/${cases.length} smoke cases passed`);
process.exit(passed === cases.length ? 0 : 1);
