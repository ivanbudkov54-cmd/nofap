-- ============================================================================
-- NoFap · опыт аватара (XP)
--
-- Запустить после 01_core.sql: Supabase Dashboard → SQL Editor → Run.
-- Повторный запуск безопасен. Колонку пишет сам пользователь в свою строку
-- profiles — её уже защищают политики profiles_*_own из 01_core.sql.
-- ============================================================================

alter table public.profiles
    add column if not exists total_xp int not null default 0
    check (total_xp >= 0);
