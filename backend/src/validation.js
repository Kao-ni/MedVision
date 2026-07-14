import { DOSE_EVENT_STATUSES, MAX_IMAGE_BYTES, MEDICINE_FORMS, SUPPORTED_IMAGE_TYPES } from "./contracts.js";
import { ValidationError } from "./errors.js";

function asTrimmedString(value, fieldName, { required = false, fallback = "" } = {}) {
  if (value == null) {
    if (required) throw new ValidationError(`${fieldName} is required`);
    return fallback;
  }

  if (typeof value !== "string") {
    throw new ValidationError(`${fieldName} must be a string`);
  }

  const normalized = value.trim();
  if (required && !normalized) {
    throw new ValidationError(`${fieldName} is required`);
  }

  return normalized;
}

function asBoolean(value, fieldName) {
  if (typeof value !== "boolean") {
    throw new ValidationError(`${fieldName} must be a boolean`);
  }
  return value;
}

export { ValidationError } from "./errors.js";

export function validateMedicinePayload(input) {
  if (!input || typeof input !== "object") {
    throw new ValidationError("medicine payload is required");
  }

  const name = asTrimmedString(input.name, "name", { required: true });
  const dosage = asTrimmedString(input.dosage, "dosage");
  const notes = asTrimmedString(input.notes, "notes");
  const frequencyNote = asTrimmedString(input.frequencyNote, "frequencyNote");
  const form = asTrimmedString(input.form ?? "pill", "form", { required: true }).toLowerCase();

  if (!MEDICINE_FORMS.includes(form)) {
    throw new ValidationError("form must be one of the supported medicine forms", {
      allowedForms: MEDICINE_FORMS
    });
  }

  return { name, dosage, form, notes, frequencyNote };
}

export function validateSchedulePayload(input) {
  if (!input || typeof input !== "object") {
    throw new ValidationError("schedule payload is required");
  }

  const medicineId = asTrimmedString(input.medicineId, "medicineId", { required: true });
  const frequencyType = asTrimmedString(input.frequencyType, "frequencyType", { required: true }).toLowerCase();
  const instructions = asTrimmedString(input.instructions, "instructions");
  const withFood = input.withFood == null ? false : asBoolean(input.withFood, "withFood");
  const times = Array.isArray(input.times) ? input.times.map((entry) => asTrimmedString(entry, "times[]", { required: true })) : null;

  if (!times || times.length === 0) {
    throw new ValidationError("times must contain at least one reminder time");
  }

  return { medicineId, frequencyType, times, withFood, instructions };
}

export function validateRecognitionUpload(input) {
  if (!input || typeof input !== "object") {
    throw new ValidationError("upload metadata is required");
  }

  const contentType = asTrimmedString(input.contentType, "contentType", { required: true }).toLowerCase();
  const size = Number(input.size);

  if (!SUPPORTED_IMAGE_TYPES.includes(contentType)) {
    throw new ValidationError("unsupported image type", {
      supportedTypes: SUPPORTED_IMAGE_TYPES
    });
  }

  if (!Number.isFinite(size) || size <= 0) {
    throw new ValidationError("upload size must be a positive number");
  }

  if (size > MAX_IMAGE_BYTES) {
    throw new ValidationError(`upload exceeds ${MAX_IMAGE_BYTES} byte limit`);
  }

  return { contentType, size };
}

export function validateDoseEventPayload(input) {
  if (!input || typeof input !== "object") {
    throw new ValidationError("dose event payload is required");
  }

  const medicineId = asTrimmedString(input.medicineId, "medicineId", { required: true });
  const scheduledFor = asTrimmedString(input.scheduledFor, "scheduledFor", { required: true });
  const status = asTrimmedString(input.status ?? "pending", "status", { required: true }).toLowerCase();
  const takenAt = input.takenAt == null ? null : asTrimmedString(input.takenAt, "takenAt", { required: true });

  if (!DOSE_EVENT_STATUSES.includes(status)) {
    throw new ValidationError("status must be one of the supported dose event states", {
      allowedStatuses: DOSE_EVENT_STATUSES
    });
  }

  if (status === "complete" && !takenAt) {
    throw new ValidationError("takenAt is required when status is complete");
  }

  return { medicineId, scheduledFor, status, takenAt };
}
