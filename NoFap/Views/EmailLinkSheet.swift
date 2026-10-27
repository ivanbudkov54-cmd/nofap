//
//  EmailLinkSheet.swift
//  NoFap
//
//  Привязка почты через код Supabase. После входа приложение только
//  обновляет статус доступа и не открывает сайт.
//

import SwiftUI
import UIKit

enum EmailLinkPurpose {
    case signIn
    case backup
}

struct EmailLinkSheet: View {

    let purpose: EmailLinkPurpose

    @Environment(CloudSync.self) private var backend
    @Environment(StreakManager.self) private var streak
    @Environment(JournalManager.self) private var journal
    @Environment(PremiumStore.self) private var subscriptions
    @Environment(AppBackup.self) private var backup
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var code = ""
    @State private var phase: Phase = .email
    @State private var isBusy = false
    @State private var message: String?
    @State private var secondsLeft = 0
    @State private var ticker: Task<Void, Never>?

    private enum Phase {
        case email, code
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(phase == .email ? "Сохраните прогресс" : "Введите код")
                    .font(Face.display(26, .semibold))
                    .foregroundStyle(Palette.marbleHigh)

                Text(phase == .email
                     ? "Укажите ваш email. На него будет оформлена подписка, а ваш текущий прогресс сохранится даже при смене телефона."
                     : "Мы отправили 6-значный код на \(email).")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.marble)
                    .fixedSize(horizontal: false, vertical: true)

                if phase == .email {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(Palette.marbleHigh)
                        .padding(14)
                        .background(Palette.basalt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    TextField("000000", text: $code)
                        .textContentType(.oneTimeCode)
                        .keyboardType(.numberPad)
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .padding(14)
                        .background(Palette.basalt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(Palette.marbleHigh)
                        .onChange(of: code) { _, value in
                            let digits = value.filter(\.isNumber)
                            code = String(digits.prefix(6))
                        }

                    Button(secondsLeft > 0 ? "Отправить снова через \(secondsLeft) с" : "Отправить код снова") {
                        Task { await sendCode() }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(secondsLeft > 0 ? Palette.ash : Palette.gold)
                    .disabled(secondsLeft > 0 || isBusy)
                }

                if let message {
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.gold)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Task {
                        if phase == .email {
                            await sendCode()
                        } else {
                            await confirm()
                        }
                    }
                } label: {
                    if isBusy {
                        ProgressView().tint(Palette.onGold)
                    } else {
                        Text(phase == .email ? "Получить код" : "Подтвердить")
                    }
                }
                .buttonStyle(GoldButton())
                .disabled(isBusy || !canSubmit)
                .opacity(canSubmit ? 1 : 0.5)

                Spacer()
            }
            .padding(20)
            .background(Palette.obsidian.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                        .foregroundStyle(Palette.ash)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onDisappear { ticker?.cancel() }
    }

    private var canSubmit: Bool {
        switch phase {
        case .email: Self.isValidEmail(email)
        case .code:  code.count == 6
        }
    }

    private func sendCode() async {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.isValidEmail(address) else {
            message = "Введите почту в формате name@example.com."
            return
        }
        email = address
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            try await SupabaseSession.shared.sendEmailCode(to: address)
            phase = .code
            startTimer()
        } catch {
            message = (error as? LocalizedError)?.errorDescription
                ?? "Нет подключения к сети. Проверьте интернет и попробуйте ещё раз."
        }
    }

    private func confirm() async {
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            try await SupabaseSession.shared.verifyEmailCode(email: email, code: code)
        } catch {
            message = (error as? LocalizedError)?.errorDescription
                ?? "Нет подключения к сети. Проверьте интернет и попробуйте ещё раз."
            return
        }
        // Теперь это другой аккаунт: сверка начинается заново, прогресс
        // либо возвращается из копии этого аккаунта, либо уходит в неё.
        backend.forgetSyncState()
        subscriptions.noteLinkedAccount(email: email)
        await subscriptions.checkSubscription()
        await backend.push(streak: streak)
        await backend.syncJournal(journal)
        switch await backup.check() {
        case .restoreNow(let found): backup.offer = found
        case .nothing:               await backup.upload(force: true)
        case .unknown:               break
        }
        if purpose == .backup {
            router.toast = "Email успешно привязан. Прогресс синхронизирован."
        }
        dismiss()
    }

    private func startTimer() {
        ticker?.cancel()
        secondsLeft = 60
        ticker = Task {
            while secondsLeft > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                secondsLeft -= 1
            }
        }
    }

    private static func isValidEmail(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }
}
