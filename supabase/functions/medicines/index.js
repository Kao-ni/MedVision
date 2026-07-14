import { AppError } from "../../../backend/src/errors.js";
import { validateMedicinePayload } from "../../../backend/src/validation.js";
import { getQueryParam, json, noContent, readJson, withErrorHandling } from "../_shared/http.js";
import { requireUser } from "../_shared/runtime.js";

Deno.serve((request) => withErrorHandling(request, async () => {
  const { userClient, userId } = await requireUser(request);
  const id = getQueryParam(request, "id");

  if (request.method === "GET") {
    const query = userClient
      .from("medicines")
      .select("id, name, dosage, form, notes, image_path, source, frequency_note, created_at, updated_at")
      .order("updated_at", { ascending: false });

    const result = id ? await query.eq("id", id).maybeSingle() : await query;
    if (result.error) {
      throw new AppError("Failed to fetch medicines", { code: "medicine_fetch_failed", status: 500, details: result.error.message });
    }
    return json(id ? result.data : { items: result.data ?? [] });
  }

  if (request.method === "POST") {
    const payload = validateMedicinePayload(await readJson(request));
    const result = await userClient
      .from("medicines")
      .insert({
        user_id: userId,
        name: payload.name,
        dosage: payload.dosage,
        form: payload.form,
        notes: payload.notes,
        source: "manual",
        frequency_note: payload.frequencyNote
      })
      .select("*")
      .single();

    if (result.error) {
      throw new AppError("Failed to create medicine", { code: "medicine_create_failed", status: 500, details: result.error.message });
    }
    return json(result.data, 201);
  }

  if (request.method === "PATCH") {
    if (!id) {
      throw new AppError("id is required", { code: "missing_id", status: 400 });
    }

    const existing = await userClient.from("medicines").select("*").eq("id", id).maybeSingle();
    if (existing.error) {
      throw new AppError("Failed to fetch medicine for update", { code: "medicine_fetch_failed", status: 500, details: existing.error.message });
    }
    if (!existing.data) {
      throw new AppError("Medicine not found", { code: "not_found", status: 404 });
    }

    const input = await readJson(request);
    const payload = validateMedicinePayload({
      name: input.name ?? existing.data.name,
      dosage: input.dosage ?? existing.data.dosage,
      form: input.form ?? existing.data.form,
      notes: input.notes ?? existing.data.notes,
      frequencyNote: input.frequencyNote ?? existing.data.frequency_note
    });

    const updated = await userClient
      .from("medicines")
      .update({
        name: payload.name,
        dosage: payload.dosage,
        form: payload.form,
        notes: payload.notes,
        frequency_note: payload.frequencyNote
      })
      .eq("id", id)
      .select("*")
      .single();

    if (updated.error) {
      throw new AppError("Failed to update medicine", { code: "medicine_update_failed", status: 500, details: updated.error.message });
    }
    return json(updated.data);
  }

  if (request.method === "DELETE") {
    if (!id) {
      throw new AppError("id is required", { code: "missing_id", status: 400 });
    }

    const deleted = await userClient.from("medicines").delete().eq("id", id);
    if (deleted.error) {
      throw new AppError("Failed to delete medicine", { code: "medicine_delete_failed", status: 500, details: deleted.error.message });
    }
    return noContent();
  }

  throw new AppError("Method not allowed", { code: "method_not_allowed", status: 405 });
}));
