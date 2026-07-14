function listFromValue(value) {
  if (Array.isArray(value)) {
    return value.map((entry) => String(entry).trim()).filter(Boolean);
  }
  if (typeof value === "string" && value.trim()) {
    return [value.trim()];
  }
  return [];
}

export function normalizeDrugQuery(input) {
  return String(input ?? "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

export function normalizeDrugInfoResponse(payload) {
  const genericNames = listFromValue(payload?.generic_name);
  const brandNames = listFromValue(payload?.brand_name);
  const purpose = listFromValue(payload?.purpose);
  const indications = listFromValue(payload?.indications_and_usage);
  const warnings = listFromValue(payload?.warnings);

  return {
    title: genericNames[0] ?? brandNames[0] ?? "Unknown medicine",
    subtitle: brandNames[0] ?? "",
    uses: [...purpose, ...indications].filter(Boolean),
    warnings,
    source: "openfda"
  };
}
