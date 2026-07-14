import { AppError, UpstreamError } from "../../../backend/src/errors.js";
import { parseRecognizedMedicine } from "../../../backend/src/parseMedicine.js";
import { validateRecognitionUpload } from "../../../backend/src/validation.js";
import { json, withErrorHandling } from "../_shared/http.js";
import { getEnv, requireUser } from "../_shared/runtime.js";

function extensionFor(contentType: string) {
  switch (contentType) {
    case "image/jpeg":
      return "jpg";
    case "image/png":
      return "png";
    case "image/heic":
      return "heic";
    case "image/heif":
      return "heif";
    default:
      return "bin";
  }
}

function toBase64(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

function extractTyphoonText(payload) {
  const content = payload?.choices?.[0]?.message?.content;
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .map((part) => typeof part?.text === "string" ? part.text : "")
      .filter(Boolean)
      .join("\n");
  }
  return "";
}

async function callTyphoon(blob: Blob, contentType: string) {
  const apiKey = getEnv("TYPHOON_API_KEY");
  const baseUrl = getEnv("TYPHOON_BASE_URL", "https://api.opentyphoon.ai/v1");
  const model = getEnv("TYPHOON_MODEL", "typhoon-ocr-preview");
  const prompt = getEnv(
    "TYPHOON_OCR_PROMPT",
    "Read the medicine packet and return the visible medicine name, dosage, dosage form, and any notes as plain text."
  );

  const bytes = new Uint8Array(await blob.arrayBuffer());
  const imageUrl = `data:${contentType};base64,${toBase64(bytes)}`;
  const response = await fetch(`${baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "content-type": "application/json"
    },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: prompt },
            { type: "image_url", image_url: { url: imageUrl } }
          ]
        }
      ]
    })
  });

  if (!response.ok) {
    throw new UpstreamError("Typhoon OCR request failed", {
      status: response.status,
      body: await response.text()
    });
  }

  const payload = await response.json();
  const text = extractTyphoonText(payload).trim();
  if (!text) {
    throw new UpstreamError("Typhoon OCR returned no readable text");
  }

  return { rawText: text, upstream: payload };
}

Deno.serve((request) => withErrorHandling(request, async () => {
  if (request.method !== "POST") {
    throw new AppError("Method not allowed", { code: "method_not_allowed", status: 405 });
  }

  const { adminClient, userId } = await requireUser(request);
  const formData = await request.formData();
  const image = formData.get("image");

  if (!(image instanceof Blob)) {
    throw new AppError("image file is required", { code: "missing_image", status: 400 });
  }

  const contentType = image.type || "application/octet-stream";
  validateRecognitionUpload({ contentType, size: image.size });

  const path = `${userId}/${crypto.randomUUID()}.${extensionFor(contentType)}`;
  const uploadResult = await adminClient.storage
    .from("medicine-images")
    .upload(path, image, { contentType, upsert: false });

  if (uploadResult.error) {
    throw new AppError("Failed to upload medicine image", {
      code: "storage_upload_failed",
      status: 500,
      details: uploadResult.error.message
    });
  }

  const createdJob = await adminClient
    .from("recognition_jobs")
    .insert({
      user_id: userId,
      image_path: path,
      status: "processing"
    })
    .select("id")
    .single();

  if (createdJob.error || !createdJob.data) {
    throw new AppError("Failed to create recognition job", {
      code: "recognition_job_failed",
      status: 500,
      details: createdJob.error?.message ?? null
    });
  }

  try {
    const typhoon = await callTyphoon(image, contentType);
    const parsedMedicine = parseRecognizedMedicine(typhoon.rawText);

    const updated = await adminClient
      .from("recognition_jobs")
      .update({
        status: "completed",
        raw_ocr_text: typhoon.rawText,
        parsed_result: parsedMedicine,
        failure_reason: ""
      })
      .eq("id", createdJob.data.id)
      .eq("user_id", userId);

    if (updated.error) {
      throw new AppError("Failed to update recognition job", {
        code: "recognition_job_update_failed",
        status: 500,
        details: updated.error.message
      });
    }

    return json({
      jobId: createdJob.data.id,
      status: "completed",
      rawText: typhoon.rawText,
      parsedMedicine,
      parseConfidence: parsedMedicine.confidence,
      warnings: parsedMedicine.warnings
    });
  } catch (error) {
    await adminClient
      .from("recognition_jobs")
      .update({
        status: "failed",
        failure_reason: error instanceof Error ? error.message : "Unknown OCR error"
      })
      .eq("id", createdJob.data.id)
      .eq("user_id", userId);
    throw error;
  }
}));
