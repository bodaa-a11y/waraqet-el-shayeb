import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

export function getAdminClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) {
    throw new Error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables are required");
  }
  return createClient(url, serviceKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

export async function getCallerUid(
  req: Request,
  adminClient: SupabaseClient
): Promise<string> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    throw new Error("unauthenticated: لازم تسجل دخول الأول عشان تلعب");
  }
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    throw new Error("unauthenticated: رمز الدخول غير صالح");
  }
  const { data: { user }, error } = await adminClient.auth.getUser(token);
  if (error || !user) {
    throw new Error("unauthenticated: جلسة تسجيل الدخول انتهت، سجّل تاني يا معلم");
  }
  return user.id;
}
