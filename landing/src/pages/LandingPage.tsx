import { useState } from "react";
import { Loader2, Shield } from "lucide-react";
import { Quiz } from "../components/Quiz";
import { Paywall } from "../components/Paywall";
import { Footer } from "../components/Footer";

type Stage = "hero" | "quiz" | "loading" | "paywall";

export function LandingPage() {
  const [stage, setStage] = useState<Stage>("hero");

  function finishQuiz() {
    setStage("loading");
    window.setTimeout(() => setStage("paywall"), 2500);
  }

  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-md flex-col px-5">
      <header className="flex items-center gap-2 py-6 text-sm font-semibold tracking-wide text-amber-400">
        <Shield size={18} />
        StopFap
      </header>

      {stage === "hero" ? (
        <section className="flex flex-1 flex-col">
          <h1 className="text-4xl font-semibold leading-tight text-white">Освободи разум от дешевого дофамина.</h1>
          <p className="mt-4 text-base leading-6 text-gray-300">
            Научный трекер дисциплины на 45 дней. Восстанови уровень энергии, тестостерона и мужского фокуса.
          </p>
          <div className="mt-6 rounded-2xl border border-white/10 bg-white/5 p-4 backdrop-blur-md">
            <p className="text-amber-400" aria-label="5 из 5">★★★★★</p>
            <p className="mt-1 text-sm text-gray-200">Стрик в скваде удерживают в 3 раза дольше</p>
          </div>
          <button
            type="button"
            onClick={() => setStage("quiz")}
            className="mt-8 rounded-full bg-amber-500 px-5 py-4 text-base font-semibold text-stone-950"
          >
            Пройти диагностику (1 минута)
          </button>
        </section>
      ) : null}

      {stage === "quiz" ? <Quiz onComplete={finishQuiz} /> : null}

      {stage === "loading" ? (
        <section className="flex flex-1 flex-col items-center justify-center text-center">
          <Loader2 className="animate-spin text-amber-400" size={36} />
          <p className="mt-6 text-lg text-white">Анализируем ответы и формируем нейро-план на 45 дней...</p>
        </section>
      ) : null}

      {stage === "paywall" ? <Paywall /> : null}
      <Footer />
    </div>
  );
}
