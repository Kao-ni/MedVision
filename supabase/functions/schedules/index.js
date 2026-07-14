import { AppError } from "../../../backend/src/errors.js";
import { validateSchedulePayload } from "../../../backend/src/validation.js";
import { getQueryParam, json, noContent, readJson, withErrorHandling } from "../_shared/http.js";
import { requireUser } from "../_shared/runtime.js";

Deno.serve((request) => withErrorHandling(request, async () => {
  const { userClient, userId } = await requireUser(request);
  const id = getQueryParam(request, "id");

  if (request.method === "GET") {
    const query = userClient
      .from("schedules")
      .select("id, medicine_id, frequency_type, times, with_food, instructions, created_at, updated_at")
      .order("updated_at", { ascending: false });

    const result = id ? await query.eq("id", id).maybeSingle() : await query;
    if (result.error) {
      throw new AppError("Failed to fetch schedules", { code: "schedule_fetch_failed", status: 500, details: result.error.message });
    }
    return json(id ? result.data : { items: result.data ?? [] });
  }

  if (request.method === "POST") {
    const payload = validateSchedulePayload(await readJson(request));
    const result = await userClient
      .from("schedules")
      .insert({
        user_id: userId,
        medicine_id: payload.medicineId,
        frequency_type: payload.frequencyType,
        times: payload.times,
        with_food: payload.withFood,
        instructions: payload.instructions
      })
      .select("*")
      .single();

    if (result.error) {
      throw new AppError("Failed to create schedule", { code: "schedule_create_failed", status: 500, details: result.error.message });
    }
    return json(result.data, 201);
  }

  if (request.method === "PATCH") {
    if (!id) {
      throw new AppError("id is required", { code: "missing_id", status: 400 });
    }

    const existing = await userClient.from("schedules").select("*").eq("id", id).maybeSingle();
    if (existing.error) {
      throw new AppError("Failed to fetch schedule for update", { code: "schedule_fetch_failed", status: 500, details: existing.error.message });
    }
    if (!existing.data) {
      throw new AppError("Schedule not found", { code: "not_found", status: 404 });
    }

    const input = await readJson(request);
    const payload = validateSchedulePayload({
      medicineId: input.medicineId ?? existing.data.medicine_id,
      frequencyType: input.frequencyType ?? existing.data.frequency_type,
      times: input.times ?? existing.data.times,
      withFood: input.withFood ?? existing.data.with_food,
      instructions: input.instructions ?? existing.data.instructions
    });

    const updated = await userClient
      .from("schedules")
      .update({
        medicine_id: payload.medicineId,
        frequency_type: payload.frequencyType,
        times: payload.times,
        with_food: payload.withFood,
        instructions: payload.instructions
      })
      .eq("id", id)
      .select("*")
      .single();

    if (updated.error) {
      throw new AppError("Failed to update schedule", { code: "schedule_update_failed", status: 500, details: updated.error.message });
    }
    return json(updated.data);
  }

  if (request.method === "DELETE") {
    if (!id) {
      throw new AppError("id is required", { code: "missing_id", status: 400 });
    }

    const deleted = await userClient.from("schedules").delete().eq("id", id);
    if (deleted.error) {
      throw new AppError("Failed to delete schedule", { code: "schedule_delete_failed", status: 500, details: deleted.error.message });
    }
    return noContent();
  }

  throw new AppError("Method not allowed", { code: "method_not_allowed", status: 405 });
}));
