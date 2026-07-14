import { createClient } from "npm:@supabase/supabase-js@2";
import { AppError } from "../../../backend/src/errors.js";

export function getEnv(name, fallback) {
  const value = Deno.env.get(name) ?? fallback;
  if (!value) {
    throw new AppError(`Missing environment variable: ${name}`, {
      code: "missing_env",
      status: 500
    });
  }
  return value;
}

export function createClients(request) {
  const supabaseUrl = getEnv("SUPABASE_URL");
  const supabaseAnonKey = getEnv("SUPABASE_ANON_KEY");
  const serviceRoleKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");
  const authHeader = request.headers.get("Authorization");

  if (!authHeader) {
    throw new AppError("Missing Authorization header", {
      code: "unauthorized",
      status: 401
    });
  }

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: {
        Authorization: authHeader
      }
    }
  });

  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  return { userClient, adminClient, authHeader };
}

export async function requireUser(request) {
  const { userClient, adminClient, authHeader } = createClients(request);
  const { data, error } = await userClient.auth.getUser();

  if (error || !data.user) {
    throw new AppError("Unauthorized", {
      code: "unauthorized",
      status: 401,
      details: error?.message ?? null
    });
  }

  return {
    userId: data.user.id,
    userClient,
    adminClient,
    authHeader
  };
}
