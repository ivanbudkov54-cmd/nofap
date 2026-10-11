-- Premium, оплаченный на сайте через Lemon Squeezy (только американский
-- App Store). Строки пишет только Edge Function lemon-webhook (ключом
-- service_role на сервере); приложение читает свою строку.
--
-- Запуск: Supabase Dashboard → SQL Editor → вставить файл → Run.
-- Повторный запуск безопасен.

create table if not exists public.web_premium (
    subscription_id text primary key,
    -- null — купили на сайте не из приложения; Premium откроют ключом из письма.
    user_id    uuid references auth.users (id) on delete set null,
    status     text not null,
    renews_at  timestamptz,
    ends_at    timestamptz,
    refunded   boolean not null default false,
    updated_at timestamptz not null default now()
);

create index if not exists web_premium_user_idx on public.web_premium (user_id);

alter table public.web_premium enable row level security;

drop policy if exists "web_premium: read own" on public.web_premium;
create policy "web_premium: read own" on public.web_premium
    for select to authenticated
    using (user_id = auth.uid());

-- Писать с клиента нельзя: ни insert, ни update, ни delete политик нет.
revoke insert, update, delete on public.web_premium from anon, authenticated;
