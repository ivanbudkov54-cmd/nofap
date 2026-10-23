// Оплата Spartan Pro через Robokassa. Ссылку на оплату собирает функция
// Supabase create-robokassa-invoice (сумму сверяет с ценой на сервере).
const INVOICE_URL = "https://gmmwfxpoidtpwbtxgjbk.supabase.co/functions/v1/create-robokassa-invoice";
// Публичный anon-ключ Supabase — не секрет, он и так лежит в приложении.
const ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdtbXdmeHBvaWR0cHdidHhnamJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgyODc2OTQsImV4cCI6MjEwMzg2MzY5NH0.qw8KEXu7q6I8FdwzNn2S1zqZnJ4tZ5IcBG7epVV-LGQ";
const AMOUNT = 349;
const PAY_LABEL = "Оплатить картой или СБП — 349 ₽";

(function () {
  // Приложение открывает страницу как …?user_id=<id аккаунта>&email=…
  // По user_id вебхук robokassa-result откроет Pro именно этому аккаунту.
  const params = new URLSearchParams(location.search);
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const incomingId = (params.get("user_id") || "").trim();
  try {
    if (uuid.test(incomingId)) localStorage.setItem("spartan_user_id", incomingId.toLowerCase());
  } catch (e) {}
  function userId() {
    if (uuid.test(incomingId)) return incomingId.toLowerCase();
    try { return localStorage.getItem("spartan_user_id") || ""; } catch (e) { return ""; }
  }

  const form = document.getElementById("pay-form");
  const email = document.getElementById("email");
  const agree = document.getElementById("agree");
  const btn = document.getElementById("pay-btn");
  const err = document.getElementById("err");
  const emailOk = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (params.get("email")) email.value = params.get("email");

  function refresh() {
    btn.disabled = !(emailOk.test(email.value.trim()) && agree.checked) || btn.dataset.loading === "1";
  }
  email.addEventListener("input", function () { err.textContent = ""; refresh(); });
  agree.addEventListener("change", refresh);
  refresh();

  form.addEventListener("submit", async function (event) {
    event.preventDefault();
    const address = email.value.trim().toLowerCase();
    if (!emailOk.test(address)) { err.textContent = "Введите рабочий email: на него придёт доступ."; return; }
    if (!agree.checked) { err.textContent = "Нужно согласие с офертой и политикой конфиденциальности."; return; }
    err.textContent = "";
    btn.dataset.loading = "1";
    btn.disabled = true;
    btn.textContent = "Соединяем с банком…";
    const controller = new AbortController();
    const timer = setTimeout(function () { controller.abort(); }, 20000);
    try {
      const res = await fetch(INVOICE_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json", "apikey": ANON_KEY, "Authorization": "Bearer " + ANON_KEY },
        body: JSON.stringify({ email: address, outSum: AMOUNT, userId: userId() }),
        signal: controller.signal
      });
      if (!res.ok) throw new Error("bad status");
      const data = await res.json();
      if (!data || typeof data.url !== "string" || !/^https:\/\//.test(data.url)) throw new Error("no url");
      location.href = data.url;
    } catch (e) {
      err.textContent = "Не удалось соединиться с банком. Попробуйте ещё раз через минуту.";
      btn.dataset.loading = "0";
      btn.textContent = PAY_LABEL;
      refresh();
    } finally {
      clearTimeout(timer);
    }
  });

  const reveal = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); } });
    }, { rootMargin: "0px 0px -8% 0px" });
    reveal.forEach(function (el) { io.observe(el); });
  } else {
    reveal.forEach(function (el) { el.classList.add("in"); });
  }
  const year = document.getElementById("year");
  if (year) year.textContent = new Date().getFullYear();
})();
