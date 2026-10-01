//
//  SupabaseConfig.swift
//  NoFap
//
//  Координаты проекта Supabase. Пока поля пустые, напарник работает на
//  локальной заглушке — приложение не ломается без сервера.
//
//  anon key не секретный: он в любом случае лежит внутри приложения.
//  Данные защищают политики Row Level Security и функции из
//  supabase/schema.sql, а не скрытность ключа.
//

import Foundation

enum SupabaseConfig {

    /// Supabase Dashboard → Project Settings → API → Project URL,
    /// вида https://abcdefghijkl.supabase.co (без слэша в конце).
    static let url = ""

    /// Supabase Dashboard → Project Settings → API → anon public.
    static let anonKey = ""

    static var isConfigured: Bool { !url.isEmpty && !anonKey.isEmpty }
}
