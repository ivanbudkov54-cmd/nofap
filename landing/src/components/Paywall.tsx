import { Lock } from "lucide-react";
import { useState, type FormEvent } from "react";
import { Link } from "react-router-dom";

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function Paywall() {
  const [email, setEmail] = useState("");
  const [agreed, setAgreed] = useState(false);
  const [error, setError] = useState("");
  const [sent, setSent] = useState(false);

  const emailValid = emailPattern.test(email.trim());
  const canPay = emailValid && agreed;

  function handlePayment(value: string) {
    // TODO: API call to Supabase Edge Function
    void value;
    setSent(true);
  }

  function onSubmit(event: FormEvent) {
    event.preventDefault();
    if (!emailValid) {
      setError("Введите рабочий email: на него придёт доступ.");
      return;
    }
    if (!agreed) {
      setError("Нужно согласие с офертой и политикой конфиденциальности.");
      return;
    }
    setError("");
    handlePayment(email.trim());
  }

  return (
    <section className="flex flex-1 flex-col">
      <h2 className="text-2xl font-semibold leading-tight text-white">Твой план готов. Доступ к StopFap Pro открыт.</h2>
      <article className="mt-6 rounded-3xl border border-amber-500/30 bg-white/5 p-5 backdrop-blur-md">
        <p className="text-sm text-amber-300">StopFap Pro (Доступ на 30 дней)</p>
        <p className="mt-2 font-mono text-5xl font-semibold text-white">399 ₽</p>
        <ul className="mt-5 space-y-2 text-sm text-gray-200">
          <li>Блокировщик триггеров</li>
          <li>Расширенная аналитика</li>
          <li>Экспресс чекин энергии</li>
          <li>SOS-система</li>
          <li>Полная база знаний</li>
          <li>Аватары прогресса</li>
        </ul>
      </article>

      <form className="mt-6 flex flex-col gap-4" onSubmit={onSubmit} noValidate>
        <label className="text-sm text-gray-300">
          Email для входа
          <input
            className="mt-2 w-full rounded-2xl border border-white/10 bg-black/30 px-4 py-3 text-base text-white outline-none ring-amber-500 focus:ring-2"
            type="email"
            required
            placeholder="Твой рабочий Email (для входа в приложение)"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            autoComplete="email"
          />
        </label>
        <label className="flex items-start gap-3 text-sm text-gray-300">
          <input
            className="mt-1 size-4 accent-amber-500"
            type="checkbox"
            checked={agreed}
            onChange={(event) => setAgreed(event.target.checked)}
          />
          <span>
            Я согласен с{" "}
            <Link className="text-amber-400 underline" to="/offer">
              Публичной офертой
            </Link>{" "}
            и{" "}
            <Link className="text-amber-400 underline" to="/privacy">
              Политикой конфиденциальности
            </Link>
          </span>
        </label>
        {error ? <p className="text-sm text-rose-500">{error}</p> : null}
        <button
          type="submit"
          disabled={!canPay}
          className="inline-flex items-center justify-center gap-2 rounded-full bg-amber-500 px-5 py-4 text-base font-semibold text-stone-950 disabled:cursor-not-allowed disabled:bg-white/10 disabled:text-gray-500"
        >
          <Lock size={16} />
          Оплатить доступ (399 ₽)
        </button>
        <p className="text-center text-xs text-gray-500">Безопасный платёж через Robokassa</p>
        {sent ? (
          <p className="text-sm text-amber-300">Email принят. Ссылка Robokassa появится после подключения оплаты.</p>
        ) : null}
      </form>
    </section>
  );
}
