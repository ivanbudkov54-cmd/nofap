# Деплой spartan-pro.ru (Beget) и оплаты Robokassa

`spartan-pro.ru/` — готовый сайт: русский лендинг Spartan Pro. Тот же сайт архивом: `spartan-pro.ru.zip`.
Сайт статичный, сборка не нужна. Цена на лендинге и в `create-robokassa-invoice`: **299 ₽** за 30 дней.

## 1. Залить сайт на Beget

Содержимое папки `spartan-pro.ru/` должно лежать прямо в `public_html` домена spartan-pro.ru
(в корне — `index.html`, `thanks.html`, `offer.html`, `privacy.html`, `refund.html`, `auth.html`, `ru.js`, `favicon.ico`, папка `assets/`).
Старые файлы из `public_html` перед этим сохранить и удалить.

Через FTP (данные — Beget → FTP):

```bash
lftp -u "$BEGET_FTP_USER" ftp.beget.com -e "mirror -R --delete deploy/spartan-pro.ru spartan-pro.ru/public_html; bye"
```

Или вручную: Beget → Файловый менеджер → `spartan-pro.ru/public_html` → загрузить `spartan-pro.ru.zip` → распаковать.

Проверка: https://spartan-pro.ru/?user_id=11111111-2222-3333-4444-555555555555&email=test@example.com
открывает лендинг, email подставлен в форму оплаты.

## 2. Supabase (проект gmmwfxpoidtpwbtxgjbk)

```bash
supabase secrets set ROBOKASSA_PASSWORD2=...        # пароль №2 из кабинета Robokassa
supabase functions deploy robokassa-result --no-verify-jwt
supabase functions deploy create-robokassa-invoice --no-verify-jwt
```

Секреты `ROBOKASSA_MERCHANT_LOGIN`, `ROBOKASSA_PASSWORD_1`, `ROBOKASSA_PASSWORD2`, `service_role` в репозиторий не класть.

Проверка: `curl -X POST https://gmmwfxpoidtpwbtxgjbk.supabase.co/functions/v1/robokassa-result` → 400 «bad request» (не 404).

## 3. Robokassa → Мои магазины → Технические настройки

- Result URL: `https://gmmwfxpoidtpwbtxgjbk.supabase.co/functions/v1/robokassa-result`, метод POST
- Success URL: `https://spartan-pro.ru/thanks.html`
- Fail URL: `https://spartan-pro.ru/`

## 4. Проверка платежа

В приложении: Pro-функция → «Узнать подробнее о программе» → оплата 299 ₽ →
вернуться в приложение → «Проверить статус доступа». Pro должен включиться.

Оплата без `?user_id=` тоже валидна: доступ привязывается к email из формы.
В приложении нужно войти по той же почте.
