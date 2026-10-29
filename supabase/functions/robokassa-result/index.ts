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
  const outSum = pick(params, "OutSum");
  const invId = pick(params, "InvId");
  const signature = pick(params, "SignatureValue");
  const shpUserId = pick(params, "Shp_user_id");
  const email = (pick(params, "Shp_email") || pick(params, "Email")).trim().toLowerCase();
  const password2 = Deno.env.get("ROBOKASSA_PASSWORD2") ?? "";

  if (!outSum || !invId || !signature || !password2) {
    return new Response("bad request", { status: 400 });
  }

  const base = `${outSum}:${invId}:${password2}${shpSuffix(params)}`;
  const received = signature.trim().toLowerCase();
  const valid = received === String(md5(base)).toLowerCase() || received === await sha256Hex(base);
  if (!valid) {
    return new Response("bad signature", { status: 403 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );

  const idNum = Number(invId);
  if (!Number.isFinite(idNum)) {
    return new Response("bad inv", { status: 400 });
  }

  const existing = await supabase
    .from("payments")
    .select("inv_id, status, email, user_id, out_sum")
    .eq("inv_id", idNum)
    .maybeSingle();

  if (existing.data?.status === "paid") {
    return ok(invId);
  }

  const paidEmail = email || existing.data?.email || "";
  let userId = "";
  if (isUuid(shpUserId)) userId = shpUserId.toLowerCase();
  if (!userId && existing.data?.user_id) userId = String(existing.data.user_id);
  if (!userId && paidEmail) {
    const looked = await supabase.rpc("account_id_for_email", { p_email: paidEmail });
    if (typeof looked.data === "string" && isUuid(looked.data)) userId = looked.data;
  }

  const amount = Number(outSum);
  if (existing.data) {
    await supabase.from("payments").update({
      status: "paid",
      paid_at: new Date().toISOString(),
      email: paidEmail || existing.data.email,
      user_id: userId || existing.data.user_id,
    }).eq("inv_id", idNum);
  } else {
    await supabase.from("payments").insert({
      inv_id: idNum,
      email: paidEmail || "unknown",
      user_id: userId || null,
      out_sum: Number.isFinite(amount) ? amount : 299,
      status: "paid",
      paid_at: new Date().toISOString(),
    });
  }

  if (paidEmail) {
    const recorded = await supabase.rpc("record_pro_grant", { p_email: paidEmail });
    if (recorded.error) {
      return new Response("grant ledger failed", { status: 500 });
    }
  }

  if (userId) {
    const granted = await supabase.rpc("apply_spartan_pro", {
      p_user_id: userId,
      p_email: paidEmail || null,
    });
    if (granted.error) {
      return new Response("grant failed", { status: 500 });
    }
  }

  return ok(invId);
});

function ok(invId: string): Response {
  return new Response(`OK${invId}`, {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}

function shpSuffix(params: URLSearchParams): string {
  const parts: string[] = [];
  for (const [key, value] of params.entries()) {
    if (key.toLowerCase().startsWith("shp_") && value) {
      parts.push(`${key}=${value}`);
    }
  }
  parts.sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
  return parts.length ? `:${parts.join(":")}` : "";
}

function pick(params: URLSearchParams, name: string): string {
  for (const [key, value] of params.entries()) {
    if (key.toLowerCase() === name.toLowerCase()) return value;
  }
  return "";
}

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
