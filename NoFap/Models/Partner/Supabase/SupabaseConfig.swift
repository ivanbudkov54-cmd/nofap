//
//  SupabaseConfig.swift
//  NoFap
//
//  Координаты проекта Supabase. Пока поля пустые, приложение работает
//  только на телефоне, напарник — на локальной заглушке.
//
//  anon key не секретный: он в любом случае лежит внутри приложения.
//  Данные защищают политики Row Level Security и функции из
//  supabase/02_partner_squad.sql, а не скрытность ключа.
//

import Foundation

enum SupabaseConfig {

    /// Supabase Dashboard → Project Settings → API → Project URL,
    /// вида https://abcdefghijkl.supabase.co (без слэша в конце).
    static let url = "https://jgshclcqetzfwoydrnmj.supabase.co"

    /// Supabase Dashboard → Project Settings → API → anon public.
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impnc2hjbGNxZXR6ZndveWRybm1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAwOTU4MjksImV4cCI6MjEwNTY3MTgyOX0.8AEQl6ioZY8IMlrlC8FXtTgKpK16pbBBFRFGi1h_N34"

    static var isConfigured: Bool { !url.isEmpty && !anonKey.isEmpty }

    /// Запущен ли на сервере supabase/02_partner_squad.sql. Пока нет —
    /// напарник и сквад живут на заглушке, а стрик и дневник (01_core.sql)
    /// уже синхронизируются. После запуска SQL поставить true.
    static let partnerTablesReady = true
}
