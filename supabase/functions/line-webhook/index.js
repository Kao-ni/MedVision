import { AppError } from "../../../backend/src/errors.js";
import {
  extractInviteCode,
  pushLineTextMessage,
  verifyLineSignature
} from "../../../backend/src/lineMessaging.js";
import { json, withErrorHandling } from "../_shared/http.js";
import { createClient } from "npm:@supabase/supabase-js@2";
import { getEnv } from "../_shared/runtime.js";

function adminClient() {
  return createClient(getEnv("SUPABASE_URL"), getEnv("SUPABASE_SERVICE_ROLE_KEY"));
}

async function redeemCode(db, code, lineUserId) {
  const invite = await db
    .from("caregiver_invite_codes")
    .select("*")
    .eq("code", code)
    .maybeSingle();

  if (invite.error || !invite.data) {
    return { ok: false, message: "Invalid code. Ask the patient to generate a new invite in MedVision." };
  }

  if (invite.data.used_at) {
    return { ok: false, message: "This code was already used." };
  }

  if (new Date(invite.data.expires_at).getTime() < Date.now()) {
    return { ok: false, message: "This code expired. Generate a new one in the MedVision app." };
  }

  const patientId = invite.data.patient_user_id;

  // Revoke any existing active link for this patient.
  await db
    .from("caregiver_line_links")
    .update({ enabled: false, revoked_at: new Date().toISOString() })
    .eq("patient_user_id", patientId)
    .is("revoked_at", null);

  const link = await db.from("caregiver_line_links").insert({
    patient_user_id: patientId,
    line_user_id: lineUserId,
    enabled: true
  });

  if (link.error) {
    return { ok: false, message: "Could not save caregiver link. Try again." };
  }

  await db
    .from("caregiver_invite_codes")
    .update({
      used_at: new Date().toISOString(),
      used_by_line_user_id: lineUserId
    })
    .eq("id", invite.data.id);

  return {
    ok: true,
    message:
      "MedVision alerts are on. You will get a LINE message if a dose is missed for 30 minutes."
  };
}

Deno.serve((request) =>
  withErrorHandling(request, async () => {
    if (request.method !== "POST") {
      throw new AppError("Method not allowed", { code: "method_not_allowed", status: 405 });
    }

    const channelSecret = getEnv("LINE_CHANNEL_SECRET");
    const channelAccessToken = getEnv("LINE_CHANNEL_ACCESS_TOKEN");
    const bodyText = await request.text();
    const signature = request.headers.get("x-line-signature") ?? "";

    const valid = await verifyLineSignature(bodyText, signature, channelSecret);
    if (!valid) {
      throw new AppError("Invalid LINE signature", { code: "unauthorized", status: 401 });
    }

    let payload;
    try {
      payload = JSON.parse(bodyText);
    } catch {
      throw new AppError("Invalid JSON", { code: "invalid_json", status: 400 });
    }

    const db = adminClient();
    const events = Array.isArray(payload.events) ? payload.events : [];

    for (const event of events) {
      const lineUserId = event?.source?.userId;
      if (!lineUserId) continue;

      if (event.type === "follow") {
        await pushLineTextMessage(
          lineUserId,
          "Welcome to MedVision caregiver alerts. Send the 8-character invite code from the patient's MedVision app to connect.",
          channelAccessToken
        );
        continue;
      }

      if (event.type === "message" && event.message?.type === "text") {
        const code = extractInviteCode(event.message.text ?? "");
        if (!code) {
          await pushLineTextMessage(
            lineUserId,
            "Send the 8-character invite code shown in MedVision (Profile → Caregiver LINE alerts).",
            channelAccessToken
          );
          continue;
        }

        const result = await redeemCode(db, code, lineUserId);
        await pushLineTextMessage(lineUserId, result.message, channelAccessToken);
      }
    }

    // LINE requires 200 quickly.
    return json({ ok: true });
  })
);
