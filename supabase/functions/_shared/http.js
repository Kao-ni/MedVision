import { AppError } from "../../../backend/src/errors.js";

const defaultHeaders = {
  "content-type": "application/json; charset=utf-8"
};

export function json(data, status = 200, headers = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...defaultHeaders, ...headers }
  });
}

export function noContent() {
  return new Response(null, { status: 204 });
}

export async function readJson(request) {
  try {
    return await request.json();
  } catch {
    throw new AppError("Request body must be valid JSON", {
      code: "invalid_json",
      status: 400
    });
  }
}

export function getQueryParam(request, key) {
  const url = new URL(request.url);
  return url.searchParams.get(key);
}

export async function withErrorHandling(request, handler) {
  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "access-control-allow-origin": "*",
        "access-control-allow-methods": "GET,POST,PATCH,DELETE,OPTIONS",
        "access-control-allow-headers": "authorization, x-client-info, apikey, content-type"
      }
    });
  }

  try {
    const response = await handler();
    response.headers.set("access-control-allow-origin", "*");
    return response;
  } catch (error) {
    const appError = error instanceof AppError
      ? error
      : new AppError(error instanceof Error ? error.message : "Unexpected error", {
          code: "internal_error",
          status: 500
        });

    console.error(JSON.stringify({
      level: "error",
      code: appError.code,
      status: appError.status,
      message: appError.message,
      details: appError.details
    }));

    return json({
      error: {
        code: appError.code,
        message: appError.message,
        details: appError.details
      }
    }, appError.status, {
      "access-control-allow-origin": "*"
    });
  }
}
