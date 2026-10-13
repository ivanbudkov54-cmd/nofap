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

    @Environment(Backend.self) private var backend
    @Environment(StreakManager.self) private var streak
    @Environment(SubscriptionManager.self) private var subscriptions
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
                    .font(Face.display(28, .semibold))
                    .foregroundStyle(Palette.marbleHigh)

                Text(phase == .email
                     ? "Укажите ваш email. На него будет оформлена подписка, а ваш текущий прогресс сохранится даже при смене телефона."
                     : "Мы отправили 6-значный код на \(email).")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.marble)
                    .fixedSize(horizontal: false, vertical: true)

                if phase == .email {
                    LatinEmailField(text: $email)
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
                        .foregroundStyle(Palette.goldLight)
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
                        ProgressView()
                    } else {
                        Text(phase == .email ? "Получить код" : "Подтвердить")
                    }
                }
                .buttonStyle(GoldButton())
                .disabled(isBusy || !canSubmit)

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
        case .email:
            Self.isValidEmail(email)
        case .code:
            code.count == 6
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
            try await backend.sendEmailCode(to: address)
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
            let userId = try await backend.confirmEmailCode(code, email: email, streak: streak)
            subscriptions.noteLinkedAccount(userId: userId, email: email)
            await subscriptions.checkSubscription(backend: backend)
            if purpose == .backup {
                router.toast = "Email успешно привязан. Прогресс синхронизирован."
            }
            dismiss()
        } catch let error as EmailLinkError {
            if case .profile = error, let userId = backend.currentUserId() {
                subscriptions.noteLinkedAccount(userId: userId, email: email)
                await subscriptions.checkSubscription(backend: backend)
                dismiss()
                return
            }
            message = error.localizedDescription
        } catch {
            message = "Нет подключения к сети. Проверьте интернет и попробуйте ещё раз."
        }
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

    private struct LatinEmailField: UIViewRepresentable {
        @Binding var text: String

        func makeUIView(context: Context) -> UITextField {
            let field = UITextField()
            field.delegate = context.coordinator
            field.font = .preferredFont(forTextStyle: .body)
            field.textColor = UIColor(red: 228 / 255, green: 231 / 255, blue: 239 / 255, alpha: 1)
            field.tintColor = UIColor(red: 240 / 255, green: 188 / 255, blue: 79 / 255, alpha: 1)
            field.attributedPlaceholder = NSAttributedString(
                string: "Email",
                attributes: [.foregroundColor: UIColor(white: 1, alpha: 0.45)]
            )
            field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
            applyKeyboard(field)
            return field
        }

        func updateUIView(_ field: UITextField, context: Context) {
            if field.text != text { field.text = text }
            applyKeyboard(field)
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(text: $text)
        }

        private func applyKeyboard(_ field: UITextField) {
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.spellCheckingType = .no
            field.smartQuotesType = .no
            field.smartDashesType = .no
            field.textContentType = .emailAddress
            field.keyboardType = .asciiCapable
            field.reloadInputViews()
        }

        final class Coordinator: NSObject, UITextFieldDelegate {
            var text: Binding<String>

            init(text: Binding<String>) {
                self.text = text
            }

            @objc func changed(_ field: UITextField) {
                text.wrappedValue = field.text ?? ""
            }

            func textFieldDidBeginEditing(_ textField: UITextField) {
                textField.keyboardType = .asciiCapable
                textField.reloadInputViews()
            }
        }
    }

    private static func isValidEmail(_ value: String) -> Bool {
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}
