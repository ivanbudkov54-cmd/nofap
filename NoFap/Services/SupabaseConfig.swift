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
    static let url = "https://jgshclcqetzfwoydrnmj.supabase.co"
    /// anon public key из того же экрана. Не service_role.
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impnc2hjbGNxZXR6ZndveWRybm1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAwOTU4MjksImV4cCI6MjEwNTY3MTgyOX0.8AEQl6ioZY8IMlrlC8FXtTgKpK16pbBBFRFGi1h_N34"

    static var isConfigured: Bool {
        url.hasPrefix("https://") && anonKey.count > 20 && !anonKey.hasPrefix("YOUR_")
    }

    static var projectURL: URL? {
        guard isConfigured else { return nil }
        return URL(string: url)
    }
}
