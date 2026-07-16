import { normalizeDrugInfoResponse, normalizeDrugQuery } from "./drugInfo.js";
import {
  isLatinScriptName,
  matchThaiMedicine,
  normalizeName,
  THAI_STRONG_THRESHOLD
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

export function shouldSkipJudge(thaiResult, openFdaResult) {
  if (!thaiResult || thaiResult.score < THAI_STRONG_THRESHOLD) return false;
  if (!openFdaResult) return true;
  return normalizeName(thaiResult.name) === normalizeName(openFdaResult.name);
}

export function namesAgree(a, b) {
  if (!a || !b) return false;
  return normalizeName(a) === normalizeName(b);
}

/**
 * Resolve consensus / disagreement / unverified from lookup + optional judge results.
 */
export function resolveConsensus({
  ocrName = "",
  ocrDosage = "",
  thaiResult = null,
  openFdaResult = null,
  judgeResult = null
} = {}) {
  const candidates = [];
  if (thaiResult) {
    candidates.push({
      source: "thai",
      name: thaiResult.name,
      score: thaiResult.score
    });
  }
  if (openFdaResult) {
    candidates.push({
      source: "openfda",
      name: openFdaResult.name,
      score: openFdaResult.score ?? 1
    });
  }
  if (judgeResult?.name) {
    candidates.push({
      source: "judge",
      name: judgeResult.name,
      dosage: judgeResult.dosage ?? null,
      verdict: judgeResult.verdict ?? null,
      notes: judgeResult.notes ?? null
    });
  }

  const thai = thaiResult;
  const fda = openFdaResult;
  const judge = judgeResult;
  const judgeUncertain = !judge || judge.verdict === "uncertain" || !judge.name;
  const dosageFromJudge = judge?.dosage?.trim() ? judge.dosage.trim() : null;

  const bothDb = Boolean(thai && fda);
  const sameDbNames = bothDb && namesAgree(thai.name, fda.name);

  // Both DB hits, same name
  if (sameDbNames) {
    return {
      status: "consensus",
      finalName: thai.name,
      finalDosage: dosageFromJudge || ocrDosage || "",
      label: "verified",
      candidates
    };
  }

  // Both DB hits, different names
  if (bothDb && !sameDbNames) {
    if (!judgeUncertain && judge.verdict && judge.verdict !== "uncertain") {
      const pick =
        judge.verdict === "prefer_thai"
          ? thai.name
          : judge.verdict === "prefer_openfda"
            ? fda.name
            : judge.name;
      return {
        status: "consensus",
        finalName: pick,
        finalDosage: dosageFromJudge || ocrDosage || "",
        label: "verified",
        candidates
      };
    }
    return {
      status: "disagreement",
      finalName: null,
      finalDosage: ocrDosage || "",
      label: "conflict",
      candidates
    };
  }

  // Thai only
  if (thai && !fda) {
    if (judgeUncertain || namesAgree(judge?.name, thai.name) || judge?.verdict === "prefer_thai") {
      return {
        status: "consensus",
        finalName: thai.name,
        finalDosage: dosageFromJudge || ocrDosage || "",
        label: "verified",
        candidates
      };
    }
    if (judge?.name && !namesAgree(judge.name, thai.name) && judge.verdict !== "uncertain") {
      // Judge disagrees with sole Thai hit — surface both
      return {
        status: "disagreement",
        finalName: null,
        finalDosage: ocrDosage || "",
        label: "conflict",
        candidates
      };
    }
    return {
      status: "consensus",
      finalName: thai.name,
      finalDosage: dosageFromJudge || ocrDosage || "",
      label: "verified",
      candidates
    };
  }

  // openFDA only
  if (fda && !thai) {
    if (judgeUncertain || namesAgree(judge?.name, fda.name) || judge?.verdict === "prefer_openfda") {
      return {
        status: "consensus",
        finalName: fda.name,
        finalDosage: dosageFromJudge || ocrDosage || "",
        label: "verified",
        candidates
      };
    }
    if (judge?.name && !namesAgree(judge.name, fda.name) && judge.verdict !== "uncertain") {
      return {
        status: "disagreement",
        finalName: null,
        finalDosage: ocrDosage || "",
        label: "conflict",
        candidates
      };
    }
    return {
      status: "consensus",
      finalName: fda.name,
      finalDosage: dosageFromJudge || ocrDosage || "",
      label: "verified",
      candidates
    };
  }

  // Judge only
  if (!thai && !fda && judge?.name && judge.verdict !== "uncertain") {
    return {
      status: "consensus",
      finalName: judge.name,
      finalDosage: dosageFromJudge || ocrDosage || "",
      label: "ai_corrected",
      candidates
    };
  }

  // Nothing verified
  return {
    status: "unverified",
    finalName: ocrName || "",
    finalDosage: ocrDosage || "",
    label: "unverified",
    candidates
  };
}

/**
 * Run Thai + openFDA lookups in parallel (openFDA gated by Latin script).
 */
export async function runLookups(ocrName, { fetchImpl = fetch, matchThai = matchThaiMedicine } = {}) {
  const thaiPromise = Promise.resolve(matchThai(ocrName));
  const fdaPromise = isLatinScriptName(ocrName)
    ? lookupOpenFdaByName(ocrName, fetchImpl)
    : Promise.resolve(null);

  const [thaiResult, openFdaResult] = await Promise.all([thaiPromise, fdaPromise]);
  return { thaiResult, openFdaResult };
}

/**
 * Full consensus after OCR parse. `callJudge` is optional injectable async function.
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

  const { thaiResult, openFdaResult } = await runLookups(ocrName, { fetchImpl, matchThai });

  let judgeResult = null;
  const skip = shouldSkipJudge(thaiResult, openFdaResult);

  if (!skip && typeof callJudge === "function") {
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
    judgeSkipped: skip
  };
}
