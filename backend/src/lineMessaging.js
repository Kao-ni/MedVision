/**
 * LINE Messaging API helpers for caregiver missed-dose alerts.
 */

export function getLineCredentials(getEnv) {
  return {
    channelAccessToken: getEnv("LINE_CHANNEL_ACCESS_TOKEN"),
    channelSecret: getEnv("LINE_CHANNEL_SECRET")
  };
}

/** Verify LINE webhook signature (HMAC-SHA256 of body, base64). */
export async function verifyLineSignature(bodyText, signatureHeader, channelSecret) {
  if (!signatureHeader || !channelSecret) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(channelSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(bodyText));
  const digest = btoa(String.fromCharCode(...new Uint8Array(mac)));
  return digest === signatureHeader;
}

export async function pushLineTextMessage(lineUserId, text, channelAccessToken) {
  const response = await fetch("https://api.line.me/v2/bot/message/push", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${channelAccessToken}`,
      "content-type": "application/json"
    },
    body: JSON.stringify({
      to: lineUserId,
      messages: [{ type: "text", text }]
    })
  });

  if (!response.ok) {
    const body = await response.text();
    return { ok: false, status: response.status, body };
  }
  return { ok: true, status: response.status };
}

export function formatMissedDoseMessage({
  patientName = "Someone",
  medicineName = "a medicine",
  dosage = "",
  scheduledFor
}) {
  const time = scheduledFor
    ? new Date(scheduledFor).toLocaleTimeString("en-GB", {
        hour: "2-digit",
        minute: "2-digit",
        timeZone: "Asia/Bangkok"
      })
    : "—";
  const dose = dosage ? ` (${dosage})` : "";
  return (
    `MedVision: ${patientName} missed ${medicineName}${dose} scheduled for ${time}. ` +
    `Please check in.\n` +
    `(แจ้งเตือน: พลาดยา ${medicineName}${dose} เวลา ${time})`
  );
}

export function generateInviteCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(8));
  return [...bytes].map((b) => alphabet[b % alphabet.length]).join("");
}

/** Extract 8-char invite code from free text. */
export function extractInviteCode(text = "") {
  const match = String(text).toUpperCase().match(/\b([A-Z0-9]{8})\b/);
  return match?.[1] ?? null;
}
