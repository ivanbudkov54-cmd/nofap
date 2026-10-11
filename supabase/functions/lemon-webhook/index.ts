// Вебхук Lemon Squeezy → таблица web_premium (supabase/04_web_premium.sql).
//
// Деплой (из папки NoFap):
//   supabase functions deploy lemon-webhook --no-verify-jwt
//   supabase secrets set LEMON_WEBHOOK_SECRET=<Signing secret из Lemon Squeezy> LEMON_STORE_ID=<id магазина>
// --no-verify-jwt нужен: Lemon Squeezy не шлёт JWT Supabase, подлинность
// проверяем подписью X-Signature. SUPABASE_URL и SUPABASE_SERVICE_ROLE_KEY
// Supabase подставляет в функцию сам — в код и репозиторий они не попадают.
//
// В Lemon Squeezy → Settings → Webhooks:
//   URL: https://<project>.supabase.co/functions/v1/lemon-webhook
//   события: subscription_created, subscription_updated, subscription_cancelled,
//            subscription_resumed, subscription_expired, subscription_paused,
//            subscription_unpaused, subscription_payment_refunded

const SECRET = Deno.env.get("LEMON_WEBHOOK_SECRET") ?? "";
const STORE_ID = Number(Deno.env.get("LEMON_STORE_ID") ?? "0");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });
  if (!SECRET || !STORE_ID) return new Response("not configured", { status: 500 });

  const raw = await req.text();
  if (!(await signatureValid(raw, req.headers.get("X-Signature") ?? ""))) {
    return new Response("bad signature", { status: 401 });
  }

  const event = JSON.parse(raw);
  const name: string = event?.meta?.event_name ?? "";
  const attrs = event?.data?.attributes ?? {};

  // Чужой магазин (тестовый, другой проект) — молча принимаем и игнорируем.
  if (Number(attrs.store_id) !== STORE_ID) return ok();

  if (name === "subscription_payment_refunded") {
    // data — счёт подписки; Premium по ней больше не даём.
    const subscriptionID = String(attrs.subscription_id ?? "");
    if (subscriptionID) {
      await rest("PATCH", `web_premium?subscription_id=eq.${encodeURIComponent(subscriptionID)}`,
                 { refunded: true, updated_at: new Date().toISOString() });
    }
    return ok();
  }

  if (!name.startsWith("subscription_") || event?.data?.type !== "subscriptions") return ok();

  const rawUser = String(event?.meta?.custom_data?.user_id ?? "").toLowerCase();
  const row: Record<string, unknown> = {
    subscription_id: String(event.data.id),
    status: String(attrs.status ?? ""),
    renews_at: attrs.renews_at ?? null,
    ends_at: attrs.ends_at ?? null,
    updated_at: new Date().toISOString(),
  };
  // user_id приходит только в событиях оплаты, начатой из приложения.
  // Не перетираем его null-ом в последующих событиях.
  if (UUID.test(rawUser)) row.user_id = rawUser;

  let res = await upsert(row);
  // Аккаунта уже нет (удалён) — сохраняем подписку без него.
  if (res.status === 409 && "user_id" in row) {
    delete row.user_id;
    res = await upsert(row);
  }
  if (!res.ok) {
    console.error("upsert failed", res.status, await res.text());
    // 500 — Lemon Squeezy повторит доставку.
    return new Response("db error", { status: 500 });
  }
  return ok();
});

function ok() {
  return new Response("ok", { status: 200 });
}

function upsert(row: Record<string, unknown>) {
  return rest("POST", "web_premium?on_conflict=subscription_id", row,
              "resolution=merge-duplicates,return=minimal");
}

function rest(method: string, path: string, body: unknown, prefer = "return=minimal") {
  return fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    method,
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      Prefer: prefer,
    },
    body: JSON.stringify(body),
  });
}

/// X-Signature — hex HMAC-SHA256 тела запроса на Signing secret.
async function signatureValid(body: string, signature: string): Promise<boolean> {
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(SECRET), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body)));
  const expected = Array.from(mac, (b) => b.toString(16).padStart(2, "0")).join("");
  if (signature.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
  return diff === 0;
}
