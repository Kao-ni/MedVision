import { normalizeDrugInfoResponse, normalizeDrugQuery } from "./drugInfo.js";
import {
  isLatinScriptName,
  matchThaiMedicine,
  normalizeName
} from "./thaiMedicineMatch.js";

function mapOpenFdaRecord(record) {
  return {
    generic_name: record?.openfda?.generic_name ?? [],
    brand_name: record?.openfda?.brand_name ?? [],
    purpose: record?.purpose ?? [],
    warnings: record?.warnings ?? [],
    indications_and_usage: record?.indications_and_usage ?? []
  };
}

/**
 * Lookup openFDA by generic/brand name. Injectible for tests.
 */
export async function lookupOpenFdaByName(name, fetchImpl = fetch) {
  const query = normalizeDrugQuery(name);
  if (!query) return null;

  const search = encodeURIComponent(
    `openfda.generic_name:"${query}"+OR+openfda.brand_name:"${query}"`
  );
  const response = await fetchImpl(
    `https://api.fda.gov/drug/label.json?limit=1&search=${search}`
  );

  if (response.status === 404) return null;
  if (!response.ok) return null;

  const payload = await response.json();
  const first = payload?.results?.[0];
  if (!first) return null;

  const normalized = normalizeDrugInfoResponse(mapOpenFdaRecord(first));
  const candidateName = normalized.subtitle || normalized.title;
  if (!candidateName || candidateName === "Unknown medicine") return null;

  return {
    source: "openfda",
    name: candidateName,
    score: 1,
    title: normalized.title,
    brand: normalized.subtitle || null
  };
}

export function namesAgree(a, b) {
  if (!a || !b) return false;
  return normalizeName(a) === normalizeName(b);
}

/**
 * Collect named candidates from sources that returned a usable name.
 * Judge with uncertain / empty name does not count as a source result.
 */
function collectNamedCandidates({ thaiResult, openFdaResult, judgeResult }) {
  const candidates = [];
  if (thaiResult?.name) {
    candidates.push({
      source: "thai",
      name: thaiResult.name,
      score: thaiResult.score
    });
  }
  if (openFdaResult?.name) {
    candidates.push({
      source: "openfda",
      name: openFdaResult.name,
      score: openFdaResult.score ?? 1
    });
  }
  if (
    judgeResult?.name &&
    String(judgeResult.name).trim() &&
    judgeResult.verdict !== "uncertain"
  ) {
    candidates.push({
      source: "judge",
      name: judgeResult.name,
      dosage: judgeResult.dosage ?? null,
      verdict: judgeResult.verdict ?? null,
      notes: judgeResult.notes ?? null
    });
  }
  return candidates;
}

/**
 * Agreement-based resolution. All sources are equal — no winner-picking.
 *
 * - 0 named results → unverified (OCR name)
 * - 1+ results, all same normalized name → consensus suggestion
 * - 2+ results with different names → disagreement (user picks)
 */
export function resolveConsensus({
  ocrName = "",
  ocrDosage = "",
  thaiResult = null,
  openFdaResult = null,
  judgeResult = null
} = {}) {
  const candidates = collectNamedCandidates({ thaiResult, openFdaResult, judgeResult });
  const dosageFromJudge =
    judgeResult?.dosage && String(judgeResult.dosage).trim()
      ? String(judgeResult.dosage).trim()
      : "";

  if (candidates.length === 0) {
    return {
      status: "unverified",
      finalName: ocrName || "",
      finalDosage: ocrDosage || "",
      label: "unverified",
      candidates
    };
  }

  const distinctKeys = [
    ...new Set(candidates.map((c) => normalizeName(c.name)).filter(Boolean))
  ];

  if (distinctKeys.length > 1) {
    return {
      status: "disagreement",
      finalName: null,
      finalDosage: ocrDosage || "",
      label: "conflict",
      candidates
    };
  }

  const agreedName = candidates[0].name;
  const sources = new Set(candidates.map((c) => c.source));
  let label = "verified";
  if (sources.size === 1 && sources.has("judge")) {
    label = "ai_corrected";
  } else if (sources.size >= 2) {
    label = "verified";
  } else {
    label = "verified";
  }

  return {
    status: "consensus",
    finalName: agreedName,
    finalDosage: dosageFromJudge || ocrDosage || "",
    label,
    candidates
  };
}

/**
 * Sequential lookups: Thai first, then gated openFDA.
 * Order is execution order only — not a trust hierarchy.
 */
export async function runLookups(ocrName, { fetchImpl = fetch, matchThai = matchThaiMedicine } = {}) {
  const thaiResult = matchThai(ocrName);
  const openFdaResult = isLatinScriptName(ocrName)
    ? await lookupOpenFdaByName(ocrName, fetchImpl)
    : null;
  return { thaiResult, openFdaResult };
}

/**
 * Accuracy-first pipeline: Thai → openFDA (gated) → LLM judge always → agreement resolution.
 */
export async function runConsensusPipeline({
  rawText,
  parsedMedicine,
  callJudge = null,
  fetchImpl = fetch,
  matchThai = matchThaiMedicine
} = {}) {
  const ocrName = parsedMedicine?.name ?? "";
  const ocrDosage = parsedMedicine?.dosage ?? "";

  // Step 2 then Step 3 — sequential, both recorded before judge.
  const { thaiResult, openFdaResult } = await runLookups(ocrName, { fetchImpl, matchThai });

  // Step 4 — LLM judge runs every time when available (accuracy over speed).
  let judgeResult = null;
  if (typeof callJudge === "function") {
    judgeResult = await callJudge({
      rawText,
      parsedMedicine,
      thaiResult,
      openFdaResult
    });
  }

  const resolution = resolveConsensus({
    ocrName,
    ocrDosage,
    thaiResult,
    openFdaResult,
    judgeResult
  });

  return {
    resolution,
    thaiResult,
    openFdaResult,
    judgeResult,
    judgeSkipped: false
  };
}
