-- Жалобы на сообщения и блокировки в чатах напарника и сквада —
-- требование App Review 1.2 для приложений с общением между людьми.
-- Жалобы разбираем в течение 24 часов: Table Editor → chat_reports.
--
-- Запуск: Supabase Dashboard → SQL Editor → вставить файл → Run.
-- Повторный запуск безопасен.

create table if not exists public.chat_reports (
    id            uuid primary key default gen_random_uuid(),
    reporter_id   uuid not null default auth.uid() references auth.users (id) on delete cascade,
    message_id    uuid,
    chat          text not null check (chat in ('partner', 'squad')),
    reported_user uuid,
    reason        text not null check (reason in ('abuse', 'sexual', 'threat', 'spam', 'other')),
    body          text check (char_length(body) <= 500),
    created_at    timestamptz not null default now(),
    resolved      boolean not null default false
);

create table if not exists public.user_blocks (
    blocker_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
    blocked    uuid not null,
    created_at timestamptz not null default now(),
    primary key (blocker_id, blocked)
);

alter table public.chat_reports enable row level security;
alter table public.user_blocks  enable row level security;

-- Пишет каждый только от своего имени; читать жалобы с клиента нельзя —
-- их смотрим в панели Supabase.
drop policy if exists "chat_reports: insert own" on public.chat_reports;
create policy "chat_reports: insert own" on public.chat_reports
    for insert to authenticated with check (reporter_id = auth.uid());

drop policy if exists "user_blocks: insert own" on public.user_blocks;
create policy "user_blocks: insert own" on public.user_blocks
    for insert to authenticated with check (blocker_id = auth.uid());

drop policy if exists "user_blocks: update own" on public.user_blocks;
create policy "user_blocks: update own" on public.user_blocks
    for update to authenticated using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

drop policy if exists "user_blocks: read own" on public.user_blocks;
create policy "user_blocks: read own" on public.user_blocks
    for select to authenticated using (blocker_id = auth.uid());
