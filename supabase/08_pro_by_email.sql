-- Pro привязан к почте, а не только к uid: оплата на анонимном аккаунте
-- не пропадает после входа по email. Вставьте в SQL Editor и Run.

create table if not exists public.pro_grants (
    email text primary key,
    pro_expires_at timestamptz not null,
    updated_at timestamptz not null default now()
);

alter table public.pro_grants enable row level security;

revoke all on table public.pro_grants from public, anon, authenticated;
grant all on table public.pro_grants to service_role;

-- Триггер из 07_pro_subscription.sql: клиент сам себе Pro не пишет.
-- claim_pro — security definer, поэтому явно разрешаем запись флагом
-- app.allow_pro_write (только внутри этой функции, local к транзакции).
create or replace function public.protect_pro_columns()
returns trigger
language plpgsql
as $$
begin
    if coalesce(auth.role(), '') is distinct from 'service_role'
       and current_setting('app.allow_pro_write', true) is distinct from 'on' then
        if tg_op = 'INSERT' then
            new.is_pro := false;
            new.pro_expires_at := null;
        else
            new.is_pro := old.is_pro;
            new.pro_expires_at := old.pro_expires_at;
        end if;
    end if;
    return new;
end;
$$;

create or replace function public.record_pro_grant(p_email text, p_days integer default 30)
returns void
language plpgsql
security definer
set search_path to public
as $$
declare
    mail text := nullif(lower(trim(coalesce(p_email, ''))), '');
    until_at timestamptz;
begin
    if mail is null then
        return;
    end if;
    select greatest(coalesce(pro_expires_at, now()), now()) + make_interval(days => p_days)
      into until_at
      from public.pro_grants
     where email = mail;
    if until_at is null then
        until_at := now() + make_interval(days => p_days);
    end if;
    insert into public.pro_grants (email, pro_expires_at, updated_at)
    values (mail, until_at, now())
    on conflict (email) do update
        set pro_expires_at = excluded.pro_expires_at,
            updated_at = now();
end;
$$;

revoke all on function public.record_pro_grant(text, integer) from public, anon, authenticated;
grant execute on function public.record_pro_grant(text, integer) to service_role;

create or replace function public.claim_pro()
returns void
language plpgsql
security definer
set search_path to public
as $$
declare
    mail text := nullif(lower(trim(coalesce(auth.jwt() ->> 'email', ''))), '');
    uid uuid := auth.uid();
    grant_until timestamptz;
    current_until timestamptz;
begin
    if uid is null or mail is null then
        return;
    end if;
    select g.pro_expires_at into grant_until
      from public.pro_grants g
     where g.email = mail
       and g.pro_expires_at > now();
    if grant_until is null then
        return;
    end if;
    select pro_expires_at into current_until
      from public.profiles
     where id = uid;
    grant_until := greatest(coalesce(current_until, grant_until), grant_until);
    perform set_config('app.allow_pro_write', 'on', true);
    insert into public.profiles (id, email, is_pro, pro_expires_at, updated_at)
    values (uid, mail, true, grant_until, now())
    on conflict (id) do update
        set is_pro = true,
            pro_expires_at = excluded.pro_expires_at,
            email = coalesce(excluded.email, public.profiles.email),
            updated_at = now();
end;
$$;

revoke all on function public.claim_pro() from public, anon;
grant execute on function public.claim_pro() to authenticated, service_role;
