# Деплой spartan-pro.ru (Beget) и оплаты Robokassa

`spartan-pro.ru/` — готовый сайт: русский лендинг Spartan Pro. Тот же сайт архивом: `spartan-pro.ru.zip`.
Сайт статичный, сборка не нужна.

## 1. Залить сайт на Beget

Содержимое папки `spartan-pro.ru/` должно лежать прямо в `public_html` домена spartan-pro.ru
(в корне — `index.html`, `thanks.html`, `offer.html`, `privacy.html`, `refund.html`, `ru.js`, папка `assets/`).
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
```

`create-robokassa-invoice` уже задеплоена (секреты ROBOKASSA_MERCHANT_LOGIN, ROBOKASSA_PASSWORD_1).
Проверка: `curl -X POST https://gmmwfxpoidtpwbtxgjbk.supabase.co/functions/v1/robokassa-result` → 400 «bad request» (не 404).

## 3. Robokassa → Мои магазины → Технические настройки

- Result URL: `https://gmmwfxpoidtpwbtxgjbk.supabase.co/functions/v1/robokassa-result`, метод POST
- Success URL: `https://spartan-pro.ru/thanks.html`
- Fail URL: `https://spartan-pro.ru/`

## 4. Проверка платежа

В приложении: Pro-функция → «Узнать подробнее о программе» → оплата 349 ₽ →
вернуться в приложение → «Проверить статус доступа». Pro должен включиться.

Pro выдаётся только по `user_id` из ссылки, которую открывает приложение.
Оплата со страницы без `?user_id=` деньги примет, но Pro не откроет.
