import { AppError, UpstreamError } from "../../../backend/src/errors.js";
import { normalizeDrugInfoResponse, normalizeDrugQuery } from "../../../backend/src/drugInfo.js";
import { getQueryParam, json, withErrorHandling } from "../_shared/http.js";
import { requireUser } from "../_shared/runtime.js";

function mapOpenFdaRecord(record) {
  return {
    generic_name: record?.openfda?.generic_name ?? [],
    brand_name: record?.openfda?.brand_name ?? [],
    purpose: record?.purpose ?? [],
    warnings: record?.warnings ?? [],
    indications_and_usage: record?.indications_and_usage ?? []
  };
}

async function fetchOpenFda(query: string) {
  const search = encodeURIComponent(`openfda.generic_name:\"${query}\"`);
  const response = await fetch(`https://api.fda.gov/drug/label.json?limit=1&search=${search}`);

  if (response.status === 404) {
    return null;
  }

  if (!response.ok) {
    throw new UpstreamError("Drug info provider request failed", {
      status: response.status,
      body: await response.text()
    });
  }

  const payload = await response.json();
  const first = payload?.results?.[0];
  return first ? normalizeDrugInfoResponse(mapOpenFdaRecord(first)) : null;
}

Deno.serve((request) => withErrorHandling(request, async () => {
  if (request.method !== "GET") {
    throw new AppError("Method not allowed", { code: "method_not_allowed", status: 405 });
  }

  const { adminClient } = await requireUser(request);
  const query = normalizeDrugQuery(getQueryParam(request, "query") ?? getQueryParam(request, "q") ?? "");

  if (!query) {
    throw new AppError("query is required", { code: "missing_query", status: 400 });
  }

  const cached = await adminClient
    .from("drug_info_cache")
    .select("response_summary, expires_at")
    .eq("normalized_query", query)
    .gt("expires_at", new Date().toISOString())
    .maybeSingle();

  if (cached.data?.response_summary) {
    return json({ cached: true, query, result: cached.data.response_summary });
  }

  const result = await fetchOpenFda(query);
  if (!result) {
    return json({ cached: false, query, result: null, message: "info_not_found" }, 404);
  }

  const expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 7).toISOString();
  const upsert = await adminClient
    .from("drug_info_cache")
    .upsert({
      normalized_query: query,
      provider: "openfda",
      response_summary: result,
      expires_at: expiresAt,
      fetched_at: new Date().toISOString()
    }, { onConflict: "normalized_query" });

  if (upsert.error) {
    console.error(JSON.stringify({ level: "warn", code: "drug_info_cache_upsert_failed", details: upsert.error.message }));
  }

  return json({ cached: false, query, result });
}));
