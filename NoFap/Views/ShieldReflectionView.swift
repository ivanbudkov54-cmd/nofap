//
//  ShieldReflectionView.swift
//  NoFap
//
//  Щит стрика: срыв без обнуления, раз в месяц — но только после честного
//  разбора. Пока разбор не сохранён, щит не тратится и стрик не меняется:
//  закрыть окно — то же, что передумать.
//

import SwiftUI

struct ShieldReflectionView: View {

    @Environment(JournalManager.self) private var journal
    @Environment(StreakManager.self) private var streak
    @Environment(\.dismiss) private var dismiss

    @State private var trigger: ShieldTrigger?
    @State private var whenWhere = ""
    @State private var nextTime = ""
    @State private var confirmClose = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "щит стрика", color: Palette.gold)
                        Text("Разбор срыва")
                            .font(Face.display(26, .semibold))
                            .foregroundStyle(Palette.marbleHigh)
                        Text("Стрик останется на месте, если честно разобрать, что случилось. Щит — один раз в месяц.")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.ash)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        question("Что стало главным триггером?")
                        FlowLayout(spacing: 8) {
                            ForEach(ShieldTrigger.allCases) { item in
                                chip(item)
                            }
                        }
                    }

                    field("Когда и где это случилось?", text: $whenWhere)
                    field("Что сделаешь в следующий раз, когда накатит так же?", text: $nextTime)

                    Button("Сохранить разбор и стрик") { save() }
                        .buttonStyle(GoldButton())
                        .disabled(trigger == nil)
                        .opacity(trigger == nil ? 0.5 : 1)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.obsidian.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        confirmClose = true
                    } label: {
                        Image(systemName: "xmark").foregroundStyle(Palette.ash)
                    }
                    .accessibilityLabel("Закрыть")
                }
            }
            .alert("Закрыть без разбора?", isPresented: $confirmClose) {
                Button("Продолжить разбор", role: .cancel) {}
                Button("Закрыть", role: .destructive) { dismiss() }
            } message: {
                Text("Щит не потратится, но и стрик не сохранится. Срыв можно будет отметить заново.")
            }
        }
        .interactiveDismissDisabled()
        .presentationBackground(Palette.obsidian)
    }

    private func question(_ text: LocalizedStringResource) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Palette.marbleHigh)
    }

    private func chip(_ item: ShieldTrigger) -> some View {
        let selected = trigger == item
        return Button { trigger = item } label: {
            Text(item.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(selected ? Color(hex: 0x1A1405) : Palette.marbleHigh)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if selected {
                        Capsule().fill(.goldFill)
                    } else {
                        Capsule().strokeBorder(Palette.vein, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func field(_ title: LocalizedStringResource, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            question(title)
            TextField("Напиши здесь", text: text, axis: .vertical)
                .lineLimit(2...4)
                .foregroundStyle(Palette.marbleHigh)
                .padding(12)
                .background(Palette.basalt, in: .rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.vein, lineWidth: 1)
                }
        }
    }

    private func save() {
        guard let trigger, streak.useShield() else { return }

        var lines = [String(localized: "Триггер: \(trigger.title)")]
        let place = whenWhere.trimmingCharacters(in: .whitespacesAndNewlines)
        let plan = nextTime.trimmingCharacters(in: .whitespacesAndNewlines)
        if !place.isEmpty { lines.append(String(localized: "Когда и где: \(place)")) }
        if !plan.isEmpty { lines.append(String(localized: "В следующий раз: \(plan)")) }

        journal.addEntry(lines.joined(separator: "\n"), promptQuestion: JournalEntry.shieldBadge,
                         isShieldReview: true)
        // Срыв всё равно был — для «часов тяги» и сервера он настоящий.
        RelapseLog.record()
        dismiss()
    }
}

enum ShieldTrigger: String, CaseIterable, Identifiable {
    case stress, boredom, loneliness, fatigue, social, alcohol, other

    var id: Self { self }

    var title: String {
        switch self {
        case .stress:     String(localized: "Стресс")
        case .boredom:    String(localized: "Скука")
        case .loneliness: String(localized: "Одиночество")
        case .fatigue:    String(localized: "Усталость")
        case .social:     String(localized: "Соцсети")
        case .alcohol:    String(localized: "Алкоголь")
        case .other:      String(localized: "Другое")
        }
    }
}
