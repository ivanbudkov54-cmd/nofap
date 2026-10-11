-- Резервная копия данных приложения: стрик, чекины, челленджи, причины,
-- опыт, прочитанные статьи, настройки — всё, что лежит в UserDefaults.
-- Одна строка на аккаунт. При новой установке (или на новом iPhone с тем же
-- аккаунтом из связки ключей iCloud) приложение скачивает её и
-- восстанавливает прогресс. Таблицы из 01_core.sql не трогает.
--
-- Запуск: Supabase Dashboard → SQL Editor → вставить файл → Run.
-- Повторный запуск безопасен.

create table if not exists public.app_backups (
    user_id     uuid primary key references auth.users (id) on delete cascade,
    -- Binary plist в base64: UserDefaults хранит даты и бинарные данные,
    -- JSON их без потерь не передаст.
    payload     text not null check (char_length(payload) < 4000000),
    app_version text,
    updated_at  timestamptz not null default now()
);

alter table public.app_backups enable row level security;

drop policy if exists "app_backups: read own" on public.app_backups;
create policy "app_backups: read own" on public.app_backups
    for select to authenticated using (user_id = auth.uid());

drop policy if exists "app_backups: insert own" on public.app_backups;
create policy "app_backups: insert own" on public.app_backups
    for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "app_backups: update own" on public.app_backups;
create policy "app_backups: update own" on public.app_backups
    for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
