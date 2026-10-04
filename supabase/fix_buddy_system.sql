-- Строгая связка напарников по уникальному invite_code.
-- В SQL Editor очисти окно и вставь только этот файл.

alter table public.profiles add column if not exists username text;
alter table public.profiles add column if not exists invite_code text;
alter table public.profiles add column if not exists buddy_id uuid;
alter table public.profiles add column if not exists last_checkin_at timestamptz;
alter table public.profiles add column if not exists total_xp int not null default 0;
alter table public.profiles add column if not exists squad_id uuid;

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

alter table public.squads enable row level security;
alter table public.squad_members enable row level security;

alter table public.profiles drop constraint if exists unique_invite_code;
alter table public.profiles add constraint unique_invite_code unique (invite_code);

delete from public.profiles
where username ilike '%Марк%'
   or username ilike '%Mark%'
   or invite_code in ('000000', 'ABCDEF');

drop policy if exists "profiles_select_invite" on public.profiles;
create policy "profiles_select_invite"
    on public.profiles for select
    to authenticated
    using (invite_code is not null);

drop function if exists public.lookup_buddy_by_code(text);
create or replace function public.lookup_buddy_by_code(target_code text)
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
        'id', id,
        'username', coalesce(username, 'Напарник'),
        'invite_code', invite_code,
        'streak_days', coalesce(current_streak_days, 0),
        'last_checkin_at', coalesce(last_checkin_at, updated_at),
        'buddy_id', buddy_id,
        'squad_id', null
    )
    into result
    from public.profiles
    where invite_code = upper(trim(target_code))
    limit 1;
    return result;
end;
$$;

drop function if exists public.handle_pair_buddies(text);
create or replace function public.handle_pair_buddies(target_code text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    me uuid := auth.uid();
    other public.profiles%rowtype;
begin
    if me is null then
        raise exception 'not authenticated';
    end if;
    if length(upper(trim(target_code))) <> 6 then
        raise exception 'код не найден';
    end if;
    select * into other
    from public.profiles
    where invite_code = upper(trim(target_code))
    limit 1;
    if other.id is null then
        raise exception 'код не найден';
    end if;
    if other.id = me then
        raise exception 'нельзя связаться с самим собой';
    end if;
    if other.buddy_id is not null
       or exists (select 1 from public.profiles where id = me and buddy_id is not null) then
        raise exception 'этот пользователь уже имеет напарника';
    end if;
    update public.profiles set buddy_id = other.id where id = me;
    update public.profiles set buddy_id = me where id = other.id;
    return public.lookup_buddy_by_code(target_code);
end;
$$;

grant execute on function public.lookup_buddy_by_code(text) to authenticated;
grant execute on function public.handle_pair_buddies(text) to authenticated;

create or replace function public.guard_buddy_id()
returns trigger
language plpgsql
as $$
begin
    if new.buddy_id is distinct from old.buddy_id and current_user = 'authenticated' then
        raise exception 'buddy_id можно менять только через handle_pair_buddies';
    end if;
    return new;
end;
$$;

drop trigger if exists guard_buddy_id on public.profiles;
create trigger guard_buddy_id
    before update on public.profiles
    for each row execute function public.guard_buddy_id();

drop function if exists public.fetch_user_squad();
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
            select coalesce(sum(coalesce(p2.current_streak_days, 0)), 0)::int
            from public.squad_members c2
            join public.profiles p2 on p2.id = c2.user_id
            where c2.squad_id = s.id
        ),
        'members', coalesce((
            select json_agg(json_build_object(
                'user_id', m.user_id,
                'name', coalesce(p.username, 'Участник'),
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

drop function if exists public.create_squad(text);
create or replace function public.create_squad(squad_name text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    code text := '';
    new_id uuid;
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;
    if exists (select 1 from public.squad_members where user_id = auth.uid()) then
        raise exception 'у тебя уже есть сквад';
    end if;
    while length(code) < 6 loop
        code := code || substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + floor(random() * 32)::int, 1);
    end loop;
    insert into public.squads (name, invite_code, created_by)
    values (squad_name, code, auth.uid())
    returning id into new_id;
    insert into public.squad_members (squad_id, user_id)
    values (new_id, auth.uid());
    update public.profiles set squad_id = new_id where id = auth.uid();
    return code;
end;
$$;

drop function if exists public.join_squad(text);
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
    if length(upper(trim(invite_code))) <> 6 then
        raise exception 'код не найден';
    end if;
    select id into found
    from public.squads
    where squads.invite_code = upper(trim(join_squad.invite_code));
    if found is null then
        raise exception 'код не найден';
    end if;
    if exists (select 1 from public.squad_members where user_id = auth.uid() and squad_id <> found) then
        raise exception 'у тебя уже есть сквад';
    end if;
    insert into public.squad_members (squad_id, user_id)
    values (found, auth.uid())
    on conflict do nothing;
    update public.profiles set squad_id = found where id = auth.uid();
    return found;
end;
$$;

drop function if exists public.leave_squad();
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

grant execute on function public.fetch_user_squad() to authenticated;
grant execute on function public.create_squad(text) to authenticated;
grant execute on function public.join_squad(text) to authenticated;
grant execute on function public.leave_squad() to authenticated;
