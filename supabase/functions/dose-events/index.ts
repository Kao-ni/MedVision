import { AppError } from "../../../backend/src/errors.js";
import {
  validateDoseEventPayload,
  validateDoseEventSyncPayload
} from "../../../backend/src/validation.js";
import { json, readJson, withErrorHandling } from "../_shared/http.js";
import { requireUser } from "../_shared/runtime.js";

async function resolveMedicineId(userClient, userId, { medicineName, dosage, form }) {
  const existing = await userClient
    .from("medicines")
    .select("id")
    .eq("user_id", userId)
    .eq("name", medicineName)
    .eq("dosage", dosage)
    .limit(1)
    .maybeSingle();

  if (existing.error) {
    throw new AppError("Failed to look up medicine", {
      code: "medicine_lookup_failed",
      status: 500,
      details: existing.error.message
    });
  }

  if (existing.data?.id) return existing.data.id;

  const created = await userClient
    .from("medicines")
    .insert({
      user_id: userId,
      name: medicineName,
      dosage,
      form,
      source: "manual"
    })
    .select("id")
    .single();

  if (created.error || !created.data) {
    throw new AppError("Failed to create medicine for dose sync", {
      code: "medicine_create_failed",
      status: 500,
      details: created.error?.message ?? null
    });
  }

  return created.data.id;
}

Deno.serve((request) =>
  withErrorHandling(request, async () => {
    const { userClient, userId } = await requireUser(request);

    if (request.method === "GET") {
      const result = await userClient
        .from("dose_events")
        .select("id, medicine_id, scheduled_for, taken_at, status, client_key, alert_sent_at, created_at")
        .order("scheduled_for", { ascending: false });

      if (result.error) {
        throw new AppError("Failed to fetch dose events", {
          code: "dose_event_fetch_failed",
          status: 500,
          details: result.error.message
        });
      }
      return json({ items: result.data ?? [] });
    }

    if (request.method === "POST") {
      const body = await readJson(request);

      // Client-keyed upsert from iOS (preferred path for caregiver alerts).
      if (body?.clientKey) {
        const payload = validateDoseEventSyncPayload(body);
        const medicineId = await resolveMedicineId(userClient, userId, payload);

        const existing = await userClient
          .from("dose_events")
          .select("id")
          .eq("user_id", userId)
          .eq("client_key", payload.clientKey)
          .maybeSingle();

        if (existing.error) {
          throw new AppError("Failed to look up dose event", {
            code: "dose_event_lookup_failed",
            status: 500,
            details: existing.error.message
          });
        }

        if (existing.data?.id) {
          const updated = await userClient
            .from("dose_events")
            .update({
              medicine_id: medicineId,
              scheduled_for: payload.scheduledFor,
              taken_at: payload.takenAt,
              status: payload.status
            })
            .eq("id", existing.data.id)
            .eq("user_id", userId)
            .select("*")
            .single();

          if (updated.error) {
            throw new AppError("Failed to update dose event", {
              code: "dose_event_update_failed",
              status: 500,
              details: updated.error.message
            });
          }
          return json(updated.data);
        }

        const inserted = await userClient
          .from("dose_events")
          .insert({
            user_id: userId,
            medicine_id: medicineId,
            scheduled_for: payload.scheduledFor,
            taken_at: payload.takenAt,
            status: payload.status,
            client_key: payload.clientKey
          })
          .select("*")
          .single();

        if (inserted.error) {
          throw new AppError("Failed to create dose event", {
            code: "dose_event_create_failed",
            status: 500,
            details: inserted.error.message
          });
        }
        return json(inserted.data, 201);
      }

      const payload = validateDoseEventPayload(body);
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
        throw new AppError("Failed to create dose event", {
          code: "dose_event_create_failed",
          status: 500,
          details: result.error.message
        });
      }
      return json(result.data, 201);
    }

    if (request.method === "PATCH") {
      const body = await readJson(request);
      const id = typeof body?.id === "string" ? body.id.trim() : "";
      if (!id) {
        throw new AppError("id is required", { code: "validation_error", status: 400 });
      }

      const patch = {};
      if (body.status != null) {
        const status = String(body.status).toLowerCase();
        patch.status = status;
      }
      if (body.takenAt !== undefined) {
        patch.taken_at = body.takenAt;
      }
      if (body.scheduledFor != null) {
        patch.scheduled_for = body.scheduledFor;
      }

      if (Object.keys(patch).length === 0) {
        throw new AppError("No fields to update", { code: "validation_error", status: 400 });
      }

      const updated = await userClient
        .from("dose_events")
        .update(patch)
        .eq("id", id)
        .eq("user_id", userId)
        .select("*")
        .single();

      if (updated.error) {
        throw new AppError("Failed to update dose event", {
          code: "dose_event_update_failed",
          status: 500,
          details: updated.error.message
        });
      }
      return json(updated.data);
    }

    throw new AppError("Method not allowed", { code: "method_not_allowed", status: 405 });
  })
);
