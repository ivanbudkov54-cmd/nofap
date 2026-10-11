# Оплата на сайте (Lemon Squeezy) — по шагам

Сайт: https://ivanbudkov54-cmd.github.io/premium/ (репозиторий `ivanbudkov54-cmd/premium`).

## 0. Иван — до всех остальных
1. Вписать на сайте имя продавца и почту поддержки (места подсвечены красным).
2. Отправить продавцу адрес сайта.

## 1. Продавец (казахская карта) — Lemon Squeezy

**Регистрация**
1. Зарегистрироваться на app.lemonsqueezy.com.
2. Создать магазин (Store) с названием приложения.
3. Settings → Payouts: банковский счёт в Казахстане + проверка личности.

**Продукт**
4. Products → New product, название `StopFap Premium`:
   - цена: Subscription, $20, каждый 1 year;
   - включить License keys (ключ придёт покупателю в письме);
   - Confirmation modal → Button link: `https://ivanbudkov54-cmd.github.io/premium/thanks.html`;
   - сохранить.

**Отправить Ивану**
5. В продукте Share → скопировать Checkout link.
6. Settings → Stores → Store ID (число).

**Вебхук**
7. Settings → Webhooks → +:
   - Callback URL: `https://jgshclcqetzfwoydrnmj.supabase.co/functions/v1/lemon-webhook`
   - Signing secret: придумать длинный случайный пароль (30+ символов);
   - события: `subscription_created`, `subscription_updated`, `subscription_cancelled`,
     `subscription_resumed`, `subscription_expired`, `subscription_paused`,
     `subscription_unpaused`, `subscription_payment_refunded`;
   - сохранить.
8. Signing secret отправить другу с Supabase в личку. Не в общий чат и не в код.

**Запуск**
9. Включить Test mode (переключатель слева внизу), сделать тестовую покупку картой
   `4242 4242 4242 4242`, любой будущий срок, любой CVC.
10. Всё сработало — Activate store. Описание: «Self-help app for breaking a compulsive
    habit», без откровенных слов.

## 2. Друг с Supabase (проект jgshclcqetzfwoydrnmj)

**Таблица**
1. SQL Editor → New query → вставить весь `supabase/04_web_premium.sql` → Run.

1б. Так же запустить `supabase/05_app_backup.sql` — копия прогресса (нужна и без
    Lemon Squeezy: по ней прогресс возвращается после переустановки).

**Функция**
2. Edge Functions → Deploy a new function → Via Editor.
3. Имя: `lemon-webhook` (ровно так).
4. Стереть пример, вставить весь `supabase/functions/lemon-webhook/index.ts` → Deploy.
5. Открыть функцию → Details → выключить «Enforce JWT verification».
   Lemon Squeezy не входит в Supabase; подлинность функция проверяет сама по подписи.

**Секреты**
6. Edge Functions → Secrets → добавить:
   - `LEMON_WEBHOOK_SECRET` — пароль от продавца;
   - `LEMON_STORE_ID` — Store ID.
7. Ключ service_role никуда вписывать не нужно — Supabase передаёт его функции сам.

## 3. Иван — в конце
1. Store ID → `LemonSqueezyConfig.storeID` в `NoFap/Models/WebPremium.swift`.
2. Checkout link → `CHECKOUT_URL` в `assets/site.js` репозитория premium.
3. Тест в Test mode с американским Apple ID: кнопка «На сайте — $20 в год» → оплата →
   вернуться в приложение → Premium включается в течение минуты.

Посмотреть кнопки в симуляторе вне США:
`xcrun simctl spawn <устройство> defaults write Albert.lvan.NoFap webCheckoutOverride -bool YES`.
