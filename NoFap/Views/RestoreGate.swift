//
//  RestoreGate.swift
//  NoFap
//
//  Первый экран при новой установке: ищет на сервере копию прогресса этого
//  аккаунта (он мог прийти через связку ключей iCloud) и восстанавливает её
//  до того, как создадутся менеджеры. Без сети ждёт недолго и пускает
//  дальше — копию предложит позже, когда сервер ответит.
//

import SwiftUI

struct RestoreGate: View {

    @Environment(\.scenePhase) private var scenePhase

    @State private var backup = AppBackup()
    /// Меняется после восстановления — AppRoot пересоздаётся с новыми данными.
    @State private var generation = 0
    @State private var isChecking = !UserDefaults.standard.bool(forKey: "onboardingDone")
    @State private var isRestoring = false

    /// Сколько ждём сервер при первом запуске, прежде чем пустить в онбординг.
    private static let firstLaunchWait: Duration = .seconds(6)

    var body: some View {
        Group {
            if isChecking {
                searching
            } else {
                AppRoot()
                    .id(generation)
            }
        }
        .environment(backup)
        .task { await firstLaunch() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, !isChecking { Task { await lookForBackup() } }
        }
        .alert("Нашли твой прогресс", isPresented: Binding(
            get: { backup.offer != nil && !isRestoring },
            set: { if !$0 && !isRestoring { backup.offer = nil } }
        ), presenting: backup.offer) { found in
            Button("Восстановить") {
                isRestoring = true
                Task {
                    await backup.restore(found)
                    backup.offer = nil
                    generation += 1
                    isRestoring = false
                }
            }
            Button("Начать заново", role: .destructive) {
                Task { await backup.decline() }
            }
        } message: { found in
            Text("На сервере есть копия от \(found.savedAt.formatted(date: .long, time: .shortened)). Восстановить её? Данные на этом телефоне заменятся.")
        }
    }

    private var searching: some View {
        VStack(spacing: 16) {
            ProgressView().tint(Palette.gold)
            Text("Ищем твой прогресс…")
                .font(.system(size: 15))
                .foregroundStyle(Palette.ash)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StoneBackground())
    }

    /// Новая установка: восстанавливаем молча — это данные самого человека.
    private func firstLaunch() async {
        guard isChecking else {
            await lookForBackup()
            return
        }
        let result = await withTaskGroup(of: AppBackup.CheckResult.self) { group in
            group.addTask { await backup.check() }
            group.addTask {
                try? await Task.sleep(for: Self.firstLaunchWait)
                return .unknown
            }
            let first = await group.next() ?? .unknown
            group.cancelAll()
            return first
        }
        if case .restoreNow(let found) = result {
            await backup.restore(found)
        }
        isChecking = false
    }

    /// Приложением уже пользуются, а сервер ответил только сейчас —
    /// спрашиваем, прежде чем заменить данные.
    private func lookForBackup() async {
        guard backup.offer == nil else { return }
        if case .restoreNow(let found) = await backup.check() {
            backup.offer = found
        }
    }
}
