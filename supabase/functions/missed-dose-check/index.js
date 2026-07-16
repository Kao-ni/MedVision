import { AppError } from "../../../backend/src/errors.js";
import {
  formatMissedDoseMessage,
  pushLineTextMessage
} from "../../../backend/src/lineMessaging.js";
import { json, withErrorHandling } from "../_shared/http.js";
import { createClient } from "npm:@supabase/supabase-js@2";
import { getEnv } from "../_shared/runtime.js";

const GRACE_MS = 30 * 60 * 1000;
const MAX_ALERT_ATTEMPTS = 5;

function adminClient() {
  return createClient(getEnv("SUPABASE_URL"), getEnv("SUPABASE_SERVICE_ROLE_KEY"));
}

function requireCronAuth(request) {
  const cronSecret = Deno.env.get("CRON_SECRET");
  const auth = request.headers.get("Authorization") ?? "";
  const bearer = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  const headerSecret = request.headers.get("x-cron-secret") ?? "";

  // Prefer explicit cron secret; fall back to service role key for dashboard schedules.
  const serviceRole = getEnv("SUPABASE_SERVICE_ROLE_KEY");
  const ok =
    (cronSecret && (bearer === cronSecret || headerSecret === cronSecret)) ||
    bearer === serviceRole;

  if (!ok) {
    throw new AppError("Unauthorized cron call", { code: "unauthorized", status: 401 });
  }
}

Deno.serve((request) =>
  withErrorHandling(request, async () => {
    if (request.method !== "POST" && request.method !== "GET") {
      throw new AppError("Method not allowed", { code: "method_not_allowed", status: 405 });
    }

    requireCronAuth(request);

    const db = adminClient();
    const channelAccessToken = Deno.env.get("LINE_CHANNEL_ACCESS_TOKEN") ?? "";
    const cutoff = new Date(Date.now() - GRACE_MS).toISOString();

    const pending = await db
      .from("dose_events")
      .select("id, user_id, medicine_id, scheduled_for, status, alert_sent_at, alert_attempts")
      .eq("status", "pending")
      .is("alert_sent_at", null)
      .lte("scheduled_for", cutoff)
      .lt("alert_attempts", MAX_ALERT_ATTEMPTS)
      .limit(100);

    if (pending.error) {
      throw new AppError("Failed to query pending doses", {
        code: "missed_query_failed",
        status: 500,
        details: pending.error.message
      });
    }

    const items = pending.data ?? [];
    let alerted = 0;
    let markedMissed = 0;
    let failed = 0;

    for (const event of items) {
      const [linkRes, medRes, profileRes] = await Promise.all([
        db
          .from("caregiver_line_links")
          .select("line_user_id, enabled")
          .eq("patient_user_id", event.user_id)
          .eq("enabled", true)
          .is("revoked_at", null)
          .maybeSingle(),
        db
          .from("medicines")
          .select("name, dosage")
          .eq("id", event.medicine_id)
          .maybeSingle(),
        db
          .from("profiles")
          .select("display_name")
          .eq("id", event.user_id)
          .maybeSingle()
      ]);

      const link = linkRes.data;
      const medicineName = medRes.data?.name ?? "a medicine";
      const dosage = medRes.data?.dosage ?? "";
      const patientName =
        (profileRes.data?.display_name && String(profileRes.data.display_name).trim()) ||
        "Someone";

      // Always mark missed for History consistency once past grace.
      const baseUpdate = {
        status: "missed",
        alert_attempts: (event.alert_attempts ?? 0) + 1
      };

      if (!link?.line_user_id || !channelAccessToken) {
        await db
          .from("dose_events")
          .update({ ...baseUpdate, alert_sent_at: new Date().toISOString() })
          .eq("id", event.id);
        markedMissed += 1;
        continue;
      }

      const text = formatMissedDoseMessage({
        patientName,
        medicineName,
        dosage,
        scheduledFor: event.scheduled_for
      });

      const push = await pushLineTextMessage(link.line_user_id, text, channelAccessToken);

      if (push.ok) {
        await db
          .from("dose_events")
          .update({ ...baseUpdate, alert_sent_at: new Date().toISOString() })
          .eq("id", event.id);
        alerted += 1;
        markedMissed += 1;
      } else {
        failed += 1;
        const attempts = (event.alert_attempts ?? 0) + 1;
        const abandon = attempts >= MAX_ALERT_ATTEMPTS;
        await db
          .from("dose_events")
          .update({
            status: "missed",
            alert_attempts: attempts,
            ...(abandon ? { alert_sent_at: new Date().toISOString() } : {})
          })
          .eq("id", event.id);
        markedMissed += 1;

        if (abandon && push.status === 403) {
          await db
            .from("caregiver_line_links")
            .update({ enabled: false, revoked_at: new Date().toISOString() })
            .eq("patient_user_id", event.user_id)
            .eq("line_user_id", link.line_user_id)
            .is("revoked_at", null);
        }
      }
    }

    return json({
      checked: items.length,
      alerted,
      markedMissed,
      failed,
      cutoff
    });
  })
);
