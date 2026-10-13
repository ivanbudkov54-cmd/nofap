import { Link } from "react-router-dom";
import { sellerInn, sellerName, supportEmail } from "../content/legal";

export function Footer() {
  return (
    <footer className="mt-auto border-t border-white/10 px-5 py-8 text-xs leading-5 text-gray-400">
      <div className="mx-auto flex max-w-md flex-col gap-4">
        <div>
          <p>Самозанятый {sellerName}</p>
          <p>ИНН: {sellerInn}</p>
          <p>
            Служба поддержки:{" "}
            <a className="underline decoration-white/20 underline-offset-2" href={`mailto:${supportEmail}`}>
              {supportEmail}
            </a>
          </p>
        </div>
        <nav className="flex flex-wrap gap-x-4 gap-y-2">
          <Link className="underline decoration-white/20 underline-offset-2" to="/offer">
            Публичная оферта
          </Link>
          <Link className="underline decoration-white/20 underline-offset-2" to="/privacy">
            Политика конфиденциальности
          </Link>
          <Link className="underline decoration-white/20 underline-offset-2" to="/refunds">
            Условия возврата
          </Link>
        </nav>
      </div>
    </footer>
  );
}
