-- Spartan Pro: поля подписки и защита от самовыдачи Pro.
-- Вставьте только этот файл в пустой SQL Editor и нажмите Run.

alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists is_pro boolean not null default false;
alter table public.profiles add column if not exists pro_expires_at timestamptz;
alter table public.profiles add column if not exists updated_at timestamptz not null default now();

create or replace function public.protect_pro_columns()
returns trigger
language plpgsql
as $$
begin
    if coalesce(auth.role(), '') is distinct from 'service_role' then
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

drop trigger if exists profiles_protect_pro_columns on public.profiles;
create trigger profiles_protect_pro_columns
    before insert or update on public.profiles
    for each row
    execute function public.protect_pro_columns();

do $$
begin
    if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'profiles'
    ) then
        alter publication supabase_realtime add table public.profiles;
    end if;
end $$;
