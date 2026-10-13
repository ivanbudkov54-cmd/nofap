import { Link } from "react-router-dom";
import { ArrowLeft } from "lucide-react";

export function LegalPage({ title, body }: { title: string; body: string }) {
  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-md flex-col px-5 py-8">
      <Link className="mb-6 inline-flex items-center gap-2 text-sm text-amber-400" to="/">
        <ArrowLeft size={16} />
        Назад к оплате
      </Link>
      <h1 className="text-2xl font-semibold text-white">{title}</h1>
      <article className="mt-6 whitespace-pre-wrap text-sm leading-6 text-gray-300">{body}</article>
    </main>
  );
}
