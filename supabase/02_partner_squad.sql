-- ============================================================================
-- NoFap · напарник и сквад на Supabase
--
-- Как применить: сначала 01_core.sql (стрик, дневник, срывы, статьи), затем
-- этот файл: Supabase Dashboard → SQL Editor → вставить весь файл → Run.
-- Файл можно запускать повторно: он удаляет и пересоздаёт только свои
-- объекты (partner_*, squad*), таблиц из 01_core.sql не трогает. Данные
-- напарника и сквада при повторном запуске стираются.
-- Ещё нужно: Authentication → Sign In / Providers → Allow anonymous sign-ins.
--
-- Принцип: приложение только ЧИТАЕТ таблицы (и только то, что разрешают
-- политики RLS), а всё, что меняет данные, делают функции ниже. Так правила
-- «кто с кем в паре» и «кто что может» живут в одном месте, и обойти их,
-- написав в таблицу напрямую, нельзя: прямой записи у клиентов нет вовсе.
--
-- На сервере только то, что нужно напарнику: прозвище, число дней, цель,
-- день последней отметки, приглашения и переписка пары. Дневник, чекины,
-- триггеры и календарь остаются на телефоне.
-- ============================================================================

drop function if exists public.create_squad_invite();
drop function if exists public.cancel_squad_invite();
drop function if exists public.join_squad(text);
drop function if exists public.leave_squad();
drop function if exists public.send_squad_message(text, text);
drop table if exists public.squad_messages;
drop table if exists public.squad_invites;
drop table if exists public.squad_members;
drop table if exists public.squads;
drop function if exists public.ensure_profile();
drop function if exists public.publish_profile(text, int, int, text);
drop function if exists public.create_invite();
drop function if exists public.cancel_invite();
drop function if exists public.redeem_invite(text);
drop function if exists public.unpair();
drop function if exists public.send_message(text, text);
drop table if exists public.partner_messages;
drop table if exists public.partner_invites;
-- Вместе с таблицей уходят и её политики — только после этого можно
-- удалить функции, на которые политики ссылаются.
drop table if exists public.partner_profiles;
drop function if exists public.my_squad();
drop function if exists public.is_squad_mate(uuid);

-- ---------------------------------------------------------------------------
-- Таблицы
-- ---------------------------------------------------------------------------

create table public.partner_profiles (
    id                uuid primary key references auth.users (id) on delete cascade,
    nickname          text not null default 'Напарник'
                      check (char_length(nickname) between 1 and 32),
    current_streak    int  not null default 0 check (current_streak >= 0),
    goal_days         int  not null default 0 check (goal_days >= 0),
    last_check_in_day text check (last_check_in_day ~ '^\d{4}-\d{2}-\d{2}$'),
    -- Связь двусторонняя: у обоих в паре partner_id указывает друг на друга.
    -- Ставят и снимают её только функции redeem_invite и unpair.
    partner_id        uuid references public.partner_profiles (id) on delete set null,
    updated_at        timestamptz not null default now()
);

create table public.partner_invites (
    code       text primary key check (code ~ '^[A-HJ-NP-Z2-9]{6}$'),
    owner_id   uuid not null references public.partner_profiles (id) on delete cascade,
    expires_at timestamptz not null,
    created_at timestamptz not null default now()
);

create table public.partner_messages (
    id           uuid primary key default gen_random_uuid(),
    sender_id    uuid not null references public.partner_profiles (id) on delete cascade,
    recipient_id uuid not null references public.partner_profiles (id) on delete cascade,
    kind         text not null check (kind in ('text', 'sos', 'support')),
    body         text not null check (char_length(body) between 1 and 500),
    -- Время сервера, а не телефона: у двух людей часы расходятся.
    sent_at      timestamptz not null default now()
);

create index messages_pair_time on public.partner_messages (sender_id, recipient_id, sent_at);
create index invites_owner on public.partner_invites (owner_id);

-- Сквад: группа до четырёх человек. Отдельно от напарника — у сквада свой
-- состав, своё приглашение и свой общий чат.
create table public.squads (
    id         uuid primary key default gen_random_uuid(),
    created_at timestamptz not null default now()
);

create table public.squad_members (
    squad_id  uuid not null references public.squads (id) on delete cascade,
    -- unique: человек одновременно состоит максимум в одном скваде.
    user_id   uuid not null unique references public.partner_profiles (id) on delete cascade,
    joined_at timestamptz not null default now(),
    primary key (squad_id, user_id)
);

-- Многоразовое приглашение: одну ссылку отправляют нескольким людям,
-- она работает, пока не истечёт или пока в скваде есть места.
create table public.squad_invites (
    code       text primary key check (code ~ '^[A-HJ-NP-Z2-9]{6}$'),
    squad_id   uuid not null references public.squads (id) on delete cascade,
    expires_at timestamptz not null,
    created_at timestamptz not null default now()
);

create table public.squad_messages (
    id        uuid primary key default gen_random_uuid(),
    squad_id  uuid not null references public.squads (id) on delete cascade,
    sender_id uuid references public.partner_profiles (id) on delete set null,
    kind      text not null check (kind in ('text', 'sos', 'support')),
    body      text not null check (char_length(body) between 1 and 500),
    sent_at   timestamptz not null default now()
);

create index squad_messages_time on public.squad_messages (squad_id, sent_at);
create index squad_invites_squad on public.squad_invites (squad_id);

-- Помощники для политик. security definer — читают squad_members в обход
-- RLS: иначе политика профилей, заглядывающая в squad_members, упиралась
-- бы в политику самой squad_members, и проверки зациклились бы.
create function public.my_squad()
returns uuid
language sql stable security definer set search_path = public
as $$
    select squad_id from squad_members where user_id = auth.uid();
$$;

create function public.is_squad_mate(p_user uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
    select exists (
        select 1 from squad_members mine
        join squad_members theirs on theirs.squad_id = mine.squad_id
        where mine.user_id = auth.uid() and theirs.user_id = p_user
    );
$$;

-- ---------------------------------------------------------------------------
-- Доступ: только чтение, и только своё
-- ---------------------------------------------------------------------------

alter table public.partner_profiles       enable row level security;
alter table public.partner_invites        enable row level security;
alter table public.partner_messages       enable row level security;
alter table public.squads         enable row level security;
alter table public.squad_members  enable row level security;
alter table public.squad_invites  enable row level security;
alter table public.squad_messages enable row level security;

revoke all on public.partner_profiles, public.partner_invites, public.partner_messages,
              public.squads, public.squad_members, public.squad_invites, public.squad_messages
from anon, authenticated;
grant select on public.partner_profiles, public.partner_invites, public.partner_messages,
                public.squad_members, public.squad_invites, public.squad_messages
to authenticated;

-- Свой профиль — всегда. Чужой — если он сам указал меня напарником (без
-- взаимности никто не читает никого) или если мы в одном скваде. После
-- разрыва или выхода из сквада доступ пропадает сам.
create policy "partner_profiles: self, mutual partner or squad mate" on public.partner_profiles
    for select to authenticated
    using (id = auth.uid() or partner_id = auth.uid() or public.is_squad_mate(id));

create policy "squad_members: my squad" on public.squad_members
    for select to authenticated
    using (squad_id = public.my_squad());

create policy "squad_invites: my squad" on public.squad_invites
    for select to authenticated
    using (squad_id = public.my_squad());

create policy "squad_messages: my squad" on public.squad_messages
    for select to authenticated
    using (squad_id = public.my_squad());

-- Приглашение видит только тот, кто его создал. Принимают его по коду
-- через redeem_invite — перебрать или прочитать чужие коды нельзя.
create policy "partner_invites: own" on public.partner_invites
    for select to authenticated
    using (owner_id = auth.uid());

create policy "partner_messages: own conversation" on public.partner_messages
    for select to authenticated
    using (auth.uid() in (sender_id, recipient_id));

-- ---------------------------------------------------------------------------
-- Функции. security definer — работают в обход RLS, поэтому каждая сама
-- проверяет, кто её вызвал, и трогает только то, что ему разрешено.
-- Ошибки поднимаются кодами (code_not_found и т. п.) — приложение
-- переводит их в понятный человеку текст.
-- ---------------------------------------------------------------------------

create function public.ensure_profile()
returns void
language plpgsql security definer set search_path = public
as $$
begin
    if auth.uid() is null then raise exception 'not_authenticated'; end if;
    insert into partner_profiles (id) values (auth.uid()) on conflict (id) do nothing;
end;
$$;

create function public.publish_profile(
    p_nickname text, p_current_streak int, p_goal_days int, p_last_check_in_day text
)
returns void
language plpgsql security definer set search_path = public
as $$
begin
    if auth.uid() is null then raise exception 'not_authenticated'; end if;
    insert into partner_profiles (id, nickname, current_streak, goal_days, last_check_in_day, updated_at)
    values (auth.uid(), p_nickname, p_current_streak, p_goal_days, p_last_check_in_day, now())
    on conflict (id) do update set
        nickname          = excluded.nickname,
        current_streak    = excluded.current_streak,
        goal_days         = excluded.goal_days,
        last_check_in_day = excluded.last_check_in_day,
        updated_at        = now();
end;
$$;

-- Код генерируется на сервере криптостойким генератором: 32 символа без
-- I, O, 0, 1, шесть знаков — больше миллиарда вариантов.
create function public.create_invite()
returns public.partner_invites
language plpgsql security definer set search_path = public, extensions
as $$
declare
    alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    new_code text;
    result   partner_invites;
begin
    if auth.uid() is null then raise exception 'not_authenticated'; end if;
    insert into partner_profiles (id) values (auth.uid()) on conflict (id) do nothing;
    if exists (select 1 from partner_profiles where id = auth.uid() and partner_id is not null) then
        raise exception 'already_paired';
    end if;

    delete from partner_invites where owner_id = auth.uid();

    loop
        new_code := '';
        for i in 1..6 loop
            -- 256 делится на 32 без остатка — распределение равномерное.
            new_code := new_code || substr(alphabet, 1 + get_byte(gen_random_bytes(1), 0) % 32, 1);
        end loop;
        begin
            insert into partner_invites (code, owner_id, expires_at)
            values (new_code, auth.uid(), now() + interval '15 minutes')
            returning * into result;
            return result;
        exception when unique_violation then
            -- совпал с чужим кодом — пробуем другой
        end;
    end loop;
end;
$$;

create function public.cancel_invite()
returns void
language plpgsql security definer set search_path = public
as $$
begin
    if auth.uid() is null then raise exception 'not_authenticated'; end if;
    delete from partner_invites where owner_id = auth.uid();
end;
$$;

-- Принять код: связывает обоих за одну транзакцию и возвращает профиль
-- напарника. Пригласившему ничего не нужно подтверждать — его partner_id
-- выставляется здесь же, и он увидит пару при следующем опросе.
create function public.redeem_invite(p_code text)
returns public.partner_profiles
language plpgsql security definer set search_path = public
as $$
declare
    me      uuid := auth.uid();
    invite  partner_invites;
    partner partner_profiles;
begin
    if me is null then raise exception 'not_authenticated'; end if;

    select * into invite from partner_invites where code = upper(p_code) for update;
    if not found then raise exception 'code_not_found'; end if;
    if invite.owner_id = me then raise exception 'code_is_mine'; end if;
    if invite.expires_at <= now() then raise exception 'code_expired'; end if;

    insert into partner_profiles (id) values (me) on conflict (id) do nothing;
    if exists (select 1 from partner_profiles where id = me and partner_id is not null) then
        raise exception 'already_paired';
    end if;

    -- Блокируем обоих в одном порядке — два встречных приглашения не
    -- свяжут человека сразу с двумя.
    perform 1 from partner_profiles where id in (me, invite.owner_id) order by id for update;
    if exists (select 1 from partner_profiles where id = invite.owner_id and partner_id is not null) then
        raise exception 'code_already_used';
    end if;

    update partner_profiles set partner_id = invite.owner_id, updated_at = now() where id = me;
    update partner_profiles set partner_id = me, updated_at = now() where id = invite.owner_id
        returning * into partner;
    delete from partner_invites where owner_id in (me, invite.owner_id);

    return partner;
end;
$$;

-- Разорвать связь: снимает её у обоих и удаляет переписку. После этого
-- бывший напарник не читает ни профиль, ни сообщения — политики требуют
-- взаимности.
create function public.unpair()
returns void
language plpgsql security definer set search_path = public
as $$
declare
    me      uuid := auth.uid();
    partner uuid;
begin
    if me is null then raise exception 'not_authenticated'; end if;
    select partner_id into partner from partner_profiles where id = me;

    if partner is not null then
        update partner_profiles set partner_id = null, updated_at = now()
            where id = partner and partner_id = me;
        delete from partner_messages
            where (sender_id = me and recipient_id = partner)
               or (sender_id = partner and recipient_id = me);
    end if;
    update partner_profiles set partner_id = null, updated_at = now() where id = me;
    delete from partner_invites where owner_id = me;
end;
$$;

-- Отправить сообщение напарнику. Только взаимному: иначе можно было бы
-- писать кому угодно, узнав его идентификатор.
create function public.send_message(p_kind text, p_body text)
returns public.partner_messages
language plpgsql security definer set search_path = public
as $$
declare
    me      uuid := auth.uid();
    partner uuid;
    result  partner_messages;
begin
    if me is null then raise exception 'not_authenticated'; end if;
    select p.partner_id into partner
        from partner_profiles p
        join partner_profiles other on other.id = p.partner_id and other.partner_id = me
        where p.id = me;
    if partner is null then raise exception 'partner_gone'; end if;

    insert into partner_messages (sender_id, recipient_id, kind, body)
    values (me, partner, p_kind, p_body)
    returning * into result;
    return result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Сквад
-- ---------------------------------------------------------------------------

-- Пригласить в сквад. Если сквада ещё нет — создаёт его со мной внутри.
-- У сквада одно открытое приглашение: новое заменяет старое.
create function public.create_squad_invite()
returns public.squad_invites
language plpgsql security definer set search_path = public, extensions
as $$
declare
    alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    me       uuid := auth.uid();
    squad    uuid;
    new_code text;
    result   squad_invites;
begin
    if me is null then raise exception 'not_authenticated'; end if;
    insert into partner_profiles (id) values (me) on conflict (id) do nothing;

    select squad_id into squad from squad_members where user_id = me;
    if squad is null then
        insert into squads default values returning id into squad;
        insert into squad_members (squad_id, user_id) values (squad, me);
    end if;

    if (select count(*) from squad_members where squad_id = squad) >= 4 then
        raise exception 'squad_full';
    end if;

    delete from squad_invites where squad_id = squad;

    loop
        new_code := '';
        for i in 1..6 loop
            new_code := new_code || substr(alphabet, 1 + get_byte(gen_random_bytes(1), 0) % 32, 1);
        end loop;
        begin
            insert into squad_invites (code, squad_id, expires_at)
            values (new_code, squad, now() + interval '24 hours')
            returning * into result;
            return result;
        exception when unique_violation then
            -- совпал с чужим кодом — пробуем другой
        end;
    end loop;
end;
$$;

create function public.cancel_squad_invite()
returns void
language plpgsql security definer set search_path = public
as $$
begin
    if auth.uid() is null then raise exception 'not_authenticated'; end if;
    delete from squad_invites where squad_id = (select squad_id from squad_members where user_id = auth.uid());
end;
$$;

-- Вступить по коду. Приглашение многоразовое, места проверяются под
-- блокировкой сквада: два человека, вступающие одновременно, не займут
-- одно последнее место вдвоём.
create function public.join_squad(p_code text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
    me     uuid := auth.uid();
    invite squad_invites;
begin
    if me is null then raise exception 'not_authenticated'; end if;

    select * into invite from squad_invites where code = upper(p_code);
    if not found then raise exception 'code_not_found'; end if;
    if invite.expires_at <= now() then raise exception 'code_expired'; end if;

    insert into partner_profiles (id) values (me) on conflict (id) do nothing;
    perform 1 from squads where id = invite.squad_id for update;

    if exists (select 1 from squad_members where user_id = me) then
        if exists (select 1 from squad_members where user_id = me and squad_id = invite.squad_id) then
            return;   -- уже здесь — повторное открытие той же ссылки не ошибка
        end if;
        raise exception 'already_in_squad';
    end if;

    if (select count(*) from squad_members where squad_id = invite.squad_id) >= 4 then
        raise exception 'squad_full';
    end if;

    insert into squad_members (squad_id, user_id) values (invite.squad_id, me);
end;
$$;

-- Выйти. Последний вышедший удаляет сквад целиком — вместе с перепиской
-- и приглашением.
create function public.leave_squad()
returns void
language plpgsql security definer set search_path = public
as $$
declare
    me    uuid := auth.uid();
    squad uuid;
begin
    if me is null then raise exception 'not_authenticated'; end if;
    select squad_id into squad from squad_members where user_id = me;
    if squad is null then return; end if;

    delete from squad_members where user_id = me;
    if not exists (select 1 from squad_members where squad_id = squad) then
        delete from squads where id = squad;
    end if;
end;
$$;

create function public.send_squad_message(p_kind text, p_body text)
returns public.squad_messages
language plpgsql security definer set search_path = public
as $$
declare
    me     uuid := auth.uid();
    squad  uuid;
    result squad_messages;
begin
    if me is null then raise exception 'not_authenticated'; end if;
    select squad_id into squad from squad_members where user_id = me;
    if squad is null then raise exception 'not_in_squad'; end if;

    insert into squad_messages (squad_id, sender_id, kind, body)
    values (squad, me, p_kind, p_body)
    returning * into result;
    return result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Права на функции
-- ---------------------------------------------------------------------------

revoke all on function
    public.ensure_profile(), public.publish_profile(text, int, int, text),
    public.create_invite(), public.cancel_invite(), public.redeem_invite(text),
    public.unpair(), public.send_message(text, text),
    public.create_squad_invite(), public.cancel_squad_invite(), public.join_squad(text),
    public.leave_squad(), public.send_squad_message(text, text),
    public.my_squad(), public.is_squad_mate(uuid)
from public, anon;

grant execute on function
    public.ensure_profile(), public.publish_profile(text, int, int, text),
    public.create_invite(), public.cancel_invite(), public.redeem_invite(text),
    public.unpair(), public.send_message(text, text),
    public.create_squad_invite(), public.cancel_squad_invite(), public.join_squad(text),
    public.leave_squad(), public.send_squad_message(text, text),
    public.my_squad(), public.is_squad_mate(uuid)
to authenticated;
