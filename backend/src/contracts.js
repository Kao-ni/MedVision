export const MEDICINE_FORMS = ["tablet", "capsule", "liquid", "injection", "patch", "inhaler", "other"];
export const DOSE_EVENT_STATUSES = ["pending", "complete", "omitted", "missed"];
export const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
export const SUPPORTED_IMAGE_TYPES = [
  "image/jpeg",
  "image/png",
  "image/heic",
  "image/heif"
];

export function normalizeMedicineForm(value) {
  const text = typeof value === "string" ? value.trim().toLowerCase() : "";
  if (!text) {
    return "";
  }
  if (text === "pill") {
    return "tablet";
  }
  return text;
}
