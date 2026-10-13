// Ссылка на оплату. Секреты: ROBOKASSA_LOGIN, ROBOKASSA_PASSWORD1.
// ROBOKASSA_IS_TEST=1 включает тестовый режим. Verify JWT можно оставить включённым:
// лендинг шлёт anon key.

import md5 from "npm:md5";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (request.method !== "POST") {
    return new Response("method not allowed", { status: 405, headers: cors });
  }

  const body = await request.json().catch(() => null) as {
    email?: string;
    amount?: number;
    shp_user_id?: string;
  } | null;
  const email = body?.email?.trim() ?? "";
  const userId = body?.shp_user_id?.trim() ?? "";
  const amount = Number(body?.amount);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || amount !== 490) {
    return Response.json({ error: "bad request" }, { status: 400, headers: cors });
  }

  const login = Deno.env.get("ROBOKASSA_LOGIN") ?? "";
  const password1 = Deno.env.get("ROBOKASSA_PASSWORD1") ?? "";
  if (!login || !password1) {
    return Response.json({ error: "robokassa is not configured" }, { status: 500, headers: cors });
  }

  const outSum = "490.00";
  const invId = String(Math.floor(Date.now() / 1000));
  const hasUser = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(userId);
  const shp = hasUser ? `:Shp_user_id=${userId}` : "";
  const signature = String(md5(`${login}:${outSum}:${invId}:${password1}${shp}`));
  const payment = new URL("https://auth.robokassa.ru/Merchant/Index.aspx");
  payment.searchParams.set("MerchantLogin", login);
  payment.searchParams.set("OutSum", outSum);
  payment.searchParams.set("InvId", invId);
  payment.searchParams.set("Description", "Spartan Pro, 30 дней");
  payment.searchParams.set("SignatureValue", signature);
  payment.searchParams.set("Email", email);
  payment.searchParams.set("Culture", "ru");
  if (Deno.env.get("ROBOKASSA_IS_TEST") === "1") {
    payment.searchParams.set("IsTest", "1");
  }
  if (hasUser) payment.searchParams.set("Shp_user_id", userId);

  return Response.json({ paymentUrl: payment.toString() }, { headers: cors });
});
