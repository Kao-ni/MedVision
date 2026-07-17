import { AppError, UpstreamError } from "../../../backend/src/errors.js";
import { parseRecognizedMedicine } from "../../../backend/src/parseMedicine.js";
import { runConsensusPipeline } from "../../../backend/src/consensusEngine.js";
import { scrubPii } from "../../../backend/src/scrubPii.js";
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

function extractTyphoonText(payload: any) {
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

function stripCodeFences(text: string) {
  return text
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
}

async function callTyphoon(blob: Blob, contentType: string) {
  const apiKey = getEnv("TYPHOON_API_KEY");
  const baseUrl = getEnv("TYPHOON_BASE_URL", "https://api.opentyphoon.ai/v1");
  const model = getEnv("TYPHOON_MODEL", "typhoon-ocr-preview");
  const prompt = getEnv(
    "TYPHOON_OCR_PROMPT",
    "Extract and transcribe all text visible in this image. The text may be in Thai, English, or a mix of both. Carefully preserve every Thai character. Return only the extracted text."
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

  return { rawText: text };
}

async function callTyphoonParser(rawText: string) {
  const apiKey = getEnv("TYPHOON_API_KEY");
  const baseUrl = getEnv("TYPHOON_BASE_URL", "https://api.opentyphoon.ai/v1");
  const model = getEnv("TYPHOON_PARSE_MODEL", "typhoon-v2.5-30b-a3b-instruct");
  const prompt = getEnv(
    "TYPHOON_PARSE_PROMPT",
    [
      "You are a medicine label parser for a medication reminder app.",
      "Convert the OCR text into STRICT JSON ONLY with these keys:",
      "{",
      '  "is_medicine": true | false,',
      '  "name": string | null,',
      '  "dosage": string | null,',
      '  "form": "tablet" | "capsule" | "liquid" | "injection" | "drops" | "cream" | "inhaler" | "patch" | "powder" | "other" | null,',
      '  "when_to_take": {',
      '    "raw": string | null,',
      '    "times_per_day": number | null,',
      '    "time_slots": ["morning"|"midday"|"evening"|"night"],',
      '    "with_food": "before"|"with"|"after"|null,',
      '    "as_needed": true | false',
      "  },",
      '  "notes": string | null,',
      '  "warnings": string[]',
      "}",
      "Normalize schedule text into when_to_take. Examples:",
      '  หลังอาหารเช้า -> time_slots ["morning"], with_food "after", times_per_day 1',
      '  ก่อนอาหาร เช้า เย็น -> time_slots ["morning","evening"], with_food "before"',
      '  ก่อนนอน -> time_slots ["night"]',
      '  เมื่อมีอาการ -> as_needed true',
      "Do not invent clock times. If no schedule is printed, use raw null, times_per_day null, time_slots [], with_food null, as_needed false.",
      "If the text is not medicine, set is_medicine to false, set all fields to null except warnings, and explain briefly in warnings.",
      "Do not add markdown, code fences, or commentary.",
      "OCR TEXT:",
      rawText
    ].join("\n")
  );

  const response = await fetch(`${baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "content-type": "application/json"
    },
    body: JSON.stringify({
      model,
      max_tokens: 800,
      messages: [
        {
          role: "system",
          content: "You extract structured medicine data from OCR text. Return strict JSON only."
        },
        {
          role: "user",
          content: prompt
        }
      ]
    })
  });

  if (!response.ok) {
    throw new UpstreamError("Typhoon parse request failed", {
      status: response.status,
      body: await response.text()
    });
  }

  const payload = await response.json();
  const text = extractTyphoonText(payload).trim();
  if (!text) {
    throw new UpstreamError("Typhoon parse returned no readable text");
  }

  return { structuredText: text };
}

async function callJudge({ rawText, parsedMedicine, thaiResult, openFdaResult }: any) {
  const apiKey = getEnv("TYPHOON_API_KEY");
  const baseUrl = getEnv("TYPHOON_BASE_URL", "https://api.opentyphoon.ai/v1");
  const model = getEnv("TYPHOON_PARSE_MODEL", "typhoon-v2.5-30b-a3b-instruct");

  const prompt = [
    "You are a medicine-label arbitrator for a reminder app used in Thailand.",
    "You receive raw OCR text, the initial parsed medicine JSON, and optional database suggestions.",
    "Decide the best medicine name and fix obvious OCR dosage typos (e.g. 5Omg -> 50mg).",
    "Do NOT invent a drug that is unsupported by the OCR or the suggestions.",
    "Return STRICT JSON ONLY:",
    "{",
    '  "name": string | null,',
    '  "dosage": string | null,',
    '  "verdict": "prefer_thai" | "prefer_openfda" | "prefer_ocr" | "uncertain",',
    '  "notes": string',
    "}",
    "",
    "RAW OCR:",
    rawText,
    "",
    "PARSED JSON:",
    JSON.stringify(parsedMedicine),
    "",
    "THAI LIST SUGGESTION:",
    JSON.stringify(thaiResult),
    "",
    "OPENFDA SUGGESTION:",
    JSON.stringify(openFdaResult)
  ].join("\n");

  const response = await fetch(`${baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "content-type": "application/json"
    },
    body: JSON.stringify({
      model,
      max_tokens: 300,
      messages: [
        {
          role: "system",
          content: "You arbitrate medicine name candidates. Return strict JSON only."
        },
        { role: "user", content: prompt }
      ]
    })
  });

  if (!response.ok) {
    return { source: "judge", name: null, dosage: null, verdict: "uncertain", notes: "judge_request_failed" };
  }

  const payload = await response.json();
  const text = stripCodeFences(extractTyphoonText(payload).trim());
  try {
    const parsed = JSON.parse(text);
    return {
      source: "judge",
      name: typeof parsed.name === "string" ? parsed.name : null,
      dosage: typeof parsed.dosage === "string" ? parsed.dosage : null,
      verdict: typeof parsed.verdict === "string" ? parsed.verdict : "uncertain",
      notes: typeof parsed.notes === "string" ? parsed.notes : ""
    };
  } catch {
    return { source: "judge", name: null, dosage: null, verdict: "uncertain", notes: "judge_parse_failed" };
  }
}

Deno.serve((request) =>
  withErrorHandling(request, async () => {
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

    const deleteScanImage = async () => {
      try {
        await adminClient.storage.from("medicine-images").remove([path]);
      } catch {
        // Best-effort cleanup — do not fail the user response.
      }
    };

    try {
      const typhoon = await callTyphoon(image, contentType);
      const { scrubbedText } = scrubPii(typhoon.rawText);
      const parsed = await callTyphoonParser(scrubbedText);
      const parsedMedicine = parseRecognizedMedicine(parsed.structuredText);

      const consensus = await runConsensusPipeline({
        rawText: scrubbedText,
        parsedMedicine,
        callJudge
      });

      const resultPayload = {
        ...parsedMedicine,
        resolution: consensus.resolution,
        judgeSkipped: consensus.judgeSkipped
      };

      const updated = await adminClient
        .from("recognition_jobs")
        .update({
          status: "completed",
          raw_ocr_text: scrubbedText,
          parsed_result: resultPayload,
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

      await deleteScanImage();

      return json({
        jobId: createdJob.data.id,
        status: "completed",
        rawText: scrubbedText,
        parsedMedicine,
        resolution: consensus.resolution,
        judgeSkipped: consensus.judgeSkipped,
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
      await deleteScanImage();
      throw error;
    }
  }));
