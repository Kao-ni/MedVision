import { AppError } from "../../../backend/src/errors.js";
import { generateInviteCode } from "../../../backend/src/lineMessaging.js";
import { json, withErrorHandling } from "../_shared/http.js";
import { requireUser } from "../_shared/runtime.js";

const INVITE_TTL_MS = 15 * 60 * 1000;

Deno.serve((request) =>
  withErrorHandling(request, async () => {
    const { userClient, adminClient, userId } = await requireUser(request);

    if (request.method === "GET") {
      const link = await userClient
        .from("caregiver_line_links")
        .select("id, line_user_id, enabled, created_at, revoked_at")
        .eq("patient_user_id", userId)
        .is("revoked_at", null)
        .maybeSingle();

      if (link.error) {
        throw new AppError("Failed to fetch caregiver link", {
          code: "caregiver_link_fetch_failed",
          status: 500,
          details: link.error.message
        });
      }

      return json({
        linked: Boolean(link.data?.enabled && link.data?.line_user_id),
        link: link.data ?? null
      });
    }

    if (request.method === "POST") {
      const code = generateInviteCode();
      const expiresAt = new Date(Date.now() + INVITE_TTL_MS).toISOString();

      // Invalidate unused prior codes for this patient.
      await adminClient
        .from("caregiver_invite_codes")
        .delete()
        .eq("patient_user_id", userId)
        .is("used_at", null);

      const inserted = await userClient
        .from("caregiver_invite_codes")
        .insert({
          code,
          patient_user_id: userId,
          expires_at: expiresAt
        })
        .select("code, expires_at")
        .single();

      if (inserted.error) {
        throw new AppError("Failed to create invite code", {
          code: "invite_create_failed",
          status: 500,
          details: inserted.error.message
        });
      }

      return json({
        code: inserted.data.code,
        expiresAt: inserted.data.expires_at,
        instructions:
          "Open the MedVision LINE Official Account and send this code as a message within 15 minutes."
      }, 201);
    }

    if (request.method === "DELETE") {
      const revoked = await userClient
        .from("caregiver_line_links")
        .update({
          enabled: false,
          revoked_at: new Date().toISOString()
        })
        .eq("patient_user_id", userId)
        .is("revoked_at", null)
        .select("id");

      if (revoked.error) {
        throw new AppError("Failed to unlink caregiver", {
          code: "caregiver_unlink_failed",
          status: 500,
          details: revoked.error.message
        });
      }

      return json({ unlinked: true, count: revoked.data?.length ?? 0 });
    }

    throw new AppError("Method not allowed", { code: "method_not_allowed", status: 405 });
  })
);
