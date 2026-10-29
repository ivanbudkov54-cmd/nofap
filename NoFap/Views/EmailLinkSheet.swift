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
    @State private var pastedLink = ""
    @State private var phase: Phase = .email
    @State private var isBusy = false
    @State private var message: String?
    @State private var secondsLeft = 0
    @State private var ticker: Task<Void, Never>?
    @FocusState private var fieldFocused: Bool

    private enum Phase {
        case email, wait
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(phase == .email ? "Сохраните прогресс" : "Откройте письмо")
                    .font(Face.display(26, .semibold))
                    .foregroundStyle(Palette.marbleHigh)

                Text(phase == .email
                     ? "Укажите ваш email. На него будет оформлена подписка, а ваш текущий прогресс сохранится даже при смене телефона."
                     : "На \(email) ушла ссылка. Не открывайте её в Safari — скопируйте из письма и вставьте сюда. Ссылка одноразовая.")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.marble)
                    .fixedSize(horizontal: false, vertical: true)

                if phase == .email {
                    LatinEmailField(text: $email)
                        .frame(height: 22)
                        .padding(14)
                        .background(Palette.basalt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    TextField("https://…/auth/v1/verify?token=…", text: $pastedLink)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .focused($fieldFocused)
                        .foregroundStyle(Palette.marbleHigh)
                        .padding(14)
                        .background(Palette.basalt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button {
                        Task { await confirmPastedLink() }
                    } label: {
                        if isBusy {
                            ProgressView().tint(Palette.onGold)
                        } else {
                            Text("Войти по ссылке")
                        }
                    }
                    .buttonStyle(GoldButton())
                    .disabled(isBusy || pastedLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(pastedLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)

                    Button(secondsLeft > 0 ? "Отправить снова через \(secondsLeft) с" : "Отправить ссылку снова") {
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

                if phase == .email {
                    Button {
                        Task { await sendCode() }
                    } label: {
                        if isBusy {
                            ProgressView().tint(Palette.onGold)
                        } else {
                            Text("Получить ссылку")
                        }
                    }
                    .buttonStyle(GoldButton())
                    .disabled(isBusy || !canSubmit)
                    .opacity(canSubmit ? 1 : 0.5)
                }

                Spacer()
            }
            .padding(20)
            // Содержимое прижато к верху, и клавиатура его не двигает.
            .ignoresSafeArea(.keyboard)
            .background(Palette.obsidian.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                        .foregroundStyle(Palette.ash)
                }
            }
        }
        // Только во весь экран: с половинной высотой клавиатура сперва
        // растягивала окно вверх, а на каждой букве оно дёргалось снова.
        .presentationDetents([.large])
        .onAppear { fieldFocused = true }
        .onChange(of: phase) { _, _ in fieldFocused = true }
        .onDisappear { ticker?.cancel() }
        .onChange(of: OpenRequest.shared.emailAuthCompleted) { _, done in
            guard done, phase == .wait else { return }
            OpenRequest.shared.emailAuthCompleted = false
            if purpose == .backup {
                router.toast = "Email успешно привязан. Прогресс синхронизирован."
            }
            dismiss()
        }
    }

    private var canSubmit: Bool {
        phase == .email && Self.isValidEmail(email)
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
            phase = .wait
            pastedLink = ""
            startTimer()
        } catch {
            message = (error as? LocalizedError)?.errorDescription
                ?? "Нет подключения к сети. Проверьте интернет и попробуйте ещё раз."
        }
    }

    private func confirmPastedLink() async {
        let raw = pastedLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: raw) else {
            message = "Вставьте ссылку целиком, начиная с https://"
            return
        }
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            let linked = try await SupabaseSession.shared.consumeVerifyURL(url)
            backend.forgetSyncState()
            if let linked, !linked.isEmpty { subscriptions.noteLinkedAccount(email: linked) }
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
        } catch {
            message = (error as? LocalizedError)?.errorDescription
                ?? "Ссылка не подошла. Запросите новую и вставьте её сюда, не открывая."
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

    private static func isValidEmail(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }
}

/// Поле почты с латинской ASCII-клавиатурой. `.emailAddress` на русской
/// системе оставляет кириллицу, и латиница в симуляторе не вводится.
private struct LatinEmailField: UIViewRepresentable {

    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = EnglishKeyboardField()
        field.delegate = context.coordinator
        field.keyboardType = .asciiCapable
        field.keyboardAppearance = .dark
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartDashesType = .no
        field.smartQuotesType = .no
        field.textContentType = .username
        field.returnKeyType = .done
        field.font = .systemFont(ofSize: 17)
        field.textColor = UIColor(Palette.marbleHigh)
        field.tintColor = UIColor(Palette.gold)
        field.attributedPlaceholder = NSAttributedString(
            string: "Email",
            attributes: [.foregroundColor: UIColor(Palette.ash)]
        )
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        DispatchQueue.main.async { field.becomeFirstResponder() }
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        if field.text != text { field.text = text }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func changed(_ field: UITextField) {
            text.wrappedValue = field.text ?? ""
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            field.resignFirstResponder()
            return true
        }
    }
}

private final class EnglishKeyboardField: UITextField {

    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first {
            $0.primaryLanguage?.hasPrefix("en") == true
        } ?? super.textInputMode
    }
}
