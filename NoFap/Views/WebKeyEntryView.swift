//
//  WebKeyEntryView.swift
//  NoFap
//
//  Ввод ключа из письма-чека Lemon Squeezy — вернуть Premium, оплаченный
//  на сайте, после переустановки или на новом телефоне.
//

import SwiftUI

struct WebKeyEntryView: View {

    @Environment(PremiumStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var key = ""
    @State private var isChecking = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Eyebrow(text: "premium с сайта", color: Palette.gold)
                Text("Ввести ключ")
                    .font(Face.display(22, .semibold))
                    .foregroundStyle(Palette.marbleHigh)
                Text("Ключ пришёл в письме с чеком после оплаты на сайте.")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.ash)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("Ключ из письма", text: $key)
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundStyle(Palette.marbleHigh)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(activate)
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(Palette.basalt, in: .rect(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(error == nil ? Palette.vein : Palette.garnet, lineWidth: 1)
                    }

                if let error {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.garnet)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 12) {
                Button(action: activate) {
                    if isChecking {
                        ProgressView().tint(Color(hex: 0x1A1405))
                    } else {
                        Text("Восстановить Premium")
                    }
                }
                .buttonStyle(GoldButton())
                .disabled(isEmpty || isChecking)
                .opacity(isEmpty ? 0.5 : 1)

                Button("Отмена") { dismiss() }
                    .buttonStyle(StoneButton())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .fittedSheet()
        .onChange(of: key) { _, _ in error = nil }
    }

    private var isEmpty: Bool { key.trimmingCharacters(in: .whitespaces).isEmpty }

    private func activate() {
        guard !isChecking else { return }
        isChecking = true
        Task {
            defer { isChecking = false }
            do {
                try await store.web.activate(key: key)
                dismiss()
            } catch let failure as WebPremium.KeyError {
                error = switch failure {
                case .invalid:      String(localized: "Такого ключа нет. Проверь, что скопировал его целиком.")
                case .expired:      String(localized: "Подписка по этому ключу закончилась.")
                case .foreignStore: String(localized: "Это ключ от другого магазина.")
                case .limitReached: String(localized: "Ключ уже включён на максимуме устройств. Напиши в поддержку — отвяжем старые.")
                case .network:      String(localized: "Нет связи. Попробуй ещё раз.")
                }
            } catch {
                self.error = String(localized: "Нет связи. Попробуй ещё раз.")
            }
        }
    }
}
