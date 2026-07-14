import { AppError } from "../../../backend/src/errors.js";
import { validateDoseEventPayload } from "../../../backend/src/validation.js";
import { json, readJson, withErrorHandling } from "../_shared/http.js";
import { requireUser } from "../_shared/runtime.js";

Deno.serve((request) => withErrorHandling(request, async () => {
  const { userClient, userId } = await requireUser(request);

  if (request.method === "GET") {
    const result = await userClient
      .from("dose_events")
      .select("id, medicine_id, scheduled_for, taken_at, status, created_at")
      .order("scheduled_for", { ascending: false });

    if (result.error) {
      throw new AppError("Failed to fetch dose events", { code: "dose_event_fetch_failed", status: 500, details: result.error.message });
    }
    return json({ items: result.data ?? [] });
  }

  if (request.method === "POST") {
    const payload = validateDoseEventPayload(await readJson(request));
    const result = await userClient
      .from("dose_events")
      .insert({
        user_id: userId,
        medicine_id: payload.medicineId,
        scheduled_for: payload.scheduledFor,
        taken_at: payload.takenAt,
        status: payload.status
      })
      .select("*")
      .single();

    if (result.error) {
      throw new AppError("Failed to create dose event", { code: "dose_event_create_failed", status: 500, details: result.error.message });
    }
    return json(result.data, 201);
  }

  throw new AppError("Method not allowed", { code: "method_not_allowed", status: 405 });
}));
