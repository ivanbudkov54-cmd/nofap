import { BrowserRouter, Route, Routes } from "react-router-dom";
import { offerText, privacyText, refundText } from "./content/legal";
import { LandingPage } from "./pages/LandingPage";
import { LegalPage } from "./pages/LegalPage";
import { Footer } from "./components/Footer";

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<LandingPage />} />
        <Route
          path="/offer"
          element={
            <div className="mx-auto flex min-h-dvh max-w-md flex-col">
              <LegalPage title="Публичная оферта" body={offerText} />
              <Footer />
            </div>
          }
        />
        <Route
          path="/privacy"
          element={
            <div className="mx-auto flex min-h-dvh max-w-md flex-col">
              <LegalPage title="Политика конфиденциальности" body={privacyText} />
              <Footer />
            </div>
          }
        />
        <Route
          path="/refunds"
          element={
            <div className="mx-auto flex min-h-dvh max-w-md flex-col">
              <LegalPage title="Условия возврата" body={refundText} />
              <Footer />
            </div>
          }
        />
      </Routes>
    </BrowserRouter>
  );
}
