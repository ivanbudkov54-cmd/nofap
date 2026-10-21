//
//  SupabaseConfig.swift
//  NoFap
//
//  Плейсхолдеры публичного клиента. Anon key безопасно класть в приложение
//  только вместе с RLS из supabase/schema.sql — service_role сюда нельзя.
//

import Foundation

enum SupabaseConfig {
    /// Project URL из Supabase → Settings → API. Пример: https://xxxx.supabase.co
    static let url = "https://gmmwfxpoidtpwbtxgjbk.supabase.co"
    /// anon public key из того же экрана. Не service_role.
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdtbXdmeHBvaWR0cHdidHhnamJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgyODc2OTQsImV4cCI6MjEwMzg2MzY5NH0.qw8KEXu7q6I8FdwzNn2S1zqZnJ4tZ5IcBG7epVV-LGQ"

    static var isConfigured: Bool {
        url.hasPrefix("https://") && anonKey.count > 20 && !anonKey.hasPrefix("YOUR_")
    }

    static var projectURL: URL? {
        guard isConfigured else { return nil }
        return URL(string: url)
    }
}
