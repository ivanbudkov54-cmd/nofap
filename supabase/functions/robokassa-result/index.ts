// ResultURL Робокассы. В кабинете функции выключите Verify JWT.
// Секреты: supabase secrets set ROBOKASSA_PASSWORD2=...
// SUPABASE_URL и SUPABASE_SERVICE_ROLE_KEY подставляются платформой.

import { createClient } from "npm:@supabase/supabase-js@2";
import md5 from "npm:md5";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (request.method !== "GET" && request.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  const params = await readParams(request);
  const outSum = params.get("OutSum") ?? "";
  const invId = params.get("InvId") ?? "";
  const signature = params.get("SignatureValue") ?? "";
  const userId = params.get("Shp_user_id") ?? "";
  const password2 = Deno.env.get("ROBOKASSA_PASSWORD2") ?? "";

  if (!outSum || !invId || !signature || !isUuid(userId) || !password2) {
    return new Response("bad request", { status: 400 });
  }

  const base = `${outSum}:${invId}:${password2}:Shp_user_id=${userId}`;
  const sha = await sha256Hex(base);
  const received = signature.trim().toLowerCase();
  const valid = received === String(md5(base)).toLowerCase() || received === sha;
  if (!valid) {
    return new Response("bad signature", { status: 403 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );
  const expires = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
  const patch = {
    is_pro: true,
    pro_expires_at: expires,
    updated_at: new Date().toISOString(),
  };

  const updated = await supabase
    .from("profiles")
    .update(patch)
    .eq("id", userId)
    .select("id");

  if (updated.error) {
    return new Response("profile update failed", { status: 500 });
  }
  if (!updated.data?.length) {
    const inserted = await supabase.from("profiles").insert({ id: userId, ...patch });
    if (inserted.error) {
      return new Response("profile missing", { status: 500 });
    }
  }

  return new Response(`OK${invId}`, {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
});

async function readParams(request: Request): Promise<URLSearchParams> {
  const url = new URL(request.url);
  if (request.method === "GET") return url.searchParams;
  const type = request.headers.get("content-type") ?? "";
  const raw = await request.text();
  if (type.includes("application/json")) {
    const body = JSON.parse(raw) as Record<string, unknown>;
    const params = new URLSearchParams();
    for (const [key, value] of Object.entries(body)) {
      if (value != null) params.set(key, String(value));
    }
    return params;
  }
  return new URLSearchParams(raw);
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}
