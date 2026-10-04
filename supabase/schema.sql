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
    tab_type text not null check (tab_type in ('journey', 'deep_dive')),
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

-- 5. Напарник. Одна связь: пригласивший и тот, кто принял код.
create table if not exists public.buddies (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    buddy_id uuid references auth.users (id) on delete set null,
    status text not null default 'pending' check (status in ('pending', 'accepted')),
    invite_code text not null unique,
    created_at timestamptz not null default now()
);

-- 6. Сквад и его участники.
create table if not exists public.squads (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    invite_code text not null unique,
    created_by uuid not null references auth.users (id) on delete cascade,
    created_at timestamptz not null default now()
);

create table if not exists public.squad_members (
    squad_id uuid not null references public.squads (id) on delete cascade,
    user_id uuid not null references auth.users (id) on delete cascade,
    primary key (squad_id, user_id)
);

alter table public.buddies enable row level security;
alter table public.squads enable row level security;
alter table public.squad_members enable row level security;

drop policy if exists "buddies_select_own" on public.buddies;
create policy "buddies_select_own"
    on public.buddies for select
    to authenticated
    using (user_id = auth.uid() or buddy_id = auth.uid());

drop policy if exists "squads_select_member" on public.squads;
create policy "squads_select_member"
    on public.squads for select
    to authenticated
    using (exists (
        select 1 from public.squad_members m
        where m.squad_id = squads.id and m.user_id = auth.uid()
    ));

drop policy if exists "squad_members_select" on public.squad_members;
create policy "squad_members_select"
    on public.squad_members for select
    to authenticated
    using (exists (
        select 1 from public.squad_members mine
        where mine.squad_id = squad_members.squad_id and mine.user_id = auth.uid()
    ));

create or replace function public.create_buddy_invite()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    code text;
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;
    code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
    insert into public.buddies (user_id, status, invite_code)
    values (auth.uid(), 'pending', code);
    return code;
end;
$$;

create or replace function public.accept_buddy_invite(invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    row_id uuid;
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;
    update public.buddies
    set buddy_id = auth.uid(), status = 'accepted'
    where buddies.invite_code = accept_buddy_invite.invite_code
      and status = 'pending'
      and user_id <> auth.uid()
    returning id into row_id;
    if row_id is null then
        raise exception 'invite not found';
    end if;
    return row_id;
end;
$$;

create or replace function public.ping_buddy_sos()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;
    -- Событие фиксируется сменой updated_at профиля.
    -- Пуш напарнику собирает клиент по последнему чекину и этому сигналу.
    update public.profiles
    set updated_at = now()
    where id = auth.uid();
end;
$$;

create or replace function public.create_squad(squad_name text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    code text;
    new_id uuid;
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;
    code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
    insert into public.squads (name, invite_code, created_by)
    values (squad_name, code, auth.uid())
    returning id into new_id;
    insert into public.squad_members (squad_id, user_id)
    values (new_id, auth.uid());
    update public.profiles set squad_id = new_id where id = auth.uid();
    return code;
end;
$$;

create or replace function public.join_squad(invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    found uuid;
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;
    select id into found from public.squads where squads.invite_code = join_squad.invite_code;
    if found is null then
        raise exception 'squad not found';
    end if;
    insert into public.squad_members (squad_id, user_id)
    values (found, auth.uid())
    on conflict do nothing;
    update public.profiles set squad_id = found where id = auth.uid();
    return found;
end;
$$;

create or replace function public.leave_squad()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;
    delete from public.squad_members where user_id = auth.uid();
    update public.profiles set squad_id = null where id = auth.uid();
end;
$$;

create or replace function public.fetch_current_buddy()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    result json;
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;
    select json_build_object(
        'id', p.id,
        'username', coalesce(p.username, 'Напарник'),
        'invite_code', coalesce(p.invite_code, ''),
        'streak_days', coalesce(p.current_streak_days, 0),
        'last_checkin_at', coalesce(p.last_checkin_at, p.updated_at),
        'buddy_id', p.buddy_id,
        'squad_id', p.squad_id
    )
    into result
    from public.profiles me
    join public.profiles p on p.id = me.buddy_id
    where me.id = auth.uid();
    return result;
end;
$$;

create or replace function public.fetch_user_squad()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    result json;
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;
    select json_build_object(
        'id', s.id,
        'name', s.name,
        'invite_code', s.invite_code,
        'member_count', (select count(*) from public.squad_members c where c.squad_id = s.id),
        'total_streak_days', (
            select coalesce(sum(p2.current_streak_days), 0)::int
            from public.squad_members c2
            join public.profiles p2 on p2.id = c2.user_id
            where c2.squad_id = s.id
        ),
        'members', coalesce((
            select json_agg(json_build_object(
                'user_id', m.user_id,
                'name', 'Участник',
                'streak_days', coalesce(p.current_streak_days, 0),
                'last_checkin', p.updated_at
            ))
            from public.squad_members m
            join public.profiles p on p.id = m.user_id
            where m.squad_id = s.id
        ), '[]'::json)
    )
    into result
    from public.squads s
    join public.squad_members me on me.squad_id = s.id and me.user_id = auth.uid()
    limit 1;
    return result;
end;
$$;

grant execute on function public.fetch_current_buddy() to authenticated;
grant execute on function public.fetch_user_squad() to authenticated;
grant execute on function public.create_buddy_invite() to authenticated;
grant execute on function public.accept_buddy_invite(text) to authenticated;
grant execute on function public.ping_buddy_sos() to authenticated;
grant execute on function public.create_squad(text) to authenticated;
grant execute on function public.join_squad(text) to authenticated;
grant execute on function public.leave_squad() to authenticated;

alter table public.profiles add column if not exists username text;
alter table public.profiles add column if not exists invite_code text;
alter table public.profiles add column if not exists buddy_id uuid;
alter table public.profiles add column if not exists squad_id uuid;
alter table public.profiles add column if not exists last_checkin_at timestamptz;
alter table public.profiles add column if not exists total_xp int not null default 0;
create unique index if not exists profiles_invite_code_key on public.profiles (invite_code);

create table if not exists public.buddy_pairs (
    id uuid primary key default gen_random_uuid(),
    user1_id uuid not null references auth.users (id) on delete cascade,
    user2_id uuid not null references auth.users (id) on delete cascade,
    status text not null default 'active' check (status in ('active', 'pending')),
    created_at timestamptz not null default now()
);

create table if not exists public.buddy_messages (
    id uuid primary key default gen_random_uuid(),
    sender_id uuid not null references auth.users (id) on delete cascade,
    receiver_id uuid not null references auth.users (id) on delete cascade,
    text text not null,
    created_at timestamptz not null default now()
);

alter table public.buddy_pairs enable row level security;
alter table public.buddy_messages enable row level security;

drop policy if exists "buddy_pairs_select" on public.buddy_pairs;
create policy "buddy_pairs_select"
    on public.buddy_pairs for select to authenticated
    using (user1_id = auth.uid() or user2_id = auth.uid());

drop policy if exists "buddy_messages_select" on public.buddy_messages;
create policy "buddy_messages_select"
    on public.buddy_messages for select to authenticated
    using (sender_id = auth.uid() or receiver_id = auth.uid());

drop policy if exists "buddy_messages_insert" on public.buddy_messages;
create policy "buddy_messages_insert"
    on public.buddy_messages for insert to authenticated
    with check (sender_id = auth.uid());

create or replace function public.ensure_invite_code()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    code text;
    result json;
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;
    select invite_code into code from public.profiles where id = auth.uid();
    if code is null or code in ('000000', 'ABCDEF', '') then
        code := '';
        while length(code) < 6 loop
            code := code || substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + floor(random() * 32)::int, 1);
        end loop;
        update public.profiles
        set invite_code = code,
            username = coalesce(username, 'Воин')
        where id = auth.uid();
    end if;
    select json_build_object(
        'id', id,
        'username', coalesce(username, 'Воин'),
        'invite_code', invite_code,
        'streak_days', current_streak_days,
        'last_checkin_at', coalesce(last_checkin_at, updated_at),
        'buddy_id', buddy_id,
        'squad_id', squad_id
    ) into result
    from public.profiles where id = auth.uid();
    return result;
end;
$$;

create or replace function public.pair_with_buddy(invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    other_id uuid;
    mine uuid := auth.uid();
    pair_id uuid;
begin
    if mine is null then
        raise exception 'not authenticated';
    end if;
    select id into other_id from public.profiles
    where profiles.invite_code = upper(pair_with_buddy.invite_code);
    if other_id is null then
        raise exception 'код не найден';
    end if;
    if other_id = mine then
        raise exception 'нельзя связаться с самим собой';
    end if;
    if exists (select 1 from public.profiles where id = mine and buddy_id is not null)
       or exists (select 1 from public.profiles where id = other_id and buddy_id is not null) then
        raise exception 'у кого-то уже есть напарник';
    end if;
    insert into public.buddy_pairs (user1_id, user2_id, status)
    values (mine, other_id, 'active')
    returning id into pair_id;
    update public.profiles set buddy_id = other_id where id = mine;
    update public.profiles set buddy_id = mine where id = other_id;
    return pair_id;
end;
$$;

create or replace function public.send_sos_push()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    partner uuid;
    who text;
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;
    select buddy_id, coalesce(username, 'Напарник') into partner, who
    from public.profiles where id = auth.uid();
    if partner is null then
        raise exception 'напарник не подключен';
    end if;
    insert into public.buddy_messages (sender_id, receiver_id, text)
    values (
        auth.uid(),
        partner,
        '🚨 Твой напарник ' || who || ' на грани срыва и нажал SOS! Поддержи его прямо сейчас!'
    );
end;
$$;

grant execute on function public.ensure_invite_code() to authenticated;
grant execute on function public.pair_with_buddy(text) to authenticated;
grant execute on function public.send_sos_push() to authenticated;
