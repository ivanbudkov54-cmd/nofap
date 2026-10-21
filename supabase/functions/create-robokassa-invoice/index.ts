// Ссылка на оплату Spartan Pro через Робокассу с чеком для самозанятого (Робочеки СМЗ).
// Секреты: ROBOKASSA_MERCHANT_LOGIN, ROBOKASSA_PASSWORD_1.
// Необязательные: SPARTAN_PRO_PRICE (цена в рублях, по умолчанию 349),
// ROBOKASSA_IS_TEST=1 — тестовый режим.
// Деплой с --no-verify-jwt: лендинг вызывает функцию без входа в аккаунт.

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
    userId?: string;
    email?: string;
    outSum?: number | string;
    shp_user_id?: string;
    amount?: number | string;
  } | null;

  const email = body?.email?.trim() ?? "";
  const userId = (body?.userId ?? body?.shp_user_id ?? "").trim();
  const requested = Number(body?.outSum ?? body?.amount);

  // Сумму присылает браузер, поэтому её сверяем с ценой на сервере:
  // иначе доступ на 30 дней можно было бы купить за 1 рубль.
  const price = Number(Deno.env.get("SPARTAN_PRO_PRICE") ?? "349");
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return json({ error: "invalid email" }, 400);
  }
  if (!Number.isFinite(requested) || requested !== price) {
    return json({ error: "invalid amount" }, 400);
  }

  const login = Deno.env.get("ROBOKASSA_MERCHANT_LOGIN") ?? "";
  const password1 = Deno.env.get("ROBOKASSA_PASSWORD_1") ?? "";
  if (!login || !password1) {
    return json({ error: "robokassa is not configured" }, 500);
  }

  const outSum = price.toFixed(2);
  const invId = String(Date.now());

  // sno не передаём: допустимых значений для самозанятого у Робокассы нет,
  // режим НПД берётся из настроек магазина в личном кабинете (Робочеки СМЗ).
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

  // Shp_* идут после пароля, по алфавиту. По Shp_user_id вебхук
  // robokassa-result понимает, кому открыть Pro.
  const hasUser = isUuid(userId);
  const shp = hasUser ? `:Shp_user_id=${userId}` : "";
  const signature = String(md5(`${login}:${outSum}:${invId}:${encodedReceipt}:${password1}${shp}`));

  const payment = new URL("https://auth.robokassa.ru/Merchant/Index.aspx");
  payment.searchParams.set("MerchantLogin", login);
  payment.searchParams.set("OutSum", outSum);
  payment.searchParams.set("InvId", invId);
  payment.searchParams.set("Description", "Spartan Pro 30 дней");
  // Робокасса раскодирует параметр один раз и сверяет подпись с тем же
  // закодированным JSON, поэтому в ссылку кладём уже закодированную строку.
  payment.searchParams.set("Receipt", encodedReceipt);
  payment.searchParams.set("SignatureValue", signature);
  payment.searchParams.set("Email", email);
  payment.searchParams.set("Culture", "ru");
  if (Deno.env.get("ROBOKASSA_IS_TEST") === "1") {
    payment.searchParams.set("IsTest", "1");
  }
  if (hasUser) payment.searchParams.set("Shp_user_id", userId);

  // paymentUrl читает уже выложенная версия лендинга.
  const paymentUrl = payment.toString();
  return json({ url: paymentUrl, paymentUrl }, 200);
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
