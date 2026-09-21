//
//  PartnerCodeEntry.swift
//  NoFap
//
//  Ввод кода напарника: шесть ячеек поверх одного скрытого поля.
//  Нормализация ровно как у своего числа в GoalPicker — заглавные,
//  посторонние знаки отсекаются, длина ограничена.
//

import SwiftUI

struct PartnerCodeEntry: View {

    @Binding var code: String
    var onComplete: (String) -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Настоящее поле спрятано: клавиатуру поднимает оно,
                // а видимые ячейки только отражают его содержимое.
                TextField("", text: $code)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .opacity(0.01)
                    .frame(height: 1)
                    .onChange(of: code) { _, raw in
                        let cleaned = PartnerCode.normalize(raw)
                        if cleaned != raw { code = cleaned }
                        if PartnerCode.isComplete(cleaned) {
                            focused = false
                            onComplete(cleaned)
                        }
                    }

                HStack(spacing: 8) {
                    ForEach(0..<PartnerCode.length, id: \.self) { index in
                        cell(at: index)
                    }
                }
                .contentShape(.rect)
                .onTapGesture { focused = true }
            }
        }
        .onAppear { focused = true }
    }

    private func cell(at index: Int) -> some View {
        let characters = Array(code)
        let value = index < characters.count ? String(characters[index]) : ""
        let isCursor = index == characters.count && focused

        return Text(value)
            .font(Face.display(22, .semibold))
            .foregroundStyle(Palette.marbleHigh)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Palette.basalt, in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isCursor ? Palette.gold : Palette.vein, lineWidth: 1)
            }
    }
}
