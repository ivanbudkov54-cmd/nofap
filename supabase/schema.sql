-- NoFap / Supabase schema
-- Вставьте целиком в SQL Editor проекта Supabase и выполните один раз.
-- Затем включите Anonymous Sign-Ins:
-- Authentication → Providers → Anonymous → Enable.

-- 1. Профиль: один ряд на пользователя auth.users.
-- current_streak_days дублирует расчёт от streak_start_date, чтобы клиент
-- мог показать кэш до пересчёта и записать число при смене дня.
create table if not exists public.profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    streak_days int not null default 0,
    current_streak_days int not null default 0,
    streak_start_date timestamptz,
    best_streak int not null default 0,
    best_streak_days int not null default 0,
    last_relapse_at timestamptz,
    updated_at timestamptz not null default now(),
    created_at timestamptz not null default now()
);

alter table public.profiles add column if not exists current_streak_days int not null default 0;
alter table public.profiles add column if not exists best_streak_days int not null default 0;
alter table public.profiles add column if not exists last_relapse_at timestamptz;
alter table public.profiles add column if not exists last_streak_freeze_date timestamptz;
alter table public.profiles add column if not exists updated_at timestamptz not null default now();

-- Старые имена streak_days / best_streak остаются, чтобы не ломать уже
-- созданную таблицу. Новые поля заполняются из них один раз.
update public.profiles
set current_streak_days = streak_days
where current_streak_days = 0 and streak_days <> 0;

update public.profiles
set best_streak_days = best_streak
where best_streak_days = 0 and best_streak <> 0;

-- 2. Дневник. mood/urge могут быть пустыми у свободной заметки;
--    CHECK в PostgreSQL пропускает NULL.
create table if not exists public.journal_entries (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    mood_score int check (mood_score between 1 and 10),
    urge_score int check (urge_score between 1 and 10),
    prompt_text text,
    reflection_note text,
    created_at timestamptz not null default now()
);

-- 3. История срывов. Каскад с auth.users удаляет её вместе с аккаунтом.
create table if not exists public.relapses (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    relapsed_at timestamptz not null default now(),
    trigger_reason text,
    notes text
);

-- 4. База знаний. tab_type ограничен тремя вкладками приложения.
create table if not exists public.knowledge_articles (
    id uuid primary key default gen_random_uuid(),
    tab_type text not null check (tab_type in ('journey', 'urge_simulator', 'deep_dive')),
    title text not null,
    description text,
    content text,
    order_index int not null default 0
);

alter table public.profiles enable row level security;
alter table public.journal_entries enable row level security;
alter table public.relapses enable row level security;
alter table public.knowledge_articles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;
drop policy if exists "journal_select_own" on public.journal_entries;
drop policy if exists "journal_insert_own" on public.journal_entries;
drop policy if exists "journal_update_own" on public.journal_entries;
drop policy if exists "journal_delete_own" on public.journal_entries;
drop policy if exists "relapses_select_own" on public.relapses;
drop policy if exists "relapses_insert_own" on public.relapses;
drop policy if exists "knowledge_select_public" on public.knowledge_articles;

create policy "profiles_select_own"
    on public.profiles for select
    to authenticated
    using (id = auth.uid());

create policy "profiles_insert_own"
    on public.profiles for insert
    to authenticated
    with check (id = auth.uid());

create policy "profiles_update_own"
    on public.profiles for update
    to authenticated
    using (id = auth.uid())
    with check (id = auth.uid());

create policy "journal_select_own"
    on public.journal_entries for select
    to authenticated
    using (user_id = auth.uid());

create policy "journal_insert_own"
    on public.journal_entries for insert
    to authenticated
    with check (user_id = auth.uid());

create policy "journal_update_own"
    on public.journal_entries for update
    to authenticated
    using (user_id = auth.uid())
    with check (user_id = auth.uid());

create policy "relapses_select_own"
    on public.relapses for select
    to authenticated
    using (user_id = auth.uid());

create policy "relapses_insert_own"
    on public.relapses for insert
    to authenticated
    with check (user_id = auth.uid());

create policy "journal_delete_own"
    on public.journal_entries for delete
    to authenticated
    using (user_id = auth.uid());

-- Статьи читают и анонимные (роль anon), и вошедшие пользователи.
create policy "knowledge_select_public"
    on public.knowledge_articles for select
    to anon, authenticated
    using (true);

-- Профиль создаётся сам при регистрации, включая анонимный вход.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id)
    values (new.id)
    on conflict (id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row
    execute function public.handle_new_user();

-- Удаление аккаунта из приложения (Apple Guideline 5.1.1).
-- Каскад на profiles и journal_entries срабатывает вместе с auth.users.
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;
    delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;
