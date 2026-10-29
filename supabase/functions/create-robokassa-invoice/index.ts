// Ссылка на оплату Spartan Pro. Счёт пишется в public.payments.
// Секреты: ROBOKASSA_MERCHANT_LOGIN, ROBOKASSA_PASSWORD_1.
// Деплой с --no-verify-jwt: лендинг вызывает функцию без входа в аккаунт.

import { createClient } from "npm:@supabase/supabase-js@2";
import md5 from "npm:md5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SERVICE_NAME = "Доступ к Spartan Pro (30 дней)";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  const body = await request.json().catch(() => null) as {
    email?: string;
    outSum?: number | string;
    amount?: number | string;
    userId?: string;
    shp_user_id?: string;
  } | null;
  const email = (body?.email ?? "").trim().toLowerCase();
  const requested = Number(body?.outSum ?? body?.amount);
  const price = 299;
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return json({ error: "invalid email" }, 400);
  }
  if (!Number.isFinite(requested) || (requested !== 299 && requested !== 349)) {
    return json({ error: "invalid amount" }, 400);
  }

  const login = Deno.env.get("ROBOKASSA_MERCHANT_LOGIN") ?? "";
  const password1 = Deno.env.get("ROBOKASSA_PASSWORD_1") ?? "";
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!login || !password1 || !supabaseUrl || !serviceKey) {
    return json({ error: "robokassa is not configured" }, 500);
  }

  const supabase = createClient(supabaseUrl, serviceKey);
  const fromClient = (body?.userId ?? body?.shp_user_id ?? "").trim();
  const { data: accountId } = await supabase.rpc("account_id_for_email", { p_email: email });
  const fromEmail = typeof accountId === "string" && isUuid(accountId) ? accountId : "";
  const userId = isUuid(fromClient) ? fromClient.toLowerCase() : fromEmail;

  const { data: payment, error: paymentError } = await supabase
    .from("payments")
    .insert({
      email,
      user_id: userId || null,
      out_sum: price,
      status: "pending",
    })
    .select("inv_id")
    .single();
  if (paymentError || payment?.inv_id == null) {
    return json({ error: "invoice insert failed" }, 500);
  }

  const outSum = price.toFixed(2);
  const invId = String(payment.inv_id);
  const receipt = JSON.stringify({
    items: [{
      name: SERVICE_NAME,
      quantity: 1,
      sum: price,
      payment_method: "full_payment",
      payment_object: "service",
      tax: "none",
    }],
  });
  const encodedReceipt = encodeURIComponent(receipt);
  const shpParts = [`Shp_email=${email}`];
  if (userId) shpParts.push(`Shp_user_id=${userId}`);
  shpParts.sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
  const shp = `:${shpParts.join(":")}`;
  const signature = String(md5(`${login}:${outSum}:${invId}:${encodedReceipt}:${password1}${shp}`));

  const paymentUrl = new URL("https://auth.robokassa.ru/Merchant/Index.aspx");
  paymentUrl.searchParams.set("MerchantLogin", login);
  paymentUrl.searchParams.set("OutSum", outSum);
  paymentUrl.searchParams.set("InvId", invId);
  paymentUrl.searchParams.set("Description", "Spartan Pro 30 дней");
  paymentUrl.searchParams.set("Receipt", encodedReceipt);
  paymentUrl.searchParams.set("SignatureValue", signature);
  paymentUrl.searchParams.set("Email", email);
  paymentUrl.searchParams.set("Culture", "ru");
  if (Deno.env.get("ROBOKASSA_IS_TEST") === "1") {
    paymentUrl.searchParams.set("IsTest", "1");
  }
  paymentUrl.searchParams.set("Shp_email", email);
  if (userId) paymentUrl.searchParams.set("Shp_user_id", userId);

  const url = paymentUrl.toString();
  return json({ url, paymentUrl: url }, 200);
});

function json(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}
