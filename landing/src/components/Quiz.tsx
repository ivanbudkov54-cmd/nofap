import { AnimatePresence, motion } from "framer-motion";
import { useState } from "react";

const steps = [
  {
    title: "Вспомни первые 10 минут после последнего срыва. Что ты чувствовал?",
    options: ["Ватный туман в голове", "Душевная пустота", "Физическая слабость", "Отвращение к себе"],
  },
  {
    title: "Чем ты уже заплатил за эту привычку за последний год?",
    options: ["Уверенность с девушками", "Энергия для бизнеса/учебы", "Сотни часов времени", "Тестостерон и форма"],
  },
  {
    title: "Готов ли ты дать себе ровно 3 дня на первую перезагрузку без компромиссов?",
    options: ["Да, я принимаю вызов", "Нет, я пока не готов"],
  },
];

export function Quiz({ onComplete }: { onComplete: (answers: string[]) => void }) {
  const [index, setIndex] = useState(0);
  const [answers, setAnswers] = useState<string[]>([]);
  const step = steps[index];
  const progress = ((index + 1) / steps.length) * 100;

  function choose(option: string) {
    const next = [...answers, option];
    if (index === steps.length - 1) {
      onComplete(next);
      return;
    }
    setAnswers(next);
    setIndex(index + 1);
  }

  return (
    <section className="flex flex-1 flex-col">
      <p className="font-mono text-xs tracking-[0.18em] text-amber-400">ТОЧКА А · {index + 1}/3</p>
      <div className="mt-3 h-1 overflow-hidden rounded-full bg-white/10">
        <motion.div className="h-full bg-amber-500" animate={{ width: `${progress}%` }} />
      </div>
      <AnimatePresence mode="wait">
        <motion.div
          key={step.title}
          initial={{ opacity: 0, x: 24 }}
          animate={{ opacity: 1, x: 0 }}
          exit={{ opacity: 0, x: -24 }}
          transition={{ duration: 0.28 }}
          className="mt-8"
        >
          <h2 className="text-2xl font-semibold leading-tight text-white">{step.title}</h2>
          <div className="mt-6 flex flex-col gap-3">
            {step.options.map((option) => (
              <button
                key={option}
                type="button"
                onClick={() => choose(option)}
                className="rounded-2xl border border-white/10 bg-white/5 px-4 py-4 text-left text-base text-gray-100 backdrop-blur-md transition hover:border-amber-500/70"
              >
                {option}
              </button>
            ))}
          </div>
        </motion.div>
      </AnimatePresence>
    </section>
  );
}
