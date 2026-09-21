//
//  SurveyQuestionView.swift
//  NoFap
//
//  Один экран на все вопросы опроса. Плитки взяты у GoalPicker, но не его
//  сетка в три колонки: подписи вроде «В постели с телефоном» в неё не
//  влезают — нужны строки во всю ширину.
//

import SwiftUI

struct SurveyQuestionView<Option: SurveyOption>: View {

    /// Один вопрос отличается от другого только тем, во что пишется ответ,
    /// поэтому вместо двух почти одинаковых вью — один биндинг в двух видах.
    enum Selection {
        case single(Binding<Option?>)
        case multiple(Binding<Set<Option>>)
    }

    let index: Int
    let total: Int
    let title: LocalizedStringResource
    let selection: Selection

    /// Поле «своими словами» есть не у всех вопросов.
    var note: Binding<String>?
    var notePlaceholder: LocalizedStringResource = "Своими словами"

    @FocusState private var noteFocused: Bool

    private var isMultiple: Bool {
        if case .multiple = selection { return true }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Eyebrow(text: "вопрос \(index) из \(total)")

                Text(title)
                    .font(Face.display(26, .medium))
                    .foregroundStyle(.marbleFill)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if isMultiple {
                    Text("Можно выбрать несколько")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.ash)
                }

                VStack(spacing: 10) {
                    ForEach(Array(Option.allCases), id: \.self) { option in
                        row(option)
                    }
                }
                .padding(.top, 4)

                if let note {
                    noteField(note)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Вариант ответа

    private func row(_ option: Option) -> some View {
        let selected = isSelected(option)

        return Button {
            toggle(option)
            noteFocused = false
        } label: {
            Text(option.label)
                .font(Face.display(16, .medium))
                .foregroundStyle(selected ? Color(hex: 0x1A1405) : Palette.marbleHigh)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 14).fill(.goldFill)
                    } else {
                        RoundedRectangle(cornerRadius: 14).fill(Palette.basalt)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(selected ? Color.clear : Palette.vein, lineWidth: 1)
                }
        }
        // Заливка выбора остаётся мгновенной (состояние показывают сразу), но
        // отклик на само касание нужен: это единственный интерактивный элемент
        // на экране, и без него нажатие ощущается мёртвым.
        .buttonStyle(PressableRow())
    }

    private func isSelected(_ option: Option) -> Bool {
        switch selection {
        case .single(let value):    value.wrappedValue == option
        case .multiple(let chosen): chosen.wrappedValue.contains(option)
        }
    }

    private func toggle(_ option: Option) {
        switch selection {
        case .single(let value):
            value.wrappedValue = option
        case .multiple(let chosen):
            if chosen.wrappedValue.contains(option) {
                chosen.wrappedValue.remove(option)
            } else {
                chosen.wrappedValue.insert(option)
            }
        }
    }

    // MARK: - Своими словами

    private func noteField(_ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Кнопка «Далее» заблокирована, пока поле пустое, поэтому подпись
            // говорит об этом прямо: «и своими словами» читалось как
            // «по желанию», и человек не понимал, почему не пускает дальше.
            Eyebrow(text: "и своими словами — обязательно")

            TextField(notePlaceholder, text: text, axis: .vertical)
                .font(.system(size: 15))
                .foregroundStyle(Palette.marbleHigh)
                .lineLimit(2...5)
                .focused($noteFocused)
                .padding(14)
                .background(Palette.basalt, in: .rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(noteFocused ? Palette.gold : Palette.vein, lineWidth: 1)
                }
        }
        .padding(.top, 8)
    }
}

/// Нажатие на строку варианта: та же реакция, что у кнопок приложения.
private struct PressableRow: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}
